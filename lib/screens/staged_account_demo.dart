import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/staged_account_service.dart';
import '../services/staged_device_unlock.dart';
import '../services/staged_identity_service.dart';
import '../theme.dart';
import 'staged_room_invites_demo.dart';

enum _Page {
  loading,
  signIn,
  register,
  finishAccount,
  setup,
  recoveryKey,
  unlock,
  recover,
  replaceRecovery,
  deviceRecovery,
  unlocked,
}

/// Isolated account prototype. It is not connected to the production app.
class StagedAccountDemo extends StatefulWidget {
  const StagedAccountDemo({
    super.key,
    required this.auth,
    required this.firestore,
    this.storage,
  });

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FlutterSecureStorage? storage;

  @override
  State<StagedAccountDemo> createState() => _StagedAccountDemoState();
}

class _StagedAccountDemoState extends State<StagedAccountDemo> {
  late final StagedAccountService _accounts;
  late final StagedIdentityService _identities;
  late final StagedDeviceUnlock _device;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _newPin = TextEditingController();
  final _confirmPin = TextEditingController();
  final _recovery = TextEditingController();
  _Page _page = _Page.loading;
  StagedAccount? _account;
  String? _recoveryKey;
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _rememberDevice = false;

  @override
  void initState() {
    super.initState();
    _accounts = StagedAccountService(
      auth: widget.auth,
      firestore: widget.firestore,
    );
    _identities = StagedIdentityService(
      auth: widget.auth,
      firestore: widget.firestore,
    );
    _device = StagedDeviceUnlock(
      auth: widget.auth,
      firestore: widget.firestore,
      storage: widget.storage,
    );
    _run(_refresh);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _pin.dispose();
    _newPin.dispose();
    _confirmPin.dispose();
    _recovery.dispose();
    _recoveryKey = null;
    super.dispose();
  }

  void _show(_Page page) {
    if (!mounted) return;
    setState(() {
      _page = page;
      _error = null;
      _notice = null;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.code);
    } on SecretBoxAuthenticationError {
      if (mounted) {
        setState(
          () => _error = 'The credentials or recovery key are incorrect.',
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.code);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.code);
    } on MissingPluginException catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on StagedNameUnavailable catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } on StagedAccountSetupRequired catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } on StagedAccountSetupFailure catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } on UnsupportedError catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final user = widget.auth.currentUser;
    if (user == null) {
      _account = null;
      _show(_Page.signIn);
      return;
    }
    if (user.isAnonymous) {
      throw StateError('The demo requires an email and password account.');
    }
    StagedAccount account;
    try {
      account = await _accounts.currentAccount();
    } on StagedAccountSetupRequired {
      _show(_Page.finishAccount);
      return;
    }
    const server = GetOptions(source: Source.server);
    final profile = await widget.firestore
        .collection('profiles_v2')
        .doc(account.code)
        .get(server);
    final identity = await widget.firestore
        .collection('private_v2')
        .doc(account.uid)
        .collection('data')
        .doc('identity')
        .get(server);
    if (profile.metadata.isFromCache ||
        profile.metadata.hasPendingWrites ||
        identity.metadata.isFromCache ||
        identity.metadata.hasPendingWrites) {
      throw StateError('Account changes are still syncing.');
    }
    if (widget.auth.currentUser?.uid != account.uid) {
      throw StateError('The signed-in account changed.');
    }
    _account = account;
    final publicKey = profile.data()?['publicKey'];
    if (publicKey == null && !identity.exists) {
      _show(_Page.setup);
    } else if (publicKey is String &&
        identity.exists &&
        identity.data()?['publicKey'] == publicKey) {
      _show(_Page.unlock);
    } else {
      throw StateError(
        'Identity setup is incomplete or invalid. Do not create a replacement key.',
      );
    }
  }

  Future<void> _authenticate({required bool register}) async {
    try {
      if (register) {
        await _accounts.register(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );
      } else {
        await _accounts.signIn(email: _email.text, password: _password.text);
      }
    } on StagedAccountSetupRequired {
      _show(_Page.loading);
      await _refresh();
      return;
    } on StagedNameUnavailable catch (error) {
      _show(_Page.loading);
      await _refresh();
      if (mounted) setState(() => _error = error.toString());
      return;
    } on StagedAccountSetupFailure catch (error) {
      _show(_Page.loading);
      await _refresh();
      if (mounted) setState(() => _error = error.toString());
      return;
    } on FirebaseException {
      if (widget.auth.currentUser != null) _show(_Page.loading);
      rethrow;
    } finally {
      if (mounted) _password.clear();
    }
    _show(_Page.loading);
    await _refresh();
  }

  Future<void> _reauthenticate() async {
    final user = widget.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw StateError('The signed-in account has no email address.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: _password.text),
    );
    if (!mounted) return;
    if (widget.auth.currentUser?.uid != user.uid) {
      throw StateError('The signed-in account changed.');
    }
    _password.clear();
    await _refresh();
  }

  Future<void> _setup() async {
    if (_pin.text != _confirmPin.text) {
      throw StateError('The PINs do not match.');
    }
    final key = await _identities.initialize(
      pin: _pin.text,
      password: _password.text,
    );
    if (!mounted) return;
    _password.clear();
    _pin.clear();
    _confirmPin.clear();
    _recovery.clear();
    _recoveryKey = key;
    _show(_Page.recoveryKey);
  }

  Future<void> _unlock({required bool device}) async {
    final pin = _pin.text;
    final identity = device
        ? await _device.unlock(pin: pin)
        : await _identities.unlock(pin: pin, password: _password.text);
    if (!device && _rememberDevice && !kIsWeb) {
      await _device.enable(identity: identity, pin: pin);
    }
    if (!mounted) return;
    _password.clear();
    _pin.clear();
    _show(_Page.unlocked);
  }

  Future<void> _recover() async {
    if (_newPin.text != _confirmPin.text) {
      throw StateError('The PINs do not match.');
    }
    await _identities.recover(
      recoveryKey: _recovery.text.trim(),
      newPin: _newPin.text,
      password: _password.text,
    );
    if (!kIsWeb) {
      await _updateDeviceAfterCloudChange(
        _device.clear,
        'cleared. Retry recovery before using this device',
      );
    }
    if (!mounted) return;
    _password.clear();
    _newPin.clear();
    _confirmPin.clear();
    _recovery.clear();
    _show(_Page.unlock);
    if (mounted) {
      setState(() => _notice = 'Recovery complete. Unlock with your new PIN.');
    }
  }

  Future<void> _recoverWithDevice() async {
    if (_newPin.text != _confirmPin.text) {
      throw StateError('The PINs do not match.');
    }
    final oldPin = _pin.text;
    final newPin = _newPin.text;
    final password = _password.text;
    final identity = await _device.unlock(pin: oldPin);
    await _identities.rewrapWithIdentity(
      identity: identity,
      pin: newPin,
      password: password,
    );
    await _updateDeviceAfterCloudChange(
      () => _device.enable(identity: identity, pin: newPin),
      'updated. Retry using the previous device PIN',
    );
    if (!mounted) return;
    _password.clear();
    _pin.clear();
    _newPin.clear();
    _confirmPin.clear();
    _show(_Page.unlocked);
  }

  Future<void> _updateDeviceAfterCloudChange(
    Future<void> Function() action,
    String nextStep,
  ) async {
    try {
      await action();
    } on FirebaseException catch (error) {
      throw StateError(
        'Cloud PIN changed, but device unlock could not be $nextStep: ${error.code}.',
      );
    } on PlatformException catch (error) {
      throw StateError(
        'Cloud PIN changed, but device unlock could not be $nextStep: ${error.message ?? error.code}.',
      );
    } on MissingPluginException catch (error) {
      throw StateError(
        'Cloud PIN changed, but device unlock could not be $nextStep: $error.',
      );
    } on StateError catch (error) {
      throw StateError(
        'Cloud PIN changed, but device unlock could not be $nextStep: ${error.message}.',
      );
    } on ArgumentError catch (error) {
      throw StateError(
        'Cloud PIN changed, but device unlock could not be $nextStep: ${error.message}.',
      );
    }
  }

  Future<void> _signOut() async {
    if (kIsWeb ||
        widget.auth.currentUser == null ||
        widget.auth.currentUser!.isAnonymous) {
      await widget.auth.signOut();
    } else {
      await _device.clearAndSignOut();
    }
    if (!mounted) return;
    _password.clear();
    _pin.clear();
    _newPin.clear();
    _confirmPin.clear();
    _recovery.clear();
    _recoveryKey = null;
    _rememberDevice = false;
    await _refresh();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      enabled: !_busy,
      obscureText: secret,
      autocorrect: !secret,
      enableSuggestions: !secret,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _button(String text, Future<void> Function() action) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: FilledButton(
      onPressed: _busy ? null : () => _run(action),
      child: Text(text),
    ),
  );

  Widget _link(String text, _Page page) => TextButton(
    onPressed: _busy
        ? null
        : () {
            _password.clear();
            _pin.clear();
            _newPin.clear();
            _confirmPin.clear();
            _recovery.clear();
            _show(page);
          },
    child: Text(text),
  );

  List<Widget> _content() {
    switch (_page) {
      case _Page.loading:
        return [
          const Text('Checking the demo account...'),
          _button('Retry', _refresh),
          if (widget.auth.currentUser != null) ...[
            const Text(
              'After a password reset, reauthenticate without removing this device key.',
            ),
            _field(_password, 'Current account password', secret: true),
            _button('Reauthenticate', _reauthenticate),
            _button('Sign out and remove device unlock', _signOut),
          ],
        ];
      case _Page.signIn:
      case _Page.register:
        final register = _page == _Page.register;
        return [
          Text(
            register ? 'Create demo account' : 'Sign in',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (register) _field(_name, 'Name'),
          _field(_email, 'Email', keyboard: TextInputType.emailAddress),
          _field(_password, 'Password', secret: true),
          _button(
            register ? 'Create account' : 'Sign in',
            () => _authenticate(register: register),
          ),
          _link(
            register ? 'Already have an account? Sign in' : 'Create an account',
            register ? _Page.signIn : _Page.register,
          ),
          if (!register)
            _button('Send password reset email', () async {
              await _accounts.sendPasswordReset(_email.text);
              if (mounted) {
                setState(
                  () => _notice =
                      'If the account exists, check its email. Encrypted data still requires a recovery key or an unlocked device.',
                );
              }
            }),
        ];
      case _Page.finishAccount:
        return [
          const Text('Finish account setup'),
          _field(_name, 'Name'),
          _button('Finish setup', () async {
            await _accounts.completeRegistration(_name.text);
            await _refresh();
          }),
          _button('Sign out', _signOut),
        ];
      case _Page.setup:
        return [
          const Text('Set up encryption'),
          const Text(
            'Choose a PIN of at least six digits. You will also receive a separate recovery key.',
          ),
          const Text(
            'If setup was interrupted after creating keys, check existing setup and replace the lost recovery key after unlocking.',
          ),
          _field(_password, 'Account password', secret: true),
          _field(_pin, 'New PIN', secret: true, keyboard: TextInputType.number),
          _field(
            _confirmPin,
            'Confirm new PIN',
            secret: true,
            keyboard: TextInputType.number,
          ),
          _button('Create encryption keys', _setup),
          _button('Check existing setup', _refresh),
          _button('Sign out', _signOut),
        ];
      case _Page.recoveryKey:
        return [
          const Text('Save your recovery key'),
          const Text(
            'Anyone with this key can recover your encrypted data. Save it somewhere safe, separate from your password. Losing it may make your data unrecoverable.',
          ),
          SelectableText(_recoveryKey ?? ''),
          _field(_recovery, 'Enter the recovery key to confirm', secret: true),
          _button('Confirm saved key', () async {
            if (_recovery.text.trim() != _recoveryKey) {
              throw StateError('The recovery key does not match.');
            }
            _recovery.clear();
            _recoveryKey = null;
            _show(_Page.unlock);
          }),
        ];
      case _Page.unlock:
        return [
          Text('Unlock ${_account?.name ?? 'account'}'),
          _field(_pin, 'PIN', secret: true, keyboard: TextInputType.number),
          if (!kIsWeb)
            _button('Unlock with device PIN', () => _unlock(device: true)),
          _field(_password, 'Account password', secret: true),
          if (!kIsWeb)
            CheckboxListTile(
              value: _rememberDevice,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _rememberDevice = value ?? false),
              title: const Text('Enable PIN unlock on this device'),
            ),
          _button('Unlock with password and PIN', () => _unlock(device: false)),
          _link('Recover with recovery key', _Page.recover),
          _link('Replace a lost recovery key', _Page.replaceRecovery),
          if (!kIsWeb)
            _link(
              'Recover with device PIN after password reset',
              _Page.deviceRecovery,
            ),
          _button('Sign out', _signOut),
        ];
      case _Page.recover:
        return [
          const Text('Recover encrypted data'),
          _field(_recovery, 'Recovery key', secret: true),
          _field(_password, 'Current account password', secret: true),
          _field(
            _newPin,
            'New PIN',
            secret: true,
            keyboard: TextInputType.number,
          ),
          _field(
            _confirmPin,
            'Confirm new PIN',
            secret: true,
            keyboard: TextInputType.number,
          ),
          _button('Recover', _recover),
          _link('Back to unlock', _Page.unlock),
        ];
      case _Page.deviceRecovery:
        return [
          const Text('Recover using this device'),
          _field(
            _pin,
            'Current device PIN',
            secret: true,
            keyboard: TextInputType.number,
          ),
          _field(_password, 'Current account password', secret: true),
          _field(
            _newPin,
            'New PIN',
            secret: true,
            keyboard: TextInputType.number,
          ),
          _field(
            _confirmPin,
            'Confirm new PIN',
            secret: true,
            keyboard: TextInputType.number,
          ),
          _button('Update cloud credentials', _recoverWithDevice),
          _link('Back to unlock', _Page.unlock),
        ];
      case _Page.replaceRecovery:
        return [
          const Text('Replace a lost recovery key'),
          const Text(
            'Your previous recovery key will stop working. Save the new key separately.',
          ),
          _field(_password, 'Account password', secret: true),
          _field(_pin, 'PIN', secret: true, keyboard: TextInputType.number),
          _button('Create replacement recovery key', () async {
            final key = await _identities.replaceRecoveryKey(
              pin: _pin.text,
              password: _password.text,
            );
            if (!mounted) return;
            _password.clear();
            _pin.clear();
            _recovery.clear();
            _recoveryKey = key;
            _show(_Page.recoveryKey);
          }),
          _link('Back to unlock', _Page.unlock),
        ];
      case _Page.unlocked:
        return [
          Text('Demo account unlocked: ${_account?.name ?? ''}'),
          Text('Account code: ${_account?.code ?? ''}'),
          const Text(
            'Story restoration and the rest of the app are not connected yet.',
          ),
          _button('Demo room invitations', () async {
            final account = _account;
            if (account == null ||
                widget.auth.currentUser?.uid != account.uid) {
              throw StateError('The signed-in account changed. Sign in again.');
            }
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StagedRoomInvitesDemo(
                  auth: widget.auth,
                  firestore: widget.firestore,
                  account: account,
                ),
              ),
            );
            if (mounted && widget.auth.currentUser?.uid != account.uid) {
              _account = null;
              _show(_Page.loading);
              await _refresh();
            }
          }),
          _button('Lock', () async {
            _show(_Page.unlock);
          }),
          _button('Sign out', _signOut),
        ];
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cVoid,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('LOCAL EMULATOR DEMO — no live accounts or data'),
              const SizedBox(height: 20),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: cEmber)),
              if (_notice != null)
                Text(_notice!, style: const TextStyle(color: cIce)),
              ..._content(),
            ],
          ),
        ),
      ),
    ),
  );
}
