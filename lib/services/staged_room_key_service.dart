import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'staged_account_service.dart';
import 'staged_room_keys.dart';

/// Demo-project-only distribution of one room key to both participants.
class StagedRoomKeyService {
  StagedRoomKeyService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore,
       _accounts = StagedAccountService(auth: auth, firestore: firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final StagedAccountService _accounts;
  static const _server = GetOptions(source: Source.server);

  void _requireUser(String uid) {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.uid != uid) {
      throw StateError('The signed-in account changed.');
    }
  }

  void _requireServer(SnapshotMetadata metadata) {
    if (metadata.isFromCache || metadata.hasPendingWrites) {
      throw StateError('Room key changes are still syncing.');
    }
  }

  /// Atomically creates both envelopes, or opens the existing pair on retry.
  Future<SecretKey> getOrCreate({
    required String sessionId,
    required SimpleKeyPair identity,
  }) => _resolve(sessionId: sessionId, identity: identity, create: true);

  /// Opens existing envelopes without creating a key.
  Future<SecretKey> load({
    required String sessionId,
    required SimpleKeyPair identity,
  }) => _resolve(sessionId: sessionId, identity: identity, create: false);

  Future<SecretKey> _resolve({
    required String sessionId,
    required SimpleKeyPair identity,
    required bool create,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId', 'Invalid room ID.');
    }
    final account = await _accounts.currentAccount();
    final roomRef = _firestore.collection('sessions_v2').doc(sessionId);
    final room = await roomRef.get(_server);
    _requireServer(room.metadata);
    final rawParticipants = room.data()?['participants'];
    if (rawParticipants is! List ||
        rawParticipants.length != 2 ||
        rawParticipants.any((value) => value is! String)) {
      throw StateError('The room has invalid participants.');
    }
    final participants = rawParticipants.cast<String>().toSet();
    if (participants.length != 2 || !participants.contains(account.code)) {
      throw StateError('The signed-in account is not a room participant.');
    }
    final publicKeys = <String, String>{};
    for (final code in participants) {
      final profile = await _firestore.collection('profiles_v2').doc(code).get(_server);
      _requireServer(profile.metadata);
      final data = profile.data();
      if (data?['code'] != code || data?['publicKey'] is! String) {
        throw StateError('A participant has not set up their identity key.');
      }
      publicKeys[code] = data!['publicKey'] as String;
    }
    final ownPublic = await identity.extractPublicKey();
    if (ownPublic.type != KeyPairType.x25519 ||
        base64.encode(ownPublic.bytes) != publicKeys[account.code]) {
      throw StateError('The unlocked identity does not match the account.');
    }
    final roomKey = await AesGcm.with256bits().newSecretKey();
    final generated = <String, Map<String, Object>>{};
    for (final code in participants) {
      generated[code] = await wrapStagedRoomKey(
        sessionId: sessionId,
        recipientCode: code,
        recipientPublicKey: publicKeys[code]!,
        roomKey: roomKey,
      );
    }

    _requireUser(account.uid);
    final envelope = await _firestore.runTransaction<Map<String, dynamic>>((
      transaction,
    ) async {
      final bound = await transaction.get(
        _firestore.collection('accounts_v2').doc(account.uid),
      );
      final currentRoom = await transaction.get(roomRef);
      final restore = await transaction.get(
        roomRef.collection('restore').doc('state'),
      );
      final currentParticipants = currentRoom.data()?['participants'];
      if (bound.data()?['code'] != account.code ||
          currentParticipants is! List ||
          currentParticipants.length != 2 ||
          !currentParticipants.toSet().containsAll(participants)) {
        throw StateError('The room or account changed.');
      }
      final existing = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final code in participants) {
        final profile = await transaction.get(
          _firestore.collection('profiles_v2').doc(code),
        );
        if (profile.data()?['code'] != code ||
            profile.data()?['publicKey'] != publicKeys[code]) {
          throw StateError('A participant identity changed.');
        }
        existing[code] = await transaction.get(roomRef.collection('keys').doc(code));
      }
      final present = existing.values.where((snapshot) => snapshot.exists).length;
      if (present == 2) {
        return Map<String, dynamic>.from(existing[account.code]!.data()!);
      }
      if (present != 0) {
        throw StateError('The room key envelopes are incomplete.');
      }
      if (!create) {
        throw StateError('The room keys have not been created.');
      }
      if (restore.exists) {
        throw StateError('Room keys are missing for an existing restore.');
      }
      for (final code in participants) {
        transaction.set(roomRef.collection('keys').doc(code), generated[code]!);
      }
      return Map<String, dynamic>.from(generated[account.code]!);
    });
    final result = await unwrapStagedRoomKey(
      sessionId: sessionId,
      recipientCode: account.code,
      recipientKeyPair: identity,
      envelope: envelope,
    );
    _requireUser(account.uid);
    return result;
  }
}
