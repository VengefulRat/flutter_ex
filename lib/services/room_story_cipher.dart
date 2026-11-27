import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class RoomStoryCipher {
  final _cipher = AesGcm.with256bits();

  Future<Map<String, String>> encrypt(String text, SecretKey key) async {
    final box = await _cipher.encrypt(utf8.encode(text), secretKey: key);
    return {
      'cipher': base64.encode(box.cipherText + box.mac.bytes),
      'iv': base64.encode(box.nonce),
    };
  }

  Future<String> decrypt(String cipher, String iv, SecretKey key) async {
    final bytes = base64.decode(cipher);
    final nonce = base64.decode(iv);
    if (bytes.length < 16 || nonce.length != 12) {
      throw const FormatException('Invalid encrypted story field.');
    }
    return utf8.decode(
      await _cipher.decrypt(
        SecretBox(
          bytes.sublist(0, bytes.length - 16),
          nonce: nonce,
          mac: Mac(bytes.sublist(bytes.length - 16)),
        ),
        secretKey: key,
      ),
    );
  }
}
