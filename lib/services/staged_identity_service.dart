import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'key_recovery.dart';
import 'staged_account_service.dart';
import 'staged_identity_keys.dart';

/// Demo-project-only identity-key setup and recovery.
class StagedIdentityService {
  StagedIdentityService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore,
       _accounts = StagedAccountService(auth: auth, firestore: firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final StagedAccountService _accounts;
  static const _server = GetOptions(source: Source.server);

  DocumentReference<Map<String, dynamic>> _identity(String uid) => _firestore
      .collection('private_v2')
      .doc(uid)
      .collection('data')
      .doc('identity');

  void _requireUser(String uid) {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.uid != uid) {
      throw StateError('The signed-in account changed.');
    }
  }

  String _signedInUid() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Sign in before recovering identity keys.');
    }
    return user.uid;
  }

  Future<void> _reauthenticate(String uid, String password) async {
    _requireUser(uid);
    final user = _auth.currentUser!;
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('The account has no email address.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    _requireUser(uid);
  }

  /// Returns a recovery key that must be shown and saved separately.
  Future<String> initialize({
    required String pin,
    required String password,
  }) async {
    final account = await _accounts.currentAccount();
    await _reauthenticate(account.uid, password);
    final material = await createStagedIdentity(
      uid: account.uid,
      pin: pin,
      password: password,
    );
    final accountRef = _firestore.collection('accounts_v2').doc(account.uid);
    final profileRef = _firestore.collection('profiles_v2').doc(account.code);
    final identityRef = _identity(account.uid);
    _requireUser(account.uid);
    await _firestore.runTransaction((transaction) async {
      final boundAccount = await transaction.get(accountRef);
      final profile = await transaction.get(profileRef);
      final existing = await transaction.get(identityRef);
      if (boundAccount.data()?['code'] != account.code ||
          profile.data()?['uid'] != account.uid ||
          profile.data()?['code'] != account.code ||
          profile.data()?.containsKey('publicKey') == true ||
          existing.exists) {
        throw StateError('Identity keys already exist or the account changed.');
      }
      transaction.set(identityRef, {
        'publicKey': material.publicKey,
        'pinEnvelope': material.pinEnvelope,
        'recoveryEnvelope': material.recoveryEnvelope,
      });
      transaction.update(profileRef, {'publicKey': material.publicKey});
    });
    _requireUser(account.uid);
    return material.recoveryKey;
  }

  Future<
    ({
      StagedAccount account,
      String publicKey,
      Map<String, dynamic> pin,
      Map<String, dynamic> recovery,
    })
  >
  _load() async {
    final account = await _accounts.currentAccount();
    final profile = await _firestore
        .collection('profiles_v2')
        .doc(account.code)
        .get(_server);
    final identity = await _identity(account.uid).get(_server);
    if (profile.metadata.isFromCache ||
        profile.metadata.hasPendingWrites ||
        identity.metadata.isFromCache ||
        identity.metadata.hasPendingWrites) {
      throw StateError('Identity changes are still syncing.');
    }
    final data = identity.data();
    final publicKey = profile.data()?['publicKey'];
    final pin = data?['pinEnvelope'];
    final recovery = data?['recoveryEnvelope'];
    if (profile.data()?['uid'] != account.uid ||
        profile.data()?['code'] != account.code ||
        publicKey is! String ||
        data?['publicKey'] != publicKey ||
        pin is! Map<String, dynamic> ||
        recovery is! Map<String, dynamic>) {
      throw StateError('Identity keys are missing or invalid.');
    }
    _requireUser(account.uid);
    return (
      account: account,
      publicKey: publicKey,
      pin: Map.of(pin),
      recovery: Map.of(recovery),
    );
  }

  Future<SimpleKeyPair> unlock({
    required String pin,
    required String password,
  }) async {
    final data = await _load();
    final identity = await unlockStagedIdentityWithCredentials(
      uid: data.account.uid,
      publicKey: data.publicKey,
      pin: pin,
      password: password,
      envelope: data.pin,
    );
    _requireUser(data.account.uid);
    return identity;
  }

  /// Recovers the identity and replaces the PIN without changing its public key.
  Future<SimpleKeyPair> recover({
    required String recoveryKey,
    required String newPin,
    required String password,
  }) async {
    final uid = _signedInUid();
    await _reauthenticate(uid, password);
    final data = await _load();
    _requireUser(uid);
    final identity = await unlockStagedIdentityWithRecovery(
      uid: data.account.uid,
      publicKey: data.publicKey,
      recoveryKey: recoveryKey,
      envelope: data.recovery,
    );
    final newEnvelope = await rewrapStagedIdentityCredentials(
      uid: data.account.uid,
      identity: identity,
      pin: newPin,
      password: password,
    );
    _requireUser(data.account.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(_identity(data.account.uid));
      final current = snapshot.data();
      if (current?['publicKey'] != data.publicKey ||
          current?['recoveryEnvelope'] is! Map<String, dynamic> ||
          !mapEquals(
            current!['recoveryEnvelope'] as Map<String, dynamic>,
            data.recovery,
          ) ||
          current['pinEnvelope'] is! Map<String, dynamic> ||
          !mapEquals(
            current['pinEnvelope'] as Map<String, dynamic>,
            data.pin,
          )) {
        throw StateError('Identity keys changed during recovery. Try again.');
      }
      transaction.update(_identity(data.account.uid), {
        'pinEnvelope': newEnvelope,
      });
    });
    _requireUser(data.account.uid);
    return identity;
  }

  /// Updates the cloud credentials using an identity unlocked on this device.
  Future<void> rewrapWithIdentity({
    required SimpleKeyPair identity,
    required String pin,
    required String password,
  }) async {
    final uid = _signedInUid();
    await _reauthenticate(uid, password);
    final data = await _load();
    _requireUser(uid);
    final publicKey = await identity.extractPublicKey();
    if (publicKey.type != KeyPairType.x25519 ||
        base64Encode(publicKey.bytes) != data.publicKey) {
      throw StateError('The unlocked identity does not match the account.');
    }
    final envelope = await rewrapStagedIdentityCredentials(
      uid: data.account.uid,
      identity: identity,
      pin: pin,
      password: password,
    );
    _requireUser(data.account.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(_identity(data.account.uid));
      final current = snapshot.data();
      if (current?['publicKey'] != data.publicKey ||
          current?['pinEnvelope'] is! Map<String, dynamic> ||
          !mapEquals(
            current!['pinEnvelope'] as Map<String, dynamic>,
            data.pin,
          )) {
        throw StateError('Identity keys changed. Try again.');
      }
      transaction.update(_identity(data.account.uid), {
        'pinEnvelope': envelope,
      });
    });
    _requireUser(data.account.uid);
  }

  /// Replaces a lost recovery key after unlocking with the current credentials.
  Future<String> replaceRecoveryKey({
    required String pin,
    required String password,
  }) async {
    final uid = _signedInUid();
    await _reauthenticate(uid, password);
    final data = await _load();
    _requireUser(uid);
    final identity = await unlockStagedIdentityWithCredentials(
      uid: data.account.uid,
      publicKey: data.publicKey,
      pin: pin,
      password: password,
      envelope: data.pin,
    );
    final recoveryKey = await createRecoveryKey();
    final envelope = await wrapPrivateKeyForRecovery(
      uid: data.account.uid,
      privateKey: await identity.extractPrivateKeyBytes(),
      recoveryKey: recoveryKey,
    );
    _requireUser(data.account.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(_identity(data.account.uid));
      final current = snapshot.data();
      if (current?['publicKey'] != data.publicKey ||
          current?['pinEnvelope'] is! Map<String, dynamic> ||
          !mapEquals(
            current!['pinEnvelope'] as Map<String, dynamic>,
            data.pin,
          ) ||
          current['recoveryEnvelope'] is! Map<String, dynamic> ||
          !mapEquals(
            current['recoveryEnvelope'] as Map<String, dynamic>,
            data.recovery,
          )) {
        throw StateError('Identity keys changed. Try again.');
      }
      transaction.update(_identity(data.account.uid), {
        'recoveryEnvelope': envelope,
      });
    });
    _requireUser(data.account.uid);
    return recoveryKey;
  }
}
