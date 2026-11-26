import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/screens/lock_screen.dart';
import 'package:lore/services/auth_service.dart';

class _FakeAuth implements AuthService {
  int silentUnlockCalls = 0;
  int pinUnlockCalls = 0;

  @override
  String? get currentCode => 'LR-TEST-CODE';

  @override
  Future<int> pinLength() async => 6;

  @override
  Future<bool> isBiometricsEnabled() async => false;

  @override
  Future<LoginResult> login(String code) async =>
      LoginResult.success(code, 'Writer');

  @override
  Future<bool> silentUnlock() async {
    silentUnlockCalls++;
    return true;
  }

  @override
  Future<bool> verifyPin(String pin) async => pin == '123456';

  @override
  Future<PinVerifyResult> verifyPinRemote(String code, String pin) async =>
      const PinVerifyResult(success: false);

  @override
  Future<bool> unlockWithPin(String pin) async {
    pinUnlockCalls++;
    return true;
  }

  @override
  Future<void> clearLockScreenAttempts() async {}

  @override
  Future<void> recordFailedLockScreenAttempt() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('account code cannot unlock without a valid PIN', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    final auth = _FakeAuth();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LockScreen(auth: auth),
                ),
              ),
              child: const Text('Open lock'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open lock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use a different account code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lr-test-code');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.textContaining('Code accepted. Enter your PIN'), findsOneWidget);
    expect(auth.silentUnlockCalls, 0);

    await tester.enterText(find.byType(TextField), '111111');
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
    expect(find.byType(LockScreen), findsOneWidget);
    expect(auth.pinUnlockCalls, 0);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsNothing);
    expect(auth.pinUnlockCalls, 1);
    expect(auth.silentUnlockCalls, 0);
  });
}
