import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  Future<Map<String, dynamic>> encryptBytes(Uint8List data, SecretKey sessionKey) async {
    final nonce = _aesGcm.newNonce();
    final encrypted = await _aesGcm.encrypt(data, secretKey: sessionKey, nonce: nonce);
    final cipherWithMac = encrypted.cipherText + encrypted.mac.bytes;
    return {'cipher': cipherWithMac, 'iv': nonce};
  }

  Future<Uint8List?> decryptBytes({required List<int> cipherBytes, required List<int> ivBytes, required SecretKey sessionKey}) async {
    try {
      final cipherText = cipherBytes.sublist(0, cipherBytes.length - 16);
      final mac = Mac(cipherBytes.sublist(cipherBytes.length - 16));
      final decrypted = await _aesGcm.decrypt(SecretBox(cipherText, nonce: ivBytes, mac: mac), secretKey: sessionKey);
      return Uint8List.fromList(decrypted);
    } catch (_) {
      return null;
    }
  }

  final _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final _db = FirebaseFirestore.instance;
  final _aesGcm = AesGcm.with256bits();
  final _pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);

  final Map<String, SecretKey> _sessionKeyCache = {};
  pc.RSAPrivateKey? _privateKey;
  pc.RSAPublicKey? _publicKey;

  Future<void> generateAndSaveKeypair({required String userCode, required String pin}) async {
    final keypair = _generateRSAKeypair();
    _privateKey = keypair.privateKey;
    _publicKey = keypair.publicKey;

    final pubKeyB64 = _encodePublicKey(keypair.publicKey);
    final privKeyBytes = _encodePrivateKeyToBytes(keypair.privateKey);
    final salt = _randomBytes(32);
    final pinKey = await _deriveKeyFromPin(pin, salt);
    final nonce = _aesGcm.newNonce();
    final encrypted = await _aesGcm.encrypt(privKeyBytes, secretKey: pinKey, nonce: nonce);

    final encPrivB64 = base64.encode(encrypted.cipherText + encrypted.mac.bytes);
    final saltB64 = base64.encode(salt);
    final ivB64 = base64.encode(nonce);

    await _storage.write(key: 'lore_enc_priv_$userCode', value: encPrivB64);
    await _storage.write(key: 'lore_priv_salt_$userCode', value: saltB64);
    await _storage.write(key: 'lore_priv_iv_$userCode', value: ivB64);
    await _storage.write(key: 'lore_raw_priv_$userCode', value: base64.encode(privKeyBytes));

    // Save public key to public profile
    await _db.collection('users').doc(userCode).update({'publicKey': pubKeyB64});

    // Save private key to secrets
    await _db.collection('user_secrets').doc(userCode).update({
      'encryptedPrivateKey': encPrivB64,
      'privateKeySalt': saltB64,
      'privateKeyIv': ivB64,
    });
  }

  Future<bool> unlockPrivateKey({required String userCode, required String pin}) async {
    try {
      String? encPrivB64 = await _storage.read(key: 'lore_enc_priv_$userCode');
      String? saltB64 = await _storage.read(key: 'lore_priv_salt_$userCode');
      String? ivB64 = await _storage.read(key: 'lore_priv_iv_$userCode');

      if (encPrivB64 == null || saltB64 == null || ivB64 == null) {
        // Check new secrets collection first
        var doc = await _db.collection('user_secrets').doc(userCode).get();
        
        // Fallback to legacy users collection for old data
        if (!doc.exists || doc.data()?['encryptedPrivateKey'] == null) {
          doc = await _db.collection('users').doc(userCode).get();
        }

        if (!doc.exists) return false;
        final data = doc.data()!;
        encPrivB64 = data['encryptedPrivateKey'] as String?;
        saltB64 = data['privateKeySalt'] as String?;
        ivB64 = data['privateKeyIv'] as String?;
        if (encPrivB64 == null || saltB64 == null || ivB64 == null) return false;

        await _storage.write(key: 'lore_enc_priv_$userCode', value: encPrivB64);
        await _storage.write(key: 'lore_priv_salt_$userCode', value: saltB64);
        await _storage.write(key: 'lore_priv_iv_$userCode', value: ivB64);
      }

      final salt = base64.decode(saltB64);
      final iv = base64.decode(ivB64);
      final encBytes = base64.decode(encPrivB64);

      final cipherText = encBytes.sublist(0, encBytes.length - 16);
      final mac = Mac(encBytes.sublist(encBytes.length - 16));

      final pinKey = await _deriveKeyFromPin(pin, salt);
      final decrypted = await _aesGcm.decrypt(SecretBox(cipherText, nonce: iv, mac: mac), secretKey: pinKey);

      _privateKey = _decodePrivateKeyFromBytes(Uint8List.fromList(decrypted));
      await _storage.write(key: 'lore_raw_priv_$userCode', value: base64.encode(Uint8List.fromList(decrypted)));

      final doc = await _db.collection('users').doc(userCode).get();
      final pubKeyB64 = doc.data()?['publicKey'] as String?;
      if (pubKeyB64 != null) _publicKey = _decodePublicKey(pubKeyB64);

      return true;
    } catch (_) {
      return false;
    }
  }

  bool get isUnlocked => _privateKey != null;

  Future<bool> hasRemoteKeyMaterial(String userCode) async {
    try {
      var doc = await _db.collection('user_secrets').doc(userCode).get();
      if (!doc.exists || doc.data()?['encryptedPrivateKey'] == null) {
        doc = await _db.collection('users').doc(userCode).get();
      }
      return doc.data()?['encryptedPrivateKey'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> silentUnlock(String userCode) async {
    if (_privateKey != null) return true;
    try {
      final rawB64 = await _storage.read(key: 'lore_raw_priv_$userCode');
      if (rawB64 == null) return false;
      _privateKey = _decodePrivateKeyFromBytes(base64.decode(rawB64));
      final doc = await _db.collection('users').doc(userCode).get();
      final pubKeyB64 = doc.data()?['publicKey'] as String?;
      if (pubKeyB64 != null) _publicKey = _decodePublicKey(pubKeyB64);
      return _privateKey != null;
    } catch (_) {
      return false;
    }
  }

  void lock() {
    _privateKey = null;
    _publicKey = null;
    _sessionKeyCache.clear();
  }

  Future<void> createSessionKey({required String sessionId, required String myCode, required String partnerCode}) async {
    final sessionKey = await _aesGcm.newSecretKey();
    final sessionKeyBytes = await sessionKey.extractBytes();
    _sessionKeyCache[sessionId] = sessionKey;

    final partnerDoc = await _db.collection('users').doc(partnerCode).get();
    final partnerPubKeyB64 = partnerDoc.data()?['publicKey'] as String?;
    if (partnerPubKeyB64 == null) return;
    final partnerPubKey = _decodePublicKey(partnerPubKeyB64);

    final myPubKey = _publicKey;
    if (myPubKey == null) return;
    final myEncrypted = _rsaEncrypt(Uint8List.fromList(sessionKeyBytes), myPubKey);
    final partnerEncrypted = _rsaEncrypt(Uint8List.fromList(sessionKeyBytes), partnerPubKey);

    await _db.collection('sessions').doc(sessionId).update({
      'sessionKey_$myCode': base64.encode(myEncrypted),
      'sessionKey_$partnerCode': base64.encode(partnerEncrypted),
    });
  }

  Future<SecretKey?> getSessionKey({required String sessionId, required String myCode}) async {
    if (_sessionKeyCache.containsKey(sessionId)) return _sessionKeyCache[sessionId];
    if (_privateKey == null) return null;
    try {
      final doc = await _db.collection('sessions').doc(sessionId).get();
      final encKeyB64 = doc.data()?['sessionKey_$myCode'] as String?;
      if (encKeyB64 == null) return null;
      final encKeyBytes = base64.decode(encKeyB64);
      final keyBytes = _rsaDecrypt(encKeyBytes, _privateKey!);
      final sessionKey = SecretKey(keyBytes);
      _sessionKeyCache[sessionId] = sessionKey;
      return sessionKey;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> encryptContent(String plaintext, SecretKey sessionKey) async {
    final nonce = _aesGcm.newNonce();
    final encrypted = await _aesGcm.encrypt(utf8.encode(plaintext), secretKey: sessionKey, nonce: nonce);
    final cipherWithMac = encrypted.cipherText + encrypted.mac.bytes;
    return {'cipher': base64.encode(cipherWithMac), 'iv': base64.encode(nonce)};
  }

  Future<String?> decryptContent({required String cipherB64, required String ivB64, required SecretKey sessionKey}) async {
    try {
      final raw = base64.decode(cipherB64);
      final iv = base64.decode(ivB64);
      final cipherText = raw.sublist(0, raw.length - 16);
      final mac = Mac(raw.sublist(raw.length - 16));
      final decrypted = await _aesGcm.decrypt(SecretBox(cipherText, nonce: iv, mac: mac), secretKey: sessionKey);
      return utf8.decode(decrypted);
    } catch (_) {
      return null;
    }
  }

  Future<void> reEncryptPrivateKeyWithNewPin({required String userCode, required String newPin}) async {
    if (_privateKey == null) return;
    final privKeyBytes = _encodePrivateKeyToBytes(_privateKey!);
    final salt = _randomBytes(32);
    final pinKey = await _deriveKeyFromPin(newPin, salt);
    final nonce = _aesGcm.newNonce();
    final encrypted = await _aesGcm.encrypt(privKeyBytes, secretKey: pinKey, nonce: nonce);

    final encPrivB64 = base64.encode(encrypted.cipherText + encrypted.mac.bytes);
    final saltB64 = base64.encode(salt);
    final ivB64 = base64.encode(nonce);

    await _storage.write(key: 'lore_enc_priv_$userCode', value: encPrivB64);
    await _storage.write(key: 'lore_priv_salt_$userCode', value: saltB64);
    await _storage.write(key: 'lore_priv_iv_$userCode', value: ivB64);
    await _storage.write(key: 'lore_raw_priv_$userCode', value: base64.encode(privKeyBytes));

    await _db.collection('user_secrets').doc(userCode).update({
      'encryptedPrivateKey': encPrivB64,
      'privateKeySalt': saltB64,
      'privateKeyIv': ivB64,
    });
  }

  Future<SecretKey> _deriveKeyFromPin(String pin, List<int> salt) async {
    final pinBytes = utf8.encode(pin);
    final secretKey = SecretKey(pinBytes);
    return _pbkdf2.deriveKey(secretKey: secretKey, nonce: salt);
  }

  Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rand.nextInt(256)));
  }

  ({pc.RSAPublicKey publicKey, pc.RSAPrivateKey privateKey}) _generateRSAKeypair() {
    final secureRandom = pc.FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64), secureRandom));

    final pair = keyGen.generateKeyPair();
    return (publicKey: pair.publicKey as pc.RSAPublicKey, privateKey: pair.privateKey as pc.RSAPrivateKey);
  }

  Uint8List _rsaEncrypt(Uint8List data, pc.RSAPublicKey publicKey) {
    final cipher = pc.OAEPEncoding(pc.RSAEngine())..init(true, pc.PublicKeyParameter<pc.RSAPublicKey>(publicKey));
    return cipher.process(data);
  }

  Uint8List _rsaDecrypt(Uint8List data, pc.RSAPrivateKey privateKey) {
    final cipher = pc.OAEPEncoding(pc.RSAEngine())..init(false, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privateKey));
    return cipher.process(data);
  }

  String _encodePublicKey(pc.RSAPublicKey key) {
    final map = {'n': key.modulus.toString(), 'e': key.exponent.toString()};
    return base64.encode(utf8.encode(jsonEncode(map)));
  }

  pc.RSAPublicKey _decodePublicKey(String b64) {
    final map = jsonDecode(utf8.decode(base64.decode(b64))) as Map;
    return pc.RSAPublicKey(BigInt.parse(map['n'] as String), BigInt.parse(map['e'] as String));
  }

  Uint8List _encodePrivateKeyToBytes(pc.RSAPrivateKey key) {
    final map = {'n': key.modulus.toString(), 'e': key.exponent.toString(), 'p': key.p.toString(), 'q': key.q.toString()};
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  pc.RSAPrivateKey _decodePrivateKeyFromBytes(Uint8List bytes) {
    final map = jsonDecode(utf8.decode(bytes)) as Map;
    final n = BigInt.parse(map['n'] as String);
    final e = BigInt.parse(map['e'] as String);
    final p = BigInt.parse(map['p'] as String);
    final q = BigInt.parse(map['q'] as String);
    return pc.RSAPrivateKey(n, e, p, q);
  }

  Future<String?> encryptSandbox(String plaintext, String pin) async {
    if (_privateKey == null) return null;
    try {
      final salt = _randomBytes(32);
      final key = await _deriveKeyFromPin(pin, salt);
      final nonce = _aesGcm.newNonce();
      final encrypted = await _aesGcm.encrypt(utf8.encode(plaintext), secretKey: key, nonce: nonce);
      final cipherWithMac = encrypted.cipherText + encrypted.mac.bytes;
      return base64.encode(Uint8List.fromList(salt + nonce + cipherWithMac));
    } catch (e) {
      return null;
    }
  }

  Future<String?> decryptSandbox(String cipherB64, String pin) async {
    try {
      final combined = base64.decode(cipherB64);
      final salt = combined.sublist(0, 32);
      final iv = combined.sublist(32, 44);
      final cipherWithMac = combined.sublist(44);

      final cipherText = cipherWithMac.sublist(0, cipherWithMac.length - 16);
      final mac = Mac(cipherWithMac.sublist(cipherWithMac.length - 16));

      final key = await _deriveKeyFromPin(pin, salt);
      final decrypted = await _aesGcm.decrypt(SecretBox(cipherText, nonce: iv, mac: mac), secretKey: key);
      return utf8.decode(decrypted);
    } catch (e) {
      return null;
    }
  }
}