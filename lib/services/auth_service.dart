import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'crypto_service.dart';
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

  // ── PIN policy ──
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

  // ── Code generation ──
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final part1 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    final part2 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'LR-$part1-$part2';
  }

  List<int> _randomBytes(int length) {
    final rnd = Random.secure();
    return List<int>.generate(length, (_) => rnd.nextInt(256));
  }

  // ── PIN hashing ──
  String _hashPinSha256(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  Future<String> _hashPinPbkdf2(String pin, List<int> salt) async {
    final key = await _pbkdf2.deriveKey(
      secretKey: crypto.SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    return base64.encode(bytes);
  }

  // ── Display name availability ──
  Future<bool> isNameAvailable(String name) async {
    final query = await _db
        .collection('users')
        .where('displayName', isEqualTo: name.toLowerCase().trim())
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  // ════════════════════════════════════════
  // REGISTER
  // ════════════════════════════════════════
  Future<RegisterResult> register(String displayName) async {
    try {
      final name = displayName.trim();
      if (name.isEmpty) return RegisterResult.error('Name cannot be empty.');
      if (name.length < 2 || name.length > 24) {
        return RegisterResult.error('Name must be 2–24 characters.');
      }
      if (!RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(name)) {
        return RegisterResult.error('Letters, numbers, _ and - only.');
      }

      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }

      final available = await isNameAvailable(name);
      if (!available) return RegisterResult.error('That name is already taken.');

      String code;
      bool codeExists = true;
      int attempts = 0;
      do {
        code = _generateCode();
        final doc = await _db.collection('users').doc(code).get();
        codeExists = doc.exists;
        attempts++;
        if (attempts > 10) {
          return RegisterResult.error('Could not generate a unique code. Try again.');
        }
      } while (codeExists);

      final uid = _auth.currentUser!.uid;

      await _db.collection('users').doc(code).set({
        'code': code,
        'displayName': name.toLowerCase().trim(),
        'displayNameOriginal': name,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'isDiscoverable': true,
        'deviceLocked': true,
        'sessionVersion': DateTime.now().millisecondsSinceEpoch,
        'genres': [],
        'bio': '',
        'writingStyle': '',
        'postFrequency': '',
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

  // ════════════════════════════════════════
  // LOGIN
  // ════════════════════════════════════════
    Future<LoginResult> login(String code) async {
    try {
      final clean = code.trim().toUpperCase();
      if (clean.isEmpty) {
        return LoginResult.error('Please enter your code.');
      }

      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }

      final doc = await _db.collection('users').doc(clean).get();
      if (!doc.exists) {
        return LoginResult.error('Code not found. Check and try again.');
      }

      final data = doc.data() ?? {};
      final locked = data['deviceLocked'] as bool? ?? false;
      final transferPending = data['transferRequestedAt'] != null;

      if (locked || transferPending) {
        return LoginResult.deviceLocked();
      }

      // Rotate the mobile session version to kick out other phones
      final newVersion = DateTime.now().millisecondsSinceEpoch;

      await _db.collection('users').doc(clean).update({
        'lastSeen': FieldValue.serverTimestamp(),
        'deviceLocked': true,
        'mobileSessionVersion': newVersion,
      });

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
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }

      final doc = await _db.collection('users').doc(clean).get();
      if (!doc.exists) {
        return LoginResult.error('Code not found. Check and try again.');
      }

      final data = doc.data() ?? {};
      final name = data['displayNameOriginal'] as String? ?? '';
      
      // Generate a new web session version (kicks out other web browsers)
      final newVersion = DateTime.now().millisecondsSinceEpoch;

      await _db.collection('users').doc(clean).update({
        'webSessionVersion': newVersion,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
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

  // ── Restore session from local storage ──

  // ════════════════════════════════════════
  // RESTORE / SIGN OUT
  // ════════════════════════════════════════

    // ════════════════════════════════════════
  // SESSION VERSION (remote sign-out)
  // ════════════════════════════════════════

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
      final doc = await _db.collection('users').doc(code).get();
      if (!doc.exists) return true;
      final data = doc.data()!;

      final prefs = await SharedPreferences.getInstance();

      if (kIsWeb) {
        final cloudWeb = data['webSessionVersion'] as int?;
        if (cloudWeb == null) return true; // Legacy account fallback
        final localWeb = prefs.getInt(_webSessionKey);
        if (localWeb == null) {
          await prefs.setInt(_webSessionKey, cloudWeb);
          return true;
        }
        return localWeb == cloudWeb;
      } else {
        final cloudMobile = data['mobileSessionVersion'] as int?;
        if (cloudMobile == null) return true; // Legacy account fallback
        final localMobile = prefs.getInt(_mobileSessionKey);
        if (localMobile == null) {
          await prefs.setInt(_mobileSessionKey, cloudMobile);
          return true;
        }
        return localMobile == cloudMobile;
      }
    } catch (_) {
      return true; // Fail open if offline
    }
  }

  /// Rotates the session version. The current device adopts the new
  /// value so it stays signed in; every other device fails the next
  /// verifySessionVersion() and is returned to Landing.
    Future<void> signOutOtherDevices() async {
    final code = _cachedCode;
    if (code == null) return;
    final v = DateTime.now().millisecondsSinceEpoch;
    
    await _db.collection('users').doc(code).update({
      'mobileSessionVersion': v,
      'webSessionVersion': v,
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
    await prefs.remove(_biometricsKey);
    await prefs.remove(_bgTimestampKey);
    await prefs.remove(_lockAttemptsKey);
    await prefs.remove(_lockAttemptsTsKey);

        final code = _cachedCode;
    if (code != null) {
      if (kIsWeb) {
        // Remove the web session so you can log in on another PC later
        await _db.collection('users').doc(code).update({
          'webSessionVersion': FieldValue.delete(),
        });
      } else {
        await _db.collection('users').doc(code).update({
          'deviceLocked': false,
          'mobileSessionVersion': FieldValue.delete(),
        });
      }
    }
        _cachedCode = null;
    _cachedName = null;
    CryptoService().lock();

    // Wipe local sandbox and preferences so the next account on this
    // device doesn't inherit anything from the one signing out.
    await SandboxStorage.clear();
    await appSettings.resetForSignOut();

    await _auth.signOut();
  }

  // ════════════════════════════════════════
  // PIN — local (fast, used by lock screen)
  // ════════════════════════════════════════

  /// Persists a new PIN. Enforces the length policy. Writes both the
  /// local copy (for the lock screen) and the server copy (for transfer
  /// recovery). Also generates or re-encrypts the E2E keypair.
  ///
  /// Throws ArgumentError if the PIN is shorter than [pinMinLength].
  Future<void> savePin(String pin) async {
    if (pin.length < pinMinLength) {
      throw ArgumentError('PIN must be at least $pinMinLength digits.');
    }
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain digits only.');
    }

    final prefs = await SharedPreferences.getInstance();
    final salt = _randomBytes(32);
    final hash = await _hashPinPbkdf2(pin, salt);

    await prefs.setString(_pinHashKey, hash);
    await prefs.setString(_pinSaltKey, base64.encode(salt));
    await prefs.setString(_pinVersionKey, 'pbkdf2');
    await prefs.setInt(_pinLengthKey, pin.length);

    final code = _cachedCode;
    if (code != null) {
      await _db.collection('users').doc(code).update({
        'pinHash': hash,
        'pinSalt': base64.encode(salt),
        'pinHashVersion': 'pbkdf2',
        'pinLength': pin.length,
        'pinAttempts': 0,
        'pinLockedUntil': FieldValue.delete(),
      });

      final crypto = CryptoService();
      if (crypto.isUnlocked) {
        // Key already in memory — safe to re-encrypt with the new PIN.
        await crypto.reEncryptPrivateKeyWithNewPin(
            userCode: code, newPin: pin);
      } else {
        // Key NOT in memory. Check Firestore before doing anything
        // destructive: if this account already has an encrypted private
        // key on file, generating a new keypair here would permanently
        // orphan every existing session. Try the PIN against the
        // existing key instead.
        final doc = await _db.collection('users').doc(code).get();
        final hasExistingKey =
            doc.data()?['encryptedPrivateKey'] != null;

        if (!hasExistingKey) {
          // Fresh account. Safe to generate.
          await crypto.generateAndSaveKeypair(
              userCode: code, pin: pin);
        } else {
          // Existing account on a wiped device. Try to unlock with the
          // PIN the user entered.
          final unlocked = await crypto.unlockPrivateKey(
              userCode: code, pin: pin);
          if (!unlocked) {
            throw ArgumentError(
              'This account already has encryption keys, and the PIN you '
              'entered does not unlock them. Use your original PIN — '
              'otherwise older content will stay locked on this device.',
            );
          }
          // Unlock succeeded. The key is now in memory and is already
          // encrypted with this same PIN on Firestore — nothing to save.
        }
      }
    }
  }

  /// Local PIN check. Handles legacy sha256 hashes and current pbkdf2.
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinHashKey);
    if (stored == null) return false;

    final version = prefs.getString(_pinVersionKey) ?? 'sha256';
    if (version == 'sha256') {
      return _hashPinSha256(pin) == stored;
    }
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
      await _db.collection('users').doc(code).update({
        'pinHash': FieldValue.delete(),
        'pinSalt': FieldValue.delete(),
        'pinHashVersion': FieldValue.delete(),
        'pinAttempts': FieldValue.delete(),
        'pinLockedUntil': FieldValue.delete(),
      });
    }
  }

  // ════════════════════════════════════════
  // PIN — remote (used by login / transfer)
  // ════════════════════════════════════════

  /// Verifies a PIN against the server. Manages attempt counting, lockout,
  /// legacy hash upgrade, and security notifications.
  Future<PinVerifyResult> verifyPinRemote(String code, String pin) async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }

    final doc = await _db.collection('users').doc(code).get();
    if (!doc.exists) {
      return PinVerifyResult(success: false, error: 'Account not found.');
    }
    final data = doc.data()!;

    // Lock check
    final lockedUntilRaw = data['pinLockedUntil'];
    if (lockedUntilRaw is Timestamp) {
      final lockedUntil = lockedUntilRaw.toDate();
      if (lockedUntil.isAfter(DateTime.now())) {
        return PinVerifyResult(
          success: false,
          isLocked: true,
          lockedUntil: lockedUntil,
          attemptsRemaining: 0,
          error: 'Account locked.',
        );
      }
    }

    final storedHash = data['pinHash'] as String?;
    if (storedHash == null) {
      return PinVerifyResult(
          success: false, error: 'No PIN set on this account.');
    }
    final version = data['pinHashVersion'] as String? ?? 'sha256';
    final saltB64 = data['pinSalt'] as String?;

    // Compute candidate hash
    String candidateHash;
    if (version == 'pbkdf2') {
      if (saltB64 == null) {
        return PinVerifyResult(
            success: false, error: 'Corrupt PIN data on server.');
      }
      candidateHash = await _hashPinPbkdf2(pin, base64.decode(saltB64));
    } else {
      candidateHash = _hashPinSha256(pin);
    }

    // ── Failure path ──
    if (candidateHash != storedHash) {
      final prevAttempts = (data['pinAttempts'] as int?) ?? 0;
      final newAttempts = prevAttempts + 1;
      final willLock = newAttempts >= maxPinAttempts;

      final update = <String, dynamic>{
        'pinAttempts': willLock ? 0 : newAttempts,
      };
      if (willLock) {
        final lockUntil = DateTime.now().add(lockoutDuration);
        update['pinLockedUntil'] = Timestamp.fromDate(lockUntil);
        await _notifySecurity(
          code,
          'Account locked after failed PIN attempts',
          'Someone tried to access your account with the wrong PIN $maxPinAttempts times. '
              'It has been locked for ${lockoutDuration.inMinutes} minutes. '
              'If this wasn\'t you, someone may have your unique code.',
        );
      } else if (newAttempts >= 3) {
        await _notifySecurity(
          code,
          'Failed PIN attempts on your account',
          '$newAttempts failed attempts. The account locks after $maxPinAttempts.',
        );
      }

      try {
        await _db.collection('users').doc(code).update(update);
      } catch (e) {
        print('[verifyPinRemote] attempt-write failed: $e');
      }

      return PinVerifyResult(
        success: false,
        attemptsRemaining: willLock ? 0 : maxPinAttempts - newAttempts,
        error: willLock
            ? 'Account locked for ${lockoutDuration.inMinutes} minutes.'
            : 'Incorrect PIN.',
      );
    }

    // ── Success path ──
    final update = <String, dynamic>{
      'pinAttempts': 0,
      'pinLockedUntil': FieldValue.delete(),
    };

    // Silent upgrade of legacy sha256 hash to pbkdf2. We have the plaintext
    // PIN right here, so this is a free opportunity to migrate.
    if (version != 'pbkdf2') {
      final newSalt = _randomBytes(32);
      final newHash = await _hashPinPbkdf2(pin, newSalt);
      update['pinHash'] = newHash;
      update['pinSalt'] = base64.encode(newSalt);
      update['pinHashVersion'] = 'pbkdf2';
    }

    try {
      await _db.collection('users').doc(code).update(update);
    } catch (e) {
      print('[verifyPinRemote] success-write failed: $e');
    }

    return PinVerifyResult(success: true, attemptsRemaining: maxPinAttempts);
  }

  /// Completes a login after the user has verified their PIN. This is the
  /// "transfer account" path — code + PIN, then we claim the device.
  Future<LoginResult> completeLoginWithPin({
    required String code,
    required String pin,
  }) async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }

      final clean = code.trim().toUpperCase();
      final verification = await verifyPinRemote(clean, pin);

      if (verification.isLocked) {
        return LoginResult.error(
            verification.error ?? 'Account locked. Try again later.');
      }
      if (!verification.success) {
        final remaining = verification.attemptsRemaining;
        final base = verification.error ?? 'Incorrect PIN.';
        final msg = remaining > 0
            ? '$base $remaining attempt${remaining == 1 ? '' : 's'} remaining.'
            : base;
        return LoginResult.error(msg);
      }

      // Rotate the session version on transfer. This tells every other
      // device signed in to the account — including the one that
      // requested the transfer — that its session is no longer valid.
      final newVersion = DateTime.now().millisecondsSinceEpoch;
      await _db.collection('users').doc(clean).update({
        'deviceLocked': true,
        'transferRequestedAt': FieldValue.delete(),
        'lastSeen': FieldValue.serverTimestamp(),
        'mobileSessionVersion': newVersion,
        'webSessionVersion': FieldValue.delete(), // Kicks out any old PC sessions
      });

      final doc = await _db.collection('users').doc(clean).get();
            final data = doc.data() ?? {};
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

  // ════════════════════════════════════════
  // LOCK SCREEN ATTEMPTS (local + notify)
  // ════════════════════════════════════════
  //
  // The lock screen verifies PINs locally, so it needs its own attempt
  // tracking. Counts are stored in SharedPreferences and reset on a
  // successful unlock. Notifications are still fired via Firestore so
  // the user sees them the next time they're signed in — even if the
  // device is lost or wiped.
  static const _lockAttemptsKey = 'lore_lockscreen_attempts';
  static const _lockAttemptsTsKey = 'lore_lockscreen_last_attempt';
  static const _lockAttemptsWindow = Duration(hours: 1);

  /// Records a failed lock screen attempt. Fires a security notification
  /// at 3, 5, and 10 attempts within the rolling window.
  Future<void> recordFailedLockScreenAttempt() async {
    final code = _cachedCode;
    if (code == null) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTs = prefs.getInt(_lockAttemptsTsKey);

    int attempts = 0;
    if (lastTs != null &&
        now - lastTs < _lockAttemptsWindow.inMilliseconds) {
      attempts = prefs.getInt(_lockAttemptsKey) ?? 0;
    }

    attempts++;
    await prefs.setInt(_lockAttemptsKey, attempts);
    await prefs.setInt(_lockAttemptsTsKey, now);

    if (attempts == 3 || attempts == 5 || attempts == 10) {
      await _notifySecurity(
        code,
        'Failed lock screen attempts',
        '$attempts failed attempts on your device. '
            'If this isn\'t you, someone may have your phone.',
      );
    }
  }

  /// Clears the lock screen attempt counter — called on successful unlock.
  Future<void> clearLockScreenAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lockAttemptsKey);
    await prefs.remove(_lockAttemptsTsKey);
  }


  // ════════════════════════════════════════
  // SECURITY NOTIFICATIONS
  // ════════════════════════════════════════
  Future<void> _notifySecurity(
    String code,
    String title,
    String subtitle,
  ) async {
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

  // ════════════════════════════════════════
  // LOCK SETTINGS
  // ════════════════════════════════════════
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

  // ════════════════════════════════════════
  // DEVICE TRANSFER
  // ════════════════════════════════════════
  Future<void> releaseDeviceLock() async {
    final code = _cachedCode;
    if (code == null) return;
    await _db.collection('users').doc(code).update({
      'deviceLocked': false,
      'transferRequestedAt': FieldValue.serverTimestamp(),
    });
  }

  // ════════════════════════════════════════
  // LOCAL STORAGE
  // ════════════════════════════════════════
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
        await _db.collection('users').doc(code).update({'fcmToken': token});
      }
      messaging.onTokenRefresh.listen((newToken) {
        _db.collection('users').doc(code).update({'fcmToken': newToken});
      });
    } catch (e) {
      print('[FCM] token save failed: $e');
    }
  }
}

// ════════════════════════════════════════
// RESULT TYPES
// ════════════════════════════════════════
class RegisterResult {
  final bool success;
  final String? code;
  final String? name;
  final String? errorMessage;

  RegisterResult._({required this.success, this.code, this.name, this.errorMessage});
  factory RegisterResult.success(String code, String name) =>
      RegisterResult._(success: true, code: code, name: name);
  factory RegisterResult.error(String message) =>
      RegisterResult._(success: false, errorMessage: message);
}

class LoginResult {
  final bool success;
  final bool isDeviceLocked;
  final String? code;
  final String? name;
  final String? errorMessage;

  LoginResult._({required this.success, this.isDeviceLocked = false, this.code, this.name, this.errorMessage});
  factory LoginResult.success(String code, String name) =>
      LoginResult._(success: true, code: code, name: name);
  factory LoginResult.deviceLocked() =>
      LoginResult._(success: false, isDeviceLocked: true);
  factory LoginResult.error(String message) =>
      LoginResult._(success: false, errorMessage: message);
}

class PinVerifyResult {
  final bool success;
  final bool isLocked;
  final DateTime? lockedUntil;
  final int attemptsRemaining;
  final String? error;
  const PinVerifyResult({
    required this.success,
    this.isLocked = false,
    this.lockedUntil,
    this.attemptsRemaining = 5,
    this.error,
  });
}