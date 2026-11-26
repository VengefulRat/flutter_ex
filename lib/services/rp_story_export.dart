import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'crypto_service.dart';

typedef StoryDecrypt = Future<String?> Function(String cipher, String iv);

class StoryPost {
  const StoryPost(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;
}

const rpStorySessionFields = [
  'title',
  'summary',
  'genre',
  'participants',
  'participantNames',
  'createdAt',
  'chapters',
  'postChapters',
];

Map<String, dynamic> _storySession(Map<String, dynamic> data) => {
  for (final field in rpStorySessionFields)
    if (data.containsKey(field)) field: data[field],
};

Object? _jsonValue(Object? value) {
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  if (value is Timestamp) {
    return {
      r'$type': 'firestore_timestamp',
      'seconds': value.seconds,
      'nanoseconds': value.nanoseconds,
    };
  }
  if (value is List) return value.map(_jsonValue).toList();
  if (value is Map) {
    final keys = value.keys.toList();
    if (keys.any((key) => key is! String)) {
      throw const FormatException('A story field has a non-string map key.');
    }
    final stringKeys = keys.cast<String>()..sort();
    return {for (final key in stringKeys) key: _jsonValue(value[key])};
  }
  throw FormatException('Unsupported story value: ${value.runtimeType}.');
}

/// Formats story metadata without dropping Firestore timestamp precision.
String formatRpStoryValue(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(_jsonValue(value));

/// Produces a versioned plaintext file; encrypted fields must all decrypt.
Future<String> encodeRpStory({
  required String sessionId,
  required Map<String, dynamic> session,
  required List<StoryPost> posts,
  required StoryDecrypt decrypt,
  required DateTime exportedAt,
}) async {
  final sorted = [...posts]
    ..sort((a, b) {
      final aTime = a.data['createdAt'];
      final bTime = b.data['createdAt'];
      if (aTime != null && aTime is! Timestamp ||
          bTime != null && bTime is! Timestamp) {
        throw const FormatException(
          'A post has an invalid creation timestamp.',
        );
      }
      if (aTime == null && bTime != null) return -1;
      if (aTime != null && bTime == null) return 1;
      final order = aTime == null
          ? 0
          : (aTime as Timestamp).compareTo(bTime as Timestamp);
      return order != 0 ? order : a.id.compareTo(b.id);
    });

  final decodedPosts = <Map<String, dynamic>>[];
  for (final post in sorted) {
    final data = Map<String, dynamic>.from(post.data);
    if (data['createdAt'] != null && data['createdAt'] is! Timestamp) {
      throw FormatException('Post ${post.id}: invalid creation timestamp.');
    }
    if (data['encrypted'] == true) {
      for (final field in ['content', 'quotedContent', 'contentRuns']) {
        final cipher = data[field];
        final iv = data['${field}Iv'];
        if (cipher == null && iv == null && field != 'content') continue;
        if (cipher is! String || iv is! String) {
          throw FormatException('Post ${post.id}: missing encrypted $field.');
        }
        final plain = await decrypt(cipher, iv);
        if (plain == null) {
          throw FormatException('Post ${post.id}: cannot decrypt $field.');
        }
        data[field] = plain;
        data.remove('${field}Iv');
      }
      data['encrypted'] = false;
    } else if (data['encrypted'] != null && data['encrypted'] != false) {
      throw FormatException('Post ${post.id}: invalid encryption flag.');
    }
    if (data['content'] is! String) {
      throw FormatException('Post ${post.id}: missing story content.');
    }
    decodedPosts.add({'id': post.id, 'data': _jsonValue(data)});
  }

  return const JsonEncoder.withIndent('  ').convert({
    'format': 'lore-rp-story',
    'version': 1,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'sessionId': sessionId,
    'session': _jsonValue(_storySession(session)),
    'postCount': decodedPosts.length,
    'posts': decodedPosts,
  });
}

class RpStoryExport {
  Future<String> create(String sessionId) async {
    final code = AuthService().currentCode;
    if (code == null) throw StateError('Sign in before exporting.');
    final ref = FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId);
    const server = GetOptions(source: Source.server);
    final session = await ref.get(server);
    final data = session.data();
    if (data == null) throw StateError('The roleplay room was not found.');
    if (session.metadata.hasPendingWrites) {
      throw StateError('Room changes are still syncing. Try again.');
    }
    final participants = data['participants'];
    if (participants is! List || !participants.contains(code)) {
      throw StateError('The signed-in account is not a room participant.');
    }

    final snapshot = await ref.collection('posts').get(server);
    if (snapshot.metadata.hasPendingWrites) {
      throw StateError('Story changes are still syncing. Try again.');
    }
    final posts = snapshot.docs.map((d) => StoryPost(d.id, d.data())).toList();
    final crypto = CryptoService();
    final needsKey = posts.any((post) => post.data['encrypted'] == true);
    final key = needsKey
        ? await crypto.getSessionKey(sessionId: sessionId, myCode: code)
        : null;
    if (needsKey && key == null) {
      throw StateError(
        'The existing room key is unavailable. Unlock the old account and try again.',
      );
    }

    final result = await encodeRpStory(
      sessionId: sessionId,
      session: data,
      posts: posts,
      decrypt: (cipher, iv) =>
          crypto.decryptContent(cipherB64: cipher, ivB64: iv, sessionKey: key!),
      exportedAt: DateTime.now(),
    );

    final checkSession = await ref.get(server);
    final checkPosts = await ref.collection('posts').get(server);
    if (checkSession.metadata.hasPendingWrites ||
        checkPosts.metadata.hasPendingWrites ||
        checkSession.data() == null ||
        jsonEncode(_jsonValue(_storySession(data))) !=
            jsonEncode(_jsonValue(_storySession(checkSession.data()!))) ||
        _postFingerprint(snapshot.docs) != _postFingerprint(checkPosts.docs)) {
      throw StateError(
        'The story changed during export. Pause writing on both devices and try again.',
      );
    }
    return result;
  }

  String _postFingerprint(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs]..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode([
      for (final doc in sorted) {'id': doc.id, 'data': _jsonValue(doc.data())},
    ]);
  }
}
