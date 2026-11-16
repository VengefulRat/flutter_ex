import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show HomeScreen;
import '../theme.dart';
import '../widgets/shared.dart';
import '../services/auth_service.dart';
import '../settings.dart';
import '../services/sandbox_sync.dart';
import '../services/firestore_service.dart';
import '../widgets/support_link.dart';
import 'lock_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool startOnLogin;
  const LoginScreen({super.key, this.startOnLogin = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late int _mode; // 0 = Login, 1 = Register, 2 = Web QR

  @override
  void initState() {
    super.initState();
    // Web uses the old code + PIN login for now.
    // QR login is disabled until we fix it properly.
    _mode = widget.startOnLogin ? 0 : 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cVoid,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _mode == 0
              ? _LoginPanel(onSwitch: () => setState(() => _mode = 1))
              : _RegisterPanel(onSwitch: () => setState(() => _mode = 0)),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
// REGISTER PANEL
// ════════════════════════════════════════
class _RegisterPanel extends StatefulWidget {
  final VoidCallback onSwitch;
  const _RegisterPanel({required this.onSwitch});
  @override
  State<_RegisterPanel> createState() => _RegisterPanelState();
}

class _RegisterPanelState extends State<_RegisterPanel> {
  final _ctrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  final _auth = AuthService();
  final _fs = FirestoreService();
  bool _loading = false;
  String? _error;
  String? _generatedCode;
  String? _registeredName;
  bool _showInviteEntry = false;
  String? _inviteError;
  bool _inviteLoading = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeemInviteAndContinue() async {
    final code = _inviteCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      _continue();
      return;
    }
    setState(() {
      _inviteLoading = true;
      _inviteError = null;
    });
    final ownerCode = await _fs.validateInviteCode(code);
    if (!mounted) return;
    if (ownerCode == null) {
      setState(() {
        _inviteError = 'Invalid or already used invite code.';
        _inviteLoading = false;
      });
      return;
    }
    await _fs.redeemInviteCode(
      inviteCode: code,
      fromCode: _auth.currentCode ?? '',
      fromName: _registeredName ?? '',
    );
    if (mounted) _continue();
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _auth.register(_ctrl.text);
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _generatedCode = result.code;
        _registeredName = result.name;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.errorMessage;
        _loading = false;
      });
    }
  }

  void _copyCode() {
    if (_generatedCode == null) return;
    Clipboard.setData(ClipboardData(text: _generatedCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cInk,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        content: const Text(
          'Code copied to clipboard',
          style: TextStyle(
            color: cParchment,
            fontStyle: FontStyle.italic,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _continue() {
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(const LockSetupScreen(isFirstTime: true)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_generatedCode != null) {
      return _buildCodeReveal();
    }
    return _buildNamePicker();
  }

  Widget _buildNamePicker() {
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          32,
          32,
          32,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text(
              'LORE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: cGold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your story starts here.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                fontStyle: FontStyle.italic,
                color: cParchment,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Welcome to Lore — your new home for the worlds you build together. '
              'No email. No password. Just a name, and a private code that is the key to your world.',
              style: TextStyle(
                fontSize: 13,
                color: cSmoke,
                fontStyle: FontStyle.italic,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Here is how it goes:\n'
              '1. Choose your name\n'
              '2. Save your private code\n'
              '3. Set your PIN — then step inside.',
              style: TextStyle(
                fontSize: 12,
                color: cMist,
                fontStyle: FontStyle.italic,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(border: Border.all(color: cAsh)),
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(
                  fontSize: 18,
                  color: cParchment,
                  fontStyle: FontStyle.italic,
                ),
                decoration: const InputDecoration(
                  hintText: 'Your name...',
                  hintStyle: TextStyle(
                    color: cSmoke,
                    fontStyle: FontStyle.italic,
                    fontSize: 18,
                  ),
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
                cursorColor: cGold,
                maxLength: 24,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => Text(
                      '$currentLength/$maxLength',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: cSmoke,
                      ),
                    ),
                onSubmitted: (_) => _register(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: cEmber,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
              behavior: HitTestBehavior.opaque,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _acceptedTerms
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 20,
                    color: _acceptedTerms ? cGold : cSmoke,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'I am 18 or older and I agree to the Terms of Service & Privacy Policy. I understand this platform is for fictional roleplay.',
                      style: TextStyle(fontSize: 12, color: cMist, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LoreTap(
              onTap: (_loading || !_acceptedTerms) ? null : _register,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: _acceptedTerms ? cParchment : cAsh,
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cVoid,
                          ),
                        )
                      : Text(
                          'Begin your story →',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: _acceptedTerms ? cVoid : cSmoke,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: LoreTap(
                onTap: widget.onSwitch,
                child: const Text(
                  'Already have a code? Enter it here',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: SupportLink(
                contextNote: 'Sent from the registration screen.',
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeReveal() {
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text(
              'LORE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: cGold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome, $_registeredName.',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                fontStyle: FontStyle.italic,
                color: cParchment,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You did it. Your world is waiting for you. '
              'This is your private code — the only key to it. '
              'Save it somewhere safe, then step inside.',
              style: TextStyle(
                fontSize: 13,
                color: cSmoke,
                fontStyle: FontStyle.italic,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 40),
            LoreTap(
              onTap: _copyCode,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cInk,
                  border: Border.all(color: cGold.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Text(
                      _generatedCode!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 24,
                        color: cGold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'tap to copy',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: cSmoke,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cInk,
                border: Border.all(color: cEmber.withValues(alpha: 0.4)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_outlined, color: cEmber, size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This code is your permanent identity. Write it down somewhere safe.\n\n'
                      'If you lose it, your account is gone forever — there is no recovery, no reset, no support option.\n\n'
                      'Never share it with anyone.',
                      style: TextStyle(
                        fontSize: 11,
                        color: cEmber,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (!_showInviteEntry) ...[
              LoreTap(
                onTap: () => setState(() => _showInviteEntry = true),
                child: const Text(
                  'Have an invite code? Enter it here',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: cSmoke,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'INVITE CODE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cGold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'If someone shared an invite code with you, enter it below to send them a direct brainstorm request.',
                style: TextStyle(
                  fontSize: 12,
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inviteCtrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  color: cGold,
                  letterSpacing: 4,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cInk,
                  hintText: 'XXXXXXXX',
                  hintStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    color: cAsh,
                    letterSpacing: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: cGold.withValues(alpha: 0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: cGold.withValues(alpha: 0.7)),
                  ),
                ),
              ),
              if (_inviteError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _inviteError!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: cEmber,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            LoreTap(
              onTap: (_loading || _inviteLoading)
                  ? null
                  : (_showInviteEntry ? _redeemInviteAndContinue : _continue),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: cParchment,
                child: Center(
                  child: _inviteLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cVoid,
                          ),
                        )
                      : Text(
                          _showInviteEntry
                              ? 'Send request & enter →'
                              : 'I\'ve saved my code — take me in →',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: cVoid,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
// LOGIN PANEL
// ════════════════════════════════════════
class _LoginPanel extends StatefulWidget {
  final VoidCallback onSwitch;
  const _LoginPanel({required this.onSwitch});
  @override
  State<_LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<_LoginPanel> {
  final _ctrl = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _auth.login(_ctrl.text);
    if (!mounted) return;
    if (result.success) {
      await appSettings.syncFromCloud();
      await SandboxSync.syncOnLogin();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushAndRemoveUntil(fadeRoute(const HomeScreen()), (_) => false);
    } else if (result.isDeviceLocked) {
      setState(() {
        _loading = false;
      });
      _showDeviceLockedDialog();
    } else {
      setState(() {
        _error = result.errorMessage;
        _loading = false;
      });
    }
  }

  void _showDeviceLockedDialog() {
    final pinCtrl = TextEditingController();
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: cInk,
          shape: const RoundedRectangleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACCOUNT LOCKED',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cEmber,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This account is locked to another device.\n\n'
                  'If this is you on a new phone, enter your PIN to transfer the account here.',
                  style: TextStyle(
                    fontSize: 13,
                    color: cMist,
                    height: 1.7,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: pinCtrl,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    color: cGold,
                    letterSpacing: 6,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••',
                    hintStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 20,
                      color: cAsh,
                      letterSpacing: 6,
                    ),
                    counterText: '',
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: cAsh),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: cGold),
                    ),
                    filled: true,
                    fillColor: cVoid,
                  ),
                  cursorColor: cGold,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: cEmber,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: LoreTap(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: cAsh),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: cSmoke,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LoreTap(
                        onTap: loading
                            ? null
                            : () async {
                                if (pinCtrl.text.isEmpty) {
                                  setDialogState(
                                    () => error = 'Please enter your PIN.',
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  loading = true;
                                  error = null;
                                });

                                final nav = Navigator.of(
                                  context,
                                ); // Capture BEFORE async gap

                                final result = await _auth.completeLoginWithPin(
                                  code: _ctrl.text.trim().toUpperCase(),
                                  pin: pinCtrl.text,
                                );

                                if (!ctx.mounted) return;

                                if (result.success) {
                                  await appSettings.syncFromCloud();
                                  await SandboxSync.syncOnLogin();

                                  if (!ctx.mounted) return;
                                  Navigator.of(ctx).pop(); // Close the dialog

                                  nav.pushAndRemoveUntil(
                                    fadeRoute(const HomeScreen()),
                                    (_) => false,
                                  );
                                } else {
                                  setDialogState(() {
                                    loading = false;
                                    error =
                                        result.errorMessage ?? 'Incorrect PIN.';
                                  });
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: cGold.withValues(alpha: 0.9),
                          child: Center(
                            child: loading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: cVoid,
                                    ),
                                  )
                                : const Text(
                                    'Transfer here',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 9,
                                      color: cVoid,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          32,
          32,
          32,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text(
              'LORE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: cGold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome back.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                fontStyle: FontStyle.italic,
                color: cParchment,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your worlds have been waiting for you. '
              'Enter your code to step back inside.',
              style: TextStyle(
                fontSize: 13,
                color: cSmoke,
                fontStyle: FontStyle.italic,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(border: Border.all(color: cAsh)),
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  color: cGold,
                  letterSpacing: 3,
                ),
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'LR-XXXX-XXXX',
                  hintStyle: TextStyle(
                    fontFamily: 'monospace',
                    color: cAsh,
                    fontSize: 20,
                    letterSpacing: 3,
                  ),
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
                cursorColor: cGold,
                onSubmitted: (_) => _login(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: cEmber,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 20),
            LoreTap(
              onTap: _loading ? null : _login,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: cParchment,
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cVoid,
                          ),
                        )
                      : const Text(
                          'Step back inside →',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: cVoid,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: LoreTap(
                onTap: widget.onSwitch,
                child: const Text(
                  'New here? Choose a name',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 12),
            const Center(
              child: SupportLink(contextNote: 'Sent from the login screen.'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
