import 'dart:convert';

import 'package:cryptography/cryptography.dart';

final _exchange = X25519();
final _cipher = AesGcm.with256bits();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

List<int> _decodeBase64(String value, int length) {
  final bytes = base64.decode(value);
  if (bytes.length != length || base64.encode(bytes) != value) {
    throw const FormatException('Invalid room-key envelope.');
  }
  return bytes;
}

List<int> _context(
  String sessionId,
  String recipientCode,
  String ephemeralPublicKey,
  String recipientPublicKey,
) {
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(sessionId) ||
      recipientCode.isEmpty) {
    throw ArgumentError('Invalid room or recipient.');
  }
  return utf8.encode(jsonEncode([
    'lore-room-key',
    1,
    sessionId,
    recipientCode,
    ephemeralPublicKey,
    recipientPublicKey,
  ]));
}

Future<SecretKey> _wrappingKey({
  required SimpleKeyPair privateKey,
  required SimplePublicKey publicKey,
  required List<int> salt,
  required List<int> context,
}) async {
  final shared = await _exchange.sharedSecretKey(
    keyPair: privateKey,
    remotePublicKey: publicKey,
  );
  final sharedBytes = await shared.extractBytes();
  var nonzero = 0;
  for (final byte in sharedBytes) {
    nonzero |= byte;
  }
  if (nonzero == 0) throw const FormatException('Invalid room-key public key.');
  return _hkdf.deriveKey(secretKey: shared, nonce: salt, info: context);
}

/// Creates an encrypted room-key envelope for one authenticated participant.
///
/// The caller must obtain the recipient public key from their verified,
/// immutable account profile and protect the envelope with participant rules.
Future<Map<String, Object>> wrapStagedRoomKey({
  required String sessionId,
  required String recipientCode,
  required String recipientPublicKey,
  required SecretKey roomKey,
}) async {
  final publicBytes = _decodeBase64(recipientPublicKey, 32);
  final roomBytes = await roomKey.extractBytes();
  if (roomBytes.length != 32) {
    throw ArgumentError('A room key must contain 32 bytes.');
  }
  final ephemeral = await _exchange.newKeyPair();
  final ephemeralBytes = (await ephemeral.extractPublicKey()).bytes;
  final ephemeralText = base64.encode(ephemeralBytes);
  final context = _context(
    sessionId,
    recipientCode,
    ephemeralText,
    recipientPublicKey,
  );
  final key = await _wrappingKey(
    privateKey: ephemeral,
    publicKey: SimplePublicKey(publicBytes, type: KeyPairType.x25519),
    salt: ephemeralBytes,
    context: context,
  );
  final box = await _cipher.encrypt(roomBytes, secretKey: key, aad: context);
  return {
    'version': 1,
    'ephemeralPublicKey': ephemeralText,
    'nonce': base64.encode(box.nonce),
    'ciphertext': base64.encode(box.cipherText + box.mac.bytes),
  };
}

/// Opens a room-key envelope using the recipient's unlocked private key.
Future<SecretKey> unwrapStagedRoomKey({
  required String sessionId,
  required String recipientCode,
  required SimpleKeyPair recipientKeyPair,
  required Map<String, dynamic> envelope,
}) async {
  final ephemeralText = envelope['ephemeralPublicKey'];
  final nonceText = envelope['nonce'];
  final ciphertextText = envelope['ciphertext'];
  if (envelope.length != 4 ||
      envelope['version'] is! int ||
      envelope['version'] != 1 ||
      ephemeralText is! String ||
      nonceText is! String ||
      ciphertextText is! String) {
    throw const FormatException('Invalid room-key envelope.');
  }
  final ephemeralBytes = _decodeBase64(ephemeralText, 32);
  final nonce = _decodeBase64(nonceText, 12);
  final encrypted = _decodeBase64(ciphertextText, 48);
  final publicKey = await recipientKeyPair.extractPublicKey();
  if (publicKey.type != KeyPairType.x25519) {
    throw ArgumentError('An X25519 key pair is required.');
  }
  final context = _context(
    sessionId,
    recipientCode,
    ephemeralText,
    base64.encode(publicKey.bytes),
  );
  final key = await _wrappingKey(
    privateKey: recipientKeyPair,
    publicKey: SimplePublicKey(ephemeralBytes, type: KeyPairType.x25519),
    salt: ephemeralBytes,
    context: context,
  );
  final bytes = await _cipher.decrypt(
    SecretBox(encrypted.sublist(0, 32), nonce: nonce, mac: Mac(encrypted.sublist(32))),
    secretKey: key,
    aad: context,
  );
  return SecretKey(bytes);
}
