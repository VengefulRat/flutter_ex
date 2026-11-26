import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'crypto_service.dart';
import 'user_code.dart';
import '../models/world.dart';
import '../settings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _codeKey        = 'lore_user_code';
  static const _nameKey        = 'lore_user_name';
  static const _pinHashKey     = 'lore_pin_hash';
  static const _pinSaltKey     = 'lore_pin_salt';
  static const _pinVersionKey  = 'lore_pin_version';
  static const _pinLengthKey   = 'lore_pin_length';
  static const _lockModeKey    = 'lore_lock_mode';
  static const _lockTimingKey  = 'lore_lock_timing';
  static const _bgTimestampKey = 'lore_bg_timestamp';
  static const _mobileSessionKey = 'lore_mobile_session';
  static const _webSessionKey    = 'lore_web_session';
  static const _biometricsKey = 'lore_biometrics_enabled';
  static const _deviceKey = 'lore_device_id';

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceKey);
    if (id == null || id.isEmpty) {
      final rnd = Random.secure();
      id = List.generate(16, (_) => rnd.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await prefs.setString(_deviceKey, id);
    }
    return id;
  }

  static const int pinMinLength = 6;
  static const int maxPinAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 5);
  static const int _pinIterations = 600000;

  String? _cachedCode;
  String? _cachedName;

  String? get currentCode => _cachedCode;
  String? get currentName => _cachedName;
  User? get firebaseUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null && _cachedCode != null;

  final _pbkdf2 = crypto.Pbkdf2(
    macAlgorithm: crypto.Hmac.sha256(),
    iterations: _pinIterations,
    bits: 256,
  );

  List<int> _randomBytes(int length) {
    final rnd = Random.secure();
    return List<int>.generate(length, (_) => rnd.nextInt(256));
  }

  String _hashPinSha256(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<String> _hashPinPbkdf2(String pin, List<int> salt) async {
    final key = await _pbkdf2.deriveKey(
      secretKey: crypto.SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    return base64.encode(bytes);
  }

  Future<bool> isNameAvailable(String name) async {
    final query = await _db
        .collection('users')
        .where('displayName', isEqualTo: name.toLowerCase().trim())
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  Future<RegisterResult> register(String displayName) async {
    try {
      final name = displayName.trim();
      if (name.isEmpty) return RegisterResult.error('Name cannot be empty.');
      if (name.length < 2 || name.length > 24) return RegisterResult.error('Name must be 2–24 characters.');
      if (!RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(name)) return RegisterResult.error('Letters, numbers, _ and - only.');

      if (_auth.currentUser == null) await _auth.signInAnonymously();

      final available = await isNameAvailable(name);
      if (!available) return RegisterResult.error('That name is already taken.');

      String code;
      bool codeExists = true;
      int attempts = 0;
      do {
        code = generateUserCode();
        final doc = await _db.collection('users').doc(code).get();
        codeExists = doc.exists;
        attempts++;
        if (attempts > 10) return RegisterResult.error('Could not generate a unique code.');
      } while (codeExists);

      final uid = _auth.currentUser!.uid;
      final v = DateTime.now().millisecondsSinceEpoch;

      // 1. Public Data
      await _db.collection('users').doc(code).set({
        'code': code,
        'uid': uid, // Needed for write permissions
        'displayName': name.toLowerCase().trim(),
        'displayNameOriginal': name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'isDiscoverable': true,
        'genres': [],
        'bio': '',
        'writingStyle': '',
        'postFrequency': '',
      });

      // 2. Private Data
      await _db.collection('user_secrets').doc(code).set({
        'uid': uid,
        'deviceLocked': true,
        'sessionVersions': {await _deviceId(): v},
        'pinAttempts': 0,
      });

      await _saveLocal(code, name);
      saveFcmToken();
      return RegisterResult.success(code, name);
    } on FirebaseException catch (e) {
      return RegisterResult.error('${e.code}: ${e.message}');
    } catch (e) {
      return RegisterResult.error('Unexpected error: $e');
    }
  }

  Future<LoginResult> login(String code) async {
    try {
      final clean = code.trim().toUpperCase();
      if (clean.isEmpty) return LoginResult.error('Please enter your code.');
      if (_auth.currentUser == null) await _auth.signInAnonymously();

      final doc = await _db.collection('users').doc(clean).get();
      if (!doc.exists) return LoginResult.error('Code not found. Check and try again.');

      final data = doc.data() ?? {};
      final uid = _auth.currentUser!.uid;
      
      // --- MIGRATION LOGIC ---
      final secretDoc = await _db.collection('user_secrets').doc(clean).get();
      if (!secretDoc.exists) {
        // Migrate existing user to new collection
        await _db.collection('user_secrets').doc(clean).set({
          'uid': uid,
          'deviceLocked': data['deviceLocked'] ?? false,
          'transferRequestedAt': data['transferRequestedAt'],
          'sessionVersions': data['sessionVersions'] ?? {},
          'pinHash': data['pinHash'],
          'pinSalt': data['pinSalt'],
          'pinHashVersion': data['pinHashVersion'],
          'pinLength': data['pinLength'],
          'pinAttempts': data['pinAttempts'] ?? 0,
          'pinLockedUntil': data['pinLockedUntil'],
          'encryptedPrivateKey': data['encryptedPrivateKey'],
          'privateKeySalt': data['privateKeySalt'],
          'privateKeyIv': data['privateKeyIv'],
        });
      } else {
        // Ensure the UID is updated so this device has write access
        await _db.collection('user_secrets').doc(clean).update({'uid': uid});
      }

      final secrets = (await _db.collection('user_secrets').doc(clean).get()).data() ?? {};
      final locked = secrets['deviceLocked'] as bool? ?? false;
      final transferPending = secrets['transferRequestedAt'] != null;

      if (locked || transferPending) return LoginResult.deviceLocked();

      final newVersion = DateTime.now().millisecondsSinceEpoch;
      final deviceId = await _deviceId();

      await _db.collection('user_secrets').doc(clean).update({
        'deviceLocked': true,
        'sessionVersions.$deviceId': newVersion,
      });
      await _db.collection('users').doc(clean).update({'lastSeen': FieldValue.serverTimestamp()});

      final name = data['displayNameOriginal'] as String? ?? '';
      await _saveLocal(clean, name);
      await _saveSessionVersion(newVersion);
      saveFcmToken();
      return LoginResult.success(clean, name);
    } on FirebaseException catch (e) {
      return LoginResult.error('${e.code}: ${e.message}');
    } catch (e) {
      return LoginResult.error('Unexpected error: $e');
    }
  }

  Future<LoginResult> loginWeb(String code) async {
    try {
      final clean = code.trim().toUpperCase();
      if (_auth.currentUser == null) await _auth.signInAnonymously();

      final doc = await _db.collection('users').doc(clean).get();
      if (!doc.exists) return LoginResult.error('Code not found. Check and try again.');

      final uid = _auth.currentUser!.uid;
      
      // --- MIGRATION LOGIC (Same as above) ---
      final secretDoc = await _db.collection('user_secrets').doc(clean).get();
      if (!secretDoc.exists) {
        final data = doc.data() ?? {};
        await _db.collection('user_secrets').doc(clean).set({
          'uid': uid,
          'deviceLocked': data['deviceLocked'] ?? false,
          'transferRequestedAt': data['transferRequestedAt'],
          'sessionVersions': data['sessionVersions'] ?? {},
          'pinHash': data['pinHash'],
          'pinSalt': data['pinSalt'],
          'pinHashVersion': data['pinHashVersion'],
          'pinLength': data['pinLength'],
          'pinAttempts': data['pinAttempts'] ?? 0,
          'pinLockedUntil': data['pinLockedUntil'],
          'encryptedPrivateKey': data['encryptedPrivateKey'],
          'privateKeySalt': data['privateKeySalt'],
          'privateKeyIv': data['privateKeyIv'],
        });
      } else {
        await _db.collection('user_secrets').doc(clean).update({'uid': uid});
      }

      final secrets = (await _db.collection('user_secrets').doc(clean).get()).data() ?? {};
      final locked = secrets['deviceLocked'] as bool? ?? false;
      final transferPending = secrets['transferRequestedAt'] != null;

      if (locked || transferPending) return LoginResult.deviceLocked();

      final name = doc.data()?['displayNameOriginal'] as String? ?? '';
      final newVersion = DateTime.now().millisecondsSinceEpoch;
      final deviceId = await _deviceId();

      await _db.collection('user_secrets').doc(clean).update({
        'sessionVersions.$deviceId': newVersion,
      });
      await _db.collection('users').doc(clean).update({'lastSeen': FieldValue.serverTimestamp()});
      
      await _saveLocal(clean, name);
      await _saveSessionVersion(newVersion);
      saveFcmToken();
      return LoginResult.success(clean, name);
    } on FirebaseException catch (e) {
      return LoginResult.error('${e.code}: ${e.message}');
    } catch (e) {
      return LoginResult.error('Unexpected error: $e');
    }
  }

  Future<void> _saveSessionVersion(int? version) async {
    if (version == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      await prefs.setInt(_webSessionKey, version);
    } else {
      await prefs.setInt(_mobileSessionKey, version);
    }
  }

  Future<bool> verifySessionVersion() async {
    final code = _cachedCode;
    if (code == null) return true;
    try {
      final doc = await _db.collection('user_secrets').doc(code).get();
      if (!doc.exists) return true;
      final data = doc.data()!;

      final prefs = await SharedPreferences.getInstance();
      final localKey = kIsWeb ? _webSessionKey : _mobileSessionKey;
      final local = prefs.getInt(localKey);

      final rawMap = data['sessionVersions'];
      if (rawMap is Map) {
        final deviceId = await _deviceId();
        final cloud = rawMap[deviceId];
        if (cloud == null) {
          final v = DateTime.now().millisecondsSinceEpoch;
          try {
            await _db.collection('user_secrets').doc(code).update({
              'sessionVersions.$deviceId': v,
            });
          } catch (_) {}
          await prefs.setInt(localKey, v);
          return true;
        }
        if (local == null) {
          await prefs.setInt(localKey, cloud as int);
          return true;
        }
        return local == cloud;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> signOutOtherDevices() async {
    final code = _cachedCode;
    if (code == null) return;
    final v = DateTime.now().millisecondsSinceEpoch;
    final deviceId = await _deviceId();
    
    await _db.collection('user_secrets').doc(code).update({
      'sessionVersions': {deviceId: v},
    });
    
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      await prefs.setInt(_webSessionKey, v);
    } else {
      await prefs.setInt(_mobileSessionKey, v);
    }
  }

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_codeKey);
    final name = prefs.getString(_nameKey);
    if (code == null || name == null) return false;
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
      } catch (_) {
        return false;
      }
    }
    _cachedCode = code;
    _cachedName = name;
    saveFcmToken();
    return true;
  }

    Future<void> updatePresence(String status) async {
    final code = _cachedCode;
    if (code == null) return;
    try {
      // We save this in the public 'users' collection because everyone needs to see it
      await _db.collection('users').doc(code).update({
        'presence': status,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[Presence] update failed: $e');
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    final code = _cachedCode;
    if (code == null) return false;
    return CryptoService().unlockPrivateKey(userCode: code, pin: pin);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_codeKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_pinHashKey);
    await prefs.remove(_pinSaltKey);
    await prefs.remove(_pinVersionKey);
    await prefs.remove(_pinLengthKey);
    await prefs.remove(_lockModeKey);
    await prefs.remove(_lockTimingKey);
    await prefs.remove(_mobileSessionKey);
    await prefs.remove(_webSessionKey);
    await prefs.remove(_biometricsKey);
    await prefs.remove(_bgTimestampKey);
    await prefs.remove(_lockAttemptsKey);
    await prefs.remove(_lockAttemptsTsKey);

    final code = _cachedCode;
    if (code != null) {
      try {
        final deviceId = await _deviceId();
        final doc = await _db.collection('user_secrets').doc(code).get();
        final rawMap = doc.data()?['sessionVersions'];
        final remaining = rawMap is Map ? rawMap.length - 1 : 0;
        final update = <String, dynamic>{
          'sessionVersions.$deviceId': FieldValue.delete(),
        };
        if (remaining <= 0) {
          update['deviceLocked'] = false;
        }
        await _db.collection('user_secrets').doc(code).update(update);
      } catch (_) {}
    }
    _cachedCode = null;
    _cachedName = null;
    CryptoService().lock();
    await SandboxStorage.clear();
    await appSettings.resetForSignOut();
    await _auth.signOut();
  }

  Future<void> savePin(String pin) async {
    if (pin.length < pinMinLength) throw ArgumentError('PIN must be at least $pinMinLength digits.');
    if (!RegExp(r'^\d+$').hasMatch(pin)) throw ArgumentError('PIN must contain digits only.');

    final salt = _randomBytes(32);
    final hash = await _hashPinPbkdf2(pin, salt);
    final saltB64 = base64.encode(salt);
    final code = _cachedCode;

    if (code != null) {
      final crypto = CryptoService();
      if (crypto.isUnlocked) {
        await crypto.reEncryptPrivateKeyWithNewPin(userCode: code, newPin: pin);
      } else {
        final doc = await _db.collection('user_secrets').doc(code).get();
        final hasExistingKey = doc.data()?['encryptedPrivateKey'] != null;
        if (!hasExistingKey) {
          await crypto.generateAndSaveKeypair(userCode: code, pin: pin);
        } else {
          final unlocked = await crypto.unlockPrivateKey(userCode: code, pin: pin);
          if (!unlocked) {
            throw ArgumentError('This account already has encryption keys, and the PIN you entered does not unlock them.');
          }
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinHashKey, hash);
    await prefs.setString(_pinSaltKey, saltB64);
    await prefs.setString(_pinVersionKey, 'pbkdf2');
    await prefs.setInt(_pinLengthKey, pin.length);

    if (code != null) {
      await _db.collection('user_secrets').doc(code).update({
        'pinHash': hash,
        'pinSalt': saltB64,
        'pinHashVersion': 'pbkdf2',
        'pinLength': pin.length,
        'pinAttempts': 0,
        'pinLockedUntil': FieldValue.delete(),
      });
    }
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinHashKey);
    if (stored == null) return false;
    final version = prefs.getString(_pinVersionKey) ?? 'sha256';
    if (version == 'sha256') return _hashPinSha256(pin) == stored;
    final saltB64 = prefs.getString(_pinSaltKey);
    if (saltB64 == null) return false;
    final candidate = await _hashPinPbkdf2(pin, base64.decode(saltB64));
    return candidate == stored;
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinHashKey) != null;
  }

  Future<int> pinLength() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pinLengthKey) ?? pinMinLength;
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.remove(_pinSaltKey);
    await prefs.remove(_pinVersionKey);
    await prefs.remove(_pinLengthKey);
    final code = _cachedCode;
    if (code != null) {
      await _db.collection('user_secrets').doc(code).update({
        'pinHash': FieldValue.delete(),
        'pinSalt': FieldValue.delete(),
        'pinHashVersion': FieldValue.delete(),
        'pinAttempts': FieldValue.delete(),
        'pinLockedUntil': FieldValue.delete(),
      });
    }
  }

  Future<PinVerifyResult> verifyPinRemote(String code, String pin) async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();

    final doc = await _db.collection('user_secrets').doc(code).get();
    if (!doc.exists) return PinVerifyResult(success: false, error: 'Account not found.');
    final data = doc.data()!;

    final lockedUntilRaw = data['pinLockedUntil'];
    if (lockedUntilRaw is Timestamp) {
      final lockedUntil = lockedUntilRaw.toDate();
      if (lockedUntil.isAfter(DateTime.now())) {
        return PinVerifyResult(success: false, isLocked: true, lockedUntil: lockedUntil, attemptsRemaining: 0, error: 'Account locked.');
      }
    }

    final storedHash = data['pinHash'] as String?;
    if (storedHash == null) return PinVerifyResult(success: false, error: 'No PIN set on this account.');
    final version = data['pinHashVersion'] as String? ?? 'sha256';
    final saltB64 = data['pinSalt'] as String?;

    String candidateHash;
    if (version == 'pbkdf2') {
      if (saltB64 == null) return PinVerifyResult(success: false, error: 'Corrupt PIN data.');
      candidateHash = await _hashPinPbkdf2(pin, base64.decode(saltB64));
    } else {
      candidateHash = _hashPinSha256(pin);
    }

    if (candidateHash != storedHash) {
      final prevAttempts = (data['pinAttempts'] as int?) ?? 0;
      final newAttempts = prevAttempts + 1;
      final willLock = newAttempts >= maxPinAttempts;
      final update = <String, dynamic>{'pinAttempts': willLock ? 0 : newAttempts};
      
      if (willLock) {
        final lockUntil = DateTime.now().add(lockoutDuration);
        update['pinLockedUntil'] = Timestamp.fromDate(lockUntil);
        await _notifySecurity(code, 'Account locked after failed PIN attempts', 'Someone tried to access your account with the wrong PIN $maxPinAttempts times.');
      } else if (newAttempts >= 3) {
        await _notifySecurity(code, 'Failed PIN attempts on your account', '$newAttempts failed attempts. The account locks after $maxPinAttempts.');
      }

      try {
        await _db.collection('user_secrets').doc(code).update(update);
      } catch (e) {
        print('[verifyPinRemote] attempt-write failed: $e');
      }

      return PinVerifyResult(success: false, attemptsRemaining: willLock ? 0 : maxPinAttempts - newAttempts, error: willLock ? 'Account locked.' : 'Incorrect PIN.');
    }

    final update = <String, dynamic>{'pinAttempts': 0, 'pinLockedUntil': FieldValue.delete()};
    if (version != 'pbkdf2') {
      final newSalt = _randomBytes(32);
      final newHash = await _hashPinPbkdf2(pin, newSalt);
      update['pinHash'] = newHash;
      update['pinSalt'] = base64.encode(newSalt);
      update['pinHashVersion'] = 'pbkdf2';
    }
    try {
      await _db.collection('user_secrets').doc(code).update(update);
    } catch (e) {
      print('[verifyPinRemote] success-write failed: $e');
    }
    return PinVerifyResult(success: true, attemptsRemaining: maxPinAttempts);
  }

  Future<LoginResult> completeLoginWithPin({required String code, required String pin}) async {
    try {
      if (_auth.currentUser == null) await _auth.signInAnonymously();
      final clean = code.trim().toUpperCase();
      final verification = await verifyPinRemote(clean, pin);

      if (verification.isLocked) return LoginResult.error(verification.error ?? 'Account locked.');
      if (!verification.success) {
        final remaining = verification.attemptsRemaining;
        final base = verification.error ?? 'Incorrect PIN.';
        return LoginResult.error(remaining > 0 ? '$base $remaining attempt${remaining == 1 ? '' : 's'} remaining.' : base);
      }

      final uid = _auth.currentUser!.uid;
      final newVersion = DateTime.now().millisecondsSinceEpoch;
      final deviceId = await _deviceId();
      
      await _db.collection('user_secrets').doc(clean).update({
        'uid': uid,
        'deviceLocked': true,
        'transferRequestedAt': FieldValue.delete(),
        'sessionVersions.$deviceId': newVersion,
      });
      await _db.collection('users').doc(clean).update({'lastSeen': FieldValue.serverTimestamp()});

      final doc = await _db.collection('users').doc(clean).get();
      final name = doc.data()?['displayNameOriginal'] as String? ?? '';

      await _saveLocal(clean, name);
      await _saveSessionVersion(newVersion);
      saveFcmToken();
      return LoginResult.success(clean, name);
    } on FirebaseException catch (e) {
      return LoginResult.error('${e.code}: ${e.message}');
    } catch (e) {
      return LoginResult.error('Unexpected error: $e');
    }
  }

  static const _lockAttemptsKey = 'lore_lockscreen_attempts';
  static const _lockAttemptsTsKey = 'lore_lockscreen_last_attempt';
  static const _lockAttemptsWindow = Duration(hours: 1);

  Future<void> recordFailedLockScreenAttempt() async {
    final code = _cachedCode;
    if (code == null) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTs = prefs.getInt(_lockAttemptsTsKey);
    int attempts = 0;
    if (lastTs != null && now - lastTs < _lockAttemptsWindow.inMilliseconds) {
      attempts = prefs.getInt(_lockAttemptsKey) ?? 0;
    }
    attempts++;
    await prefs.setInt(_lockAttemptsKey, attempts);
    await prefs.setInt(_lockAttemptsTsKey, now);
    if (attempts == 3 || attempts == 5 || attempts == 10) {
      await _notifySecurity(code, 'Failed lock screen attempts', '$attempts failed attempts on your device. If this isn\'t you, someone may have your phone.');
    }
  }

  Future<void> clearLockScreenAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lockAttemptsKey);
    await prefs.remove(_lockAttemptsTsKey);
  }

  Future<void> _notifySecurity(String code, String title, String subtitle) async {
    try {
      await _db.collection('notifications').add({
        'toCode': code,
        'type': 'security_warning',
        'title': title,
        'subtitle': subtitle,
        'data': <String, dynamic>{},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[security] notify failed: $e');
    }
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final code = _cachedCode;
    if (code == null) return;
    await prefs.setBool('${_biometricsKey}_$code', enabled);
  }

  Future<bool> isBiometricsEnabled() async {
    final code = _cachedCode;       
    if (code == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_biometricsKey}_$code') ?? false;
  }

  Future<bool> silentUnlock() async {
    final code = _cachedCode;
    if (code == null) return false;
    return CryptoService().silentUnlock(code);
  }
  
  Future<void> saveLockMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lockModeKey, mode);
  }

  Future<String> getLockMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lockModeKey) ?? 'none';
  }

  Future<void> saveLockTiming(String timing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lockTimingKey, timing);
  }

  Future<String> getLockTiming() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lockTimingKey) ?? 'always';
  }

  Future<void> saveBackgroundTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bgTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> shouldLock() async {
    final mode = await getLockMode();
    if (mode == 'none') return false;
    final timing = await getLockTiming();
    if (timing == 'always') return true;
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_bgTimestampKey);
    if (ts == null) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - ts;
    if (timing == 'close') return false;
    return elapsed > 5 * 60 * 1000;
  }

  Future<void> releaseDeviceLock() async {
    final code = _cachedCode;
    if (code == null) return;
    await _db.collection('user_secrets').doc(code).update({
      'deviceLocked': false,
      'transferRequestedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveLocal(String code, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeKey, code);
    await prefs.setString(_nameKey, name);
    _cachedCode = code;
    _cachedName = name;
  }

  Future<void> saveFcmToken() async {
    final code = _cachedCode;
    if (code == null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null) {
        await _db.collection('user_secrets').doc(code).update({'fcmToken': token});
      }
      messaging.onTokenRefresh.listen((newToken) {
        _db.collection('user_secrets').doc(code).update({'fcmToken': newToken});
      });
    } catch (e) {
      print('[FCM] token save failed: $e');
    }
  }
}

class RegisterResult {
  final bool success;
  final String? code;
  final String? name;
  final String? errorMessage;
  RegisterResult._({required this.success, this.code, this.name, this.errorMessage});
  factory RegisterResult.success(String code, String name) => RegisterResult._(success: true, code: code, name: name);
  factory RegisterResult.error(String message) => RegisterResult._(success: false, errorMessage: message);
}

class LoginResult {
  final bool success;
  final bool isDeviceLocked;
  final String? code;
  final String? name;
  final String? errorMessage;
  LoginResult._({required this.success, this.isDeviceLocked = false, this.code, this.name, this.errorMessage});
  factory LoginResult.success(String code, String name) => LoginResult._(success: true, code: code, name: name);
  factory LoginResult.deviceLocked() => LoginResult._(success: false, isDeviceLocked: true);
  factory LoginResult.error(String message) => LoginResult._(success: false, errorMessage: message);
}

class PinVerifyResult {
  final bool success;
  final bool isLocked;
  final DateTime? lockedUntil;
  final int attemptsRemaining;
  final String? error;
  const PinVerifyResult({required this.success, this.isLocked = false, this.lockedUntil, this.attemptsRemaining = 5, this.error});
}