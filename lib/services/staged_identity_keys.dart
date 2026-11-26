import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'key_recovery.dart';

final _exchange = X25519();
final _cipher = AesGcm.with256bits();
final _pinKdf = Argon2id(
  parallelism: 1,
  memory: 19456,
  iterations: 2,
  hashLength: 32,
);

class StagedIdentityMaterial {
  const StagedIdentityMaterial({
    required this.publicKey,
    required this.pinEnvelope,
    required this.recoveryEnvelope,
    required this.recoveryKey,
  });

  final String publicKey;
  final Map<String, Object> pinEnvelope;
  final Map<String, Object> recoveryEnvelope;
  final String recoveryKey;
}

void _validatePin(String pin) {
  if (!RegExp(r'^[0-9]{6,64}$').hasMatch(pin)) {
    throw ArgumentError('PIN must contain 6 to 64 digits.');
  }
}

List<int> _credentials(String password, String pin) {
  _validatePin(pin);
  if (password.isEmpty) throw ArgumentError('Password must not be empty.');
  return utf8.encode(jsonEncode(['lore-password-pin', 1, password, pin]));
}

List<int> _associatedData(String uid, String publicKey) {
  if (uid.isEmpty) throw ArgumentError('Account ID must not be empty.');
  return utf8.encode(jsonEncode(['lore-identity-password-pin', 2, uid, publicKey]));
}

List<int> _decodeBase64(String value, int length) {
  final bytes = base64.decode(value);
  if (bytes.length != length || base64.encode(bytes) != value) {
    throw const FormatException('Invalid identity key material.');
  }
  return bytes;
}

Future<Map<String, Object>> _wrapPin({
  required String uid,
  required String publicKey,
  required List<int> privateKey,
  required String pin,
  required String password,
}) async {
  final random = Random.secure();
  final salt = List<int>.generate(16, (_) => random.nextInt(256));
  final pinKey = await _pinKdf.deriveKey(
    secretKey: SecretKey(_credentials(password, pin)),
    nonce: salt,
  );
  final box = await _cipher.encrypt(
    privateKey,
    secretKey: pinKey,
    aad: _associatedData(uid, publicKey),
  );
  return {
    'version': 2,
    'salt': base64.encode(salt),
    'nonce': base64.encode(box.nonce),
    'ciphertext': base64.encode(box.cipherText + box.mac.bytes),
  };
}

Future<SimpleKeyPair> _checkIdentity(List<int> privateKey, String publicKey) async {
  _decodeBase64(publicKey, 32);
  if (privateKey.length != 32) {
    throw const FormatException('Invalid private identity key.');
  }
  final pair = await _exchange.newKeyPairFromSeed(privateKey);
  if (base64.encode((await pair.extractPublicKey()).bytes) != publicKey) {
    throw const FormatException('The private key does not match the account.');
  }
  return pair;
}

/// Generates new key material without writing it to a device or server.
Future<StagedIdentityMaterial> createStagedIdentity({
  required String uid,
  required String pin,
  required String password,
}) async {
  _credentials(password, pin);
  if (uid.isEmpty) throw ArgumentError('Account ID must not be empty.');
  final pair = await _exchange.newKeyPair();
  final privateKey = await pair.extractPrivateKeyBytes();
  final publicKey = base64.encode((await pair.extractPublicKey()).bytes);
  final recoveryKey = await createRecoveryKey();
  return StagedIdentityMaterial(
    publicKey: publicKey,
    pinEnvelope: await _wrapPin(
      uid: uid,
      publicKey: publicKey,
      privateKey: privateKey,
      pin: pin,
      password: password,
    ),
    recoveryEnvelope: await wrapPrivateKeyForRecovery(
      uid: uid,
      privateKey: privateKey,
      recoveryKey: recoveryKey,
    ),
    recoveryKey: recoveryKey,
  );
}

/// Unlocks the cloud identity key using the password and PIN.
Future<SimpleKeyPair> unlockStagedIdentityWithCredentials({
  required String uid,
  required String publicKey,
  required String pin,
  required String password,
  required Map<String, dynamic> envelope,
}) async {
  final credentials = _credentials(password, pin);
  final saltText = envelope['salt'];
  final nonceText = envelope['nonce'];
  final ciphertextText = envelope['ciphertext'];
  if (envelope.length != 4 ||
      envelope['version'] is! int ||
      envelope['version'] != 2 ||
      saltText is! String ||
      nonceText is! String ||
      ciphertextText is! String) {
    throw const FormatException('Invalid PIN envelope.');
  }
  final salt = _decodeBase64(saltText, 16);
  final nonce = _decodeBase64(nonceText, 12);
  final encrypted = _decodeBase64(ciphertextText, 48);
  final pinKey = await _pinKdf.deriveKey(
    secretKey: SecretKey(credentials),
    nonce: salt,
  );
  final privateKey = await _cipher.decrypt(
    SecretBox(encrypted.sublist(0, 32), nonce: nonce, mac: Mac(encrypted.sublist(32))),
    secretKey: pinKey,
    aad: _associatedData(uid, publicKey),
  );
  return _checkIdentity(privateKey, publicKey);
}

/// Unlocks the same identity using the separately stored recovery key.
Future<SimpleKeyPair> unlockStagedIdentityWithRecovery({
  required String uid,
  required String publicKey,
  required String recoveryKey,
  required Map<String, dynamic> envelope,
}) async {
  final privateKey = await recoverPrivateKey(
    uid: uid,
    envelope: envelope,
    recoveryKey: recoveryKey,
  );
  return _checkIdentity(privateKey, publicKey);
}

/// Rewraps an already unlocked identity without changing its public key.
Future<Map<String, Object>> rewrapStagedIdentityCredentials({
  required String uid,
  required SimpleKeyPair identity,
  required String pin,
  required String password,
}) async {
  if ((await identity.extractPublicKey()).type != KeyPairType.x25519) {
    throw ArgumentError('An X25519 identity is required.');
  }
  return _wrapPin(
    uid: uid,
    publicKey: base64.encode((await identity.extractPublicKey()).bytes),
    privateKey: await identity.extractPrivateKeyBytes(),
    pin: pin,
    password: password,
  );
}
