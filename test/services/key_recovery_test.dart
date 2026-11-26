import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/services/key_recovery.dart';

void main() {
  test(
    'recovers key material only with the recovery key and account',
    () async {
      final recoveryKey = await createRecoveryKey();
      final otherKey = await createRecoveryKey();
      final privateKey = utf8.encode('private key material');
      final envelope = await wrapPrivateKeyForRecovery(
        uid: 'account-1',
        privateKey: privateKey,
        recoveryKey: recoveryKey,
      );
      final secondEnvelope = await wrapPrivateKeyForRecovery(
        uid: 'account-1',
        privateKey: privateKey,
        recoveryKey: recoveryKey,
      );

      expect(envelope.values, isNot(contains(recoveryKey)));
      expect(secondEnvelope['nonce'], isNot(envelope['nonce']));
      expect(
        await recoverPrivateKey(
          uid: 'account-1',
          envelope: envelope,
          recoveryKey: recoveryKey,
        ),
        privateKey,
      );
      await expectLater(
        recoverPrivateKey(
          uid: 'account-1',
          envelope: envelope,
          recoveryKey: otherKey,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        recoverPrivateKey(
          uid: 'account-2',
          envelope: envelope,
          recoveryKey: recoveryKey,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      final ciphertext = base64.decode(envelope['ciphertext'] as String);
      ciphertext[0] ^= 1;
      await expectLater(
        recoverPrivateKey(
          uid: 'account-1',
          envelope: {...envelope, 'ciphertext': base64.encode(ciphertext)},
          recoveryKey: recoveryKey,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );

  test('rejects invalid keys and malformed recovery envelopes', () async {
    final key = await createRecoveryKey();
    final envelope = await wrapPrivateKeyForRecovery(
      uid: 'account-1',
      privateKey: [1, 2, 3],
      recoveryKey: key,
    );
    for (final invalidKey in ['', key.substring(1), '$key=']) {
      await expectLater(
        recoverPrivateKey(
          uid: 'account-1',
          envelope: envelope,
          recoveryKey: invalidKey,
        ),
        throwsFormatException,
      );
    }
    for (final invalidEnvelope in [
      {...envelope, 'version': 2},
      {
        ...envelope,
        'nonce': base64.encode([1]),
      },
      {...envelope, 'ciphertext': base64.encode(List.filled(16, 0))},
      {...envelope, 'extra': true},
    ]) {
      await expectLater(
        recoverPrivateKey(
          uid: 'account-1',
          envelope: invalidEnvelope,
          recoveryKey: key,
        ),
        throwsFormatException,
      );
    }
  });
}
