import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/services/staged_room_keys.dart';

void main() {
  test('both participants can unwrap the same room key', () async {
    final x25519 = X25519();
    final alice = await x25519.newKeyPair();
    final bob = await x25519.newKeyPair();
    final roomKey = await AesGcm.with256bits().newSecretKey();
    Future<Map<String, Object>> wrap(String code, SimpleKeyPair pair) async =>
        wrapStagedRoomKey(
          sessionId: 'room',
          recipientCode: code,
          recipientPublicKey: base64.encode(
            (await pair.extractPublicKey()).bytes,
          ),
          roomKey: roomKey,
        );
    final aliceEnvelope = await wrap('alice', alice);
    final bobEnvelope = await wrap('bob', bob);
    final aliceRoomKey = await unwrapStagedRoomKey(
      sessionId: 'room',
      recipientCode: 'alice',
      recipientKeyPair: alice,
      envelope: aliceEnvelope,
    );
    final bobRoomKey = await unwrapStagedRoomKey(
      sessionId: 'room',
      recipientCode: 'bob',
      recipientKeyPair: bob,
      envelope: bobEnvelope,
    );
    expect(await aliceRoomKey.extractBytes(), await roomKey.extractBytes());
    expect(await bobRoomKey.extractBytes(), await roomKey.extractBytes());
    final cipher = AesGcm.with256bits();
    final message = await cipher.encrypt(
      utf8.encode('Story'),
      secretKey: aliceRoomKey,
    );
    expect(
      utf8.decode(await cipher.decrypt(message, secretKey: bobRoomKey)),
      'Story',
    );
  });

  test(
    'rejects wrong recipients, changed context and tampered envelopes',
    () async {
      final x25519 = X25519();
      final recipient = await x25519.newKeyPair();
      final outsider = await x25519.newKeyPair();
      final envelope = await wrapStagedRoomKey(
        sessionId: 'room',
        recipientCode: 'bob',
        recipientPublicKey: base64.encode(
          (await recipient.extractPublicKey()).bytes,
        ),
        roomKey: await AesGcm.with256bits().newSecretKey(),
      );
      Future<SecretKey> unwrap({
        String sessionId = 'room',
        String code = 'bob',
        SimpleKeyPair? key,
        Map<String, dynamic>? data,
      }) => unwrapStagedRoomKey(
        sessionId: sessionId,
        recipientCode: code,
        recipientKeyPair: key ?? recipient,
        envelope: data ?? envelope,
      );
      await expectLater(
        unwrap(key: outsider),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        unwrap(sessionId: 'other-room'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        unwrap(code: 'alice'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final bytes = base64.decode(envelope['ciphertext'] as String);
      bytes[0] ^= 1;
      await expectLater(
        unwrap(data: {...envelope, 'ciphertext': base64.encode(bytes)}),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        unwrap(
          data: {
            ...envelope,
            'ephemeralPublicKey': base64.encode(List.filled(32, 0)),
          },
        ),
        throwsFormatException,
      );
      await expectLater(
        unwrap(data: {...envelope, 'version': 2}),
        throwsFormatException,
      );
    },
  );
}
