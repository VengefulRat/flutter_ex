import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import '../services/auth_service.dart';
import '../settings.dart';
import '../services/sandbox_sync.dart';
import 'home_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show showDownloadDialog;

class WebQRPanel extends StatefulWidget {
    const WebQRPanel({super.key});
  @override
  State<WebQRPanel> createState() => WebQRPanelState();
}

class WebQRPanelState extends State<WebQRPanel> {
    final String _sessionId = _generateSessionId();

  static String _generateSessionId() {
    final rnd = Random.secure();
    return List<int>.generate(32, (_) => rnd.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
  final _db = FirebaseFirestore.instance;
  final _auth = AuthService();
  final _pinCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pinFocus = FocusNode();

  StreamSubscription? _approvalSub;
  bool _approved = false;
  bool _loggingIn = false;
  bool _showManualEntry = false;
  String _userCode = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _listenToApproval();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_pinFocus);
    });
  }

  @override
  void dispose() {
    _approvalSub?.cancel();
    _pinCtrl.dispose();
    _codeCtrl.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _submitManualCode() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_pinFocus);
    });
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Enter your code.');
      return;
    }
    setState(() {
      _loggingIn = true;
      _error = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocus.requestFocus();
    });

    final result = await _auth.loginWeb(code);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loggingIn = false;
        _error = 'Code not found. Check and try again.';
      });
      return;
    }

    setState(() {
      _userCode = code;
      _approved = true;
      _loggingIn = false;
    });
  }

    Future<void> _completeWebLogin() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'Please enter your PIN.');
      return;
    }
    setState(() {
      _loggingIn = true;
      _error = null;
    });

    if (_auth.currentCode != _userCode) {
      final result = await _auth.loginWeb(_userCode);
      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _loggingIn = false;
          _error = 'Could not find account.';
        });
        return;
      }
    }

    // Verify the PIN against the server FIRST. This is what enforces the
    // attempt counter and lockout after 5 wrong tries, and it fires
    // security notifications when someone is hammering the account.
    // Skipping this (as the old code did) meant the web flow had no
    // rate limit at all — an attacker could try PINs forever.
    final verification = await _auth.verifyPinRemote(_userCode, pin);
    if (!mounted) return;

    if (verification.isLocked) {
      await _auth.signOut();
      if (!mounted) return;
      setState(() {
        _loggingIn = false;
        _error = 'Account locked. Try again in a few minutes.';
      });
      return;
    }

    if (!verification.success) {
      final remaining = verification.attemptsRemaining;
      setState(() {
        _loggingIn = false;
        _error = remaining > 0
            ? 'Incorrect PIN. $remaining attempt${remaining == 1 ? '' : 's'} remaining.'
            : (verification.error ?? 'Incorrect PIN.');
      });
      return;
    }

    // PIN is verified by the server. Now actually load the crypto key.
    final unlocked = await _auth.unlockWithPin(pin);
    if (!mounted) return;
    if (!unlocked) {
      await _auth.signOut();
      if (!mounted) return;
      setState(() {
        _loggingIn = false;
        _error = 'Could not unlock. Try again.';
      });
      return;
    }

    await appSettings.syncFromCloud();
    await SandboxSync.syncOnLogin();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(fadeRoute(const HomeScreen()), (_) => false);
  }

  Future<void> _listenToApproval() async {
    // Web must be authed before it can listen, or the rule
    // `allow read, write: if request.auth != null` rejects it.
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint('web anon sign-in failed: $e');
      }
    }

    _approvalSub?.cancel();
    _approvalSub = _db
        .collection('web_auth_sessions')
        .doc(_sessionId)
        .snapshots()
        .listen(
          (snap) {
            if (snap.exists && snap.data()?['status'] == 'authorized') {
              if (!mounted) return;
              setState(() {
                _approved = true;
                _userCode = snap.data()!['userCode'];
              });
            }
          },
          onError: (e) {
            debugPrint('web_auth_sessions listen failed: $e');
            if (mounted) {
              setState(() => _error = 'Could not listen for approval: $e');
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Welcome back.',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                    color: cParchment,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your stories are waiting on the big screen.\n'
                  'Open Lore on your phone,\ngo to Settings > Link Desktop, and scan this code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: cSmoke,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),
                if (_approved) _buildPinEntry() else _buildQrOrManual(),
                const SizedBox(height: 48),

                // ÔöÇÔöÇ DOWNLOAD ANDROID APP BUTTON ÔöÇÔöÇ
                const Text(
                  'OR',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: cSmoke,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                LoreTap(
                  onTap: () => showDownloadDialog(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: cGold.withValues(alpha: 0.3)),
                      color: cGold.withValues(alpha: 0.05),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.android, size: 16, color: cGold),
                        SizedBox(width: 10),
                        Text(
                          'DOWNLOAD ANDROID APP',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: cGold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrOrManual() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: QrImageView(
            data: _sessionId,
            version: QrVersions.auto,
            size: 200.0,
          ),
        ),
        const SizedBox(height: 32),
        if (!_showManualEntry)
          LoreTap(
            onTap: () => setState(() {
              _showManualEntry = true;
              _error = null;
            }),
            child: const Text(
              'Log in with unique code and pin',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: cSmoke,
                letterSpacing: 1,
              ),
            ),
          )
        else
          _buildManualEntry(),
      ],
    );
  }

  Widget _buildManualEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ENTER YOUR UNIQUE CODE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(border: Border.all(color: cAsh)),
          child: TextField(
            controller: _codeCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              color: cGold,
              letterSpacing: 3,
            ),
            decoration: const InputDecoration(
              hintText: 'LR-XXXX-XXXX',
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                color: cAsh,
                fontSize: 18,
                letterSpacing: 3,
              ),
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
            ),
            cursorColor: cGold,
            onSubmitted: (_) => _submitManualCode(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 12,
              color: cEmber,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 12),
        LoreTap(
          onTap: _loggingIn ? null : _submitManualCode,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: cParchment,
            child: Center(
              child: _loggingIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cVoid,
                      ),
                    )
                  : const Text(
                      'Continue ÔåÆ',
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
        const SizedBox(height: 12),
        Center(
          child: LoreTap(
            onTap: () => setState(() {
              _showManualEntry = false;
              _error = null;
              _codeCtrl.clear();
            }),
            child: const Text(
              'Back to QR',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: cSmoke,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinEntry() {
    return Column(
      children: [
        const Text(
          'Code accepted.',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.italic,
            color: cGold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your PIN to unlock your stories on this device.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: cSmoke,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(border: Border.all(color: cAsh)),
          child: TextField(
            controller: _pinCtrl,
            focusNode: _pinFocus,
            autofocus: true,
            obscureText: true,
            keyboardType: kIsWeb
                ? TextInputType.visiblePassword
                : TextInputType.number,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 24,
              color: cGold,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              hintText: 'ÔÇóÔÇóÔÇóÔÇóÔÇóÔÇó',
              hintStyle: TextStyle(color: cAsh, letterSpacing: 8),
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
            ),
            cursorColor: cGold,
            onSubmitted: (_) => _completeWebLogin(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: cEmber, fontSize: 12)),
        ],
        const SizedBox(height: 20),
        LoreTap(
          onTap: _loggingIn ? null : _completeWebLogin,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: cParchment,
            child: Center(
              child: _loggingIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cVoid,
                      ),
                    )
                  : const Text(
                      'Unlock Web App ÔåÆ',
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
      ],
    );
  }
}
