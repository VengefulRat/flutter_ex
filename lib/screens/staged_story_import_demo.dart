import 'dart:async';
import 'dart:io' show IOException;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/rp_story_import.dart';
import '../services/staged_account_service.dart';
import '../services/staged_device_unlock.dart';
import '../services/staged_identity_service.dart';
import '../services/staged_restore_service.dart';
import '../services/staged_room_invites.dart';

/// Imports only into the local migration demo, never the production app.
class StagedStoryImportDemo extends StatefulWidget {
  const StagedStoryImportDemo({
    super.key,
    required this.auth,
    required this.firestore,
    required this.functions,
    required this.account,
    required this.room,
    this.storage,
    this.selectFile,
  });

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final StagedAccount account;
  final StagedRoom room;
  final FlutterSecureStorage? storage;
  final Future<XFile?> Function()? selectFile;

  @override
  State<StagedStoryImportDemo> createState() => _StagedStoryImportDemoState();
}

class _StagedStoryImportDemoState extends State<StagedStoryImportDemo> {
  late final StagedRestoreService _restore;
  late final StagedIdentityService _identity;
  late final StagedDeviceUnlock _device;
  late final StreamSubscription<User?> _authChanges;
  final _pin = TextEditingController();
  final _password = TextEditingController();
  RpStoryBackup? _backup;
  Map<String, Set<String>> _authors = {};
  final _mapping = <String, String>{};
  String? _status;
  String? _importer;
  String? _reviewer;
  String? _error;
  String? _notice;
  bool _statusLoaded = false;
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
    _run(_refreshStatus);
  }

  void _invalidate(String message) {
    if (!mounted) return;
    setState(() {
      _invalidated = true;
      _backup = null;
      _authors = {};
      _mapping.clear();
      _pin.clear();
      _password.clear();
      _statusLoaded = false;
      _notice = null;
      _error = message;
    });
  }

  @override
  void dispose() {
    _authChanges.cancel();
    _backup = null;
    _mapping.clear();
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
    } on IOException catch (error) {
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

  Future<void> _refreshStatus() async {
    final snapshot = await widget.firestore
        .collection('sessions_v2')
        .doc(widget.room.id)
        .collection('restore')
        .doc('state')
        .get(const GetOptions(source: Source.server));
    _requireUser();
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw StateError('Restore changes are still syncing. Try again.');
    }
    final data = snapshot.data();
    final status = data?['status'];
    final importer = data?['importerCode'];
    final reviewer = data?['reviewerCode'];
    if (data != null &&
        (![
              'uploading',
              'verifying',
              'review',
              'approved',
              'rejected',
              'completed',
            ].contains(status) ||
            importer is! String ||
            reviewer is! String ||
            importer == reviewer ||
            !widget.room.participants.contains(importer) ||
            !widget.room.participants.contains(reviewer))) {
      throw StateError('The restore state is invalid.');
    }
    if (!mounted || _invalidated) return;
    setState(() {
      _status = status as String?;
      _importer = importer as String?;
      _reviewer = reviewer as String?;
      _statusLoaded = true;
    });
  }

  Future<void> _chooseBackup() async {
    final file =
        await (widget.selectFile?.call() ??
            openFile(
              acceptedTypeGroups: const [
                XTypeGroup(
                  label: 'Story backup JSON',
                  extensions: ['json'],
                  mimeTypes: ['application/json'],
                ),
              ],
            ));
    _requireUser();
    if (file == null || !mounted) return;
    setState(() {
      _backup = null;
      _authors = {};
      _mapping.clear();
    });
    final source = await file.readAsString();
    _requireUser();
    final backup = decodeRpStory(source);
    final authors = <String, Set<String>>{};
    for (final post in backup.posts) {
      final code = post.data['authorCode'];
      final name = post.data['authorName'];
      if (code is! String || code.isEmpty || name is! String) {
        throw FormatException('Post ${post.id} has no valid author.');
      }
      authors.putIfAbsent(code, () => <String>{}).add(name);
    }
    if (authors.length > 2) {
      throw const FormatException(
        'This backup has more than two authors and cannot be mapped to this room.',
      );
    }
    if (!mounted || _invalidated) return;
    setState(() {
      _backup = backup;
      _authors = authors;
    });
  }

  Future<void> _stage() async {
    final backup = _backup;
    if (backup == null) throw StateError('Choose a story backup first.');
    if (_mapping.length != _authors.length ||
        _mapping.values.toSet().length != _mapping.length) {
      throw StateError('Map each original author to a different participant.');
    }
    await _refreshStatus();
    _requireUser();
    final partner = widget.room.participants.singleWhere(
      (code) => code != widget.account.code,
    );
    if (_status != null &&
        (!['uploading', 'verifying', 'rejected'].contains(_status) ||
            _importer != widget.account.code ||
            _reviewer != partner)) {
      throw StateError(
        'This restore cannot be started or retried by your account.',
      );
    }
    try {
      final identity = _useDevice
          ? await _device.unlock(pin: _pin.text)
          : await _identity.unlock(pin: _pin.text, password: _password.text);
      _requireUser();
      if (mounted) setState(() => _statusLoaded = false);
      await _restore.stage(
        sessionId: widget.room.id,
        reviewerCode: partner,
        identity: identity,
        backup: backup,
        authorCodes: Map.of(_mapping),
      );
      await _refreshStatus();
      if (mounted && !_invalidated) {
        setState(() => _notice = 'Backup staged for partner review.');
      }
    } finally {
      if (mounted) {
        _pin.clear();
        _password.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Import a demo story')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'LOCAL EMULATOR DEMO — use a test backup, not your real story. '
                  'Backup files contain plaintext; keep the original somewhere safe.',
                ),
                const SizedBox(height: 12),
                SelectableText('Target room: ${widget.room.id}'),
                SelectableText(
                  'Participants: ${widget.room.participants.join(', ')}',
                ),
                const Text(
                  'The importer checks the staged copy against the chosen backup. '
                  'Partner review is separate; publishing is not connected yet. '
                  'Keep the original backup and remember the author mapping for publishing.',
                ),
                TextButton(
                  onPressed: _busy || _invalidated
                      ? null
                      : () => _run(_refreshStatus),
                  child: const Text('Refresh restore status'),
                ),
                Text(
                  _statusLoaded
                      ? _status == null
                            ? 'No restore has been started.'
                            : 'Restore status: $_status'
                      : 'Restore status not loaded.',
                ),
                const Text(
                  'If an upload is interrupted, refresh its status before retrying. '
                  'Retries replace staged data only; an already requested review cannot be restarted unless rejected.',
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_notice != null) Text(_notice!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy || _invalidated
                      ? null
                      : () => _run(_chooseBackup),
                  child: const Text('Choose backup JSON'),
                ),
                if (_backup != null) ...[
                  SelectableText('Source room: ${_backup!.sessionId}'),
                  Text('Exported: ${_backup!.exportedAt.toIso8601String()}'),
                  Text('Posts: ${_backup!.posts.length}'),
                  const Text(
                    'Map each original author to the correct participant:',
                  ),
                  for (final entry in _authors.entries)
                    DropdownButtonFormField<String>(
                      key: ValueKey('author-${entry.key}'),
                      initialValue: _mapping[entry.key],
                      decoration: InputDecoration(
                        labelText: '${entry.value.join(', ')} (${entry.key})',
                      ),
                      items: [
                        for (final code in widget.room.participants)
                          DropdownMenuItem(value: code, child: Text(code)),
                      ],
                      onChanged: _busy || _invalidated
                          ? null
                          : (value) => setState(() {
                              if (value == null) {
                                _mapping.remove(entry.key);
                              } else {
                                _mapping[entry.key] = value;
                              }
                            }),
                    ),
                  const SizedBox(height: 12),
                  const Text('Unlock your identity for this import.'),
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
                    onPressed: _busy || _invalidated || !_statusLoaded
                        ? null
                        : () => _run(_stage),
                    child: const Text('Stage backup for review'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
