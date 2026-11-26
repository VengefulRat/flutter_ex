@TestOn('browser')
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/services/staged_account_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseAuth auth;
  late FirebaseFirestore firestore;
  late StagedAccountService service;

  setUpAll(() async {
    final app = await Firebase.initializeApp(
      name: 'migration-test',
      options: const FirebaseOptions(
        apiKey: 'demo-key',
        appId: '1:123:web:demo',
        messagingSenderId: '123',
        projectId: 'demo-lore-migration',
      ),
    );
    auth = FirebaseAuth.instanceFor(app: app);
    firestore = FirebaseFirestore.instanceFor(app: app);
    await auth.useAuthEmulator('127.0.0.1', 18765);
    firestore.useFirestoreEmulator('127.0.0.1', 18764);
    service = StagedAccountService(auth: auth, firestore: firestore);
  });

  tearDown(() async {
    await auth.signOut();
  });

  test('registers and signs in with a stable account identity', () async {
    final account = await service.register(
      email: 'alice@example.invalid',
      password: 'a-test-password',
      name: 'Alice',
    );
    expect(account.code, matches(r'^LR-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$'));
    expect((await service.currentAccount()).code, account.code);
    expect(
      (await service.completeRegistration('AnotherName')).code,
      account.code,
    );
    await expectLater(
      service.signIn(email: 'bob@example.invalid', password: 'a-test-password'),
      throwsStateError,
    );

    await auth.signOut();
    await expectLater(
      service.signIn(
        email: 'alice@example.invalid',
        password: 'wrong-password',
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
    final signedIn = await service.signIn(
      email: 'alice@example.invalid',
      password: 'a-test-password',
    );
    expect(signedIn.uid, account.uid);
    expect(signedIn.code, account.code);
    expect(signedIn.name, 'Alice');
    await service.sendPasswordReset('alice@example.invalid');
  });

  test(
    'a taken name leaves registration recoverable without replacing it',
    () async {
      await expectLater(
        service.register(
          email: 'bob@example.invalid',
          password: 'a-test-password',
          name: 'ALICE',
        ),
        throwsA(isA<StagedNameUnavailable>()),
      );
      await expectLater(
        service.currentAccount(),
        throwsA(isA<StagedAccountSetupRequired>()),
      );
      final bob = await service.completeRegistration('Bob');
      expect(bob.name, 'Bob');
      final alice = await firestore.collection('names_v2').doc('alice').get();
      expect(alice.data()?['code'], isNot(bob.code));
    },
  );
}
