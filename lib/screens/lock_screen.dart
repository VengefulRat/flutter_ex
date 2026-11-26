import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'package:local_auth/local_auth.dart';
import 'gestures_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

// ── Entry point ──
Future<bool> showLockScreen(BuildContext context) async {
  final result = await Navigator.of(context).push<bool>(
    PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, _, _) => const LockScreen(),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
  return result ?? false;
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.auth});

  final AuthService? auth;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _localAuth = LocalAuthentication();
  bool _biometricsAvailable = false;
  bool _bioAutoPrompted = false;
  late final _auth = widget.auth ?? AuthService();
  String _mode = 'pin'; // 'pin' | 'code'
  String _pinInput = '';
  int _pinLength = AuthService.pinMinLength;
  bool _loading = true;
  bool _verifying = false;
  String? _error;
  final _codeCtrl = TextEditingController();
  bool _codeLoading = false;
  final _pinCtrl = TextEditingController();

  // PC / web: real keyboard, no fingerprint scanner, no on-screen keypad.
  bool get _isDesktopPlatform =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
  bool _isDesktop(BuildContext context) =>
      _isDesktopPlatform || MediaQuery.sizeOf(context).width >= 900;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final pinLen = await _auth.pinLength();

    // Check if biometrics are enabled and available
    final bioEnabled = await _auth.isBiometricsEnabled();
    if (bioEnabled && !_isDesktopPlatform) {
      try {
        final canCheck = await _localAuth.canCheckBiometrics;
        final isSupported = await _localAuth.isDeviceSupported();
        if (canCheck && isSupported && !kIsWeb) {
          if (mounted) setState(() => _biometricsAvailable = true);
          if (!_bioAutoPrompted) {
            _bioAutoPrompted = true;
            await _promptBiometrics();
            if (!mounted) return; // Biometrics popped us — don't finish loading
          }
        }
      } catch (e) {
        debugPrint('Biometrics init error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _pinLength = pinLen;
        _loading = false;
      });
    }
  }

  Future<void> _promptBiometrics() async {
    if (_verifying) return;
    if (!mounted) return;
    setState(() => _verifying = true);
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock your stories',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        final success = await _auth.silentUnlock();
        if (success && mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
        } else {
          if (mounted) {
            setState(() {
              _verifying = false;
              _error = 'Biometric unlock failed. Please use your PIN.';
            });
          }
        }
      } else {
        if (mounted) setState(() => _verifying = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _error = 'Biometric error. Please use your PIN.';
        });
      }
    }
  }

  void _onDigit(String digit) {
    if (_verifying) return;
    if (_pinInput.length >= _pinLength) return;
    setState(() {
      _pinInput += digit;
      _error = null;
    });
    if (_pinInput.length == _pinLength) _verifyPin();
  }

  void _onDelete() {
    if (_pinInput.isEmpty) return;
    setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
  }

    Future<void> _verifyPin() async {
    if (_verifying) return;
    if (!mounted) return;
    setState(() => _verifying = true);

    bool ok = await _auth.verifyPin(_pinInput);
    if (!ok) {
      final code = _auth.currentCode;
      if (code != null) {
        final remote = await _auth.verifyPinRemote(code, _pinInput);
        ok = remote.success;
      }
    }

    if (ok && mounted) {
      await _auth.clearLockScreenAttempts();
  
      final unlocked = await _auth.unlockWithPin(_pinInput);
      if (!mounted) return;
      if (!unlocked) {
        setState(() {
          _pinInput = '';
          _verifying = false;
          _error =
              'Couldn\'t unlock your stories with that PIN. Try again.';
        });
        _pinCtrl.clear();
        return;
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } else if (mounted) {
      await _auth.recordFailedLockScreenAttempt();
      HapticFeedback.heavyImpact();
      setState(() {
        _pinInput = '';
        _verifying = false;
        _error = 'Incorrect PIN. Try again.';
      });
      _pinCtrl.clear();
    }
  }

    Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _codeLoading = true;
      _error = null;
    });
    final result = await _auth.login(code);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _codeLoading = false;
        _error = result.isDeviceLocked
            ? 'This account is locked to another device.'
            : 'Code not found.';
      });
      return;
    }

    setState(() {
      _codeLoading = false;
      _mode = 'pin';
      _pinInput = '';
      _pinCtrl.clear();
      _error =
          'Code accepted. Enter your PIN to unlock your stories on this device.';
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: cVoid,
        body: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 1, color: cGold),
          ),
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (_isDesktop(context)) return KeyEventResult.ignored;
        if (_mode != 'pin' || _verifying) return KeyEventResult.ignored;

        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.backspace) {
            _onDelete();
            return KeyEventResult.handled;
          }
          final numString = event.character;
          if (numString != null && RegExp(r'^[0-9]$').hasMatch(numString)) {
            _onDigit(numString);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: cVoid,
        body: SafeArea(
          // We add LayoutBuilder + SingleChildScrollView + IntrinsicHeight
          // This keeps the Spacer() working on tall screens, but allows scrolling on short ones
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          const Spacer(),
                          Image.asset(
                            'assets/images/1234.png',
                            height: _isDesktop(context) ? 160 : 120,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your worlds have been waiting',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: cSmoke,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 36),
                          if (_mode == 'pin')
                            _buildPinPrompt()
                          else
                            _buildCodePrompt(),
                          const Spacer(),
                          if (_mode == 'pin') ...[
                            GestureDetector(
                              onTap: () => setState(() {
                                _mode = 'code';
                                _error = null;
                              }),
                              child: const Text(
                                'Use a different account code',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  color: cSmoke,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_mode == 'code') ...[
                            GestureDetector(
                              onTap: () => setState(() {
                                _mode = 'pin';
                                _error = null;
                                _codeCtrl.clear();
                              }),
                              child: const Text(
                                '← Back to PIN',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  color: cSmoke,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPinPrompt() {
    return Column(
      children: [
        Text(
          'Enter your $_pinLength-digit PIN',
          style: const TextStyle(
            fontSize: 16,
            color: cMist,
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _pinLength,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pinInput.length ? cGold : Colors.transparent,
                border: Border.all(color: i < _pinInput.length ? cGold : cAsh),
              ),
            ),
          ),
        ),
        if (_biometricsAvailable && !_isDesktop(context)) ...[
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _promptBiometrics,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cGold.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.fingerprint, size: 32, color: cGold),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 11,
              color: cEmber,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 40),
        if (_isDesktop(context))
          SizedBox(
            width: 280,
            child: TextField(
              controller: _pinCtrl,
              autofocus: true,
              enabled: !_verifying,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: _pinLength,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 22,
                color: cGold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Type PIN + Enter',
                hintStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: cSmoke,
                  letterSpacing: 2,
                ),
                filled: true,
                fillColor: cInk,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: cAsh),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: cGold.withValues(alpha: 0.6)),
                ),
              ),
              onChanged: (v) {
                if (_verifying) return;
                final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                if (digits != v) {
                  _pinCtrl.text = digits;
                  _pinCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: digits.length),
                  );
                }
                setState(() {
                  _pinInput = digits;
                  _error = null;
                });
                if (digits.length == _pinLength) _verifyPin();
              },
              onSubmitted: (_) {
                if (_verifying) return;
                if (_pinInput.length == _pinLength) _verifyPin();
              },
            ),
          ),
        if (_isDesktop(context) && _verifying) ...[
          const SizedBox(height: 20),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: cGold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Unlocking...',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: cSmoke,
              letterSpacing: 3,
            ),
          ),
        ],
        if (!_isDesktop(context))
          _buildNumpad(),
      ],
    );
  }

  Widget _buildCodePrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter your unique code',
          style: TextStyle(
            fontSize: 16,
            color: cMist,
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'You will still need your PIN to unlock your stories.',
          style: TextStyle(
            fontSize: 11,
            color: cSmoke,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            color: cParchment,
            letterSpacing: 4,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: cInk,
            hintText: 'LR-XXXX-XXXX',
            hintStyle: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: cAsh,
              letterSpacing: 2,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: cAsh),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: cGold.withValues(alpha: 0.6)),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 11,
              color: cEmber,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _codeLoading ? null : _verifyCode,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: cGold.withValues(alpha: 0.15),
            child: Center(
              child: _codeLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cGold,
                      ),
                    )
                  : const Text(
                      'Unlock',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: cGold,
                        letterSpacing: 3,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumpad() => _verifying
      ? const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cGold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Unlocking...',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: cSmoke,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        )
      : _Numpad(onDigit: _onDigit, onDelete: _onDelete);
}

/// Shared numpad with press feedback. Highlights the tapped key for
/// ~120ms and fires a light haptic tap.
class _Numpad extends StatefulWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  const _Numpad({required this.onDigit, required this.onDelete});

  @override
  State<_Numpad> createState() => _NumpadState();
}

class _NumpadState extends State<_Numpad> {
  String? _pressed;

  void _tap(String d) {
    HapticFeedback.lightImpact();
    if (d == '⌫') {
      widget.onDelete();
    } else {
      widget.onDigit(d);
    }
  }

  Future<void> _flash(String d) async {
    setState(() => _pressed = d);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _pressed = null);
  }

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((d) {
                  if (d.isEmpty) return const SizedBox(width: 92, height: 72);
                  final isPressed = _pressed == d;
                  return GestureDetector(
                    onTapDown: (_) => setState(() => _pressed = d),
                    onTapUp: (_) {
                      _flash(d);
                      _tap(d);
                    },
                    onTapCancel: () => setState(() => _pressed = null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      width: 72,
                      height: 72,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPressed ? cGold.withValues(alpha: 0.15) : cInk,
                        border: Border.all(
                          color: isPressed ? cGold : cAsh,
                          width: isPressed ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: d == '⌫'
                            ? Icon(
                                Icons.backspace_outlined,
                                size: 20,
                                color: isPressed ? cGold : cSmoke,
                              )
                            : Text(
                                d,
                                style: TextStyle(
                                  fontSize: 22,
                                  color: isPressed ? cGold : cParchment,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── Lock Setup Screen ──
class LockSetupScreen extends StatefulWidget {
  final bool isFirstTime;
  const LockSetupScreen({super.key, this.isFirstTime = false});
  @override
  State<LockSetupScreen> createState() => _LockSetupScreenState();
}

class _LockSetupScreenState extends State<LockSetupScreen> {
  final _auth = AuthService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _bioEnabled = false;
  bool _bioAvailable = false;
  bool _togglingBio = false;

  int _step = 1;
  final int _pinLength = AuthService.pinMinLength;
  String _pinFirst = '';
  String _pinInput = '';
  String? _error;
  bool _savingPin = false;
  int _pinCompleteToken = 0;

  String _currentTiming = 'always';
  bool _loadingCurrent = true;

  @override
  void initState() {
    super.initState();
    if (widget.isFirstTime) {
      _loadingCurrent = false;
    } else {
      _loadCurrent();
    }
  }

  Future<void> _loadCurrent() async {
    final timing = await _auth.getLockTiming();

    final bioEnabled = await _auth.isBiometricsEnabled();
    bool bioAvailable = false;
    try {
      bioAvailable =
          await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentTiming = timing;
        _bioEnabled = bioEnabled;
        _bioAvailable = bioAvailable;
        _loadingCurrent = false;
        _step = 0;
      });
    }
  }

  void _onDigit(String digit) {
    if (_savingPin) return;
    if (_pinInput.length >= _pinLength) return;
    setState(() { _pinInput += digit; _error = null; });
    if (_pinInput.length == _pinLength) {
      final ticket = ++_pinCompleteToken;
      Future.delayed(const Duration(milliseconds: 150), () {
        _onPinComplete(ticket);
      });
    }
  }

  void _onDelete() {
    if (_savingPin) return;
    if (_pinInput.isEmpty) return;
    _pinCompleteToken++; // Cancel any pending completion — PIN is no longer full
    setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
  }

    void _onPinComplete(int ticket) {
    if (!mounted) return;
    if (ticket != _pinCompleteToken) return; // Stale — user deleted / retyped
    if (_savingPin) return;
    if (_pinInput.length != _pinLength) return; // PIN is no longer full
    if (_step == 1) {
      setState(() { _pinFirst = _pinInput; _pinInput = ''; _step = 2; });
    } else if (_step == 2) {
      if (_pinInput == _pinFirst) {
        _savePin();
      } else {
        setState(() {
          _pinInput = '';
          _error = 'PINs don\'t match. Try again.';
          _step = 1;
          _pinFirst = '';
        });
      }
    }
  }

  Future<void> _savePin() async {
    setState(() {
      _savingPin = true;
      _error = null;
    });
    try {
      await _auth.savePin(_pinFirst);
      await _auth.unlockWithPin(_pinFirst);
      if (!mounted) return;
      if (widget.isFirstTime) {
        setState(() {
          _step = 4;
          _pinInput = '';
          _savingPin = false;
        });
      } else {
        setState(() {
          _step = 0;
          _pinInput = '';
          _pinFirst = '';
          _savingPin = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingPin = false;
        _pinInput = '';
        _pinFirst = '';
        _step = 1;
        _error =
            'Could not save PIN. ${e.toString().replaceFirst('Invalid argument(s): ', '')}';
      });
    }
  }

  Future<void> _saveTimingOnly(String timing) async {
    await _auth.saveLockTiming(timing);
    if (mounted) {
      setState(() {
        _currentTiming = timing;
        _step = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Only listen when we are actually entering a PIN (step 1 or 2)
        if (_step != 1 && _step != 2) return KeyEventResult.ignored;
        if (_savingPin) return KeyEventResult.ignored;

        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.backspace) {
            _onDelete();
            return KeyEventResult.handled;
          }
          final numString = event.character;
          if (numString != null && RegExp(r'^[0-9]$').hasMatch(numString)) {
            _onDigit(numString);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: cVoid,
        body: SafeArea(
          child: _loadingCurrent
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 1,
                      color: cGold,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isFirstTime) ...[
                        const Text(
                          'SECURE YOUR ACCOUNT',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            color: cGold,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _step == 1
                              ? 'Choose a $_pinLength-digit PIN. You\'ll need this to recover your account.'
                              : _step == 2
                              ? 'Enter your PIN again to confirm.'
                              : '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: cSmoke,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ] else ...[
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_step == 0) {
                                  Navigator.of(context).pop();
                                } else {
                                  setState(() {
                                    _step = 0;
                                    _pinInput = '';
                                    _pinFirst = '';
                                    _error = null;
                                  });
                                }
                              },
                              child: const Icon(
                                Icons.arrow_back_ios,
                                color: cSmoke,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'SECURITY SETTINGS',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: cGold,
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                      Expanded(child: _buildStep()),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildOverview();
      case 1:
        return _buildPinEntry(isConfirm: false);
      case 2:
        return _buildPinEntry(isConfirm: true);
      case 4:
        return _buildDone();
      case 12:
        return _buildTimingEdit();
      default:
        return const SizedBox();
    }
  }

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PIN',
          style: TextStyle(
            fontSize: 9,
            color: cSmoke,
            fontFamily: 'monospace',
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() {
            _step = 1;
            _pinInput = '';
            _pinFirst = '';
            _error = null;
          }),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: cAsh)),
            child: Row(
              children: [
                const Text(
                  'Change PIN',
                  style: TextStyle(
                    fontSize: 15,
                    color: cParchment,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 16, color: cAsh),
              ],
            ),
          ),
        ),

        if (_bioAvailable && !kIsWeb) ...[
          const SizedBox(height: 24),
          const Text(
            'BIOMETRICS',
            style: TextStyle(
              fontSize: 9,
              color: cSmoke,
              fontFamily: 'monospace',
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              if (_togglingBio) return;
              _togglingBio = true;
              try {
                final success = await _localAuth.authenticate(
                  localizedReason: 'Confirm to enable biometric unlock',
                  options: const AuthenticationOptions(
                    stickyAuth: true,
                    biometricOnly: true,
                  ),
                );
                if (success && mounted) {
                  final next = !_bioEnabled;
                  await _auth.setBiometricsEnabled(next);
                  if (mounted) setState(() => _bioEnabled = next);
                }
              } catch (e) {
                debugPrint('Biometric setup error: $e');
              } finally {
                _togglingBio = false;
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _bioEnabled ? cGold.withValues(alpha: 0.4) : cAsh,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fingerprint, size: 20, color: cSmoke),
                  const SizedBox(width: 12),
                  Text(
                    _bioEnabled ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                      fontSize: 15,
                      color: _bioEnabled ? cGold : cMist,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _bioEnabled ? cGold.withValues(alpha: 0.2) : cAsh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 150),
                      alignment: _bioEnabled
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _bioEnabled ? cGold : cSmoke,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 32),
        const Text(
          'LOCK BEHAVIOUR',
          style: TextStyle(
            fontSize: 9,
            color: cSmoke,
            fontFamily: 'monospace',
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: cAsh)),
          child: const Text(
            'Your PIN is required every time Lore opens, to unlock your '
            'encryption keys. This protects your stories if your phone '
            'is ever in someone else\'s hands.',
            style: TextStyle(
              fontSize: 12,
              color: cMist,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinEntry({required bool isConfirm}) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    if (_savingPin) {
      return Center(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: cGold),
          ),
          const SizedBox(height: 24),
          const Text(
            'Securing your account...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: cMist,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generating your encryption key. This takes a few seconds, '
            'but only happens once.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: cSmoke,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
        ),
      );
    }

    final title = isConfirm ? 'Confirm your PIN' : 'Set your PIN';
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              color: cParchment,
              fontWeight: FontWeight.w300,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pinLength,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pinInput.length ? cGold : Colors.transparent,
                  border: Border.all(
                    color: i < _pinInput.length ? cGold : cAsh,
                  ),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: cEmber,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 40),
          if (isDesktop)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Type your PIN on your keyboard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            _buildNumpad(),
        ],
      ),
    );
  }

  Widget _buildTimingEdit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'When should Lore lock?',
          style: TextStyle(
            fontSize: 20,
            color: cParchment,
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 32),
        _timingEditOption(
          'Every time you open the app',
          'always',
          'Most secure',
        ),
        const SizedBox(height: 8),
        _timingEditOption(
          'After 5 minutes in background',
          'background',
          'Locks if you switch away for more than 5 minutes',
        ),
        const SizedBox(height: 8),
        _timingEditOption(
          'Only when fully closed',
          'close',
          'Only locks after you fully close the app',
        ),
      ],
    );
  }

  Widget _timingEditOption(String label, String value, String sub) {
    final selected = _currentTiming == value;
    return GestureDetector(
      onTap: () => _saveTimingOnly(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? cGold.withValues(alpha: 0.5) : cAsh,
          ),
          color: selected ? cGold.withValues(alpha: 0.04) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: cParchment,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11,
                      color: cSmoke,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check, size: 14, color: cGold),
          ],
        ),
      ),
    );
  }

  Widget _buildDone() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All set.',
          style: TextStyle(
            fontSize: 28,
            color: cParchment,
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your story is yours. Every word, image, and note is protected by end-to-end encryption.\n\n'
          'Your data is never shared, tracked, or sold. Only you and your writing partner hold the keys to your worlds.',
          style: TextStyle(
            fontSize: 13,
            color: cSmoke,
            fontStyle: FontStyle.italic,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 48),
        GestureDetector(
          onTap: () {
            if (widget.isFirstTime) {
              // Show the tutorial first, then go to Home
              Navigator.of(context).pushReplacement(
                fadeRoute(const GesturesScreen(isFirstTime: true)),
              );
              // We use pushReplacement so they can't back out of the tutorial to the lock screen.
              // We will handle going to Home from inside the GesturesScreen next.
            } else {
              Navigator.of(context).pop(true);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: cGold.withValues(alpha: 0.15),
            child: const Center(
              child: Text(
                'Continue',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: cGold,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumpad() => _Numpad(onDigit: _onDigit, onDelete: _onDelete);
}
