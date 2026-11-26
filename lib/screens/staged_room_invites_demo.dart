import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/staged_account_service.dart';
import '../services/staged_room_invites.dart';

class StagedRoomInvitesDemo extends StatefulWidget {
  const StagedRoomInvitesDemo({
    super.key,
    required this.auth,
    required this.firestore,
    required this.account,
  });

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final StagedAccount account;

  @override
  State<StagedRoomInvitesDemo> createState() => _StagedRoomInvitesDemoState();
}

class _StagedRoomInvitesDemoState extends State<StagedRoomInvitesDemo> {
  late final StagedRoomInvites _service;
  late final StreamSubscription<User?> _authChanges;
  final _partner = TextEditingController();
  List<StagedRoomInvite> _invitations = [];
  List<StagedRoom> _rooms = [];
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _invalidated = false;

  @override
  void initState() {
    super.initState();
    _service = StagedRoomInvites(
      auth: widget.auth,
      firestore: widget.firestore,
      accountUid: widget.account.uid,
    );
    _authChanges = widget.auth.authStateChanges().listen(
      (user) {
        if (user?.uid != widget.account.uid || user?.isAnonymous == true) {
          _invalidate(
            'The signed-in account changed. Return and sign in again.',
          );
        }
      },
      onError: (Object error) {
        _invalidate('Could not monitor the signed-in account: $error');
      },
    );
    _run(_refresh);
  }

  void _invalidate(String message) {
    if (!mounted) return;
    setState(() {
      _invalidated = true;
      _invitations = [];
      _rooms = [];
      _partner.clear();
      _notice = null;
      _error = message;
    });
  }

  @override
  void dispose() {
    _authChanges.cancel();
    _partner.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _invalidated) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.code);
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final invites = await _service.invitations();
    final rooms = await _service.rooms();
    if (!mounted || _invalidated) return;
    setState(() {
      _invitations = invites;
      _rooms = rooms;
    });
  }

  Future<void> _send() async {
    await _service.send(_partner.text);
    if (!mounted || _invalidated) return;
    _partner.clear();
    setState(() => _notice = 'Invitation sent.');
    await _refresh();
  }

  Future<void> _respond(StagedRoomInvite invitation, bool accept) async {
    await _service.respond(invitation.id, accept: accept);
    if (!mounted || _invalidated) return;
    setState(() => _notice = accept ? 'Room created.' : 'Invitation declined.');
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Demo room invitations')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('LOCAL EMULATOR DEMO — no live accounts or data'),
              const SizedBox(height: 12),
              if (!_invalidated)
                SelectableText('Your account code: ${widget.account.code}'),
              const Text(
                'Share your code with your partner and verify their code before sending an invitation.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _partner,
                enabled: !_busy && !_invalidated,
                decoration: const InputDecoration(
                  labelText: 'Partner account code',
                  border: OutlineInputBorder(),
                ),
              ),
              FilledButton(
                onPressed: _busy || _invalidated ? null : () => _run(_send),
                child: const Text('Send invitation'),
              ),
              const Text(
                'If a request fails, refresh before retrying: it may already have been sent or accepted.',
              ),
              TextButton(
                onPressed: _busy || _invalidated ? null : () => _run(_refresh),
                child: const Text('Refresh invitations and rooms'),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_notice != null) Text(_notice!),
              const SizedBox(height: 16),
              Text(
                'Invitations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_invitations.isEmpty) const Text('No invitations loaded.'),
              for (final invite in _invitations)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          '${invite.fromCode} → ${invite.toCode}: ${invite.status}',
                        ),
                        if (invite.sessionId != null)
                          SelectableText('Room: ${invite.sessionId}'),
                        if (invite.toCode == widget.account.code &&
                            invite.status == 'pending')
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() => _respond(invite, true)),
                                child: const Text('Accept'),
                              ),
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() => _respond(invite, false)),
                                child: const Text('Decline'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Rooms', style: Theme.of(context).textTheme.titleLarge),
              if (_rooms.isEmpty) const Text('No rooms loaded.'),
              for (final room in _rooms)
                Card(
                  child: ListTile(
                    title: SelectableText('Room: ${room.id}'),
                    subtitle: SelectableText(
                      'Participants: ${room.participants.join(', ')}',
                    ),
                  ),
                ),
              const Text(
                'Story restoration is not connected to this screen yet.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
