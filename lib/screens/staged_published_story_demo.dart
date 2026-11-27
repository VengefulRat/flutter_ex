import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/staged_account_service.dart';
import '../services/staged_device_unlock.dart';
import '../services/staged_identity_service.dart';
import '../services/staged_restore_service.dart';
import '../services/staged_room_invites.dart';
import 'rp_room.dart';

class StagedPublishedStoryDemo extends StatefulWidget {
  const StagedPublishedStoryDemo({
    super.key,
    required this.auth,
    required this.firestore,
    required this.functions,
    required this.account,
    required this.room,
    this.storage,
  });

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final StagedAccount account;
  final StagedRoom room;
  final FlutterSecureStorage? storage;

  @override
  State<StagedPublishedStoryDemo> createState() =>
      _StagedPublishedStoryDemoState();
}

class _StagedPublishedStoryDemoState extends State<StagedPublishedStoryDemo> {
  late final StagedRestoreService _restore;
  late final StagedIdentityService _identity;
  late final StagedDeviceUnlock _device;
  late final StreamSubscription<User?> _authChanges;
  final _pin = TextEditingController();
  final _password = TextEditingController();
  List<RPPost>? _posts;
  String? _error;
  bool _busy = false;
  bool _invalidated = false;
  bool _useDevice = false;

  @override
  void initState() {
    super.initState();
    _restore = StagedRestoreService(
      auth: widget.auth,
      firestore: widget.firestore,
      functions: widget.functions,
    );
    _identity = StagedIdentityService(
      auth: widget.auth,
      firestore: widget.firestore,
    );
    _device = StagedDeviceUnlock(
      auth: widget.auth,
      firestore: widget.firestore,
      storage: widget.storage,
    );
    _authChanges = widget.auth.authStateChanges().listen(
      (user) {
        if (user?.uid != widget.account.uid || user?.isAnonymous == true) {
          _invalidate(
            'The signed-in account changed. Return and sign in again.',
          );
        }
      },
      onError: (Object error) =>
          _invalidate('Could not monitor the signed-in account: $error'),
    );
  }

  void _invalidate(String message) {
    if (!mounted) return;
    setState(() {
      _invalidated = true;
      _posts = null;
      _pin.clear();
      _password.clear();
      _error = message;
    });
  }

  void _requireUser() {
    final user = widget.auth.currentUser;
    if (!mounted ||
        _invalidated ||
        user == null ||
        user.isAnonymous ||
        user.uid != widget.account.uid) {
      throw StateError(
        'The signed-in account changed. Return and sign in again.',
      );
    }
  }

  Future<void> _load() async {
    if (_busy || _invalidated) return;
    setState(() {
      _busy = true;
      _posts = null;
      _error = null;
    });
    try {
      _requireUser();
      final SimpleKeyPair identity;
      try {
        identity = _useDevice
            ? await _device.unlock(pin: _pin.text)
            : await _identity.unlock(pin: _pin.text, password: _password.text);
      } on SecretBoxAuthenticationError {
        throw StateError('The password or PIN is incorrect.');
      }
      _requireUser();
      final data = await _restore.loadPublishedPosts(
        sessionId: widget.room.id,
        identity: identity,
      );
      _requireUser();
      setState(() {
        _posts = data
            .map((post) => RPPost.fromData(post, widget.account.code))
            .toList();
      });
    } on SecretBoxAuthenticationError {
      if (mounted && !_invalidated) {
        setState(() => _error = 'Could not authenticate the encrypted story.');
      }
    } on FirebaseException catch (error) {
      if (mounted && !_invalidated) {
        setState(() => _error = error.message ?? error.code);
      }
    } on PlatformException catch (error) {
      if (mounted && !_invalidated) {
        setState(() => _error = error.message ?? error.code);
      }
    } on MissingPluginException catch (error) {
      if (mounted && !_invalidated) setState(() => _error = error.toString());
    } on FormatException catch (error) {
      if (mounted && !_invalidated) setState(() => _error = error.message);
    } on StateError catch (error) {
      if (mounted && !_invalidated) setState(() => _error = error.message);
    } on ArgumentError catch (error) {
      if (mounted && !_invalidated) {
        setState(() => _error = error.message.toString());
      }
    } on UnsupportedError catch (error) {
      if (mounted && !_invalidated) {
        setState(() => _error = error.message ?? error.toString());
      }
    } finally {
      if (mounted) {
        _pin.clear();
        _password.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _authChanges.cancel();
    _posts = null;
    _pin.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Published demo story')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: 1 + (posts?.length ?? 0),
                itemBuilder: (context, index) {
                  if (index > 0) {
                    return SelectionArea(
                      child: ReadOnlyRPPost(post: posts![index - 1]),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('LOCAL EMULATOR DEMO — read-only story view.'),
                      TextField(
                        controller: _pin,
                        enabled: !_busy && !_invalidated,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'PIN'),
                      ),
                      if (!kIsWeb)
                        CheckboxListTile(
                          value: _useDevice,
                          onChanged: _busy || _invalidated
                              ? null
                              : (value) => setState(() {
                                  _useDevice = value ?? false;
                                  _password.clear();
                                }),
                          title: const Text('Use this device’s PIN unlock'),
                        ),
                      if (!_useDevice)
                        TextField(
                          controller: _password,
                          enabled: !_busy && !_invalidated,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Account password',
                          ),
                        ),
                      FilledButton(
                        onPressed: _busy || _invalidated ? null : _load,
                        child: const Text('Open published story'),
                      ),
                      if (_busy) const LinearProgressIndicator(),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (posts != null) ...[
                        Text('Posts: ${posts.length}'),
                        if (posts.isEmpty)
                          const Text('The published story has no posts.'),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
