import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'staged_account_service.dart';

class StagedRoomInvite {
  const StagedRoomInvite({
    required this.id,
    required this.fromCode,
    required this.toCode,
    required this.status,
    this.sessionId,
  });

  final String id;
  final String fromCode;
  final String toCode;
  final String status;
  final String? sessionId;
}

class StagedRoom {
  const StagedRoom({
    required this.id,
    required this.requestId,
    required this.participants,
  });

  final String id;
  final String requestId;
  final List<String> participants;
}

/// Invitation and room creation for the isolated migration demo.
class StagedRoomInvites {
  StagedRoomInvites({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required String accountUid,
  }) : _auth = auth,
       _firestore = firestore,
       _accountUid = accountUid,
       _accounts = StagedAccountService(auth: auth, firestore: firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final String _accountUid;
  final StagedAccountService _accounts;
  static const _server = GetOptions(source: Source.server);
  static final _codePattern = RegExp(
    r'^LR-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$',
  );
  static final _idPattern = RegExp(r'^[a-zA-Z0-9_-]{1,128}$');

  void _requireUser() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.uid != _accountUid) {
      throw StateError('The signed-in account changed. Sign in again.');
    }
  }

  Future<StagedAccount> _account() async {
    _requireUser();
    final account = await _accounts.currentAccount();
    _requireUser();
    if (account.uid != _accountUid) {
      throw StateError('The signed-in account changed. Sign in again.');
    }
    return account;
  }

  void _requireServer(SnapshotMetadata metadata) {
    if (metadata.isFromCache || metadata.hasPendingWrites) {
      throw StateError('Room changes are still syncing. Try again.');
    }
  }

  StagedRoomInvite _invite(String id, Map<String, dynamic> data) {
    final from = data['fromCode'];
    final to = data['toCode'];
    final status = data['status'];
    final sessionId = data['sessionId'];
    if (!_idPattern.hasMatch(id) ||
        from is! String ||
        !_codePattern.hasMatch(from) ||
        to is! String ||
        !_codePattern.hasMatch(to) ||
        from == to ||
        !['pending', 'accepted', 'declined'].contains(status) ||
        (status == 'accepted'
            ? sessionId is! String || !_idPattern.hasMatch(sessionId)
            : sessionId != null)) {
      throw StateError('An invitation contains invalid data.');
    }
    return StagedRoomInvite(
      id: id,
      fromCode: from,
      toCode: to,
      status: status as String,
      sessionId: sessionId as String?,
    );
  }

  Future<List<StagedRoomInvite>> invitations() async {
    final account = await _account();
    final collection = _firestore.collection('interests_v2');
    final incoming = await collection
        .where('toCode', isEqualTo: account.code)
        .get(_server);
    final outgoing = await collection
        .where('fromCode', isEqualTo: account.code)
        .get(_server);
    _requireServer(incoming.metadata);
    _requireServer(outgoing.metadata);
    _requireUser();
    return [
      for (final doc in [...incoming.docs, ...outgoing.docs])
        _invite(doc.id, doc.data()),
    ];
  }

  Future<List<StagedRoom>> rooms() async {
    final account = await _account();
    final snapshot = await _firestore
        .collection('sessions_v2')
        .where('participants', arrayContains: account.code)
        .get(_server);
    _requireServer(snapshot.metadata);
    _requireUser();
    return [
      for (final doc in snapshot.docs) _room(doc.id, doc.data(), account.code),
    ];
  }

  StagedRoom _room(String id, Map<String, dynamic> data, String code) {
    final requestId = data['requestId'];
    final participants = data['participants'];
    if (!_idPattern.hasMatch(id) ||
        requestId is! String ||
        !_idPattern.hasMatch(requestId) ||
        participants is! List ||
        participants.length != 2 ||
        participants.any(
          (value) => value is! String || !_codePattern.hasMatch(value),
        ) ||
        participants.toSet().length != 2 ||
        !participants.contains(code)) {
      throw StateError('A room contains invalid participant data.');
    }
    return StagedRoom(
      id: id,
      requestId: requestId,
      participants: List<String>.unmodifiable(participants.cast<String>()),
    );
  }

  Future<void> send(String partnerCode) async {
    final account = await _account();
    final code = partnerCode.trim().toUpperCase();
    if (!_codePattern.hasMatch(code) || code == account.code) {
      throw ArgumentError('Enter the other participant’s valid account code.');
    }
    _requireUser();
    await _firestore.collection('interests_v2').doc().set({
      'fromCode': account.code,
      'toCode': code,
      'status': 'pending',
    });
    _requireUser();
  }

  /// Acceptance and room creation are atomic and retryable after a lost reply.
  Future<void> respond(String invitationId, {required bool accept}) async {
    if (!_idPattern.hasMatch(invitationId)) {
      throw ArgumentError('Invalid invitation ID.');
    }
    final account = await _account();
    final request = _firestore.collection('interests_v2').doc(invitationId);
    final newRoom = _firestore.collection('sessions_v2').doc();
    _requireUser();
    // Return validation errors before writing; FlutterFire can double-complete
    // the transaction future when a callback throws on Android.
    final error = await _firestore.runTransaction<String?>((transaction) async {
      final snapshot = await transaction.get(request);
      final data = snapshot.data();
      if (data == null) return 'The invitation no longer exists.';
      StagedRoomInvite invite;
      try {
        invite = _invite(snapshot.id, data);
      } on StateError catch (error) {
        return error.message;
      }
      if (invite.toCode != account.code) {
        return 'Only the recipient can answer this invitation.';
      }
      if (invite.status == (accept ? 'accepted' : 'declined')) {
        if (accept) {
          final existingRoom = await transaction.get(
            _firestore.collection('sessions_v2').doc(invite.sessionId),
          );
          final roomData = existingRoom.data();
          if (roomData == null) {
            return 'The accepted invitation has no room.';
          }
          StagedRoom room;
          try {
            room = _room(existingRoom.id, roomData, account.code);
          } on StateError catch (error) {
            return error.message;
          }
          if (room.requestId != invitationId ||
              !room.participants.contains(invite.fromCode)) {
            return 'The accepted invitation has an invalid room.';
          }
        }
        return null;
      }
      if (invite.status != 'pending') {
        return 'This invitation has already been answered.';
      }
      if (accept) {
        transaction.update(request, {
          'status': 'accepted',
          'sessionId': newRoom.id,
        });
        transaction.set(newRoom, {
          'requestId': invitationId,
          'participants': [invite.fromCode, invite.toCode],
        });
      } else {
        transaction.update(request, {'status': 'declined'});
      }
      return null;
    });
    _requireUser();
    if (error != null) throw StateError(error);
  }
}
