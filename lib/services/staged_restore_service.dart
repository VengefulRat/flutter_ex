import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'rp_story_export.dart';
import 'rp_story_import.dart';
import 'room_story_cipher.dart';
import 'staged_account_service.dart';
import 'staged_room_key_service.dart';
import 'staged_story_publish.dart';
import 'staged_story_review.dart';
import 'staged_story_upload.dart';

/// Coordinates the demo-only restore services using the shared room key.
class StagedRestoreService {
  StagedRestoreService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _auth = auth,
       _firestore = firestore,
       _accounts = StagedAccountService(auth: auth, firestore: firestore),
       _keys = StagedRoomKeyService(auth: auth, firestore: firestore),
       _upload = StagedStoryUploadService(firestore),
       _review = StagedStoryReviewService(firestore),
       _publish = StagedStoryPublishService(firestore, functions: functions);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final StagedAccountService _accounts;
  final StagedRoomKeyService _keys;
  final StagedStoryUploadService _upload;
  final StagedStoryReviewService _review;
  final StagedStoryPublishService _publish;
  final _cipher = RoomStoryCipher();

  Future<void> stage({
    required String sessionId,
    required String reviewerCode,
    required SimpleKeyPair identity,
    required RpStoryBackup backup,
    required Map<String, String> authorCodes,
  }) async {
    final account = await _accounts.currentAccount();
    final key = await _keys.getOrCreate(
      sessionId: sessionId,
      identity: identity,
    );
    await _upload.stage(
      sessionId: sessionId,
      importerCode: account.code,
      reviewerCode: reviewerCode,
      backup: backup,
      authorCodes: authorCodes,
      encrypt: (text) => _cipher.encrypt(text, key),
    );
  }

  Future<StagedStoryReview> loadReview({
    required String sessionId,
    required SimpleKeyPair identity,
  }) async {
    final account = await _accounts.currentAccount();
    final key = await _keys.load(sessionId: sessionId, identity: identity);
    return _review.load(
      sessionId: sessionId,
      reviewerCode: account.code,
      decrypt: (cipher, iv) => _cipher.decrypt(cipher, iv, key),
    );
  }

  Future<void> decide(StagedStoryReview review, {required bool approve}) async {
    final account = await _accounts.currentAccount();
    if (account.code != review.reviewerCode) {
      throw StateError('The signed-in account is not the review recipient.');
    }
    await _review.decide(review, approve: approve);
  }

  Future<void> publish({
    required String sessionId,
    required SimpleKeyPair identity,
    required RpStoryBackup backup,
    required Map<String, String> authorCodes,
  }) async {
    final account = await _accounts.currentAccount();
    final key = await _keys.load(sessionId: sessionId, identity: identity);
    await _publish.publish(
      sessionId: sessionId,
      importerCode: account.code,
      backup: backup,
      authorCodes: authorCodes,
      decrypt: (cipher, iv) => _cipher.decrypt(cipher, iv, key),
    );
  }

  /// Loads a completed restore as decrypted maps for the existing room view.
  Future<List<Map<String, dynamic>>> loadPublishedPosts({
    required String sessionId,
    required SimpleKeyPair identity,
  }) async {
    final account = await _accounts.currentAccount();
    final key = await _keys.load(sessionId: sessionId, identity: identity);
    final room = _firestore.collection('sessions_v2').doc(sessionId);
    final stateRef = room.collection('restore').doc('state');
    const server = GetOptions(source: Source.server);

    Future<int> completedVersion() async {
      final snapshot = await stateRef.get(server);
      final data = snapshot.data();
      final version = data?['reviewVersion'];
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        throw StateError('Restore changes are still syncing.');
      }
      if (data?['status'] != 'completed' ||
          version is! int ||
          version < 1 ||
          data?['decisionVersion'] != version) {
        throw StateError('The story restore is not complete.');
      }
      return version;
    }

    final version = await completedVersion();
    final snapshot = await room.collection('posts').get(server);
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw StateError('Story changes are still syncing.');
    }
    final posts = await decryptStoryPosts(
      posts: [for (final doc in snapshot.docs) StoryPost(doc.id, doc.data())],
      decrypt: (cipher, iv) => _cipher.decrypt(cipher, iv, key),
    );
    if (await completedVersion() != version) {
      throw StateError('The restore changed. Load the story again.');
    }
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.uid != account.uid) {
      throw StateError('The signed-in account changed.');
    }
    return List.unmodifiable([
      for (final post in posts)
        Map<String, dynamic>.unmodifiable({...post.data, 'id': post.id}),
    ]);
  }
}
