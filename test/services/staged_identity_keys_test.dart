import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/services/staged_identity_keys.dart';
import 'package:lore/services/staged_room_keys.dart';

void main() {
  test('credentials and recovery key unlock the same identity and room key', () async {
    final identity = await createStagedIdentity(uid: 'account', pin: '123456', password: 'password');
    final byPin = await unlockStagedIdentityWithCredentials(
      uid: 'account',
      publicKey: identity.publicKey,
      pin: '123456',
      password: 'password',
      envelope: identity.pinEnvelope,
    );
    final byRecovery = await unlockStagedIdentityWithRecovery(
      uid: 'account',
      publicKey: identity.publicKey,
      recoveryKey: identity.recoveryKey,
      envelope: identity.recoveryEnvelope,
    );
    expect(
      (await byPin.extractPublicKey()).bytes,
      (await byRecovery.extractPublicKey()).bytes,
    );
    final roomKey = await AesGcm.with256bits().newSecretKey();
    final envelope = await wrapStagedRoomKey(
      sessionId: 'room',
      recipientCode: 'code',
      recipientPublicKey: identity.publicKey,
      roomKey: roomKey,
    );
    final recoveredRoomKey = await unwrapStagedRoomKey(
      sessionId: 'room',
      recipientCode: 'code',
      recipientKeyPair: byRecovery,
      envelope: envelope,
    );
    expect(await recoveredRoomKey.extractBytes(), await roomKey.extractBytes());

    final newPin = await rewrapStagedIdentityCredentials(
      uid: 'account',
      identity: byRecovery,
      pin: '654321',
      password: 'new-password',
    );
    final unlocked = await unlockStagedIdentityWithCredentials(
      uid: 'account',
      publicKey: identity.publicKey,
      pin: '654321',
      password: 'new-password',
      envelope: newPin,
    );
    expect(
      base64.encode((await unlocked.extractPublicKey()).bytes),
      identity.publicKey,
    );
  });

  test(
    'rejects wrong PIN, account, recovery key and public-key substitution',
    () async {
      final identity = await createStagedIdentity(
        uid: 'account',
        pin: '123456',
        password: 'password',
      );
      await expectLater(
        unlockStagedIdentityWithCredentials(
          uid: 'account',
          publicKey: identity.publicKey,
          pin: '000000',
          password: 'password',
          envelope: identity.pinEnvelope,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        unlockStagedIdentityWithCredentials(
          uid: 'account',
          publicKey: identity.publicKey,
          pin: '123456',
          password: 'wrong-password',
          envelope: identity.pinEnvelope,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        unlockStagedIdentityWithRecovery(
          uid: 'other-account',
          publicKey: identity.publicKey,
          recoveryKey: identity.recoveryKey,
          envelope: identity.recoveryEnvelope,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final otherPublicKey = base64.encode(
        (await (await X25519().newKeyPair()).extractPublicKey()).bytes,
      );
      await expectLater(
        unlockStagedIdentityWithRecovery(
          uid: 'account',
          publicKey: otherPublicKey,
          recoveryKey: identity.recoveryKey,
          envelope: identity.recoveryEnvelope,
        ),
        throwsFormatException,
      );
      await expectLater(
        createStagedIdentity(uid: 'account', pin: '123', password: 'password'),
        throwsArgumentError,
      );
    },
  );
}
