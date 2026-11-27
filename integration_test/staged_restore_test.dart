import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lore/main.dart' as app_main;
import 'package:lore/services/rp_story_export.dart';
import 'package:lore/services/rp_story_import.dart';
import 'package:lore/services/staged_account_service.dart';
import 'package:lore/services/staged_device_unlock.dart';
import 'package:lore/services/staged_identity_service.dart';
import 'package:lore/services/staged_restore_service.dart';
import 'package:lore/services/staged_room_invites.dart';
import 'package:lore/services/staged_room_post_writer.dart';
import 'package:lore/screens/staged_account_demo.dart';
import 'package:lore/screens/staged_room_invites_demo.dart';
import 'package:lore/screens/staged_story_import_demo.dart';
import 'package:lore/screens/staged_story_review_demo.dart';

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
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    final aliceWriter = StagedRoomPostWriter(
      auth: auth,
      firestore: firestore,
      account: alice,
      identity: aliceKey,
    );
    final freshPost = await aliceWriter.addPost(
      sessionId: roomId,
      content: 'First post in a new room',
    );
    expect(
      (await room.collection('keys').doc(alice.code).get()).exists,
      isTrue,
    );
    expect((await room.collection('keys').doc(bob.code).get()).exists, isTrue);
    expect(
      (await room.collection('posts').doc(freshPost).get()).data()?['content'],
      isNot('First post in a new room'),
    );
    await aliceWriter.deletePost(sessionId: roomId, postId: freshPost);
    final backup = RpStoryBackup(
      sessionId: 'old-room',
      exportedAt: DateTime.utc(2026),
      session: {
        'chapters': ['Chapter 1'],
      },
      posts: [
        StoryPost('post-alice', {
          'authorCode': 'old-alice',
          'authorName': 'Alice before migration',
          'content': 'The beginning',
          'createdAt': Timestamp(0, 0),
        }),
        StoryPost('post', {
          'authorCode': 'old-bob',
          'authorName': 'Bob before migration',
          'content': 'Story',
          'contentRuns': '[{"text":"Story","bold":true}]',
          'createdAt': Timestamp(1, 0),
        }),
      ],
    );
    final authors = {'old-alice': alice.code, 'old-bob': bob.code};
    await tester.pumpWidget(
      MaterialApp(
        home: StagedRoomInvitesDemo(
          auth: auth,
          firestore: firestore,
          functions: functions,
          account: alice,
        ),
      ),
    );
    await waitFor('Import a demo story');
    await tester.ensureVisible(find.text('Import a demo story'));
    await tester.tap(find.text('Import a demo story'));
    await waitFor('No restore has been started.');
    await tester.pageBack();
    await tester.pumpAndSettle();

    final backupJson = await encodeRpStory(
      sessionId: backup.sessionId,
      session: backup.session,
      posts: backup.posts,
      decrypt: (_, _) async => throw StateError('Unexpected encryption.'),
      exportedAt: backup.exportedAt,
    );
    var fileSelections = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StagedStoryImportDemo(
          auth: auth,
          firestore: firestore,
          functions: functions,
          account: alice,
          room: rooms.single,
          selectFile: () async {
            fileSelections++;
            return XFile.fromData(
              utf8.encode(fileSelections == 1 ? 'invalid JSON' : backupJson),
              name: 'test-story.json',
              mimeType: 'application/json',
            );
          },
        ),
      ),
    );
    await waitFor('No restore has been started.');
    await tester.tap(find.text('Choose backup JSON'));
    await waitFor('Unexpected character');
    await tester.tap(find.text('Choose backup JSON'));
    await waitFor('Posts: 2');
    await tester.ensureVisible(find.text('Stage backup for review'));
    await tester.tap(find.text('Stage backup for review'));
    await waitFor('Map each original author to a different participant.');

    Future<void> mapAuthor(String oldCode, String newCode) async {
      final dropdown = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.endsWith('-$oldCode'),
      );
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(newCode).last);
      await tester.pumpAndSettle();
    }

    await mapAuthor('old-alice', alice.code);
    await mapAuthor('old-bob', alice.code);
    await tester.ensureVisible(find.text('Stage backup for review'));
    await tester.tap(find.text('Stage backup for review'));
    await waitFor('Map each original author to a different participant.');
    await mapAuthor('old-bob', bob.code);
    await tester.ensureVisible(find.widgetWithText(TextField, 'PIN'));
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '000000');
    await tester.enterText(
      find.widgetWithText(TextField, 'Account password'),
      'emulator-password',
    );
    await tester.ensureVisible(find.text('Stage backup for review'));
    await tester.tap(find.text('Stage backup for review'));
    await waitFor('The password or PIN is incorrect.');
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '123456');
    await tester.enterText(
      find.widgetWithText(TextField, 'Account password'),
      'emulator-password',
    );
    await tester.ensureVisible(find.text('Stage backup for review'));
    await tester.tap(find.text('Stage backup for review'));
    await waitFor('Backup staged for partner review.');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Verify and publish demo story'),
          )
          .onPressed,
      isNull,
    );
    expect(
      (await room.collection('restore').doc('state').get()).data()?['status'],
      'review',
    );
    await expectLater(
      aliceWriter.addPost(sessionId: roomId, content: 'Not during review'),
      throwsA(isA<FirebaseException>()),
    );
    await auth.signOut();
    await waitFor('The signed-in account changed. Return and sign in again.');
    expect(find.text('Posts: 2'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await accounts.signIn(
      email: 'android-bob@example.invalid',
      password: 'emulator-password',
    );
    final oldReview = await restore.loadReview(
      sessionId: roomId,
      identity: bobKey,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StagedRoomInvitesDemo(
          auth: auth,
          firestore: firestore,
          functions: functions,
          account: bob,
        ),
      ),
    );
    await waitFor('Review a demo story');
    await tester.tap(find.text('Review a demo story'));
    await waitFor('Load story for review');

    Future<void> unlockReview(String pin) async {
      await tester.enterText(find.widgetWithText(TextField, 'PIN'), pin);
      await tester.enterText(
        find.widgetWithText(TextField, 'Account password'),
        'emulator-password',
      );
      await tester.tap(find.text('Load story for review'));
    }

    await unlockReview('000000');
    await waitFor('The password or PIN is incorrect.');
    await unlockReview('654321');
    await waitFor('Posts: 2');
    bool hasSelectable(String text) => tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .any((widget) => widget.data?.contains(text) ?? false);
    expect(hasSelectable('The beginning'), isTrue);
    expect(hasSelectable('Story'), isTrue);
    expect(hasSelectable('Chapter 1'), isTrue);
    expect(hasSelectable('bold'), isTrue);
    final approve = find.widgetWithText(FilledButton, 'Approve review');
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    await tester.tap(find.text('Reject review'));
    await waitFor('Review rejected. The importer can retry the staging.');
    expect(
      (await room.collection('restore').doc('state').get()).data()?['status'],
      'rejected',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await auth.signOut();
    await accounts.signIn(
      email: 'android-alice@example.invalid',
      password: 'emulator-password',
    );
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
    await expectLater(
      restore.decide(oldReview, approve: true),
      throwsStateError,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StagedStoryReviewDemo(
          auth: auth,
          firestore: firestore,
          functions: functions,
          account: bob,
          room: rooms.single,
        ),
      ),
    );
    await waitFor('Load story for review');
    await unlockReview('654321');
    await waitFor('Posts: 2');
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    await tester.tap(find.text('I reviewed all posts and room metadata.'));
    await tester.pump();
    expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
    await tester.tap(find.text('Approve review'));
    await waitFor(
      'Review approved. The importer can publish after verification.',
    );
    expect(
      (await room.collection('restore').doc('state').get()).data()?['status'],
      'approved',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await auth.signOut();
    await accounts.signIn(
      email: 'android-alice@example.invalid',
      password: 'emulator-password',
    );
    final incorrectBackup = await encodeRpStory(
      sessionId: backup.sessionId,
      session: backup.session,
      posts: [
        backup.posts.first,
        StoryPost('post', {
          ...backup.posts.last.data,
          'content': 'Wrong story',
        }),
      ],
      decrypt: (_, _) async => throw StateError('Unexpected encryption.'),
      exportedAt: backup.exportedAt,
    );
    var publishSelections = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StagedStoryImportDemo(
          auth: auth,
          firestore: firestore,
          functions: functions,
          account: alice,
          room: rooms.single,
          selectFile: () async {
            publishSelections++;
            return XFile.fromData(
              utf8.encode(
                publishSelections == 1 ? incorrectBackup : backupJson,
              ),
              name: 'test-story.json',
              mimeType: 'application/json',
            );
          },
        ),
      ),
    );
    await waitFor('Restore status: approved');
    await tester.tap(find.text('Choose backup JSON'));
    await waitFor('Posts: 2');
    await mapAuthor('old-alice', alice.code);
    await mapAuthor('old-bob', bob.code);
    Future<void> publish() async {
      await tester.enterText(find.widgetWithText(TextField, 'PIN'), '123456');
      await tester.enterText(
        find.widgetWithText(TextField, 'Account password'),
        'emulator-password',
      );
      await tester.ensureVisible(find.text('Verify and publish demo story'));
      await tester.tap(find.text('Verify and publish demo story'));
    }

    await publish();
    await waitFor('Story post post does not match.');
    expect((await room.collection('posts').get()).docs, isEmpty);
    await tester.ensureVisible(find.text('Refresh restore status'));
    await tester.tap(find.text('Refresh restore status'));
    await waitFor('Restore status: approved');
    await tester.ensureVisible(find.text('Choose backup JSON'));
    await tester.tap(find.text('Choose backup JSON'));
    await waitFor('Posts: 2');
    await mapAuthor('old-alice', bob.code);
    await mapAuthor('old-bob', alice.code);
    await publish();
    await waitFor('Story post post-alice does not match.');
    expect((await room.collection('posts').get()).docs, isEmpty);
    await tester.tap(find.text('Refresh restore status'));
    await waitFor('Restore status: approved');
    await mapAuthor('old-alice', alice.code);
    await mapAuthor('old-bob', bob.code);
    await publish();
    await waitFor('Demo story published and restore completed.');
    expect(
      (await room.collection('restore').doc('state').get()).data()?['status'],
      'completed',
    );
    await publish();
    await waitFor(
      'Restore was already complete; the approved staging matches this backup.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await auth.signOut();
    await accounts.signIn(
      email: 'android-bob@example.invalid',
      password: 'emulator-password',
    );
    final post = await room.collection('posts').doc('post').get();
    expect(post.exists, isTrue);
    expect(post.data()?['content'], isNot('Story'));
    final published = await restore.loadPublishedPosts(
      sessionId: roomId,
      identity: bobKey,
    );
    expect(published.map((post) => post['id']), ['post-alice', 'post']);
    expect(published.last['content'], 'Story');
    expect(published.last['contentRuns'], '[{"text":"Story","bold":true}]');
    expect(published.last['authorCode'], bob.code);
    final bobWriter = StagedRoomPostWriter(
      auth: auth,
      firestore: firestore,
      account: bob,
      identity: bobKey,
    );
    final newPostId = await bobWriter.addPost(
      sessionId: roomId,
      content: 'New encrypted post',
      contentRuns: '[{"text":"New encrypted post","bold":true}]',
      quotedContent: 'The beginning',
      quotedAuthor: 'Alice',
    );
    final encryptedPost = await room.collection('posts').doc(newPostId).get();
    expect(encryptedPost.data()?['content'], isNot('New encrypted post'));
    var postsWithNew = await restore.loadPublishedPosts(
      sessionId: roomId,
      identity: bobKey,
    );
    expect(postsWithNew.last['content'], 'New encrypted post');
    expect(postsWithNew.last['quotedContent'], 'The beginning');
    await bobWriter.editPost(
      sessionId: roomId,
      postId: newPostId,
      newContent: 'Edited encrypted post',
      contentRuns: '',
    );
    postsWithNew = await restore.loadPublishedPosts(
      sessionId: roomId,
      identity: bobKey,
    );
    expect(postsWithNew.last['content'], 'Edited encrypted post');
    expect(postsWithNew.last['contentRuns'], isNull);
    expect(postsWithNew.last['quotedContent'], 'The beginning');
    await auth.signOut();
    await accounts.signIn(
      email: 'android-alice@example.invalid',
      password: 'emulator-password',
    );
    await expectLater(
      aliceWriter.editPost(
        sessionId: roomId,
        postId: newPostId,
        newContent: 'Forbidden edit',
      ),
      throwsA(isA<FirebaseException>()),
    );
    await expectLater(
      aliceWriter.deletePost(sessionId: roomId, postId: newPostId),
      throwsA(isA<FirebaseException>()),
    );
    await expectLater(
      bobWriter.deletePost(sessionId: roomId, postId: newPostId),
      throwsStateError,
    );
    await auth.signOut();
    await accounts.signIn(
      email: 'android-bob@example.invalid',
      password: 'emulator-password',
    );
    await bobWriter.deletePost(sessionId: roomId, postId: newPostId);
    expect(
      (await room.collection('posts').doc(newPostId).get()).exists,
      isFalse,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StagedRoomInvitesDemo(
          auth: auth,
          firestore: firestore,
          functions: functions,
          account: bob,
        ),
      ),
    );
    await waitFor('View published demo story');
    await tester.ensureVisible(find.text('View published demo story'));
    await tester.tap(find.text('View published demo story'));
    await waitFor('Open published story');
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '000000');
    await tester.enterText(
      find.widgetWithText(TextField, 'Account password'),
      'emulator-password',
    );
    await tester.ensureVisible(find.text('Open published story'));
    await tester.tap(find.text('Open published story'));
    await waitFor('The password or PIN is incorrect.');
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '654321');
    await tester.enterText(
      find.widgetWithText(TextField, 'Account password'),
      'emulator-password',
    );
    await tester.ensureVisible(find.text('Open published story'));
    await tester.tap(find.text('Open published story'));
    await waitFor('Posts: 2');
    expect(find.text('The beginning'), findsOneWidget);
    expect(find.text('Story', findRichText: true), findsOneWidget);
    await auth.signOut();
    await waitFor('The signed-in account changed. Return and sign in again.');
    expect(find.text('The beginning'), findsNothing);
    expect(find.text('Story', findRichText: true), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
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

  if (app_main.migrationDemoEnabled) {
    testWidgets('real app shell opens an isolated demo account', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final name = 'Shell${DateTime.now().microsecondsSinceEpoch}';
      final email = '$name@example.invalid';
      final account = await StagedAccountService(
        auth: auth,
        firestore: firestore,
      ).register(email: email, password: 'emulator-password', name: name);
      await StagedIdentityService(
        auth: auth,
        firestore: firestore,
      ).initialize(pin: '123456', password: 'emulator-password');
      final originalUid = account.uid;
      final appsBefore = Firebase.apps.map((app) => app.name).toSet();
      await tester.pumpWidget(const app_main.LoreApp());
      await tester.runAsync(() async {
        for (var i = 0; i < 300; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          if (find.text('Create an account').evaluate().isNotEmpty) return;
        }
      });
      expect(find.text('Create an account'), findsOneWidget);
      await tester.pumpAndSettle();
      final demoApp = Firebase.app('lore-migration-demo');
      expect(demoApp.options.projectId, 'demo-lore-migration');
      expect(
        Firebase.apps.map((app) => app.name).toSet().difference(appsBefore),
        {'lore-migration-demo'},
      );
      await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'emulator-password',
      );
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Email'))
            .controller!
            .text,
        email,
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Password'))
            .controller!
            .text,
        'emulator-password',
      );
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        for (var i = 0; i < 300; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          if (find.text('Unlock $name').evaluate().isNotEmpty) return;
        }
      });
      expect(
        find.text('Unlock $name'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      expect(
        FirebaseAuth.instanceFor(app: demoApp).currentUser?.uid,
        originalUid,
      );
      expect(auth.currentUser?.uid, originalUid);
      await FirebaseAuth.instanceFor(app: demoApp).signOut();
      expect(auth.currentUser?.uid, originalUid);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
