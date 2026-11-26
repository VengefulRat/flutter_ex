// The Firebase SDK types are faked here; rule enforcement is tested separately.
// ignore_for_file: subtype_of_sealed_class

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lore/services/staged_account_service.dart';
import 'package:lore/services/staged_device_unlock.dart';
import 'package:lore/services/staged_identity_service.dart';
import 'package:lore/services/staged_room_key_service.dart';
import 'package:lore/screens/staged_account_demo.dart';

class _App extends Fake implements FirebaseApp {
  _App(String projectId)
    : options = FirebaseOptions(
        apiKey: 'demo',
        appId: 'demo',
        messagingSenderId: 'demo',
        projectId: projectId,
      );

  @override
  String get name => 'test-app';

  @override
  final FirebaseOptions options;
}

class _User extends Fake implements User {
  _User(this.uid, this.email, this.password);

  @override
  final String uid;
  @override
  final String email;
  String password;
  void Function()? onReauthenticated;

  @override
  bool get isAnonymous => false;

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    if (credential is! EmailAuthCredential ||
        credential.email != email ||
        credential.password != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    onReauthenticated?.call();
    return _Credential();
  }
}

class _Credential extends Fake implements UserCredential {}

class _SecureStorage extends Fake implements FlutterSecureStorage {
  final values = <String, String>{};
  bool failDelete = false;
  bool failWrite = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrite) throw StateError('Secure storage write failed.');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failDelete) throw StateError('Secure storage deletion failed.');
    values.remove(key);
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.app);

  @override
  final FirebaseApp app;

  final accounts = <String, (String, _User)>{};
  User? _user;
  String? resetEmail;

  @override
  User? get currentUser => _user;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = _User('uid-${accounts.length}', email, password);
    accounts[email] = (password, user);
    _user = user;
    return _Credential();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final account = accounts[email];
    if (account == null || account.$1 != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    _user = account.$2;
    return _Credential();
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resetEmail = email;
  }
}

class _Snapshot<T> extends Fake implements DocumentSnapshot<T> {
  _Snapshot(this._data);
  final T? _data;

  @override
  bool get exists => _data != null;

  @override
  SnapshotMetadata get metadata => _Metadata();

  @override
  T? data() => _data;
}

class _Metadata extends Fake implements SnapshotMetadata {
  @override
  bool get isFromCache => false;

  @override
  bool get hasPendingWrites => false;
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);
  final _Firestore store;

  @override
  final String path;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, '${this.path}/$path');

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    if (store.requireReauthentication) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return _Snapshot(store.documents[path]);
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final _Firestore store;
  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, '${this.path}/$path');
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.store);
  final _Firestore store;
  final writes = <String, Map<String, dynamic>>{};
  final updates = <String, Map<String, dynamic>>{};

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async => _Snapshot(store.documents[documentReference.path] as T?);

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    writes[documentReference.path] = Map<String, dynamic>.from(
      data as Map<String, dynamic>,
    );
    return this;
  }

  @override
  Transaction update(DocumentReference reference, Map<String, dynamic> data) {
    updates[reference.path] = data;
    return this;
  }
}

class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore(this.app);

  @override
  final FirebaseApp app;

  final documents = <String, Map<String, dynamic>>{};
  bool failNextTransaction = false;
  bool requireReauthentication = false;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (failNextTransaction) {
      failNextTransaction = false;
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    final transaction = _Transaction(this);
    final result = await transactionHandler(transaction);
    documents.addAll(transaction.writes);
    for (final entry in transaction.updates.entries) {
      documents[entry.key]!.addAll(entry.value);
    }
    return result;
  }
}

void main() {
  late _Auth auth;
  late _Firestore firestore;
  late StagedAccountService service;

  setUp(() {
    final app = _App('demo-lore-migration');
    auth = _Auth(app);
    firestore = _Firestore(app);
    service = StagedAccountService(auth: auth, firestore: firestore);
  });

  test('registers atomically and signs back in to the same account', () async {
    final account = await service.register(
      email: ' alice@example.invalid ',
      password: 'password',
      name: 'Alice',
    );
    expect(
      firestore.documents['accounts_v2/${account.uid}']?['code'],
      account.code,
    );
    expect(firestore.documents['names_v2/alice']?['code'], account.code);
    expect(
      firestore.documents['profiles_v2/${account.code}']?['uid'],
      account.uid,
    );
    expect(
      (await service.completeRegistration('Different')).code,
      account.code,
    );
    await expectLater(
      service.signIn(email: 'bob@example.invalid', password: 'password'),
      throwsStateError,
    );

    await auth.signOut();
    await expectLater(
      service.signIn(email: 'alice@example.invalid', password: 'wrong'),
      throwsA(isA<FirebaseAuthException>()),
    );
    final signedIn = await service.signIn(
      email: 'alice@example.invalid',
      password: 'password',
    );
    expect(signedIn.uid, account.uid);
    expect(signedIn.code, account.code);
    expect(signedIn.name, 'Alice');
    await service.sendPasswordReset(' alice@example.invalid ');
    expect(auth.resetEmail, 'alice@example.invalid');
  });

  test(
    'taken names leave setup recoverable without altering the first account',
    () async {
      final alice = await service.register(
        email: 'alice@example.invalid',
        password: 'password',
        name: 'Alice',
      );
      await auth.signOut();
      await expectLater(
        service.register(
          email: 'bob@example.invalid',
          password: 'password',
          name: 'ALICE',
        ),
        throwsA(isA<StagedNameUnavailable>()),
      );
      await expectLater(
        service.currentAccount(),
        throwsA(isA<StagedAccountSetupRequired>()),
      );
      final bob = await service.completeRegistration('Bob');
      expect(bob.uid, isNot(alice.uid));
      expect(firestore.documents['names_v2/alice']?['code'], alice.code);
      expect(firestore.documents['names_v2/bob']?['code'], bob.code);
    },
  );

  test('rejects invalid names before creating Firebase accounts', () async {
    await expectLater(
      service.register(
        email: 'user@example.invalid',
        password: 'password',
        name: '!',
      ),
      throwsArgumentError,
    );
    expect(auth.accounts, isEmpty);
    expect(firestore.documents, isEmpty);
  });

  test('reports failed profile setup and allows a retry', () async {
    firestore.failNextTransaction = true;
    await expectLater(
      service.register(
        email: 'user@example.invalid',
        password: 'password',
        name: 'Writer',
      ),
      throwsA(isA<StagedAccountSetupFailure>()),
    );
    expect(auth.currentUser, isNotNull);
    expect(firestore.documents, isEmpty);
    final account = await service.completeRegistration('Writer');
    expect(account.uid, auth.currentUser!.uid);
  });

  test('refuses to operate on a non-demo Firebase project', () {
    final app = _App('production-project');
    expect(
      () => StagedAccountService(auth: _Auth(app), firestore: _Firestore(app)),
      throwsStateError,
    );
  });

  test('refuses to combine Firebase projects', () {
    expect(
      () => StagedAccountService(
        auth: _Auth(_App('demo-one')),
        firestore: _Firestore(_App('demo-two')),
      ),
      throwsStateError,
    );
  });

  test(
    'sets up identity keys atomically and recovers a forgotten PIN',
    () async {
      final account = await service.register(
        email: 'alice@example.invalid',
        password: 'password',
        name: 'Alice',
      );
      final identities = StagedIdentityService(
        auth: auth,
        firestore: firestore,
      );
      final profilePath = 'profiles_v2/${account.code}';
      final identityPath = 'private_v2/${account.uid}/data/identity';
      firestore.failNextTransaction = true;
      await expectLater(
        identities.initialize(pin: '123456', password: 'password'),
        throwsA(isA<FirebaseException>()),
      );
      expect(firestore.documents[identityPath], isNull);
      expect(
        firestore.documents[profilePath]!.containsKey('publicKey'),
        isFalse,
      );

      final recoveryKey = await identities.initialize(
        pin: '123456',
        password: 'password',
      );
      final identityDoc = firestore.documents[identityPath]!;
      expect(
        identityDoc['publicKey'],
        firestore.documents[profilePath]!['publicKey'],
      );
      expect(jsonEncode(identityDoc), isNot(contains(recoveryKey)));
      expect(jsonEncode(identityDoc), isNot(contains('123456')));
      final original = await identities.unlock(
        pin: '123456',
        password: 'password',
      );
      await expectLater(
        identities.initialize(pin: '123456', password: 'password'),
        throwsStateError,
      );
      await expectLater(
        identities.recover(
          recoveryKey: 'wrong',
          newPin: '654321',
          password: 'password',
        ),
        throwsFormatException,
      );
      final recovered = await identities.recover(
        recoveryKey: recoveryKey,
        newPin: '654321',
        password: 'password',
      );
      expect(
        (await original.extractPublicKey()).bytes,
        (await recovered.extractPublicKey()).bytes,
      );
      await expectLater(
        identities.unlock(pin: '123456', password: 'password'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await identities.unlock(pin: '654321', password: 'password');
      final replacement = await identities.replaceRecoveryKey(
        pin: '654321',
        password: 'password',
      );
      await expectLater(
        identities.recover(
          recoveryKey: recoveryKey,
          newPin: '111111',
          password: 'password',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      (auth.currentUser as _User).password = 'new-password';
      await expectLater(
        identities.replaceRecoveryKey(pin: '654321', password: 'password'),
        throwsA(isA<FirebaseAuthException>()),
      );
      await expectLater(
        identities.unlock(pin: '654321', password: 'new-password'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await identities.recover(
        recoveryKey: replacement,
        newPin: '111111',
        password: 'new-password',
      );
      await identities.unlock(pin: '111111', password: 'new-password');
    },
  );

  test('both new accounts can securely share an immutable room key', () async {
    final identities = StagedIdentityService(auth: auth, firestore: firestore);
    final roomKeys = StagedRoomKeyService(auth: auth, firestore: firestore);
    final alice = await service.register(
      email: 'alice@example.invalid',
      password: 'password',
      name: 'Alice',
    );
    await identities.initialize(pin: '123456', password: 'password');
    final aliceIdentity = await identities.unlock(
      pin: '123456',
      password: 'password',
    );
    await auth.signOut();
    final bob = await service.register(
      email: 'bob@example.invalid',
      password: 'password',
      name: 'Bob',
    );
    await identities.initialize(pin: '654321', password: 'password');
    final bobIdentity = await identities.unlock(
      pin: '654321',
      password: 'password',
    );
    firestore.documents['sessions_v2/room'] = {
      'participants': [alice.code, bob.code],
    };
    await expectLater(
      roomKeys.getOrCreate(sessionId: 'room', identity: aliceIdentity),
      throwsStateError,
    );
    firestore.failNextTransaction = true;
    await expectLater(
      roomKeys.getOrCreate(sessionId: 'room', identity: bobIdentity),
      throwsA(isA<FirebaseException>()),
    );
    expect(firestore.documents['sessions_v2/room/keys/${alice.code}'], isNull);
    expect(firestore.documents['sessions_v2/room/keys/${bob.code}'], isNull);
    final bobRoomKey = await roomKeys.getOrCreate(
      sessionId: 'room',
      identity: bobIdentity,
    );
    final firstBobEnvelope = Map<String, dynamic>.from(
      firestore.documents['sessions_v2/room/keys/${bob.code}']!,
    );
    await auth.signOut();
    await service.signIn(email: 'alice@example.invalid', password: 'password');
    final aliceRoomKey = await roomKeys.getOrCreate(
      sessionId: 'room',
      identity: aliceIdentity,
    );
    expect(await aliceRoomKey.extractBytes(), await bobRoomKey.extractBytes());
    expect(
      firestore.documents['sessions_v2/room/keys/${bob.code}'],
      firstBobEnvelope,
    );
  });

  test(
    'device unlock requires PIN and removes access after clearing',
    () async {
      final account = await service.register(
        email: 'alice@example.invalid',
        password: 'password',
        name: 'Alice',
      );
      final identities = StagedIdentityService(
        auth: auth,
        firestore: firestore,
      );
      await identities.initialize(pin: '123456', password: 'password');
      final identity = await identities.unlock(
        pin: '123456',
        password: 'password',
      );
      final storage = _SecureStorage();
      final device = StagedDeviceUnlock(
        auth: auth,
        firestore: firestore,
        storage: storage,
      );
      await device.enable(identity: identity, pin: '123456');
      final stored = storage.values['lore_v2_device_unlock_${account.uid}']!;
      expect(stored, isNot(contains('password')));
      expect(stored, isNot(contains('123456')));
      expect(
        stored,
        isNot(contains(base64.encode(await identity.extractPrivateKeyBytes()))),
      );
      await expectLater(
        device.unlock(pin: '000000'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final unlocked = await device.unlock(pin: '123456');
      expect(
        (await unlocked.extractPublicKey()).bytes,
        (await identity.extractPublicKey()).bytes,
      );
      final key = 'lore_v2_device_unlock_${account.uid}';
      storage.values[key] = '{"version":1}';
      await expectLater(device.unlock(pin: '123456'), throwsFormatException);
      storage.values[key] = stored;
      await auth.signOut();
      await expectLater(device.unlock(pin: '123456'), throwsStateError);
      await service.register(
        email: 'bob@example.invalid',
        password: 'password',
        name: 'Bob',
      );
      await expectLater(device.unlock(pin: '123456'), throwsStateError);
      await auth.signOut();
      await service.signIn(
        email: 'alice@example.invalid',
        password: 'password',
      );
      storage.failDelete = true;
      await expectLater(device.clearAndSignOut(), throwsStateError);
      expect(auth.currentUser?.uid, account.uid);
      expect(storage.values[key], stored);
      storage.failDelete = false;
      await device.clearAndSignOut();
      expect(auth.currentUser, isNull);
      expect(storage.values[key], isNull);
      await expectLater(device.unlock(pin: '123456'), throwsStateError);
    },
  );

  test('device identity can rewrap credentials after password reset', () async {
    final account = await service.register(
      email: 'alice@example.invalid',
      password: 'old-password',
      name: 'Alice',
    );
    final identities = StagedIdentityService(auth: auth, firestore: firestore);
    final recoveryKey = await identities.initialize(
      pin: '123456',
      password: 'old-password',
    );
    final identity = await identities.unlock(
      pin: '123456',
      password: 'old-password',
    );
    final device = StagedDeviceUnlock(
      auth: auth,
      firestore: firestore,
      storage: _SecureStorage(),
    );
    await device.enable(identity: identity, pin: '123456');
    final user = auth.currentUser as _User;
    user.password = 'new-password';
    auth.accounts[user.email] = ('new-password', user);
    await auth.signOut();
    await service.signIn(
      email: 'alice@example.invalid',
      password: 'new-password',
    );
    final unlocked = await device.unlock(pin: '123456');
    firestore.requireReauthentication = true;
    user.onReauthenticated = () => firestore.requireReauthentication = false;
    await expectLater(
      identities.rewrapWithIdentity(
        identity: unlocked,
        pin: '654321',
        password: 'old-password',
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
    await expectLater(
      identities.rewrapWithIdentity(
        identity: await X25519().newKeyPair(),
        pin: '654321',
        password: 'new-password',
      ),
      throwsStateError,
    );
    firestore.requireReauthentication = true;
    await identities.rewrapWithIdentity(
      identity: unlocked,
      pin: '654321',
      password: 'new-password',
    );
    await device.enable(identity: unlocked, pin: '654321');
    await expectLater(
      device.unlock(pin: '123456'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    await device.unlock(pin: '654321');
    final cloud = await identities.unlock(
      pin: '654321',
      password: 'new-password',
    );
    expect(
      (await cloud.extractPublicKey()).bytes,
      (await identity.extractPublicKey()).bytes,
    );
    firestore.requireReauthentication = true;
    final recovered = await identities.recover(
      recoveryKey: recoveryKey,
      newPin: '111111',
      password: 'new-password',
    );
    expect(
      (await recovered.extractPublicKey()).bytes,
      (await identity.extractPublicKey()).bytes,
    );
    expect(firestore.documents['accounts_v2/${account.uid}'], isNotNull);
  });

  testWidgets('demo confirms recovery and supports device PIN unlock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _SecureStorage();
    Future<void> waitForText(String text, {bool contains = false}) async {
      final finder = contains ? find.textContaining(text) : find.text(text);
      await tester.runAsync(() async {
        for (var i = 0; i < 200; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (finder.evaluate().isNotEmpty) return;
        }
      });
      expect(finder, findsOneWidget);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: StagedAccountDemo(
          auth: auth,
          firestore: firestore,
          storage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Alice');
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'alice@example.invalid',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Set up encryption'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Account password'),
      'password',
    );
    await tester.enterText(find.widgetWithText(TextField, 'New PIN'), '123456');
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm new PIN'),
      '654321',
    );
    await tester.tap(find.text('Create encryption keys'));
    await tester.pumpAndSettle();
    expect(find.text('The PINs do not match.'), findsOneWidget);
    expect(
      firestore.documents.keys.where((path) => path.endsWith('/data/identity')),
      isEmpty,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm new PIN'),
      '123456',
    );
    await tester.tap(find.text('Create encryption keys'));
    await waitForText('Save your recovery key');
    final key = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter the recovery key to confirm'),
      'wrong',
    );
    await tester.tap(find.text('Confirm saved key'));
    await tester.pumpAndSettle();
    expect(find.text('The recovery key does not match.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter the recovery key to confirm'),
      key,
    );
    await tester.tap(find.text('Confirm saved key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '123456');
    await tester.enterText(
      find.widgetWithText(TextField, 'Account password'),
      'password',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock with password and PIN'));
    await waitForText('Demo account unlocked: Alice');
    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '000000');
    await tester.tap(find.text('Unlock with device PIN'));
    await waitForText('The credentials or recovery key are incorrect.');
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '123456');
    await tester.tap(find.text('Unlock with device PIN'));
    await waitForText('Demo account unlocked: Alice');
    final user = auth.currentUser as _User;
    user.password = 'new-password';
    user.onReauthenticated = () => firestore.requireReauthentication = false;
    firestore.requireReauthentication = true;
    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recover with device PIN after password reset'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Current device PIN'),
      '123456',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Current account password'),
      'new-password',
    );
    await tester.enterText(find.widgetWithText(TextField, 'New PIN'), '654321');
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm new PIN'),
      '654321',
    );
    storage.failWrite = true;
    await tester.tap(find.text('Update cloud credentials'));
    await waitForText(
      'Cloud PIN changed, but device unlock could not be updated',
      contains: true,
    );
    storage.failWrite = false;
    await tester.tap(find.text('Update cloud credentials'));
    await waitForText('Demo account unlocked: Alice');
    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recover with recovery key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Recovery key'), key);
    await tester.enterText(
      find.widgetWithText(TextField, 'Current account password'),
      'new-password',
    );
    await tester.enterText(find.widgetWithText(TextField, 'New PIN'), '222222');
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm new PIN'),
      '222222',
    );
    storage.failDelete = true;
    await tester.tap(find.widgetWithText(FilledButton, 'Recover'));
    await waitForText(
      'Cloud PIN changed, but device unlock could not be cleared',
      contains: true,
    );
    expect(storage.values, isNotEmpty);
    storage.failDelete = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Recover'));
    await waitForText('Recovery complete. Unlock with your new PIN.');
    expect(storage.values, isEmpty);
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '222222');
    await tester.enterText(
      find.widgetWithText(TextField, 'Account password'),
      'new-password',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock with password and PIN'));
    await waitForText('Demo account unlocked: Alice');
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
    expect(storage.values, isEmpty);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('demo lets an account finish setup after a taken name', (
    tester,
  ) async {
    await service.register(
      email: 'first@example.invalid',
      password: 'password',
      name: 'Alice',
    );
    await auth.signOut();
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: StagedAccountDemo(
          auth: auth,
          firestore: firestore,
          storage: _SecureStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Alice');
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'second@example.invalid',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Finish account setup'), findsOneWidget);
    expect(find.textContaining('name is already taken'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Bob');
    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();
    expect(find.text('Set up encryption'), findsOneWidget);
  });

  testWidgets('demo reauthenticates without deleting a device key', (
    tester,
  ) async {
    final account = await service.register(
      email: 'alice@example.invalid',
      password: 'password',
      name: 'Alice',
    );
    final identities = StagedIdentityService(auth: auth, firestore: firestore);
    final storage = _SecureStorage();
    await tester.runAsync(() async {
      await identities.initialize(pin: '123456', password: 'password');
      final identity = await identities.unlock(
        pin: '123456',
        password: 'password',
      );
      await StagedDeviceUnlock(
        auth: auth,
        firestore: firestore,
        storage: storage,
      ).enable(identity: identity, pin: '123456');
    });
    final user = auth.currentUser as _User;
    user.password = 'new-password';
    user.onReauthenticated = () => firestore.requireReauthentication = false;
    firestore.requireReauthentication = true;
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: StagedAccountDemo(
          auth: auth,
          firestore: firestore,
          storage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reauthenticate'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Current account password'),
      'new-password',
    );
    await tester.tap(find.text('Reauthenticate'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock Alice'), findsOneWidget);
    expect(storage.values, contains('lore_v2_device_unlock_${account.uid}'));
  });
}
