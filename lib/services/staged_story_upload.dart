import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'rp_story_export.dart';
import 'rp_story_import.dart';

/// Demo-project-only story staging. Key sharing and publishing are separate.
class StagedStoryUploadService {
  StagedStoryUploadService(this._firestore) {
    if (!_firestore.app.options.projectId.startsWith('demo-')) {
      throw StateError('Staged uploads require a demo Firebase project.');
    }
  }

  final FirebaseFirestore _firestore;
  static const _server = GetOptions(source: Source.server);
  static const _batchSize = 400;
  static const _batchBytes = 4 * 1024 * 1024;
  static const _documentBytes = 900000;
  static const _metadataChunkSize = 32768;

  void _requireServer(SnapshotMetadata metadata) {
    if (metadata.isFromCache || metadata.hasPendingWrites) {
      throw StateError('Restore changes are still syncing.');
    }
  }

  /// Prepares the complete backup, uploads it, then freezes and verifies it.
  ///
  /// Retrying an interrupted upload or verification replaces only staged data.
  /// Once a review has been requested, it cannot be restarted without rejection.
  Future<void> stage({
    required String sessionId,
    required String importerCode,
    required String reviewerCode,
    required RpStoryBackup backup,
    required Map<String, String> authorCodes,
    required StoryEncrypt encrypt,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId', 'Invalid room ID.');
    }
    if (importerCode.isEmpty ||
        reviewerCode.isEmpty ||
        importerCode == reviewerCode) {
      throw ArgumentError('The importer and reviewer must be different.');
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
    final metadataJson = await encodeRpStory(
      sessionId: backupCopy.sessionId,
      session: backupCopy.session,
      posts: [],
      decrypt: (_, _) async => throw StateError('Unexpected encrypted metadata.'),
      exportedAt: backupCopy.exportedAt,
    );
    decodeRpStory(metadataJson);
    final roomRef = _firestore.collection('sessions_v2').doc(sessionId);
    final room = await roomRef.get(_server);
    _requireServer(room.metadata);
    final participants = room.data()?['participants'];
    if (participants is! List ||
        participants.length != 2 ||
        participants.any((code) => code is! String) ||
        !participants.contains(importerCode) ||
        !participants.contains(reviewerCode)) {
      throw StateError('The target room does not have both participants.');
    }
    final prepared = await prepareRpStoryPosts(
      backup: backupCopy,
      authorCodes: authorsCopy,
      targetParticipants: participants.cast<String>().toSet(),
      encrypt: encrypt,
    );
    verifyRpStoryPostSet(expected: prepared, actual: prepared);
    for (final post in prepared) {
      for (final field in ['createdAt', 'editedAt']) {
        final value = post.data[field];
        if (value is Timestamp && value.nanoseconds % 1000 != 0) {
          throw FormatException(
            'Post ${post.id} has a timestamp Firestore cannot preserve exactly.',
          );
        }
      }
    }
    final metadata = <StoryPost>[];
    for (var start = 0; start < metadataJson.length;) {
      var end = start + _metadataChunkSize;
      if (end > metadataJson.length) end = metadataJson.length;
      if (end < metadataJson.length &&
          metadataJson.codeUnitAt(end - 1) >= 0xd800 &&
          metadataJson.codeUnitAt(end - 1) <= 0xdbff &&
          metadataJson.codeUnitAt(end) >= 0xdc00 &&
          metadataJson.codeUnitAt(end) <= 0xdfff) {
        end--;
      }
      final encrypted = await encryptStoryField(
        plaintext: metadataJson.substring(start, end),
        encrypt: encrypt,
        context: 'story metadata',
      );
      metadata.add(
        StoryPost(metadata.length.toString().padLeft(6, '0'), {
          'cipher': encrypted.cipher,
          'iv': encrypted.iv,
        }),
      );
      start = end;
    }
    if (metadata.length > 1000000) {
      throw const FormatException('The story metadata is too large to stage.');
    }

    final stateRef = roomRef.collection('restore').doc('state');
    final postsRef = stateRef.collection('posts');
    final metadataRef = stateRef.collection('metadata');
    int writeSize(String path, Map<String, dynamic> data) {
      var size = 1024 + utf8.encode(path).length;
      for (final entry in data.entries) {
        size += utf8.encode(entry.key).length + 32;
        if (entry.value is String) {
          size += utf8.encode(entry.value as String).length;
        }
      }
      return size;
    }

    for (final entry in [
      for (final post in prepared) (ref: postsRef, post: post),
      for (final chunk in metadata) (ref: metadataRef, post: chunk),
    ]) {
      final id = entry.post.id;
      if (id == '.' ||
          id == '..' ||
          RegExp(r'^__.*__$').hasMatch(id) ||
          utf8.encode(id).length > 1500 ||
          writeSize('${entry.ref.path}/$id', entry.post.data) > _documentBytes) {
        throw FormatException('Story document $id is too large or has an invalid ID.');
      }
    }
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(stateRef);
      if (!snapshot.exists) {
        transaction.set(stateRef, {
          'status': 'uploading',
          'importerCode': importerCode,
          'reviewerCode': reviewerCode,
          'postCount': prepared.length,
          'metadataCount': metadata.length,
          'reviewVersion': 0,
          'decisionVersion': 0,
        });
        return;
      }
      final data = snapshot.data()!;
      if (data['importerCode'] != importerCode ||
          data['reviewerCode'] != reviewerCode ||
          !['uploading', 'verifying', 'rejected'].contains(data['status']) ||
          data['reviewVersion'] is! int ||
          data['decisionVersion'] is! int) {
        throw StateError('The existing restore cannot be restarted.');
      }
      transaction.update(stateRef, {
        'status': 'uploading',
        'postCount': prepared.length,
        'metadataCount': metadata.length,
      });
    });

    var batch = _firestore.batch();
    var count = 0;
    var bytes = 0;
    Future<void> flush() async {
      if (count == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      count = 0;
      bytes = 0;
    }

    Future<void> replace(
      CollectionReference<Map<String, dynamic>> collection,
      List<StoryPost> expected,
    ) async {
      final existing = await collection.get(_server);
      _requireServer(existing.metadata);
      final ids = expected.map((post) => post.id).toSet();
      for (final post in existing.docs) {
        if (ids.contains(post.id)) continue;
        final size = 1024 + utf8.encode(post.reference.path).length;
        if (count == _batchSize || bytes + size > _batchBytes) await flush();
        batch.delete(post.reference);
        count++;
        bytes += size;
      }
      for (final post in expected) {
        final ref = collection.doc(post.id);
        final size = writeSize(ref.path, post.data);
        if (count == _batchSize || bytes + size > _batchBytes) await flush();
        batch.set(ref, post.data);
        count++;
        bytes += size;
      }
    }

    await replace(postsRef, prepared);
    await replace(metadataRef, metadata);
    await flush();

    final version = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(stateRef);
      final data = snapshot.data();
      if (data == null ||
          data['status'] != 'uploading' ||
          data['importerCode'] != importerCode ||
          data['reviewerCode'] != reviewerCode ||
          data['postCount'] != prepared.length ||
          data['metadataCount'] != metadata.length ||
          data['reviewVersion'] is! int ||
          (data['reviewVersion'] as int) >= 9007199254740991) {
        throw StateError('The restore changed during upload.');
      }
      final version = (data['reviewVersion'] as int) + 1;
      transaction.update(stateRef, {
        'status': 'verifying',
        'reviewVersion': version,
      });
      return version;
    });

    final frozen = await postsRef.get(_server);
    _requireServer(frozen.metadata);
    verifyRpStoryPostSet(
      expected: prepared,
      actual: [for (final post in frozen.docs) StoryPost(post.id, post.data())],
    );
    final frozenMetadata = await metadataRef.get(_server);
    _requireServer(frozenMetadata.metadata);
    verifyRpStoryPostSet(
      expected: metadata,
      actual: [
        for (final chunk in frozenMetadata.docs) StoryPost(chunk.id, chunk.data()),
      ],
    );
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(stateRef);
      final data = snapshot.data();
      if (data == null ||
          data['status'] != 'verifying' ||
          data['importerCode'] != importerCode ||
          data['reviewerCode'] != reviewerCode ||
          data['postCount'] != prepared.length ||
          data['metadataCount'] != metadata.length ||
          data['reviewVersion'] != version) {
        throw StateError('The restore changed during verification.');
      }
      transaction.update(stateRef, {'status': 'review'});
    });
  }
}
