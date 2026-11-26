import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'rp_story_import.dart';
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
  }) : _accounts = StagedAccountService(auth: auth, firestore: firestore),
       _keys = StagedRoomKeyService(auth: auth, firestore: firestore),
       _upload = StagedStoryUploadService(firestore),
       _review = StagedStoryReviewService(firestore),
       _publish = StagedStoryPublishService(firestore, functions: functions);

  final StagedAccountService _accounts;
  final StagedRoomKeyService _keys;
  final StagedStoryUploadService _upload;
  final StagedStoryReviewService _review;
  final StagedStoryPublishService _publish;
  final _cipher = AesGcm.with256bits();

  Future<Map<String, String>> _encrypt(String text, SecretKey key) async {
    final box = await _cipher.encrypt(utf8.encode(text), secretKey: key);
    return {
      'cipher': base64.encode(box.cipherText + box.mac.bytes),
      'iv': base64.encode(box.nonce),
    };
  }

  Future<String?> _decrypt(String cipher, String iv, SecretKey key) async {
    final bytes = base64.decode(cipher);
    final nonce = base64.decode(iv);
    if (bytes.length < 16 || nonce.length != 12) {
      throw const FormatException('Invalid encrypted story field.');
    }
    return utf8.decode(
      await _cipher.decrypt(
        SecretBox(
          bytes.sublist(0, bytes.length - 16),
          nonce: nonce,
          mac: Mac(bytes.sublist(bytes.length - 16)),
        ),
        secretKey: key,
      ),
    );
  }

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
      encrypt: (text) => _encrypt(text, key),
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
      decrypt: (cipher, iv) => _decrypt(cipher, iv, key),
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
      decrypt: (cipher, iv) => _decrypt(cipher, iv, key),
    );
  }
}
