import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lore/services/rp_story_export.dart';
import 'package:lore/services/rp_story_import.dart';
import 'package:lore/services/staged_account_service.dart';
import 'package:lore/services/staged_device_unlock.dart';
import 'package:lore/services/staged_identity_service.dart';
import 'package:lore/services/staged_restore_service.dart';
import 'package:lore/services/staged_room_invites.dart';
import 'package:lore/screens/staged_account_demo.dart';
import 'package:lore/screens/staged_room_invites_demo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseApp app;
  late FirebaseAuth auth;
  late FirebaseFirestore firestore;
  late FirebaseFunctions functions;
  setUpAll(() async {
    app = await Firebase.initializeApp(
      name: 'migration-integration',
      options: const FirebaseOptions(
        apiKey: 'AIzaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        appId: '1:123:android:0123456789abcdef',
        messagingSenderId: '123',
        projectId: 'demo-lore-migration',
      ),
    );
    auth = FirebaseAuth.instanceFor(app: app);
    firestore = FirebaseFirestore.instanceFor(app: app);
    functions = FirebaseFunctions.instanceFor(app: app);
    await auth.useAuthEmulator('127.0.0.1', 18765);
    firestore.useFirestoreEmulator('127.0.0.1', 18764);
    functions.useFunctionsEmulator('127.0.0.1', 18766);
    await auth.signOut();
  });
  setUp(() async {
    await auth.signOut();
  });
  tearDownAll(() async {
    await auth.signOut();
    await app.delete();
  });

  testWidgets('two accounts restore an approved story through the emulators', (
    tester,
  ) async {
    Future<void> waitFor(String text) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 300; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          if (find.text(text).evaluate().isNotEmpty) return;
        }
      });
      expect(find.text(text), findsOneWidget);
    }

    final accounts = StagedAccountService(auth: auth, firestore: firestore);
    final identities = StagedIdentityService(auth: auth, firestore: firestore);
    final restore = StagedRestoreService(
      auth: auth,
      firestore: firestore,
      functions: functions,
    );

    final alice = await accounts.register(
      email: 'android-alice@example.invalid',
      password: 'emulator-password',
      name: 'AndroidAlice',
    );
    await identities.initialize(pin: '123456', password: 'emulator-password');
    final aliceKey = await identities.unlock(
      pin: '123456',
      password: 'emulator-password',
    );
    final device = StagedDeviceUnlock(auth: auth, firestore: firestore);
    await device.enable(identity: aliceKey, pin: '123456');
    final deviceKey = await device.unlock(pin: '123456');
    expect(
      (await deviceKey.extractPublicKey()).bytes,
      (await aliceKey.extractPublicKey()).bytes,
    );
    await device.clearAndSignOut();
    final bob = await accounts.register(
      email: 'android-bob@example.invalid',
      password: 'emulator-password',
      name: 'AndroidBob',
    );
    await identities.initialize(pin: '654321', password: 'emulator-password');
    final bobKey = await identities.unlock(
      pin: '654321',
      password: 'emulator-password',
    );
    await auth.signOut();
    await accounts.signIn(
      email: 'android-alice@example.invalid',
      password: 'emulator-password',
    );
    final aliceInvites = StagedRoomInvites(
      auth: auth,
      firestore: firestore,
      accountUid: alice.uid,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StagedRoomInvitesDemo(
          auth: auth,
          firestore: firestore,
          account: alice,
        ),
      ),
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 300; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        final button = find.widgetWithText(FilledButton, 'Send invitation');
        if (button.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(button).onPressed != null) {
          return;
        }
      }
    });
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Send invitation'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Partner account code'),
      bob.code,
    );
    await tester.tap(find.text('Send invitation'));
    await waitFor('Invitation sent.');
    await tester.pumpWidget(const SizedBox.shrink());
    final outgoing = await aliceInvites.invitations();
    expect(outgoing, hasLength(1));
    await expectLater(
      aliceInvites.respond(outgoing.single.id, accept: true),
      throwsStateError,
    );
    await auth.signOut();
    await accounts.signIn(
      email: 'android-bob@example.invalid',
      password: 'emulator-password',
    );
    await expectLater(aliceInvites.rooms(), throwsStateError);
    final bobInvites = StagedRoomInvites(
      auth: auth,
      firestore: firestore,
      accountUid: bob.uid,
    );
    final incoming = await bobInvites.invitations();
    expect(incoming.single.id, outgoing.single.id);
    await tester.pumpWidget(
      MaterialApp(
        home: StagedRoomInvitesDemo(
          auth: auth,
          firestore: firestore,
          account: bob,
        ),
      ),
    );
    await waitFor('Accept');
    await tester.ensureVisible(find.text('Accept'));
    await tester.tap(find.text('Accept'));
    await waitFor('Room created.');
    await bobInvites.respond(incoming.single.id, accept: true);
    final rooms = await bobInvites.rooms();
    expect(rooms, hasLength(1));
    expect(rooms.single.participants.toSet(), {alice.code, bob.code});
    final roomId = rooms.single.id;
    final room = firestore.collection('sessions_v2').doc(roomId);
    await auth.signOut();
    await waitFor('The signed-in account changed. Return and sign in again.');
    expect(find.textContaining('Your account code:'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await accounts.signIn(
      email: 'android-alice@example.invalid',
      password: 'emulator-password',
    );
    expect((await aliceInvites.rooms()).single.id, roomId);
    await aliceInvites.send(bob.code);
    final secondInvite = (await aliceInvites.invitations()).singleWhere(
      (invite) => invite.status == 'pending',
    );
    await auth.signOut();
    await accounts.signIn(
      email: 'android-bob@example.invalid',
      password: 'emulator-password',
    );
    await bobInvites.respond(secondInvite.id, accept: false);
    await bobInvites.respond(secondInvite.id, accept: false);
    await expectLater(
      bobInvites.respond(secondInvite.id, accept: true),
      throwsStateError,
    );
    expect(
      (await bobInvites.invitations())
          .singleWhere((invite) => invite.id == secondInvite.id)
          .status,
      'declined',
    );
    await auth.signOut();
    await accounts.signIn(
      email: 'android-alice@example.invalid',
      password: 'emulator-password',
    );
    final backup = RpStoryBackup(
      sessionId: 'old-room',
      exportedAt: DateTime.utc(2026),
      session: {
        'chapters': ['Chapter 1'],
      },
      posts: [
        StoryPost('post', {
          'authorCode': 'old-bob',
          'authorName': 'Bob before migration',
          'content': 'Story',
          'contentRuns': '[{"text":"Story","bold":true}]',
          'createdAt': Timestamp(1, 0),
        }),
      ],
    );
    final authors = {'old-bob': bob.code};
    await restore.stage(
      sessionId: roomId,
      reviewerCode: bob.code,
      identity: aliceKey,
      backup: backup,
      authorCodes: authors,
    );
    await auth.signOut();
    await accounts.signIn(
      email: 'android-bob@example.invalid',
      password: 'emulator-password',
    );
    final review = await restore.loadReview(
      sessionId: roomId,
      identity: bobKey,
    );
    expect(review.posts.single.data['content'], 'Story');
    expect(review.posts.single.data['contentRuns'], contains('"bold":true'));
    expect(review.session['chapters'], ['Chapter 1']);
    await restore.decide(review, approve: true);
    await auth.signOut();
    await accounts.signIn(
      email: 'android-alice@example.invalid',
      password: 'emulator-password',
    );
    await restore.publish(
      sessionId: roomId,
      identity: aliceKey,
      backup: backup,
      authorCodes: authors,
    );
    expect(
      (await room.collection('restore').doc('state').get()).data()?['status'],
      'completed',
    );
    await auth.signOut();
    await accounts.signIn(
      email: 'android-bob@example.invalid',
      password: 'emulator-password',
    );
    final post = await room.collection('posts').doc('post').get();
    expect(post.exists, isTrue);
    expect(post.data()?['content'], isNot('Story'));
    await auth.signOut();
  });

  testWidgets('demo screen creates, confirms and unlocks an account', (
    tester,
  ) async {
    Future<void> waitFor(String text) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 300; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          if (find.text(text).evaluate().isNotEmpty) return;
        }
      });
      expect(
        find.text(text),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .whereType<String>()
            .join(' | '),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: StagedAccountDemo(auth: auth, firestore: firestore),
      ),
    );
    await waitFor('Create an account');
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'UiTester');
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'ui@example.invalid',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'emulator-password',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await waitFor('Set up encryption');
    await tester.enterText(
      find.widgetWithText(TextField, 'Account password'),
      'emulator-password',
    );
    await tester.enterText(find.widgetWithText(TextField, 'New PIN'), '123456');
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm new PIN'),
      '123456',
    );
    await tester.ensureVisible(find.text('Create encryption keys'));
    await tester.tap(find.text('Create encryption keys'));
    await waitFor('Save your recovery key');
    final recovery = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter the recovery key to confirm'),
      recovery,
    );
    await tester.ensureVisible(find.text('Confirm saved key'));
    await tester.tap(find.text('Confirm saved key'));
    await waitFor('Unlock UiTester');
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '123456');
    await tester.enterText(
      find.widgetWithText(TextField, 'Account password'),
      'emulator-password',
    );
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.ensureVisible(find.text('Unlock with password and PIN'));
    await tester.tap(find.text('Unlock with password and PIN'));
    await waitFor('Demo account unlocked: UiTester');
    await tester.ensureVisible(find.text('Lock'));
    await tester.tap(find.text('Lock'));
    await waitFor('Unlock UiTester');
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '123456');
    await tester.ensureVisible(find.text('Unlock with device PIN'));
    await tester.tap(find.text('Unlock with device PIN'));
    await waitFor('Demo account unlocked: UiTester');
    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await waitFor('Create an account');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
