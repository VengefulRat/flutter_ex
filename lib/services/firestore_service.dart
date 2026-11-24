import 'dart:math';
import 'dart:ui' show Color;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/world.dart';
import 'auth_service.dart';
import 'crypto_service.dart';
import '../settings.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();
  final CryptoService _crypto = CryptoService();

  // ── Helper: get session key, creating it if needed ──
  Future<dynamic> _sessionKey(String sessionId) async {
    final code = _auth.currentCode;
    if (code == null) return null;

    // Fast path — cached or private key already loaded.
    var key = await _crypto.getSessionKey(sessionId: sessionId, myCode: code);
    if (key != null) return key;

    // Private key already unlocked but no session key. Try to self-heal
    // the case where the initial createSessionKey failed silently.
    if (_crypto.isUnlocked) {
      if (await _tryRecoverSessionKey(sessionId, code)) {
        key = await _crypto.getSessionKey(sessionId: sessionId, myCode: code);
      }
      return key;
    }

    // Private key is being unlocked (post-transfer, post-PIN-entry).
    // Poll briefly. 10 × 500ms = 5s ceiling. Bail immediately if the
    // unlock finishes but the key still isn't there.
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      key = await _crypto.getSessionKey(sessionId: sessionId, myCode: code);
      if (key != null) return key;
      if (_crypto.isUnlocked) {
        if (await _tryRecoverSessionKey(sessionId, code)) {
          key = await _crypto.getSessionKey(sessionId: sessionId, myCode: code);
        }
        return key;
      }
    }
    return null;
  }

  /// Self-heals a session whose sessionKey_{myCode} field is missing.
  /// Happens when the initial createSessionKey call failed (partner
  /// didn't have a public key yet, network hiccup, etc). We have
  /// everything we need now, so just write it.
  Future<bool> _tryRecoverSessionKey(String sessionId, String myCode) async {
    try {
      final doc = await _db.collection('sessions').doc(sessionId).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      if (!participants.contains(myCode)) return false;

      // Already there? Then the prior attempt just failed to decrypt
      // (key mismatch — different problem).
      if (data['sessionKey_$myCode'] != null) return false;

      String partnerCode = '';
      for (final p in participants) {
        if (p != myCode) {
          partnerCode = p;
          break;
        }
      }
      if (partnerCode.isEmpty) return false;

      // Partner must have a public key on file — otherwise there's
      // nothing to encrypt to and we can't help.
      final partnerDoc = await _db.collection('users').doc(partnerCode).get();
      if (partnerDoc.data()?['publicKey'] == null) return false;

      await _crypto.createSessionKey(
        sessionId: sessionId,
        myCode: myCode,
        partnerCode: partnerCode,
      );
      print('[sessionKey] recovered key for $sessionId');
      return true;
    } catch (e) {
      print('[sessionKey] recovery failed for $sessionId: $e');
      return false;
    }
  }

  // Throws if the session key is unavailable — refuses to write plaintext.
  Future<dynamic> _requireSessionKey(String sessionId) async {
    final key = await _sessionKey(sessionId);
    if (key == null) {
      throw StateError('Session key unavailable — refusing to write plaintext');
    }
    return key;
  }

  // ════════════════════════════════════════
  // USER PROFILE
  // ════════════════════════════════════════

  Future<Map<String, dynamic>?> getProfile(String code) async {
    final doc = await _db.collection('users').doc(code).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final code = _auth.currentCode;
    if (code == null) return;
    // Never let a profile edit overwrite auth / crypto fields,
    // even if a caller accidentally passes them.
    const blockedKeys = {
      'pinHash',
      'pinSalt',
      'publicKey',
      'encryptedPrivateKey',
      'privateKeySalt',
      'privateKeyIv',
      'deviceLocked',
      'transferPending',
      'transferCode',
      'pinAttempts',
      'pinLockedUntil',
      'code',
    };
    final safeData = Map<String, dynamic>.from(data)
      ..removeWhere((key, _) => blockedKeys.contains(key));
    await _db.collection('users').doc(code).update({
      ...safeData,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Atomically increments a numeric counter field on the current user's
  /// doc. Uses FieldValue.increment so concurrent writes from another
  /// device (or a retry) can't clobber the value. Missing fields are
  /// treated as 0 by Firestore. Silently no-ops if we're not signed in.
  Future<void> incrementUserCounter(String key, int delta) async {
    final code = _auth.currentCode;
    if (code == null) return;
    try {
      await _db.collection('users').doc(code).update({
        key: FieldValue.increment(delta),
      });
    } catch (e) {
      print('[incrementUserCounter] $key delta=$delta failed: $e');
    }
  }

  // ════════════════════════════════════════
  // DISCOVERY
  // ════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> discoverableUsers({
    String? genre,
    int limit = 20,
  }) {
    final myCode = _auth.currentCode;
    Query query = _db
        .collection('users')
        .where('isDiscoverable', isEqualTo: true)
        .limit(limit);

    if (genre != null && genre.isNotEmpty) {
      query = query.where('genres', arrayContains: genre);
    }

    return query.snapshots().map(
      (snap) => snap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .where((u) => u['code'] != myCode)
          .toList(),
    );
  }

  // ════════════════════════════════════════
  // INTERESTS (requests)
  // ════════════════════════════════════════

  Future<void> sendInterest({
    required String toCode,
    required String message,
    required String genre,
  }) async {
    final fromCode = _auth.currentCode!;
    final fromName = _auth.currentName!;

    await _db.collection('interests').add({
      'fromCode': fromCode,
      'fromName': fromName,
      'toCode': toCode,
      'message': message,
      'genre': genre,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _addNotification(
      toCode: toCode,
      type: 'interest',
      title: 'New interest from $fromName',
      subtitle: '$genre · Just now',
      data: {'fromCode': fromCode, 'genre': genre},
    );
  }

  Future<String> respondToInterest({
    required String interestId,
    required String fromCode,
    required String fromName,
    required String genre,
    required bool accepted,
  }) async {
    final myCode = _auth.currentCode!;
    final myName = _auth.currentName!;
    final interestRef = _db.collection('interests').doc(interestId);

    // Transaction: only the first responder wins. A double-tap or a retry
    // sees status != 'pending' and bails, so we can't create two sessions.
    final sessionId = await _db.runTransaction<String>((tx) async {
      final snap = await tx.get(interestRef);
      if (!snap.exists) return '';
      final data = snap.data()!;
      if (data['status'] != 'pending') return '';

      tx.update(interestRef, {
        'status': accepted ? 'accepted' : 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (!accepted) return '';

      final sessionRef = _db.collection('sessions').doc();
      tx.set(sessionRef, {
        'participants': [myCode, fromCode],
        'participantNames': {myCode: myName, fromCode: fromName},
        'genre': genre,
        'status': 'brainstorm',
        'createdAt': FieldValue.serverTimestamp(),
        'lastPostAt': FieldValue.serverTimestamp(),
        'postCount': 0,
      });
      return sessionRef.id;
    });

    if (sessionId.isEmpty) return '';

    // Post-transaction, best-effort. If either fails the session still
    // exists — the user can regenerate the key by re-opening the room.
    try {
      await _crypto.createSessionKey(
        sessionId: sessionId,
        myCode: myCode,
        partnerCode: fromCode,
      );
    } catch (e) {
      print('[respondToInterest] createSessionKey failed: $e');
    }

    try {
      await _addNotification(
        toCode: fromCode,
        type: 'accepted',
        title: '$myName accepted your request',
        subtitle: '$genre · Just now',
        data: {'sessionId': sessionId, 'genre': genre},
      );
    } catch (e) {
      print('[respondToInterest] notification failed: $e');
    }

    return sessionId;
  }

  // ════════════════════════════════════════
  // SESSIONS (RP + Brainstorm)
  // ════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> mySessions() {
    final code = _auth.currentCode!;
    return _db
        .collection('sessions')
        .where('participants', arrayContains: code)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList(),
        );
  }

  /// Sets or clears the session title. Empty string removes the title.
  Future<void> updateSessionTitle(String sessionId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      await _db.collection('sessions').doc(sessionId).update({
        'title': FieldValue.delete(),
      });
    } else {
      await _db.collection('sessions').doc(sessionId).update({
        'title': trimmed,
        'titleUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateSessionStatus(String sessionId, String status) async {
    await _db.collection('sessions').doc(sessionId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ════════════════════════════════════════
  // POSTS (RP Room)
  // ════════════════════════════════════════

    Stream<List<Map<String, dynamic>>> sessionPosts(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('posts')
        .snapshots()
        .asyncMap((snap) async {
          final sessionKey = await _sessionKey(sessionId);
          return _decryptDocs(snap, sessionKey, ['content', 'quotedContent']);
        });
  }

  Future<String?> addPost({
    required String sessionId,
    required String content,
    String? chapter,
    String? quotedPostId,
    String? quotedContent,
    String? quotedAuthor,
    String? characterName,
    String? locationName,
    Color? textColor,
  }) async {
    final code = _auth.currentCode;
    final name = _auth.currentName;
    if (code == null || name == null) {
      print('[addPost] ERROR: currentCode or currentName is null');
      return null;
    }
    print('[addPost] Writing post to session $sessionId by $code');

    try {
      final sessionKey = await _requireSessionKey(sessionId);

      final enc = await _crypto.encryptContent(content, sessionKey);
      final storedContent = enc['cipher']!;
      final storedIv = enc['iv'];

      String? storedQuotedContent;
      String? storedQuotedIv;
      if (quotedContent != null) {
        final qEnc = await _crypto.encryptContent(quotedContent, sessionKey);
        storedQuotedContent = qEnc['cipher'];
        storedQuotedIv = qEnc['iv'];
      }

      final batch = _db.batch();
      final postRef = _db
          .collection('sessions')
          .doc(sessionId)
          .collection('posts')
          .doc();

      batch.set(postRef, {
        'authorCode': code,
        'authorName': name,
        'characterName': characterName,
        'locationName': locationName,
        'textColor': textColor?.toARGB32(),
        'content': storedContent,
        'contentIv': storedIv,
        'quotedPostId': quotedPostId,
        'quotedContent': storedQuotedContent,
        'quotedContentIv': storedQuotedIv,
        'quotedAuthor': quotedAuthor,
        'encrypted': true,
        'chapter': chapter ?? 'Chapter 1',
        'createdAt': FieldValue.serverTimestamp(),
        'edited': false,
      });

      batch.update(_db.collection('sessions').doc(sessionId), {
        'lastPostAt': FieldValue.serverTimestamp(),
        'postCount': FieldValue.increment(1),
        'lastPostAuthor': code,
        'status': 'active',
      });

      await batch.commit();
      print('[addPost] Success id=${postRef.id} chapter=${chapter ?? 'Chapter 1'}');

      final partnerCode = await _getPartnerCode(sessionId, code);
      if (partnerCode != null) {
        final wordCount = content
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .length;
        await _addNotification(
          toCode: partnerCode,
          type: 'rp_post',
          title: '$name posted',
          subtitle: '$wordCount words',
          data: {'sessionId': sessionId},
        );
      }
      return postRef.id;
    } catch (e) {
      print('[addPost] FAILED: $e');
      rethrow;
    }
  }

  Future<void> editPost({
    required String sessionId,
    required String postId,
    required String newContent,
    Color? textColor,
  }) async {
    final sessionKey = await _requireSessionKey(sessionId);
    final enc = await _crypto.encryptContent(newContent, sessionKey);
    await _db
        .collection('sessions')
        .doc(sessionId)
        .collection('posts')
        .doc(postId)
        .update({
          'content': enc['cipher']!,
          'contentIv': enc['iv'],
          'textColor': textColor?.toARGB32(),
          'encrypted': true,
          'edited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> deletePost({
    required String sessionId,
    required String postId,
  }) async {
    // Batch: either both writes land or neither does, so postCount
    // can't drift if the second write fails.
    final batch = _db.batch();
    batch.delete(
      _db.collection('sessions').doc(sessionId).collection('posts').doc(postId),
    );
    batch.update(_db.collection('sessions').doc(sessionId), {
      'postCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  // ════════════════════════════════════════
  // BRAINSTORM MESSAGES
  // ════════════════════════════════════════

    Stream<List<Map<String, dynamic>>> brainstormMessages(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('brainstorm')
        .snapshots()
        .asyncMap((snap) async {
          final sessionKey = await _sessionKey(sessionId);
          return _decryptDocs(snap, sessionKey, ['content']);
        });
  }

  Future<void> addBrainstormMessage({
    required String sessionId,
    required String content,
    required String type,
  }) async {
    final code = _auth.currentCode;
    final name = _auth.currentName;
    if (code == null || name == null) return;

    final sessionKey = await _requireSessionKey(sessionId);
    final enc = await _crypto.encryptContent(content, sessionKey);
    final storedContent = enc['cipher']!;
    final storedIv = enc['iv'];

    await _db
        .collection('sessions')
        .doc(sessionId)
        .collection('brainstorm')
        .add({
          'authorCode': code,
          'authorName': name,
          'content': storedContent,
          'contentIv': storedIv,
          'encrypted': true,
          'type': type,
          'createdAt': FieldValue.serverTimestamp(),
        });

    final partnerCode = await _getPartnerCode(sessionId, code);
    if (partnerCode != null) {
      await _addNotification(
        toCode: partnerCode,
        type: 'brainstorm_message',
        title: '$name sent a message',
        subtitle: 'New message',
        data: {'sessionId': sessionId},
      );
    }
  }

  /// Change a brainstorm message's type after the fact. Used by the
  /// prelude pin menu — someone long-presses a chat message and
  /// promotes it to a rule / character / world / plot pin, or converts
  /// a pin back to chat.
  Future<void> setBrainstormMessageType({
    required String sessionId,
    required String messageId,
    required String type,
  }) async {
    await _db
        .collection('sessions')
        .doc(sessionId)
        .collection('brainstorm')
        .doc(messageId)
        .update({'type': type});
  }

  // ════════════════════════════════════════
  // OOC MESSAGES
  // ════════════════════════════════════════

    Stream<List<Map<String, dynamic>>> oocMessages(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('ooc')
        .snapshots()
        .asyncMap((snap) async {
          final sessionKey = await _sessionKey(sessionId);
          return _decryptDocs(snap, sessionKey, ['content']);
        });
  }

  Future<void> addOocMessage({
    required String sessionId,
    required String content,
    bool isSystem = false,
  }) async {
    final code = _auth.currentCode;
    final name = _auth.currentName;
    if (code == null || name == null) return;

    String storedContent = content;
    String? storedIv;
    if (!isSystem) {
      final sessionKey = await _requireSessionKey(sessionId);
      final enc = await _crypto.encryptContent(content, sessionKey);
      storedContent = enc['cipher']!;
      storedIv = enc['iv'];
    }

    await _db.collection('sessions').doc(sessionId).collection('ooc').add({
      'authorCode': isSystem ? 'system' : code,
      'authorName': isSystem ? 'System' : name,
      'content': storedContent,
      'contentIv': storedIv,
      'encrypted': !isSystem,
      'isSystem': isSystem,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!isSystem) {
      final partnerCode = await _getPartnerCode(sessionId, code);
      if (partnerCode != null) {
        await _addNotification(
          toCode: partnerCode,
          type: 'ooc_message',
          title: '$name (OOC)',
          subtitle: 'New message',
          data: {'sessionId': sessionId},
        );
      }
    }
  }

  // SHARED SESSION LOG — sessions/{id}/log/{entryId}
// Encrypted with the per-session key. Allowlist only.
// NEVER writes: importedCharacterIds, importedWorldIds, Sandbox,
// or the "write as" selection. Those stay local, per-device.

Map<String, dynamic> _sanitizeLogMap(Map<String, dynamic> input) {
  final out = <String, dynamic>{};
  for (final e in input.entries) {
    final k = e.key.toLowerCase();
    if (k.contains('key') || k.contains('token') || k.contains('code') ||
        k.contains('password') || k.contains('secret') || k.contains('private')) {
      continue;
    }
    final v = e.value;
    if (v is Map<String, dynamic>) {
      out[e.key] = _sanitizeLogMap(v);
    } else if (v is List) {
      out[e.key] = v.map((x) => x is Map<String, dynamic> ? _sanitizeLogMap(x) : x).toList();
    } else {
      out[e.key] = v;
    }
  }
  return out;
}

Future<void> upsertLogEntry({
  required String sessionId,
  required Map<String, dynamic> entryJson,
}) async {
  final sessionKey = await _requireSessionKey(sessionId);
  const allowed = {'id', 'type', 'title', 'body', 'createdAt', 'role', 'customTag', 'characterData', 'worldData'};
  final safe = <String, dynamic>{};
  for (final k in allowed) {
    if (entryJson.containsKey(k)) safe[k] = entryJson[k];
  }
  final enc = await _crypto.encryptContent(jsonEncode(_sanitizeLogMap(safe)), sessionKey);
  await _db.collection('sessions').doc(sessionId).collection('log').doc(entryJson['id'] as String).set({
    'content': enc['cipher'],
    'contentIv': enc['iv'],
    'encrypted': true,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> deleteLogEntry({required String sessionId, required String entryId}) async {
  await _db.collection('sessions').doc(sessionId).collection('log').doc(entryId).delete();
}

  Stream<List<Map<String, dynamic>>> logEntries(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('log')
        .snapshots()
        .asyncMap((snap) async {
          final sessionKey = await _sessionKey(sessionId);
          final docs = await _decryptDocs(snap, sessionKey, ['content']);
          
          final out = <Map<String, dynamic>>[];
          for (final d in docs) {
            if (d['content'] != null && d['content'] != '[encrypted]') {
              try { out.add(Map<String, dynamic>.from(jsonDecode(d['content']))); } catch (_) {}
            }
          }
          return out;
        });
  }

  // ════════════════════════════════════════
  // NOTIFICATIONS
  // ════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> myNotifications() {
    final code = _auth.currentCode!;
    return _db
        .collection('notifications')
        .where('toCode', isEqualTo: code)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
          final all = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();

          // Filter based on the user's Alert Settings
                    return all.where((n) {
            final type = n['type'] as String? ?? '';
            if (type == 'rp_post' && !appSettings.notifRpPost) return false;
            if (type == 'ooc_message' && !appSettings.notifOoc) return false;
            if (type == 'brainstorm_message' && !appSettings.notifBrainstorm) return false;
            
            // These two were previously ignored by the backend!
            if (type == 'interest' && !appSettings.notifInterest) return false;
            if (type == 'accepted' && !appSettings.notifNewPost) return false;

            // Security warnings should ALWAYS show, no matter what toggles are off.
            if (type == 'security_warning') return true;

            return true;
          }).toList();
        });
  }

  Future<void> markNotificationRead(String notifId) async {
    await _db.collection('notifications').doc(notifId).update({'read': true});
  }

  /// Returns the other participant's code, or null if the session has
  /// no valid partner (missing, single-participant, or the caller isn't
  /// in the list). Previously returned '' which callers treated as truthy.
  Future<String?> _getPartnerCode(String sessionId, String myCode) async {
    try {
      final doc = await _db.collection('sessions').doc(sessionId).get();
      if (!doc.exists) return null;
      final participants = List<String>.from(doc.data()?['participants'] ?? []);
      if (participants.length < 2) return null;
      for (final p in participants) {
        if (p != myCode) return p;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _addNotification({
    required String toCode,
    required String type,
    required String title,
    required String subtitle,
    Map<String, dynamic>? data,
  }) async {
    await _db.collection('notifications').add({
      'toCode': toCode,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'data': data ?? {},
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Invite Codes ──

  Future<String> generateInviteCode(String ownerCode) async {
    // Delete any existing unused invite code for this user
    final existing = await _db
        .collection('invites')
        .where('ownerCode', isEqualTo: ownerCode)
        .where('used', isEqualTo: false)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    // Random.secure() so two users generating in the same millisecond
    // don't collide. Retry a few times in case the doc already exists.
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();

    for (int attempt = 0; attempt < 5; attempt++) {
      final buf = StringBuffer();
      for (int i = 0; i < 8; i++) {
        buf.write(chars[rnd.nextInt(chars.length)]);
      }
      final code = buf.toString();
      final ref = _db.collection('invites').doc(code);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'code': code,
          'ownerCode': ownerCode,
          'used': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return code;
      }
    }

    throw StateError('Failed to generate unique invite code');
  }

  Future<String?> getActiveInviteCode(String ownerCode) async {
    final snap = await _db
        .collection('invites')
        .where('ownerCode', isEqualTo: ownerCode)
        .where('used', isEqualTo: false)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<String?> validateInviteCode(String inviteCode) async {
    final doc = await _db
        .collection('invites')
        .doc(inviteCode.trim().toUpperCase())
        .get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    if (data['used'] == true) return null;
    return data['ownerCode'] as String?;
  }

  Future<void> redeemInviteCode({
    required String inviteCode,
    required String fromCode,
    required String fromName,
  }) async {
    final trimmed = inviteCode.trim().toUpperCase();
    final inviteRef = _db.collection('invites').doc(trimmed);

    // Transaction: only one client can successfully mark the invite
    // used. A second simultaneous redeem reads used:true and returns null.
    final ownerCode = await _db.runTransaction<String?>((tx) async {
      final snap = await tx.get(inviteRef);
      if (!snap.exists) return null;
      final data = snap.data()!;
      if (data['used'] == true) return null;
      tx.update(inviteRef, {
        'used': true,
        'usedBy': fromCode,
        'usedAt': FieldValue.serverTimestamp(),
      });
      return data['ownerCode'] as String?;
    });

    if (ownerCode == null) return;

    try {
      await _addNotification(
        toCode: ownerCode,
        type: 'invite_request',
        title: 'Invite redeemed',
        subtitle: '$fromName wants to brainstorm with you',
        data: {
          'fromCode': fromCode,
          'fromName': fromName,
          'inviteCode': trimmed,
        },
      );
    } catch (e) {
      print('[redeemInviteCode] notification failed: $e');
    }
  }

  // ── Block System ──

  Future<void> blockUser({
    required String myCode,
    required String blockedCode,
    required bool archiveSessions,
  }) async {
    await _db.collection('blocks').doc('${myCode}_$blockedCode').set({
      'blockerCode': myCode,
      'blockedCode': blockedCode,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (archiveSessions) {
      final snap = await _db
          .collection('sessions')
          .where('participants', arrayContains: myCode)
          .get();
      for (final doc in snap.docs) {
        final participants = List<String>.from(
          doc.data()['participants'] ?? [],
        );
        if (participants.contains(blockedCode)) {
          await doc.reference.update({'status': 'archived'});
        }
      }
    }
  }

  Future<bool> isBlocked({
    required String myCode,
    required String otherCode,
  }) async {
    final a = await _db.collection('blocks').doc('${myCode}_$otherCode').get();
    final b = await _db.collection('blocks').doc('${otherCode}_$myCode').get();
    return a.exists || b.exists;
  }

  Future<void> unblockUser({
    required String myCode,
    required String blockedCode,
  }) async {
    await _db.collection('blocks').doc('${myCode}_$blockedCode').delete();
  }

  Future<List<String>> getBlockedCodes(String myCode) async {
    final snap = await _db
        .collection('blocks')
        .where('blockerCode', isEqualTo: myCode)
        .get();
    return snap.docs.map((d) => d.data()['blockedCode'] as String).toList();
  }

  Future<List<String>> getWhoBlockedMe(String myCode) async {
    final snap = await _db
        .collection('blocks')
        .where('blockedCode', isEqualTo: myCode)
        .get();
    return snap.docs.map((d) => d.data()['blockerCode'] as String).toList();
  }

  // ════════════════════════════════════════
  // SESSION STAT BLOCKS
  // ════════════════════════════════════════

  /// One stat block per participant per session. Stored under the session
  /// (not the user doc) so it lives and dies with the RP — no bleed across
  /// sessions and nothing to clean up when the session is archived.
  Stream<Map<String, StatBlock>> sessionStats(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('stats')
        .snapshots()
        .map((snap) {
          final result = <String, StatBlock>{};
          for (final doc in snap.docs) {
            try {
              result[doc.id] = _statBlockFromMap(doc.data());
            } catch (e) {
              print('[sessionStats] failed to parse ${doc.id}: $e');
            }
          }
          return result;
        });
  }

  /// Writes my stat block for this session. Pass `null` to remove it.
  /// Writes my stat block for this session. Pass `null` to remove it.
  Future<void> saveSessionStats(String sessionId, StatBlock? block) async {
    final code = _auth.currentCode;
    if (code == null) return;
    final ref = _db
        .collection('sessions')
        .doc(sessionId)
        .collection('stats')
        .doc(code);
    if (block == null) {
      try {
        await ref.delete();
      } catch (_) {}
    } else {
      try {
        await ref.set(_statBlockToMap(block));
        print(
          '[stats] wrote ${block.stats.length} stats for $code '
          'in session $sessionId',
        );
      } catch (e) {
        print('[stats] WRITE FAILED: $e');
        rethrow;
      }
    }
  }

  Map<String, dynamic> _statBlockToMap(StatBlock block) => {
    'name': block.name,
    'useTiles': block.useTiles,
    'stats': block.stats
        .map(
          (s) => {
            'name': s.name,
            'value': s.value,
            'isPool': s.isPool,
            'maxValue': s.maxValue,
            'barColor': s.barColor.toARGB32(),
            'barStyle': s.barStyle.name,
            'segments': s.segments,
          },
        )
        .toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  StatBlock _statBlockFromMap(Map<String, dynamic> data) {
    final list = (data['stats'] as List<dynamic>? ?? []);
    return StatBlock(
      name: data['name'] as String? ?? 'Stats',
      useTiles: data['useTiles'] as bool? ?? false,
      stats: list.map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return StatEntry(
          name: m['name'] as String? ?? '',
          value: (m['value'] as num?)?.toInt() ?? 0,
          isPool: m['isPool'] as bool? ?? false,
          maxValue: (m['maxValue'] as num?)?.toInt() ?? 0,
          barColor: m['barColor'] != null ? Color(m['barColor'] as int) : null,
          barStyle: StatBarStyle.values.firstWhere(
            (x) => x.name == m['barStyle'],
            orElse: () => StatBarStyle.stripe,
          ),
          segments: (m['segments'] as num?)?.toInt() ?? 10,
        );
      }).toList(),
    );
  }

  // ════════════════════════════════════════
  // MEDIA UPLOADS (E2EE)
  // ════════════════════════════════════════

  Future<dynamic> getSessionKeyForMedia(String sessionId) async {
    return await _sessionKey(sessionId);
  }

  Future<void> sendEncryptedOocMedia({
    required String sessionId,
    required String storagePath,
  }) async {
    final code = _auth.currentCode;
    final name = _auth.currentName;
    if (code == null || name == null) return;

    await _db.collection('sessions').doc(sessionId).collection('ooc').add({
      'authorCode': code,
      'authorName': name,
      'content': '',
      'mediaUrl': storagePath,
      'isEncryptedMedia': true,
      'encrypted': false,
      'isSystem': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final partnerCode = await _getPartnerCode(sessionId, code);
    if (partnerCode != null) {
      await _addNotification(
        toCode: partnerCode,
        type: 'ooc_message',
        title: '$name (OOC)',
        subtitle: 'Sent a photo',
        data: {'sessionId': sessionId},
      );
    }
  }

  Future<void> deleteNotification(String notifId) async {
    try {
      await _db.collection('notifications').doc(notifId).delete();
    } catch (e) {
      print('[deleteNotification] failed: $e');
    }
  }

  Future<void> markAllNotificationsRead(String code) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('toCode', isEqualTo: code)
          .where('read', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('[markAllRead] failed: $e');
    }
  }

  Future<void> updateSessionDetails(
    String sessionId, {
    required String title,
    required String summary,
    String? backgroundUrl,
  }) async {
    final data = <String, dynamic>{
      'title': title,
      'summary': summary,
      'backgroundUrl': ?backgroundUrl,
      'titleUpdatedAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('sessions').doc(sessionId).update(data);
  }

  Future<void> saveImportedItems(
    String sessionId,
    List<String> characterIds,
    List<String> worldIds,
  ) async {
    try {
      await _db.collection('sessions').doc(sessionId).update({
        'importedCharacterIds': characterIds,
        'importedWorldIds': worldIds,
      });
    } catch (e) {
      print('[saveImportedItems] failed: $e');
    }
  }

  Future<void> deleteSessionCompletely(String sessionId) async {
    try {
      // 1. Delete subcollections (chunked to avoid timeouts)
      final subcollections = ['posts', 'ooc', 'brainstorm', 'stats', 'log'];
      for (var sub in subcollections) {
        final snap = await _db
            .collection('sessions')
            .doc(sessionId)
            .collection(sub)
            .get();
        final batch = _db.batch();
        for (var doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // 2. Delete all files in Firebase Storage for this session
      try {
        final storageRef = FirebaseStorage.instance.ref().child(
          'sessions/$sessionId',
        );
        final listResult = await storageRef.listAll();

        // Delete items directly in the folder (e.g., background.jpg)
        for (var item in listResult.items) {
          await item.delete();
        }

        // Delete nested files (e.g., media/123.jpg, media/456.enc)
        for (var prefix in listResult.prefixes) {
          final nestedList = await prefix.listAll();
          for (var file in nestedList.items) {
            await file.delete();
          }
        }
      } catch (e) {
        // Folder might not exist if no images were ever sent, that's fine.
        print('[deleteSession] Storage delete warning: $e');
      }

      // 3. Finally, delete the main session document
      await _db.collection('sessions').doc(sessionId).delete();

      print('[deleteSession] Successfully deleted session $sessionId');
    } catch (e) {
      print('[deleteSession] FAILED: $e');
      rethrow;
    }
  }
    // ── Helper to decrypt a list of docs ──
  Future<List<Map<String, dynamic>>> _decryptDocs(
    QuerySnapshot snap,
    dynamic sessionKey,
    List<String> fieldsToDecrypt,
  ) async {
    final docs = <Map<String, dynamic>>[];
    for (final d in snap.docs) {
      final data = Map<String, dynamic>.from(d.data() as Map);
      data['id'] = d.id;
      if (data['encrypted'] == true && sessionKey != null) {
        for (final field in fieldsToDecrypt) {
          final cipher = data[field] as String?;
          final iv = data['${field}Iv'] as String?;
          if (cipher != null && iv != null) {
            final plain = await _crypto.decryptContent(
              cipherB64: cipher,
              ivB64: iv,
              sessionKey: sessionKey,
            );
            data[field] = plain ?? '[encrypted]';
          }
        }
      }
      docs.add(data);
    }
    docs.sort((a, b) {
      final at = a['createdAt'];
      final bt = b['createdAt'];
      if (at == null) return -1;
      if (bt == null) return 1;
      return (at as dynamic).compareTo(bt as dynamic);
    });
    return docs;
  }
}
