import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'rp_story_export.dart';

typedef StoryEncrypt = Future<Map<String, String>> Function(String plaintext);

Future<({String cipher, String iv})> encryptStoryField({
  required String plaintext,
  required StoryEncrypt encrypt,
  required String context,
}) async {
  final encrypted = await encrypt(plaintext);
  final cipher = encrypted['cipher'];
  final iv = encrypted['iv'];
  if (cipher == null || cipher.isEmpty || iv == null || iv.isEmpty) {
    throw StateError('Encryption failed for $context.');
  }
  try {
    final cipherBytes = base64Decode(cipher);
    final ivBytes = base64Decode(iv);
    if (cipherBytes.length < 16 ||
        ivBytes.length != 12 ||
        base64Encode(cipherBytes) != cipher ||
        base64Encode(ivBytes) != iv) {
      throw const FormatException('Invalid encrypted data.');
    }
  } on FormatException {
    throw StateError('Encryption returned invalid data for $context.');
  }
  return (cipher: cipher, iv: iv);
}

class RpStoryBackup {
  const RpStoryBackup({
    required this.sessionId,
    required this.exportedAt,
    required this.session,
    required this.posts,
  });

  final String sessionId;
  final DateTime exportedAt;
  final Map<String, dynamic> session;
  final List<StoryPost> posts;
}

Object? _decodeValue(Object? value) {
  if (value is List) return value.map(_decodeValue).toList();
  if (value is Map<String, dynamic>) {
    if (value[r'$type'] == 'firestore_timestamp' &&
        value.length == 3 &&
        value.containsKey('seconds') &&
        value.containsKey('nanoseconds')) {
      final seconds = value['seconds'];
      final nanoseconds = value['nanoseconds'];
      if (seconds is! int ||
          seconds < -62135596800 ||
          seconds > 253402300799 ||
          nanoseconds is! int ||
          nanoseconds < 0 ||
          nanoseconds >= 1000000000) {
        throw const FormatException('Invalid story timestamp.');
      }
      return Timestamp(seconds, nanoseconds);
    }
    return _decodeMap(value);
  }
  return value;
}

Map<String, dynamic> _decodeMap(Map<String, dynamic> value) =>
    {for (final entry in value.entries) entry.key: _decodeValue(entry.value)};

/// Checks the backup envelope and plaintext post fields without writing data.
RpStoryBackup decodeRpStory(String source) {
  final root = jsonDecode(source);
  if (root is! Map<String, dynamic> ||
      root['format'] != 'lore-rp-story' ||
      root['version'] is! int ||
      root['version'] != 1) {
    throw const FormatException('Unsupported story backup format or version.');
  }

  final sessionId = root['sessionId'];
  final exportedAt = root['exportedAt'];
  final session = root['session'];
  final posts = root['posts'];
  if (sessionId is! String ||
      sessionId.isEmpty ||
      sessionId.contains('/') ||
      exportedAt is! String ||
      session is! Map<String, dynamic> ||
      posts is! List ||
      root['postCount'] is! int ||
      root['postCount'] != posts.length) {
    throw const FormatException('Invalid story backup metadata.');
  }
  final date = DateTime.tryParse(exportedAt);
  if (date == null || !date.isUtc) {
    throw const FormatException('Invalid story export date.');
  }

  final decodedPosts = <StoryPost>[];
  final ids = <String>{};
  for (final item in posts) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('Invalid story post.');
    }
    final id = item['id'];
    final rawData = item['data'];
    if (id is! String ||
        id.isEmpty ||
        id.contains('/') ||
        !ids.add(id) ||
        rawData is! Map<String, dynamic>) {
      throw const FormatException('Invalid or duplicate story post ID.');
    }
    final data = _decodeMap(rawData);
    if (data['content'] is! String ||
        (data['encrypted'] != null && data['encrypted'] != false) ||
        (data['createdAt'] != null && data['createdAt'] is! Timestamp) ||
        (data['quotedContent'] != null && data['quotedContent'] is! String) ||
        (data['contentRuns'] != null && data['contentRuns'] is! String)) {
      throw FormatException('Post $id has invalid or encrypted story content.');
    }
    decodedPosts.add(StoryPost(id, data));
  }

  return RpStoryBackup(
    sessionId: sessionId,
    exportedAt: date,
    session: _decodeMap(session),
    posts: decodedPosts,
  );
}

/// Decrypts a complete, consecutively numbered staged metadata set.
Future<RpStoryBackup> decodeStagedStoryMetadata({
  required List<StoryPost> chunks,
  required int expectedCount,
  required StoryDecrypt decrypt,
}) async {
  if (expectedCount < 1 ||
      expectedCount > 1000000 ||
      chunks.length != expectedCount) {
    throw const FormatException('The staged story metadata count does not match.');
  }
  final sorted = [...chunks]..sort((a, b) => a.id.compareTo(b.id));
  final metadata = StringBuffer();
  for (var index = 0; index < sorted.length; index++) {
    final chunk = sorted[index];
    final cipher = chunk.data['cipher'];
    final iv = chunk.data['iv'];
    if (chunk.id != index.toString().padLeft(6, '0') ||
        chunk.data.length != 2 ||
        cipher is! String ||
        iv is! String) {
      throw const FormatException('Invalid staged story metadata.');
    }
    final plaintext = await decrypt(cipher, iv);
    if (plaintext == null) {
      throw StateError('Cannot decrypt the story metadata.');
    }
    metadata.write(plaintext);
  }
  final backup = decodeRpStory(metadata.toString());
  if (backup.posts.isNotEmpty ||
      backup.session.keys.any((field) => !rpStorySessionFields.contains(field))) {
    throw const FormatException('Invalid staged story metadata.');
  }
  return backup;
}

const _importablePostFields = {
  'authorCode',
  'authorName',
  'characterName',
  'locationName',
  'textColor',
  'content',
  'contentIv',
  'contentDelta',
  'contentRuns',
  'contentRunsIv',
  'quotedPostId',
  'quotedContent',
  'quotedContentIv',
  'quotedAuthor',
  'encrypted',
  'chapter',
  'createdAt',
  'edited',
  'editedAt',
};

/// Prepares posts for a new room without writing them or changing the backup.
///
/// The caller must authorize the target room and provide its new encryption key.
/// Posts without a creation timestamp or with legacy delta formatting are
/// rejected rather than assigned invented timestamps or losing formatting.
Future<List<StoryPost>> prepareRpStoryPosts({
  required RpStoryBackup backup,
  required Map<String, String> authorCodes,
  required Set<String> targetParticipants,
  required StoryEncrypt encrypt,
}) async {
  final prepared = _mapRpStoryPosts(
    backup: backup,
    authorCodes: authorCodes,
    targetParticipants: targetParticipants,
  );
  for (final post in prepared) {
    final data = post.data;
    for (final field in ['content', 'quotedContent', 'contentRuns']) {
      final plaintext = data[field];
      if (plaintext == null && field != 'content') continue;
      final encrypted = await encryptStoryField(
        plaintext: plaintext as String,
        encrypt: encrypt,
        context: 'post ${post.id}',
      );
      data[field] = encrypted.cipher;
      data['${field}Iv'] = encrypted.iv;
    }
    data['encrypted'] = true;
  }
  return prepared;
}

List<StoryPost> _mapRpStoryPosts({
  required RpStoryBackup backup,
  required Map<String, String> authorCodes,
  required Set<String> targetParticipants,
}) {
  if (authorCodes.values.toSet().length != authorCodes.length ||
      authorCodes.values.any(
        (code) => code.isEmpty || !targetParticipants.contains(code),
      )) {
    throw const FormatException('Invalid story author mapping.');
  }

  final prepared = <StoryPost>[];
  for (final post in backup.posts) {
    final data = Map<String, dynamic>.from(post.data);
    if (data.keys.any((key) => !_importablePostFields.contains(key))) {
      throw FormatException('Post ${post.id} contains unsupported fields.');
    }
    if (data['contentDelta'] != null) {
      throw FormatException(
        'Post ${post.id} has unsupported legacy formatting; the backup was not changed.',
      );
    }
    data.remove('contentDelta');
    if (data['authorName'] is! String || data['createdAt'] is! Timestamp) {
      throw FormatException(
        'Post ${post.id} needs an author name and creation timestamp to restore.',
      );
    }
    for (final field in [
      'quotedPostId',
      'quotedAuthor',
      'characterName',
      'locationName',
      'chapter',
    ]) {
      if (data[field] != null && data[field] is! String) {
        throw FormatException('Post ${post.id} has invalid $field.');
      }
    }
    if ((data['textColor'] != null && data['textColor'] is! int) ||
        (data['edited'] != null && data['edited'] is! bool) ||
        (data['editedAt'] != null && data['editedAt'] is! Timestamp)) {
      throw FormatException('Post ${post.id} has invalid metadata.');
    }
    final author = data['authorCode'];
    if (author is! String || !authorCodes.containsKey(author)) {
      throw FormatException('Post ${post.id} has an unmapped author.');
    }
    data['authorCode'] = authorCodes[author]!;
    if (data['content'] is! String ||
        (data['encrypted'] != null && data['encrypted'] != false)) {
      throw FormatException('Post ${post.id} is not a plaintext story post.');
    }
    data.remove('encrypted');

    for (final field in ['content', 'quotedContent', 'contentRuns']) {
      final plaintext = data[field];
      data.remove('${field}Iv');
      if (plaintext == null && field != 'content') continue;
      if (plaintext is! String) {
        throw FormatException('Post ${post.id} has invalid $field.');
      }
    }
    prepared.add(StoryPost(post.id, data));
  }
  return prepared;
}

/// Verifies decrypted staged posts against the original backup and mapping.
Future<void> verifyRpStoryBackupPosts({
  required RpStoryBackup backup,
  required Map<String, String> authorCodes,
  required Set<String> targetParticipants,
  required List<StoryPost> staged,
  required StoryDecrypt decrypt,
}) async {
  final expected = _mapRpStoryPosts(
    backup: backup,
    authorCodes: authorCodes,
    targetParticipants: targetParticipants,
  );
  final actual = <StoryPost>[];
  for (final post in staged) {
    final data = Map<String, dynamic>.from(post.data);
    if (data.remove('encrypted') != true) {
      throw FormatException('Post ${post.id} is not encrypted.');
    }
    for (final field in ['content', 'quotedContent', 'contentRuns']) {
      final cipher = data[field];
      final iv = data.remove('${field}Iv');
      if (cipher == null && iv == null && field != 'content') continue;
      if (cipher is! String || iv is! String) {
        throw FormatException('Post ${post.id} has invalid encrypted $field.');
      }
      final plaintext = await decrypt(cipher, iv);
      if (plaintext == null) {
        throw StateError('Cannot decrypt $field for post ${post.id}.');
      }
      data[field] = plaintext;
    }
    actual.add(StoryPost(post.id, data));
  }
  verifyRpStoryPostSet(expected: expected, actual: actual);
}

/// Checks a complete server-fetched post set against an independently retained
/// prepared set. Callers must also verify the restore state and review version.
void verifyRpStoryPostSet({
  required List<StoryPost> expected,
  required List<StoryPost> actual,
}) {
  Map<String, StoryPost> index(List<StoryPost> posts) {
    final result = <String, StoryPost>{};
    for (final post in posts) {
      if (post.id.isEmpty ||
          post.id.contains('/') ||
          result.containsKey(post.id)) {
        throw const FormatException('Invalid or duplicate story post ID.');
      }
      result[post.id] = post;
    }
    return result;
  }

  bool sameValue(Object? a, Object? b) {
    if (a == null || b == null) return a == null && b == null;
    if (a is String && b is String) return a == b;
    if (a is bool && b is bool) return a == b;
    if (a is int && b is int) return a == b;
    if (a is Timestamp && b is Timestamp) return a == b;
    return false;
  }

  final expectedById = index(expected);
  final actualById = index(actual);
  if (expectedById.length != actualById.length) {
    throw const FormatException('The story post set is incomplete or has extra posts.');
  }
  for (final entry in expectedById.entries) {
    final actualPost = actualById[entry.key];
    final expectedData = entry.value.data;
    if (actualPost == null ||
        actualPost.data.length != expectedData.length ||
        expectedData.entries.any(
          (field) =>
              !actualPost.data.containsKey(field.key) ||
              !sameValue(field.value, actualPost.data[field.key]),
        )) {
      throw FormatException('Story post ${entry.key} does not match.');
    }
  }
}
