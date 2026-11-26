import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/services/rp_story_export.dart';

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
}
