import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/rp_story_export.dart';
import '../services/staged_account_service.dart';
import '../services/staged_device_unlock.dart';
import '../services/staged_identity_service.dart';
import '../services/staged_restore_service.dart';
import '../services/staged_room_invites.dart';
import '../services/staged_story_review.dart';

/// Partner review in the isolated migration demo.
class StagedStoryReviewDemo extends StatefulWidget {
  const StagedStoryReviewDemo({
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
  State<StagedStoryReviewDemo> createState() => _StagedStoryReviewDemoState();
}

class _StagedStoryReviewDemoState extends State<StagedStoryReviewDemo> {
  late final StagedRestoreService _restore;
  late final StagedIdentityService _identity;
  late final StagedDeviceUnlock _device;
  late final StreamSubscription<User?> _authChanges;
  final _pin = TextEditingController();
  final _password = TextEditingController();
  StagedStoryReview? _review;
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _invalidated = false;
  bool _useDevice = false;
  bool _confirmed = false;

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
      _review = null;
      _confirmed = false;
      _pin.clear();
      _password.clear();
      _notice = null;
      _error = message;
    });
  }

  @override
  void dispose() {
    _authChanges.cancel();
    _review = null;
    _pin.dispose();
    _password.dispose();
    super.dispose();
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
    if (widget.room.participants.length != 2 ||
        widget.room.participants.toSet().length != 2 ||
        !widget.room.participants.contains(widget.account.code)) {
      throw StateError('The room has invalid participants.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _invalidated) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      _requireUser();
      await action();
    } on SecretBoxAuthenticationError {
      if (mounted && !_invalidated) {
        setState(() => _error = 'The password or PIN is incorrect.');
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _review = null;
      _confirmed = false;
    });
    try {
      final identity = _useDevice
          ? await _device.unlock(pin: _pin.text)
          : await _identity.unlock(pin: _pin.text, password: _password.text);
      _requireUser();
      final review = await _restore.loadReview(
        sessionId: widget.room.id,
        identity: identity,
      );
      _requireUser();
      setState(() => _review = review);
    } finally {
      if (mounted) {
        _pin.clear();
        _password.clear();
      }
    }
  }

  Future<void> _decide({required bool approve}) async {
    final review = _review;
    if (review == null || (approve && !_confirmed)) {
      throw StateError('Load and review the story before deciding.');
    }
    try {
      await _restore.decide(review, approve: approve);
      _requireUser();
      setState(
        () => _notice = approve
            ? 'Review approved. The importer can publish after verification.'
            : 'Review rejected. The importer can retry the staging.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _review = null;
          _confirmed = false;
        });
      }
    }
  }

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('LOCAL EMULATOR DEMO — use test stories only.'),
      SelectableText('Target room: ${widget.room.id}'),
      const Text(
        'Unlock to load the staged story. Review every post and all metadata '
        'before approving. Formatting details are shown as raw data, not a visual preview.',
      ),
      const Text(
        'Reviewing the staged copy does not prove that the original backup was complete.',
      ),
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
          decoration: const InputDecoration(labelText: 'Account password'),
        ),
      FilledButton(
        onPressed: _busy || _invalidated ? null : () => _run(_load),
        child: const Text('Load story for review'),
      ),
      const Text(
        'If a decision fails, check the restore status and load the review again before retrying.',
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (_notice != null) Text(_notice!),
    ],
  );

  Widget _summary(StagedStoryReview review) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 20),
      Text('Review version: ${review.reviewVersion}'),
      SelectableText('Source room: ${review.sourceSessionId}'),
      Text('Exported: ${review.exportedAt.toIso8601String()}'),
      Text('Posts: ${review.posts.length}'),
      Text('Room metadata', style: Theme.of(context).textTheme.titleLarge),
      SelectableText(formatRpStoryValue(review.session)),
      const SizedBox(height: 12),
      Text('Story posts', style: Theme.of(context).textTheme.titleLarge),
    ],
  );

  Widget _post(StagedStoryReview review, int index) {
    final post = review.posts[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              'Post ${index + 1} of ${review.posts.length}: ${post.id}',
            ),
            SelectableText(post.data['content'] as String),
            const SizedBox(height: 8),
            const Text('Complete post data, including formatting:'),
            SelectableText(formatRpStoryValue(post.data)),
          ],
        ),
      ),
    );
  }

  Widget _actions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CheckboxListTile(
        value: _confirmed,
        onChanged: _busy || _invalidated
            ? null
            : (value) => setState(() => _confirmed = value ?? false),
        title: const Text('I reviewed all posts and room metadata.'),
      ),
      Wrap(
        spacing: 8,
        children: [
          FilledButton(
            onPressed: _busy || _invalidated || !_confirmed
                ? null
                : () => _run(() => _decide(approve: true)),
            child: const Text('Approve review'),
          ),
          OutlinedButton(
            onPressed: _busy || _invalidated
                ? null
                : () => _run(() => _decide(approve: false)),
            child: const Text('Reject review'),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final review = _review;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Review a demo story')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: review == null ? 1 : review.posts.length + 3,
                itemBuilder: (context, index) {
                  if (index == 0) return _header();
                  if (index == 1) return _summary(review!);
                  if (index == review!.posts.length + 2) return _actions();
                  return _post(review, index - 2);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
