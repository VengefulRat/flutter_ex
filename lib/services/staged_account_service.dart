import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_code.dart';

class StagedAccount {
  const StagedAccount({
    required this.uid,
    required this.code,
    required this.name,
  });

  final String uid;
  final String code;
  final String name;
}

class StagedAccountSetupRequired implements Exception {
  const StagedAccountSetupRequired();

  @override
  String toString() => 'Account setup is incomplete. Choose a name to finish.';
}

class StagedNameUnavailable implements Exception {
  const StagedNameUnavailable();

  @override
  String toString() => 'That name is already taken. Choose another to finish setup.';
}

class StagedAccountSetupFailure implements Exception {
  const StagedAccountSetupFailure(this.cause);

  final FirebaseException cause;

  @override
  String toString() =>
      'Account created, but setup failed. Retry setup: ${cause.code}.';
}

/// Experimental account flow for a demo Firebase project only.
class StagedAccountService {
  StagedAccountService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore {
    if (!auth.app.options.projectId.startsWith('demo-') ||
        auth.app.options.projectId != firestore.app.options.projectId ||
        auth.app.name != firestore.app.name) {
      throw StateError('Staged accounts require one demo Firebase project.');
    }
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  void _requireSignedOut() {
    if (_auth.currentUser != null) {
      throw StateError('Sign out before switching accounts.');
    }
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Sign in with email and password first.');
    }
    return user;
  }

  String _validateName(String name) {
    final trimmed = name.trim();
    if (!RegExp(r'^[a-zA-Z0-9_-]{2,24}$').hasMatch(trimmed)) {
      throw ArgumentError('Name must be 2–24 letters, numbers, _ or -.');
    }
    return trimmed;
  }

  /// If profile setup fails, the new user remains signed in and can retry it.
  Future<StagedAccount> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _requireSignedOut();
    final validName = _validateName(name);
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    try {
      return await completeRegistration(validName);
    } on FirebaseException catch (error) {
      throw StagedAccountSetupFailure(error);
    }
  }

  Future<StagedAccount> signIn({
    required String email,
    required String password,
  }) async {
    _requireSignedOut();
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return currentAccount();
  }

  Future<StagedAccount> currentAccount() async {
    final user = _requireUser();
    const server = GetOptions(source: Source.server);
    final account = await _firestore
        .collection('accounts_v2')
        .doc(user.uid)
        .get(server);
    if (!account.exists) throw const StagedAccountSetupRequired();
    final code = account.data()?['code'];
    if (code is! String || code.isEmpty || code.contains('/')) {
      throw StateError('Account has an invalid code.');
    }
    final profile = await _firestore
        .collection('profiles_v2')
        .doc(code)
        .get(server);
    return _readProfile(user.uid, code, profile.data());
  }

  Future<StagedAccount> completeRegistration(String name) async {
    final user = _requireUser();
    final validName = _validateName(name);
    final lowerName = validName.toLowerCase();
    final accountRef = _firestore.collection('accounts_v2').doc(user.uid);
    final nameRef = _firestore.collection('names_v2').doc(lowerName);

    for (var attempt = 0; attempt < 10; attempt++) {
      final code = generateUserCode();
      final profileRef = _firestore.collection('profiles_v2').doc(code);
      final result = await _firestore.runTransaction<StagedAccount?>((
        transaction,
      ) async {
        final account = await transaction.get(accountRef);
        if (account.exists) {
          final existingCode = account.data()?['code'];
          if (existingCode is! String ||
              existingCode.isEmpty ||
              existingCode.contains('/')) {
            throw StateError('Account has an invalid code.');
          }
          final existingProfile = await transaction.get(
            _firestore.collection('profiles_v2').doc(existingCode),
          );
          return _readProfile(user.uid, existingCode, existingProfile.data());
        }
        final nameEntry = await transaction.get(nameRef);
        if (nameEntry.exists) throw const StagedNameUnavailable();
        final profile = await transaction.get(profileRef);
        if (profile.exists) return null;

        transaction.set(accountRef, {'code': code});
        transaction.set(profileRef, {
          'uid': user.uid,
          'code': code,
          'displayName': lowerName,
          'displayNameOriginal': validName,
          'isDiscoverable': true,
        });
        transaction.set(nameRef, {'code': code});
        return StagedAccount(uid: user.uid, code: code, name: validName);
      });
      if (result != null) return result;
    }
    throw StateError('Could not generate a unique account code.');
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  StagedAccount _readProfile(
    String uid,
    String code,
    Map<String, dynamic>? profile,
  ) {
    final name = profile?['displayNameOriginal'];
    if (profile == null ||
        profile['uid'] != uid ||
        profile['code'] != code ||
        name is! String) {
      throw StateError('Account profile is missing or invalid.');
    }
    return StagedAccount(uid: uid, code: code, name: name);
  }
}
