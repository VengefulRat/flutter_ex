import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'rp_story_export.dart';
import 'rp_story_import.dart';

/// Demo-project-only publishing of an approved, verified story.
class StagedStoryPublishService {
  StagedStoryPublishService(
    this._firestore, {
    required FirebaseFunctions functions,
  }) : _functions = functions {
    if (!_firestore.app.options.projectId.startsWith('demo-') ||
        _functions.app.options.projectId != _firestore.app.options.projectId ||
        _functions.app.name != _firestore.app.name) {
      throw StateError('Staged publishing requires one demo Firebase project.');
    }
  }

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  static const _server = GetOptions(source: Source.server);
  static const _batchSize = 10;
  static const _batchBytes = 4 * 1024 * 1024;

  void _requireServer(SnapshotMetadata metadata) {
    if (metadata.isFromCache || metadata.hasPendingWrites) {
      throw StateError('Restore changes are still syncing.');
    }
  }

  /// Publishes only after checking the approved set against the original backup.
  ///
  /// Previously published matching documents are retained on retry. Conflicting
  /// or extra documents stop the restore without deleting existing room data.
  Future<void> publish({
    required String sessionId,
    required String importerCode,
    required RpStoryBackup backup,
    required Map<String, String> authorCodes,
    required StoryDecrypt decrypt,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(sessionId) ||
        importerCode.isEmpty) {
      throw ArgumentError('Invalid room or importer.');
    }
    final backupCopy = RpStoryBackup(
      sessionId: backup.sessionId,
      exportedAt: backup.exportedAt,
      session: Map.of(backup.session),
      posts: [
        for (final post in backup.posts)
          StoryPost(post.id, Map<String, dynamic>.from(post.data)),
      ],
    );
    final authorsCopy = Map<String, String>.from(authorCodes);
    if (backupCopy.session.keys.any(
      (field) => !rpStorySessionFields.contains(field),
    )) {
      throw const FormatException('The story has unsupported room metadata.');
    }
    Future<String> canonicalMetadata(RpStoryBackup value) => encodeRpStory(
      sessionId: value.sessionId,
      session: value.session,
      posts: [],
      decrypt: (_, _) async =>
          throw StateError('Unexpected encrypted metadata.'),
      exportedAt: value.exportedAt,
    );
    final expectedMetadata = await canonicalMetadata(backupCopy);
    final roomRef = _firestore.collection('sessions_v2').doc(sessionId);
    final room = await roomRef.get(_server);
    _requireServer(room.metadata);
    final participants = room.data()?['participants'];
    if (participants is! List ||
        participants.length != 2 ||
        participants.any((code) => code is! String) ||
        !participants.contains(importerCode)) {
      throw StateError('The target room has invalid participants.');
    }
    final participantCodes = participants.cast<String>().toSet();
    if (participantCodes.length != 2) {
      throw StateError('The target room has invalid participants.');
    }

    final stateRef = roomRef.collection('restore').doc('state');
    final stateSnapshot = await stateRef.get(_server);
    _requireServer(stateSnapshot.metadata);
    final state = stateSnapshot.data();
    final version = state?['reviewVersion'];
    final count = state?['postCount'];
    final metadataCount = state?['metadataCount'];
    if (!['approved', 'completed'].contains(state?['status']) ||
        state?['importerCode'] != importerCode ||
        state?['reviewerCode'] is! String ||
        !participantCodes.contains(state?['reviewerCode']) ||
        state?['reviewerCode'] == importerCode ||
        version is! int ||
        version < 1 ||
        state?['decisionVersion'] != version ||
        count is! int ||
        count < 0 ||
        metadataCount is! int ||
        metadataCount < 1) {
      throw StateError('The restore is not approved for publishing.');
    }

    final stagedPosts = await stateRef.collection('posts').get(_server);
    _requireServer(stagedPosts.metadata);
    final posts = [
      for (final doc in stagedPosts.docs) StoryPost(doc.id, doc.data()),
    ];
    if (posts.length != count) {
      throw StateError('The approved post count does not match.');
    }
    await verifyRpStoryBackupPosts(
      backup: backupCopy,
      authorCodes: authorsCopy,
      targetParticipants: participantCodes,
      staged: posts,
      decrypt: decrypt,
    );
    final stagedMetadata = await stateRef.collection('metadata').get(_server);
    _requireServer(stagedMetadata.metadata);
    final chunks = [
      for (final doc in stagedMetadata.docs) StoryPost(doc.id, doc.data()),
    ];
    final actualMetadata = await decodeStagedStoryMetadata(
      chunks: chunks,
      expectedCount: metadataCount,
      decrypt: decrypt,
    );
    if (await canonicalMetadata(actualMetadata) != expectedMetadata) {
      throw const FormatException(
        'The approved room metadata does not match the backup.',
      );
    }
    if (state!['status'] == 'completed') return;

    final livePosts = roomRef.collection('posts');
    final liveMetadata = roomRef.collection('story_metadata');
    Future<List<StoryPost>> read(
      CollectionReference<Map<String, dynamic>> ref,
    ) async {
      final snapshot = await ref.get(_server);
      _requireServer(snapshot.metadata);
      return [for (final doc in snapshot.docs) StoryPost(doc.id, doc.data())];
    }

    List<StoryPost> missing(
      List<StoryPost> expected,
      List<StoryPost> existing,
    ) {
      final byId = {for (final post in expected) post.id: post};
      final matching = <StoryPost>[];
      for (final post in existing) {
        final approved = byId.remove(post.id);
        if (approved == null) {
          throw FormatException(
            'Room contains an unexpected document: ${post.id}.',
          );
        }
        matching.add(approved);
      }
      verifyRpStoryPostSet(expected: matching, actual: existing);
      return byId.values.toList();
    }

    final remainingPosts = missing(posts, await read(livePosts));
    final remainingMetadata = missing(chunks, await read(liveMetadata));
    var batch = _firestore.batch();
    var batchCount = 0;
    var batchBytes = 0;
    Future<void> flush() async {
      if (batchCount == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      batchCount = 0;
      batchBytes = 0;
    }

    Future<void> add(
      CollectionReference<Map<String, dynamic>> collection,
      List<StoryPost> remaining,
    ) async {
      for (final post in remaining) {
        final ref = collection.doc(post.id);
        var size = 1024 + utf8.encode(ref.path).length;
        for (final entry in post.data.entries) {
          size += utf8.encode(entry.key).length + 32;
          if (entry.value is String) {
            size += utf8.encode(entry.value as String).length;
          }
        }
        if (batchCount == _batchSize || batchBytes + size > _batchBytes) {
          await flush();
        }
        batch.set(ref, post.data);
        batchCount++;
        batchBytes += size;
      }
    }

    await add(livePosts, remainingPosts);
    await add(liveMetadata, remainingMetadata);
    await flush();
    verifyRpStoryPostSet(expected: posts, actual: await read(livePosts));
    verifyRpStoryPostSet(expected: chunks, actual: await read(liveMetadata));
    final response = await _functions
        .httpsCallable(
          'finalizeStagedRestore',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 560)),
        )
        .call<Map<String, dynamic>>({
          'sessionId': sessionId,
          'reviewVersion': version,
        });
    if (response.data['status'] != 'completed') {
      throw StateError('The restore finalizer returned an invalid response.');
    }
    final finished = await stateRef.get(_server);
    _requireServer(finished.metadata);
    final current = finished.data();
    if (current == null ||
        current['status'] != 'completed' ||
        current['importerCode'] != importerCode ||
        current['reviewerCode'] != state['reviewerCode'] ||
        current['reviewVersion'] != version ||
        current['decisionVersion'] != version ||
        current['postCount'] != count ||
        current['metadataCount'] != metadataCount) {
      throw StateError('The restore was not finalized as expected.');
    }
  }
}
