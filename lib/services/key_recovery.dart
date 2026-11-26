import 'dart:convert';

import 'package:cryptography/cryptography.dart';

final _recoveryCipher = AesGcm.with256bits();

/// Creates a random recovery key. It must not be stored with the envelope.
Future<String> createRecoveryKey() async {
  final key = await _recoveryCipher.newSecretKey();
  return base64Url.encode(await key.extractBytes()).replaceAll('=', '');
}

SecretKey _readRecoveryKey(String recoveryKey) {
  final bytes = base64Url.decode(base64Url.normalize(recoveryKey));
  if (bytes.length != 32 ||
      base64Url.encode(bytes).replaceAll('=', '') != recoveryKey) {
    throw const FormatException('Invalid recovery key.');
  }
  return SecretKey(bytes);
}

List<int> _associatedData(String uid) {
  if (uid.isEmpty) throw ArgumentError.value(uid, 'uid', 'Must not be empty.');
  return utf8.encode(jsonEncode(['lore-key-recovery', 1, uid]));
}

/// Encrypts private key bytes for recovery without storing the recovery key.
Future<Map<String, Object>> wrapPrivateKeyForRecovery({
  required String uid,
  required List<int> privateKey,
  required String recoveryKey,
}) async {
  if (privateKey.isEmpty) {
    throw ArgumentError.value(privateKey, 'privateKey', 'Must not be empty.');
  }
  final box = await _recoveryCipher.encrypt(
    privateKey,
    secretKey: _readRecoveryKey(recoveryKey),
    aad: _associatedData(uid),
  );
  return {
    'version': 1,
    'nonce': base64.encode(box.nonce),
    'ciphertext': base64.encode(box.cipherText + box.mac.bytes),
  };
}

/// Decrypts a recovery envelope; authentication failures are propagated.
Future<List<int>> recoverPrivateKey({
  required String uid,
  required Map<String, dynamic> envelope,
  required String recoveryKey,
}) async {
  final nonceText = envelope['nonce'];
  final ciphertextText = envelope['ciphertext'];
  if (envelope.length != 3 ||
      envelope['version'] is! int ||
      envelope['version'] != 1 ||
      nonceText is! String ||
      ciphertextText is! String) {
    throw const FormatException('Invalid recovery envelope.');
  }
  final nonce = base64.decode(nonceText);
  final ciphertext = base64.decode(ciphertextText);
  if (nonce.length != 12 ||
      ciphertext.length <= 16 ||
      base64.encode(nonce) != nonceText ||
      base64.encode(ciphertext) != ciphertextText) {
    throw const FormatException('Invalid recovery envelope.');
  }
  return _recoveryCipher.decrypt(
    SecretBox(
      ciphertext.sublist(0, ciphertext.length - 16),
      nonce: nonce,
      mac: Mac(ciphertext.sublist(ciphertext.length - 16)),
    ),
    secretKey: _readRecoveryKey(recoveryKey),
    aad: _associatedData(uid),
  );
}
