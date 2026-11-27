import 'package:cloud_firestore/cloud_firestore.dart';

import 'rp_story_export.dart';
import 'rp_story_import.dart';

class StagedStoryReview {
  StagedStoryReview._({
    required FirebaseFirestore firestore,
    required this.sessionId,
    required this.reviewerCode,
    required this.reviewVersion,
    required int metadataCount,
    required this.sourceSessionId,
    required this.exportedAt,
    required this.session,
    required this.posts,
  }) : _firestore = firestore,
       _metadataCount = metadataCount;

  final FirebaseFirestore _firestore;
  final String sessionId;
  final String reviewerCode;
  final int reviewVersion;
  final int _metadataCount;
  final String sourceSessionId;
  final DateTime exportedAt;
  final Map<String, dynamic> session;
  final List<StoryPost> posts;
}

/// Demo-project-only review of the staged story and its historical metadata.
class StagedStoryReviewService {
  StagedStoryReviewService(this._firestore) {
    if (!_firestore.app.options.projectId.startsWith('demo-')) {
      throw StateError('Staged reviews require a demo Firebase project.');
    }
  }

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _state(String sessionId) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId', 'Invalid room ID.');
    }
    return _firestore
        .collection('sessions_v2')
        .doc(sessionId)
        .collection('restore')
        .doc('state');
  }

  ({int version, int count, int metadataCount, String importer}) _reviewState(
    Map<String, dynamic>? data,
    String reviewerCode,
  ) {
    final version = data?['reviewVersion'];
    final count = data?['postCount'];
    final metadataCount = data?['metadataCount'];
    final importer = data?['importerCode'];
    if (data?['status'] != 'review' ||
        data?['reviewerCode'] != reviewerCode ||
        importer is! String ||
        importer.isEmpty ||
        importer == reviewerCode ||
        version is! int ||
        version < 1 ||
        count is! int ||
        count < 0 ||
        metadataCount is! int ||
        metadataCount < 1 ||
        metadataCount > 1000000) {
      throw StateError('This restore is not available for review.');
    }
    return (
      version: version,
      count: count,
      metadataCount: metadataCount,
      importer: importer,
    );
  }

  /// Fetches and decrypts every staged post and metadata chunk for review.
  ///
  /// Matching the declared count does not prove that the importer included
  /// every post in the backup; the importer must verify that separately.
  /// The decryptor must authenticate the ciphertext and fail on a wrong key.
  Future<StagedStoryReview> load({
    required String sessionId,
    required String reviewerCode,
    required StoryDecrypt decrypt,
  }) async {
    if (reviewerCode.isEmpty) {
      throw ArgumentError.value(
        reviewerCode,
        'reviewerCode',
        'Must not be empty.',
      );
    }
    final stateRef = _state(sessionId);
    const server = GetOptions(source: Source.server);
    final first = await stateRef.get(server);
    if (first.metadata.isFromCache || first.metadata.hasPendingWrites) {
      throw StateError('Restore changes are still syncing.');
    }
    final state = _reviewState(first.data(), reviewerCode);
    final snapshot = await stateRef.collection('posts').get(server);
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw StateError('Story changes are still syncing.');
    }
    if (snapshot.docs.length != state.count) {
      throw StateError('The staged story post count does not match.');
    }
    final metadataSnapshot = await stateRef.collection('metadata').get(server);
    if (metadataSnapshot.metadata.isFromCache ||
        metadataSnapshot.metadata.hasPendingWrites) {
      throw StateError('Story metadata changes are still syncing.');
    }
    final backupMetadata = await decodeStagedStoryMetadata(
      chunks: [
        for (final doc in metadataSnapshot.docs) StoryPost(doc.id, doc.data()),
      ],
      expectedCount: state.metadataCount,
      decrypt: decrypt,
    );

    final posts = await decryptStoryPosts(
      posts: [for (final doc in snapshot.docs) StoryPost(doc.id, doc.data())],
      decrypt: decrypt,
    );

    final last = await stateRef.get(server);
    if (last.metadata.isFromCache || last.metadata.hasPendingWrites) {
      throw StateError('Restore changes are still syncing.');
    }
    if (_reviewState(last.data(), reviewerCode) != state) {
      throw StateError('The restore changed. Load it again before reviewing.');
    }
    return StagedStoryReview._(
      firestore: _firestore,
      sessionId: sessionId,
      reviewerCode: reviewerCode,
      reviewVersion: state.version,
      metadataCount: state.metadataCount,
      sourceSessionId: backupMetadata.sessionId,
      exportedAt: backupMetadata.exportedAt,
      session: _freezeMap(backupMetadata.session),
      posts: List.unmodifiable(posts),
    );
  }

  /// The UI must ask the reviewer to inspect the loaded posts before deciding.
  Future<void> decide(StagedStoryReview review, {required bool approve}) async {
    if (!identical(review._firestore, _firestore)) {
      throw ArgumentError(
        'The review belongs to a different Firebase instance.',
      );
    }
    final stateRef = _state(review.sessionId);
    // Return validation errors before writing: FlutterFire can double-complete
    // the future when a transaction callback throws on Android.
    final error = await _firestore.runTransaction<String?>((transaction) async {
      final snapshot = await transaction.get(stateRef);
      ({int version, int count, int metadataCount, String importer}) state;
      try {
        state = _reviewState(snapshot.data(), review.reviewerCode);
      } on StateError catch (error) {
        return error.message;
      }
      if (state.version != review.reviewVersion ||
          state.count != review.posts.length ||
          state.metadataCount != review._metadataCount) {
        return 'The restore changed. Load it again before deciding.';
      }
      transaction.update(stateRef, {
        'status': approve ? 'approved' : 'rejected',
        'decisionVersion': review.reviewVersion,
      });
      return null;
    });
    if (error != null) throw StateError(error);
  }
}

Object? _freezeValue(Object? value) {
  if (value is List) return List.unmodifiable(value.map(_freezeValue));
  if (value is Map<String, dynamic>) return _freezeMap(value);
  return value;
}

Map<String, dynamic> _freezeMap(Map<String, dynamic> value) => Map.unmodifiable(
  value.map((key, value) => MapEntry(key, _freezeValue(value))),
);
