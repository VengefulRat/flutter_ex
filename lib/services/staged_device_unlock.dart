import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'key_recovery.dart';
import 'staged_account_service.dart';
import 'staged_identity_keys.dart';

/// Demo-project-only PIN unlock using a device-protected random secret.
class StagedDeviceUnlock {
  StagedDeviceUnlock({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    FlutterSecureStorage? storage,
  }) : _auth = auth,
       _firestore = firestore,
       _accounts = StagedAccountService(auth: auth, firestore: firestore),
       _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final StagedAccountService _accounts;
  final FlutterSecureStorage _storage;

  String _currentUid() {
    if (kIsWeb) {
      throw UnsupportedError('Device PIN unlock is not available on the web.');
    }
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Sign in before unlocking this device.');
    }
    return user.uid;
  }

  String _storageKey(String uid) => 'lore_v2_device_unlock_$uid';

  /// Stores no raw private key, account password or PIN.
  Future<void> enable({
    required SimpleKeyPair identity,
    required String pin,
  }) async {
    final uid = _currentUid();
    final account = await _accounts.currentAccount();
    if (account.uid != uid) throw StateError('The signed-in account changed.');
    final profile = await _firestore
        .collection('profiles_v2')
        .doc(account.code)
        .get(const GetOptions(source: Source.server));
    if (profile.metadata.isFromCache || profile.metadata.hasPendingWrites) {
      throw StateError('Identity changes are still syncing.');
    }
    final publicKey = await identity.extractPublicKey();
    final publicText = base64.encode(publicKey.bytes);
    if (publicKey.type != KeyPairType.x25519 ||
        profile.data()?['uid'] != uid ||
        profile.data()?['code'] != account.code ||
        profile.data()?['publicKey'] != publicText) {
      throw StateError('The unlocked identity does not match the account.');
    }
    final deviceSecret = await createRecoveryKey();
    final envelope = await rewrapStagedIdentityCredentials(
      uid: uid,
      identity: identity,
      pin: pin,
      password: deviceSecret,
    );
    if (_currentUid() != uid) {
      throw StateError('The signed-in account changed.');
    }
    await _storage.write(
      key: _storageKey(uid),
      value: jsonEncode({
        'version': 1,
        'publicKey': publicText,
        'deviceSecret': deviceSecret,
        'envelope': envelope,
      }),
    );
  }

  /// Requires the PIN even when a cached device secret exists.
  Future<SimpleKeyPair> unlock({required String pin}) async {
    final uid = _currentUid();
    final stored = await _storage.read(key: _storageKey(uid));
    if (stored == null) throw StateError('Device unlock has not been enabled.');
    final data = jsonDecode(stored);
    if (data is! Map<String, dynamic> ||
        data.length != 4 ||
        data['version'] is! int ||
        data['version'] != 1 ||
        data['publicKey'] is! String ||
        data['deviceSecret'] is! String ||
        data['envelope'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid device unlock data.');
    }
    final identity = await unlockStagedIdentityWithCredentials(
      uid: uid,
      publicKey: data['publicKey'] as String,
      pin: pin,
      password: data['deviceSecret'] as String,
      envelope: data['envelope'] as Map<String, dynamic>,
    );
    if (_currentUid() != uid) {
      throw StateError('The signed-in account changed.');
    }
    return identity;
  }

  /// Call before signing out or removing this device.
  Future<void> clear() => _storage.delete(key: _storageKey(_currentUid()));

  /// Removes device unlock before an intentional sign-out.
  Future<void> clearAndSignOut() async {
    final uid = _currentUid();
    await clear();
    if (_currentUid() != uid) {
      throw StateError('The signed-in account changed.');
    }
    await _auth.signOut();
  }
}
