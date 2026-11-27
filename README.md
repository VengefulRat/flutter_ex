# lore2

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Migration emulator tests

The migration services and rules are incomplete and are not connected to the
production app. Do not deploy the rules or function under `test/firestore`.
The function is intentionally restricted to the local demo emulators.

Install the emulator function dependencies with `npm ci` in
`test/firestore/functions`. From `test/firestore`, run:

```
firebase emulators:exec --project demo-lore-migration --only auth,firestore,functions --config firebase.json "node --test restore_finalizer_test.js auth_rules_integration_test.js"
firebase emulators:exec --project demo-lore-migration --only firestore --config firebase.json "node --test account_rules_test.js"
```

For the Android integration test, start the Auth, Firestore and Functions
emulators with the same project and config, then run
`flutter test integration_test/staged_restore_test.dart -d <android-device>`.
Use an Android emulator: the test connects to the host's local Firebase
emulators. Its debug-only network configuration permits HTTP to `10.0.2.2`.

The standalone account demo can be launched with
`flutter run -t lib/migration_demo.dart -d <android-emulator>`, while the local
Auth, Firestore and Functions emulators are running. It uses only the demo
project and local emulators; it does not connect to live accounts. After
unlocking, users can send, accept or decline demo room invitations using account
codes and see their demo rooms. Verify your partner's code before inviting them.
Refresh after an interrupted request before retrying, because it may already
have succeeded.
For a demo room, a test backup can be selected, its authors mapped to the two
participants, and its encrypted contents staged for review. The partner can
load all staged posts and room metadata, then approve or reject the reviewed
version. Formatting is displayed as raw data, not a visual preview. Use test
data, not the real story: this is not a production environment. After approval,
the importer selects the same backup and mapping on the import screen to verify
and publish. If publishing is interrupted, refresh the status and retry with
the same backup and mapping. Keep the original backup safe; the production app
remains separate.

The normal app entry point can also open this same demo in the real app shell:
`flutter run -t lib/main.dart --dart-define=LORE_MIGRATION_DEMO=true -d <android-emulator>`.
This switch only works in debug builds and initializes the named demo project
and local emulators instead of production Firebase. Without it, startup and
existing accounts remain unchanged. This is not yet production integration:
the existing home and room screens still use the legacy schema.
After publishing, a read-only demo view can unlock and display the restored
posts using the room's text renderer. The full room screen is not yet connected
to the new service; it still uses the legacy schema.
The existing room editor now uses a post-writer interface. An encrypted writer
for the demo schema exists, but is not yet selected by the full room screen;
room metadata, notifications, and the remaining room features still need to be
migrated before that switch is safe.

Finalization compares the approved encrypted staged and published documents;
it cannot establish that the importer included everything in the original
backup. The importer must verify that separately, and the other participant
must review the staged content. Production rollout requires additional
security review, app integration and real-device validation.
