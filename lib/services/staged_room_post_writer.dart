import 'dart:ui' show Color;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'room_post_writer.dart';
import 'room_story_cipher.dart';
import 'staged_account_service.dart';
import 'staged_room_key_service.dart';

/// Encrypted room writes for the isolated migration project.
class StagedRoomPostWriter implements RoomPostWriter {
  StagedRoomPostWriter({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required StagedAccount account,
    required SimpleKeyPair identity,
  }) : _auth = auth,
       _firestore = firestore,
       _account = account,
       _identity = identity,
       _accounts = StagedAccountService(auth: auth, firestore: firestore),
       _keys = StagedRoomKeyService(auth: auth, firestore: firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final StagedAccount _account;
  final SimpleKeyPair _identity;
  final StagedAccountService _accounts;
  final StagedRoomKeyService _keys;
  final _cipher = RoomStoryCipher();
  static final _idPattern = RegExp(r'^[a-zA-Z0-9_-]{1,128}$');

  void _requireUser() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.uid != _account.uid) {
      throw StateError('The signed-in account changed.');
    }
  }

  Future<SecretKey> _key(String sessionId, {required bool create}) async {
    _requireUser();
    final account = await _accounts.currentAccount();
    if (account.uid != _account.uid ||
        account.code != _account.code ||
        account.name != _account.name) {
      throw StateError('The signed-in account changed.');
    }
    final key = create
        ? await _keys.getOrCreate(sessionId: sessionId, identity: _identity)
        : await _keys.load(sessionId: sessionId, identity: _identity);
    _requireUser();
    return key;
  }

  DocumentReference<Map<String, dynamic>> _post(
    String sessionId,
    String postId,
  ) {
    if (!_idPattern.hasMatch(sessionId) || !_idPattern.hasMatch(postId)) {
      throw ArgumentError('Invalid room or post ID.');
    }
    return _firestore
        .collection('sessions_v2')
        .doc(sessionId)
        .collection('posts')
        .doc(postId);
  }

  @override
  Future<String> addPost({
    required String sessionId,
    required String content,
    String? chapter,
    String? quotedPostId,
    String? quotedContent,
    String? contentRuns,
    String? quotedAuthor,
    String? characterName,
    String? locationName,
    Color? textColor,
  }) async {
    final key = await _key(sessionId, create: true);
    final encrypted = await _cipher.encrypt(content, key);
    final quote = quotedContent == null
        ? null
        : await _cipher.encrypt(quotedContent, key);
    final runs = contentRuns == null || contentRuns.isEmpty
        ? null
        : await _cipher.encrypt(contentRuns, key);
    _requireUser();
    final post = _firestore
        .collection('sessions_v2')
        .doc(sessionId)
        .collection('posts')
        .doc();
    await post.set({
      'authorCode': _account.code,
      'authorName': _account.name,
      'characterName': characterName,
      'locationName': locationName,
      'textColor': textColor?.toARGB32(),
      'content': encrypted['cipher']!,
      'contentIv': encrypted['iv']!,
      'contentRuns': runs?['cipher'],
      'contentRunsIv': runs?['iv'],
      'quotedPostId': quotedPostId,
      'quotedContent': quote?['cipher'],
      'quotedContentIv': quote?['iv'],
      'quotedAuthor': quotedAuthor,
      'encrypted': true,
      'chapter': chapter ?? 'Chapter 1',
      'createdAt': FieldValue.serverTimestamp(),
      'edited': false,
    });
    _requireUser();
    return post.id;
  }

  @override
  Future<void> editPost({
    required String sessionId,
    required String postId,
    String? contentRuns,
    required String newContent,
    Color? textColor,
  }) async {
    final post = _post(sessionId, postId);
    final key = await _key(sessionId, create: false);
    final encrypted = await _cipher.encrypt(newContent, key);
    final runs = contentRuns == null || contentRuns.isEmpty
        ? null
        : await _cipher.encrypt(contentRuns, key);
    _requireUser();
    await post.update({
      'content': encrypted['cipher']!,
      'contentIv': encrypted['iv']!,
      'textColor': textColor?.toARGB32(),
      'edited': true,
      'editedAt': FieldValue.serverTimestamp(),
      if (contentRuns != null) ...{
        'contentRuns': runs?['cipher'],
        'contentRunsIv': runs?['iv'],
      },
    });
    _requireUser();
  }

  @override
  Future<void> deletePost({
    required String sessionId,
    required String postId,
  }) async {
    final post = _post(sessionId, postId);
    await _key(sessionId, create: false);
    _requireUser();
    await post.delete();
    _requireUser();
  }
}
