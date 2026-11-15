import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

// ─────────────────────────────────────────────────────────────
// CryptoService
//
// Architecture:
//   • Each user has an RSA-2048 keypair generated on registration.
//   • Public key stored in Firestore (users/{code}/publicKey).
//   • Private key encrypted with AES-256-GCM using a key derived
//     from the user's PIN via PBKDF2-SHA256 (100k iterations).
//     The encrypted private key is stored BOTH in flutter_secure_storage
//     (fast local access) and Firestore (for device transfer).
//   • Each session has a random 256-bit AES session key, encrypted
//     separately with each participant's public key and stored in
//     the session document.
//   • All post/brainstorm/ooc content is encrypted with the session
//     key using AES-256-GCM before hitting Firestore.
//
// What Firestore sees:
//   users/{code}:
//     publicKey: "base64 RSA public key"      ← public, fine
//     encryptedPrivateKey: "base64 blob"      ← encrypted with PIN
//     privateKeySalt: "base64 salt"           ← salt for PBKDF2
//     privateKeyIv: "base64 IV"               ← IV for AES-GCM
//
//   sessions/{id}:
//     sessionKey_{code}: "base64 blob"        ← session key encrypted with user's RSA public key
//
//   sessions/{id}/posts/{id}:
//     content: "base64 AES-GCM ciphertext"    ← encrypted
//     iv: "base64 IV"                         ← unique per message
//     (everything else stays plaintext)
// ─────────────────────────────────────────────────────────────

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  /// Encrypt raw bytes (for images/files)
  Future<Map<String, dynamic>> encryptBytes(
    Uint8List data,
    SecretKey sessionKey,
  ) async {
    final nonce = _aesGcm.newNonce();
    final encrypted = await _aesGcm.encrypt(
      data,
      secretKey: sessionKey,
      nonce: nonce,
    );
    final cipherWithMac = encrypted.cipherText + encrypted.mac.bytes;
    return {'cipher': cipherWithMac, 'iv': nonce};
  }

  /// Decrypt raw bytes back to a Uint8List
  Future<Uint8List?> decryptBytes({
    required List<int> cipherBytes,
    required List<int> ivBytes,
    required SecretKey sessionKey,
  }) async {
    try {
      final cipherText = cipherBytes.sublist(0, cipherBytes.length - 16);
      final mac = Mac(cipherBytes.sublist(cipherBytes.length - 16));
      final decrypted = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: ivBytes, mac: mac),
        secretKey: sessionKey,
      );
      return Uint8List.fromList(decrypted);
    } catch (_) {
      return null;
    }
  }

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _db = FirebaseFirestore.instance;
  final _aesGcm = AesGcm.with256bits();
  final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  // ── In-memory cache of the unlocked session keys ──
  // sessionId → SecretKey (AES-256)
  final Map<String, SecretKey> _sessionKeyCache = {};

  // ── In-memory RSA private key (loaded once on unlock) ──
  pc.RSAPrivateKey? _privateKey;
  pc.RSAPublicKey? _publicKey;

  // ─────────────────────────────────────────────────
  // REGISTRATION — generate keypair + save
  // ─────────────────────────────────────────────────

  /// Call after PIN is set. Generates RSA keypair, encrypts private key
  /// with PIN-derived key, saves everything.
  Future<void> generateAndSaveKeypair({
    required String userCode,
    required String pin,
  }) async {
    // Generate RSA-2048 keypair using PointyCastle
    final keypair = _generateRSAKeypair();
    _privateKey = keypair.privateKey;
    _publicKey = keypair.publicKey;

    // Encode public key to base64 for Firestore
    final pubKeyB64 = _encodePublicKey(keypair.publicKey);

    // Encrypt private key with PIN (for Firestore backup + PIN-lock flow)
    final privKeyBytes = _encodePrivateKeyToBytes(keypair.privateKey);
    final salt = _randomBytes(32);
    final pinKey = await _deriveKeyFromPin(pin, salt);
    final nonce = _aesGcm.newNonce();
    final encrypted = await _aesGcm.encrypt(
      privKeyBytes,
      secretKey: pinKey,
      nonce: nonce,
    );

    final encPrivB64 = base64.encode(
      encrypted.cipherText + encrypted.mac.bytes,
    );
    final saltB64 = base64.encode(salt);
    final ivB64 = base64.encode(nonce);

    // Store PIN-encrypted key in secure storage + Firestore (for transfer recovery)
    await _storage.write(key: 'lore_enc_priv_$userCode', value: encPrivB64);
    await _storage.write(key: 'lore_priv_salt_$userCode', value: saltB64);
    await _storage.write(key: 'lore_priv_iv_$userCode', value: ivB64);
    // Also store raw key bytes in secure storage for no-lock-screen silent unlock
    await _storage.write(
      key: 'lore_raw_priv_$userCode',
      value: base64.encode(privKeyBytes),
    );

    // Store in Firestore (encrypted version only — raw never leaves device)
    await _db.collection('users').doc(userCode).update({
      'publicKey': pubKeyB64,
      'encryptedPrivateKey': encPrivB64,
      'privateKeySalt': saltB64,
      'privateKeyIv': ivB64,
    });
  }

  // ─────────────────────────────────────────────────
  // LOGIN — unlock private key with PIN
  // ─────────────────────────────────────────────────

  /// Call on login/unlock after PIN verified. Loads and decrypts private key.
  /// Falls back to Firestore if secure storage is empty (new device after transfer).
  Future<bool> unlockPrivateKey({
    required String userCode,
    required String pin,
  }) async {
    try {
      String? encPrivB64 = await _storage.read(key: 'lore_enc_priv_$userCode');
      String? saltB64 = await _storage.read(key: 'lore_priv_salt_$userCode');
      String? ivB64 = await _storage.read(key: 'lore_priv_iv_$userCode');

      // New device — pull from Firestore
      if (encPrivB64 == null || saltB64 == null || ivB64 == null) {
        final doc = await _db.collection('users').doc(userCode).get();
        if (!doc.exists) return false;
        final data = doc.data()!;
        encPrivB64 = data['encryptedPrivateKey'] as String?;
        saltB64 = data['privateKeySalt'] as String?;
        ivB64 = data['privateKeyIv'] as String?;
        if (encPrivB64 == null || saltB64 == null || ivB64 == null) {
          return false;
        }

        // Re-cache in secure storage on this new device
        await _storage.write(key: 'lore_enc_priv_$userCode', value: encPrivB64);
        await _storage.write(key: 'lore_priv_salt_$userCode', value: saltB64);
        await _storage.write(key: 'lore_priv_iv_$userCode', value: ivB64);
      }

      final salt = base64.decode(saltB64);
      final iv = base64.decode(ivB64);
      final encBytes = base64.decode(encPrivB64);

      // Split ciphertext and MAC (last 16 bytes)
      final cipherText = encBytes.sublist(0, encBytes.length - 16);
      final mac = Mac(encBytes.sublist(encBytes.length - 16));

      final pinKey = await _deriveKeyFromPin(pin, salt);
      final decrypted = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: iv, mac: mac),
        secretKey: pinKey,
      );

      _privateKey = _decodePrivateKeyFromBytes(Uint8List.fromList(decrypted));

      // Cache the raw key locally so future cold-starts can use
      // silentUnlock without needing the PIN again.
      await _storage.write(
        key: 'lore_raw_priv_$userCode',
        value: base64.encode(Uint8List.fromList(decrypted)),
      );

      // Also load public key
      final doc = await _db.collection('users').doc(userCode).get();
      final pubKeyB64 = doc.data()?['publicKey'] as String?;
      if (pubKeyB64 != null) {
        _publicKey = _decodePublicKey(pubKeyB64);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Whether the private key is currently loaded in memory
  bool get isUnlocked => _privateKey != null;

  /// True if Firestore has encrypted private-key material for this user.
  /// Used after a device wipe: local secure storage is empty but the
  /// account's keys still exist server-side.
  Future<bool> hasRemoteKeyMaterial(String userCode) async {
    try {
      final doc = await _db.collection('users').doc(userCode).get();
      return doc.data()?['encryptedPrivateKey'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Silent unlock for users with lock screen disabled.
  /// Uses raw private key from secure storage (never leaves device).
  Future<bool> silentUnlock(String userCode) async {
    if (_privateKey != null) return true;
    try {
      final rawB64 = await _storage.read(key: 'lore_raw_priv_$userCode');
      if (rawB64 == null) return false;
      _privateKey = _decodePrivateKeyFromBytes(base64.decode(rawB64));
      // Load public key from Firestore
      final doc = await _db.collection('users').doc(userCode).get();
      final pubKeyB64 = doc.data()?['publicKey'] as String?;
      if (pubKeyB64 != null) _publicKey = _decodePublicKey(pubKeyB64);
      return _privateKey != null;
    } catch (_) {
      return false;
    }
  }

  /// Clear private key from memory (on sign out)
  void lock() {
    _privateKey = null;
    _publicKey = null;
    _sessionKeyCache.clear();
  }

  // ─────────────────────────────────────────────────
  // SESSION KEY — create and retrieve
  // ─────────────────────────────────────────────────

  /// Create a new session key for a new session. Encrypts it with
  /// both participants' public keys and writes to Firestore.
  Future<void> createSessionKey({
    required String sessionId,
    required String myCode,
    required String partnerCode,
  }) async {
    // Generate random 256-bit session key
    final sessionKey = await _aesGcm.newSecretKey();
    final sessionKeyBytes = await sessionKey.extractBytes();

    // Cache locally
    _sessionKeyCache[sessionId] = sessionKey;

    // Fetch partner's public key
    final partnerDoc = await _db.collection('users').doc(partnerCode).get();
    final partnerPubKeyB64 = partnerDoc.data()?['publicKey'] as String?;
    if (partnerPubKeyB64 == null) return;
    final partnerPubKey = _decodePublicKey(partnerPubKeyB64);

    // Encrypt session key with my public key and partner's public key
    final myPubKey = _publicKey;
    if (myPubKey == null) return;
    final myEncrypted = _rsaEncrypt(
      Uint8List.fromList(sessionKeyBytes),
      myPubKey,
    );
    final partnerEncrypted = _rsaEncrypt(
      Uint8List.fromList(sessionKeyBytes),
      partnerPubKey,
    );

    await _db.collection('sessions').doc(sessionId).update({
      'sessionKey_$myCode': base64.encode(myEncrypted),
      'sessionKey_$partnerCode': base64.encode(partnerEncrypted),
    });
  }

  /// Get the session key for a session, decrypting it with our private key.
  /// Caches in memory after first load.
  Future<SecretKey?> getSessionKey({
    required String sessionId,
    required String myCode,
  }) async {
    if (_sessionKeyCache.containsKey(sessionId)) {
      return _sessionKeyCache[sessionId];
    }
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

  // ─────────────────────────────────────────────────
  // ENCRYPT / DECRYPT CONTENT
  // ─────────────────────────────────────────────────

  /// Encrypt a string, returns {'cipher': base64, 'iv': base64}
  Future<Map<String, String>> encryptContent(
    String plaintext,
    SecretKey sessionKey,
  ) async {
    final nonce = _aesGcm.newNonce();
    final encrypted = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: sessionKey,
      nonce: nonce,
    );
    final cipherWithMac = encrypted.cipherText + encrypted.mac.bytes;
    return {'cipher': base64.encode(cipherWithMac), 'iv': base64.encode(nonce)};
  }

  /// Decrypt a content blob back to plaintext string.
  /// Returns null if decryption fails (key mismatch, corrupt data).
  Future<String?> decryptContent({
    required String cipherB64,
    required String ivB64,
    required SecretKey sessionKey,
  }) async {
    try {
      final raw = base64.decode(cipherB64);
      final iv = base64.decode(ivB64);
      final cipherText = raw.sublist(0, raw.length - 16);
      final mac = Mac(raw.sublist(raw.length - 16));
      final decrypted = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: iv, mac: mac),
        secretKey: sessionKey,
      );
      return utf8.decode(decrypted);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────
  // UPDATE PIN — re-encrypt private key with new PIN
  // ─────────────────────────────────────────────────

  Future<void> reEncryptPrivateKeyWithNewPin({
    required String userCode,
    required String newPin,
  }) async {
    if (_privateKey == null) return;
    final privKeyBytes = _encodePrivateKeyToBytes(_privateKey!);
    final salt = _randomBytes(32);
    final pinKey = await _deriveKeyFromPin(newPin, salt);
    final nonce = _aesGcm.newNonce();
    final encrypted = await _aesGcm.encrypt(
      privKeyBytes,
      secretKey: pinKey,
      nonce: nonce,
    );
    final encPrivB64 = base64.encode(
      encrypted.cipherText + encrypted.mac.bytes,
    );
    final saltB64 = base64.encode(salt);
    final ivB64 = base64.encode(nonce);

    await _storage.write(key: 'lore_enc_priv_$userCode', value: encPrivB64);
    await _storage.write(key: 'lore_priv_salt_$userCode', value: saltB64);
    await _storage.write(key: 'lore_priv_iv_$userCode', value: ivB64);
    // Keep raw key up to date for silent unlock
    await _storage.write(
      key: 'lore_raw_priv_$userCode',
      value: base64.encode(privKeyBytes),
    );

    await _db.collection('users').doc(userCode).update({
      'encryptedPrivateKey': encPrivB64,
      'privateKeySalt': saltB64,
      'privateKeyIv': ivB64,
    });
  }

  // ─────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────

  Future<SecretKey> _deriveKeyFromPin(String pin, List<int> salt) async {
    final pinBytes = utf8.encode(pin);
    final secretKey = SecretKey(pinBytes);
    return _pbkdf2.deriveKey(secretKey: secretKey, nonce: salt);
  }

  Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rand.nextInt(256)));
  }

  // RSA keypair generation
  ({pc.RSAPublicKey publicKey, pc.RSAPrivateKey privateKey})
  _generateRSAKeypair() {
    final secureRandom = pc.FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = pc.RSAKeyGenerator()
      ..init(
        pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          secureRandom,
        ),
      );

    final pair = keyGen.generateKeyPair();
    return (
      publicKey: pair.publicKey as pc.RSAPublicKey,
      privateKey: pair.privateKey as pc.RSAPrivateKey,
    );
  }

  // RSA OAEP encrypt (for small payloads like session keys)
  Uint8List _rsaEncrypt(Uint8List data, pc.RSAPublicKey publicKey) {
    final cipher = pc.OAEPEncoding(pc.RSAEngine())
      ..init(true, pc.PublicKeyParameter<pc.RSAPublicKey>(publicKey));
    return cipher.process(data);
  }

  Uint8List _rsaDecrypt(Uint8List data, pc.RSAPrivateKey privateKey) {
    final cipher = pc.OAEPEncoding(pc.RSAEngine())
      ..init(false, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privateKey));
    return cipher.process(data);
  }

  // Key serialisation — DER-like encoding via BigInt components
  String _encodePublicKey(pc.RSAPublicKey key) {
    final map = {'n': key.modulus.toString(), 'e': key.exponent.toString()};
    return base64.encode(utf8.encode(jsonEncode(map)));
  }

  pc.RSAPublicKey _decodePublicKey(String b64) {
    final map = jsonDecode(utf8.decode(base64.decode(b64))) as Map;
    return pc.RSAPublicKey(
      BigInt.parse(map['n'] as String),
      BigInt.parse(map['e'] as String),
    );
  }

  Uint8List _encodePrivateKeyToBytes(pc.RSAPrivateKey key) {
    final map = {
      'n': key.modulus.toString(),
      'e': key.exponent.toString(),
      'p': key.p.toString(),
      'q': key.q.toString(),
    };
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
  // ─────────────────────────────────────────────────
  // SANDBOX ENCRYPTION (E2EE for Worlds & Characters)
  // ─────────────────────────────────────────────────

  Future<String?> encryptSandbox(String plaintext, String pin) async {
    if (_privateKey == null) return null;
    try {
      // We derive a key from the PIN just for the sandbox
      final salt = _randomBytes(32);
      final key = await _deriveKeyFromPin(pin, salt);
      final nonce = _aesGcm.newNonce();
      final encrypted = await _aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: key,
        nonce: nonce,
      );
      final cipherWithMac = encrypted.cipherText + encrypted.mac.bytes;

      // We combine salt + iv + cipher so we can decrypt it later
      final combined = Uint8List.fromList(salt + nonce + cipherWithMac);
      return base64.encode(combined);
    } catch (e) {
      return null;
    }
  }

  Future<String?> decryptSandbox(String cipherB64, String pin) async {
    try {
      final combined = base64.decode(cipherB64);
      final salt = combined.sublist(0, 32);
      final iv = combined.sublist(32, 44); // 12 byte nonce
      final cipherWithMac = combined.sublist(44);

      final cipherText = cipherWithMac.sublist(0, cipherWithMac.length - 16);
      final mac = Mac(cipherWithMac.sublist(cipherWithMac.length - 16));

      final key = await _deriveKeyFromPin(pin, salt);
      final decrypted = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: iv, mac: mac),
        secretKey: key,
      );
      return utf8.decode(decrypted);
    } catch (e) {
      return null;
    }
  }
}
