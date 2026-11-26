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
Auth and Firestore emulators are running. It uses only the demo project and
local emulators; it does not connect to live accounts. After unlocking, users
can send, accept or decline demo room invitations using account codes and see
their demo rooms. Verify your partner's code before inviting them. Refresh after
an interrupted request before retrying, because it may already have succeeded.
Story import and the production app are not connected to these screens.

Finalization compares the approved encrypted staged and published documents;
it cannot establish that the importer included everything in the original
backup. The importer must verify that separately, and the other participant
must review the staged content. Production rollout requires additional
security review, app integration and real-device validation.
