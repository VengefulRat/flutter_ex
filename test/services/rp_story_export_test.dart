import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/services/rp_story_export.dart';
import 'package:lore/services/rp_story_import.dart';

void main() {
  test(
    'exports ordered, decrypted posts with chapters and rich formatting',
    () async {
      final aes = AesGcm.with256bits();
      final key = await aes.newSecretKey();
      Future<Map<String, String>> encrypt(String text) async {
        final box = await aes.encrypt(utf8.encode(text), secretKey: key);
        return {
          'cipher': base64Encode(box.cipherText + box.mac.bytes),
          'iv': base64Encode(box.nonce),
        };
      }

      final content = await encrypt('A story');
      final quote = await encrypt('Earlier words');
      final runs = await encrypt('[{"text":"A story","bold":true}]');
      Future<String?> decrypt(String cipher, String iv) async {
        final bytes = base64Decode(cipher);
        final box = SecretBox(
          bytes.sublist(0, bytes.length - 16),
          nonce: base64Decode(iv),
          mac: Mac(bytes.sublist(bytes.length - 16)),
        );
        return utf8.decode(await aes.decrypt(box, secretKey: key));
      }

      final result =
          jsonDecode(
                await encodeRpStory(
                  sessionId: 'room',
                  session: {
                    'title': 'Our story',
                    'chapters': ['Chapter 1', 'Chapter 2'],
                    'postChapters': {'later': 'Chapter 2'},
                    'sessionKey_secret': 'never-export-this',
                  },
                  posts: [
                    StoryPost('later', {
                      'encrypted': true,
                      'content': content['cipher'],
                      'contentIv': content['iv'],
                      'quotedContent': quote['cipher'],
                      'quotedContentIv': quote['iv'],
                      'contentRuns': runs['cipher'],
                      'contentRunsIv': runs['iv'],
                      'authorName': 'Writer',
                      'createdAt': Timestamp(2, 123),
                    }),
                    StoryPost('earlier', {
                      'content': 'Old post',
                      'createdAt': Timestamp(1, 0),
                    }),
                  ],
                  decrypt: decrypt,
                  exportedAt: DateTime.utc(2026),
                ),
              )
              as Map<String, dynamic>;
      expect(result['postCount'], 2);
      expect(result['session']['chapters'], ['Chapter 1', 'Chapter 2']);
      expect(result['session']['postChapters']['later'], 'Chapter 2');
      expect(result['session'].containsKey('sessionKey_secret'), isFalse);
      final posts = result['posts'] as List;
      expect(posts.map((p) => p['id']), ['earlier', 'later']);
      final later = posts.last['data'];
      expect(later['content'], 'A story');
      expect(later['quotedContent'], 'Earlier words');
      expect(later['contentRuns'], '[{"text":"A story","bold":true}]');
      expect(later['authorName'], 'Writer');
      expect(later['createdAt']['nanoseconds'], 123);
      expect(later['encrypted'], isFalse);
      expect(later.containsKey('contentIv'), isFalse);
    },
  );

  test('fails instead of saving missing or undecryptable content', () async {
    Future<String> export(Map<String, dynamic> post) => encodeRpStory(
      sessionId: 'room',
      session: {},
      posts: [StoryPost('broken', post)],
      decrypt: (_, _) async => null,
      exportedAt: DateTime.utc(2026),
    );

    await expectLater(
      export({'encrypted': true, 'content': 'cipher'}),
      throwsFormatException,
    );
    await expectLater(
      export({'encrypted': true, 'content': 'cipher', 'contentIv': 'iv'}),
      throwsFormatException,
    );
    await expectLater(
      encodeRpStory(
        sessionId: 'room',
        session: {},
        posts: [
          StoryPost('broken', {
            'encrypted': true,
            'content': 'cipher',
            'contentIv': 'iv',
            'contentRuns': 'cipher-without-iv',
          }),
        ],
        decrypt: (_, _) async => 'story',
        exportedAt: DateTime.utc(2026),
      ),
      throwsFormatException,
    );
    await expectLater(export({'content': null}), throwsFormatException);
    await expectLater(
      export({'content': 'story', 'createdAt': 'invalid'}),
      throwsFormatException,
    );
  });

  test(
    'reads an exported story without changing posts or timestamps',
    () async {
      final source = await encodeRpStory(
        sessionId: 'old-room',
        session: {
          'chapters': ['Chapter 1'],
          'postChapters': {'post-1': 'Chapter 1'},
          'createdAt': Timestamp(1, 42),
        },
        posts: [
          StoryPost('post-1', {
            'content': 'Story',
            'quotedContent': 'Earlier',
            'contentRuns': '[{"text":"Story","bold":true}]',
            'createdAt': Timestamp(2, 123),
            'editedAt': Timestamp(3, 456),
          }),
        ],
        decrypt: (_, _) async => throw StateError('Unexpected decrypt'),
        exportedAt: DateTime.utc(2026),
      );

      final backup = decodeRpStory(source);
      expect(backup.sessionId, 'old-room');
      expect(backup.exportedAt, DateTime.utc(2026));
      expect(backup.session['createdAt'], Timestamp(1, 42));
      expect(backup.session['postChapters'], {'post-1': 'Chapter 1'});
      expect(backup.posts.single.id, 'post-1');
      expect(backup.posts.single.data['content'], 'Story');
      expect(backup.posts.single.data['quotedContent'], 'Earlier');
      expect(
        backup.posts.single.data['contentRuns'],
        '[{"text":"Story","bold":true}]',
      );
      expect(backup.posts.single.data['createdAt'], Timestamp(2, 123));
      expect(backup.posts.single.data['editedAt'], Timestamp(3, 456));
    },
  );

  test('rejects corrupt and unsupported story backups', () async {
    final source = await encodeRpStory(
      sessionId: 'room',
      session: {},
      posts: [
        StoryPost('post', {'content': 'story'}),
      ],
      decrypt: (_, _) async => null,
      exportedAt: DateTime.utc(2026),
    );
    Map<String, dynamic> backup() => jsonDecode(source) as Map<String, dynamic>;

    final wrongVersion = backup()..['version'] = 2;
    final nonIntegerVersion = backup()..['version'] = 1.0;
    final wrongCount = backup()..['postCount'] = 2;
    final duplicate = backup();
    final duplicatePosts = duplicate['posts'] as List;
    duplicatePosts.add(duplicatePosts.first);
    duplicate['postCount'] = 2;
    final encrypted = backup();
    encrypted['posts'][0]['data']['encrypted'] = true;
    final invalidTimestamp = backup();
    invalidTimestamp['posts'][0]['data']['createdAt'] = {
      r'$type': 'firestore_timestamp',
      'seconds': 1,
      'nanoseconds': 1000000000,
    };
    final timestampAsPost = backup();
    timestampAsPost['posts'][0]['data'] = {
      r'$type': 'firestore_timestamp',
      'seconds': 1,
      'nanoseconds': 0,
    };

    for (final value in [
      wrongVersion,
      nonIntegerVersion,
      wrongCount,
      duplicate,
      encrypted,
      invalidTimestamp,
      timestampAsPost,
    ]) {
      expect(() => decodeRpStory(jsonEncode(value)), throwsFormatException);
    }
    expect(() => decodeRpStory('{'), throwsFormatException);
  });

  test('prepares mapped posts encrypted with the new room key', () async {
    final oldKey = await AesGcm.with256bits().newSecretKey();
    final newKey = await AesGcm.with256bits().newSecretKey();
    final aes = AesGcm.with256bits();
    final source = await encodeRpStory(
      sessionId: 'old-room',
      session: {
        'postChapters': {'post': 'Chapter 1'},
      },
      posts: [
        StoryPost('post', {
          'authorCode': 'old-author',
          'authorName': 'Writer',
          'content': 'Story',
          'quotedContent': 'Earlier',
          'contentRuns': '[{"text":"Story","bold":true}]',
          'contentIv': 'old-iv',
          'contentDelta': null,
          'createdAt': Timestamp(2, 123),
        }),
      ],
      decrypt: (_, _) async => null,
      exportedAt: DateTime.utc(2026),
    );
    final backup = decodeRpStory(source);
    final prepared = await prepareRpStoryPosts(
      backup: backup,
      authorCodes: {'old-author': 'new-author'},
      targetParticipants: {'new-author', 'new-partner'},
      encrypt: (plain) async {
        final box = await aes.encrypt(utf8.encode(plain), secretKey: newKey);
        return {
          'cipher': base64Encode(box.cipherText + box.mac.bytes),
          'iv': base64Encode(box.nonce),
        };
      },
    );

    final data = prepared.single.data;
    expect(prepared.single.id, 'post');
    expect(data['authorCode'], 'new-author');
    expect(data['authorName'], 'Writer');
    expect(data['createdAt'], Timestamp(2, 123));
    expect(data['encrypted'], isTrue);
    expect(data.containsKey('contentDelta'), isFalse);
    expect(backup.posts.single.data['content'], 'Story');
    expect(backup.posts.single.data['contentIv'], 'old-iv');
    expect(backup.posts.single.data.containsKey('contentDelta'), isTrue);

    for (final entry in {
      'content': 'Story',
      'quotedContent': 'Earlier',
      'contentRuns': '[{"text":"Story","bold":true}]',
    }.entries) {
      final bytes = base64Decode(data[entry.key] as String);
      final box = SecretBox(
        bytes.sublist(0, bytes.length - 16),
        nonce: base64Decode(data['${entry.key}Iv'] as String),
        mac: Mac(bytes.sublist(bytes.length - 16)),
      );
      expect(
        utf8.decode(await aes.decrypt(box, secretKey: newKey)),
        entry.value,
      );
      await expectLater(
        aes.decrypt(box, secretKey: oldKey),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    }
  });

  test('refuses unsafe author mappings and unsupported post data', () async {
    final source = await encodeRpStory(
      sessionId: 'room',
      session: {},
      posts: [
        StoryPost('post', {
          'authorCode': 'old',
          'authorName': 'Writer',
          'content': 'story',
          'createdAt': Timestamp(1, 0),
        }),
      ],
      decrypt: (_, _) async => null,
      exportedAt: DateTime.utc(2026),
    );
    final backup = decodeRpStory(source);
    Future<Map<String, String>> encrypt(String _) async => {
      'cipher': 'cipher',
      'iv': 'iv',
    };

    await expectLater(
      prepareRpStoryPosts(
        backup: backup,
        authorCodes: {'old': 'outsider'},
        targetParticipants: {'participant'},
        encrypt: encrypt,
      ),
      throwsFormatException,
    );
    await expectLater(
      prepareRpStoryPosts(
        backup: backup,
        authorCodes: {},
        targetParticipants: {'participant'},
        encrypt: encrypt,
      ),
      throwsFormatException,
    );

    backup.posts.single.data['contentDelta'] = 'legacy formatting';
    await expectLater(
      prepareRpStoryPosts(
        backup: backup,
        authorCodes: {'old': 'participant'},
        targetParticipants: {'participant'},
        encrypt: encrypt,
      ),
      throwsFormatException,
    );
    expect(backup.posts.single.data['content'], 'story');
  });

  test('rejects unsupported metadata and invalid encryption output', () async {
    final source = await encodeRpStory(
      sessionId: 'room',
      session: {},
      posts: [
        StoryPost('post', {
          'authorCode': 'old',
          'authorName': 'Writer',
          'content': 'story',
          'createdAt': Timestamp(1, 0),
        }),
      ],
      decrypt: (_, _) async => null,
      exportedAt: DateTime.utc(2026),
    );
    final backup = decodeRpStory(source);
    final post = backup.posts.single.data;
    Future<List<StoryPost>> prepare() => prepareRpStoryPosts(
      backup: backup,
      authorCodes: {'old': 'participant'},
      targetParticipants: {'participant'},
      encrypt: (_) async => {'cipher': 'cipher', 'iv': 'iv'},
    );

    post.remove('createdAt');
    await expectLater(prepare(), throwsFormatException);
    post['createdAt'] = Timestamp(1, 0);
    post['chapter'] = 1;
    await expectLater(prepare(), throwsFormatException);
    post.remove('chapter');
    await expectLater(prepare(), throwsStateError);
  });

  test('verifies the exact prepared post set, independent of order', () {
    final expected = [
      StoryPost('first', {
        'content': 'cipher-one',
        'createdAt': Timestamp(1, 123),
        'edited': false,
        'chapter': null,
      }),
      StoryPost('second', {'content': 'cipher-two'}),
    ];
    List<StoryPost> copy() => [
      for (final post in expected)
        StoryPost(post.id, Map<String, dynamic>.from(post.data)),
    ];

    expect(
      () => verifyRpStoryPostSet(
        expected: expected,
        actual: copy().reversed.toList(),
      ),
      returnsNormally,
    );
    final missing = copy()..removeLast();
    final extra = copy()..add(StoryPost('extra', {'content': 'cipher'}));
    final duplicate = copy()..add(copy().first);
    final changed = copy()..first.data['createdAt'] = Timestamp(1, 124);
    final missingNullField = copy()..first.data.remove('chapter');
    final changedType = copy()..first.data['edited'] = 0;
    for (final actual in [
      missing,
      extra,
      duplicate,
      changed,
      missingNullField,
      changedType,
    ]) {
      expect(
        () => verifyRpStoryPostSet(expected: expected, actual: actual),
        throwsFormatException,
      );
    }
  });
}
