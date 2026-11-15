import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import '../models/world.dart';

class SandboxPull {
  final List<WorldEntry> worlds;
  final List<CharacterEntry> characters;
  const SandboxPull({required this.worlds, required this.characters});
}

class SandboxSync {
  static final _db = FirebaseFirestore.instance;
  static final _auth = AuthService();

  static Timer? _worldsDebounce;
  static Timer? _charsDebounce;
  static List<WorldEntry>? _pendingWorlds;
  static List<CharacterEntry>? _pendingChars;

  static void pushWorlds(List<WorldEntry> worlds) {
    _pendingWorlds = worlds;
    _worldsDebounce?.cancel();
    _worldsDebounce = Timer(const Duration(seconds: 1), _flushWorlds);
  }

  static void pushCharacters(List<CharacterEntry> chars) {
    _pendingChars = chars;
    _charsDebounce?.cancel();
    _charsDebounce = Timer(const Duration(seconds: 1), _flushChars);
  }

  static Future<void> flush() async {
    _worldsDebounce?.cancel();
    _charsDebounce?.cancel();
    await _flushWorlds();
    await _flushChars();
  }

  static Future<void> _flushWorlds() async {
    final worlds = _pendingWorlds;
    if (worlds == null) return;
    final code = _auth.currentCode;
    // No code yet — keep pending, it will flush on next push/flush.
    if (code == null) return;
    try {
      // set(merge) not update(): update() throws if the user doc
      // doesn't exist yet, which drops a new user's first save.
      await _db.collection('users').doc(code).set({
        'sandboxWorlds': jsonEncode(worlds.map((w) => w.toJson()).toList()),
        'sandboxUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Only clear pending on success — a failed write keeps its data
      // for the next push/flush instead of vanishing.
      if (identical(_pendingWorlds, worlds)) _pendingWorlds = null;
    } catch (e) {
      print('[SandboxSync] worlds push failed: $e');
    }
  }

  static Future<void> _flushChars() async {
    final chars = _pendingChars;
    if (chars == null) return;
    final code = _auth.currentCode;
    if (code == null) return;
    try {
      await _db.collection('users').doc(code).set({
        'sandboxCharacters': jsonEncode(chars.map((c) => c.toJson()).toList()),
        'sandboxUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (identical(_pendingChars, chars)) _pendingChars = null;
    } catch (e) {
      print('[SandboxSync] characters push failed: $e');
    }
  }

  static Future<void> syncOnLogin() async {
    final pull = await SandboxSync.pull();
    // pull == null means "no usable cloud data OR the pull failed"
    // (no doc, no network, parse error). In ALL of those cases the
    // safe move is keep local data — never wipe it.
    if (pull == null) return;
    await SandboxStorage.saveWorlds(pull.worlds);
    await SandboxStorage.saveCharacters(pull.characters);
  }

  static Future<SandboxPull?> pull() async {
    final code = _auth.currentCode;
    if (code == null) return null;
    try {
      final doc = await _db.collection('users').doc(code).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      final worldsRaw = data['sandboxWorlds'] as String?;
      final charsRaw = data['sandboxCharacters'] as String?;
      if (worldsRaw == null && charsRaw == null) return null;

      final worlds = <WorldEntry>[];
      final chars = <CharacterEntry>[];

      if (worldsRaw != null) {
        try {
          final list = jsonDecode(worldsRaw) as List;
          for (final e in list) {
            worlds.add(
              WorldEntry.fromJson(Map<String, dynamic>.from(e as Map)),
            );
          }
        } catch (e) {
          print('[SandboxSync] worlds parse failed: $e');
          // Corrupt on one side => treat the whole pull as unusable,
          // so syncOnLogin keeps local data instead of overwriting
          // one side with empty.
          return null;
        }
      }
      if (charsRaw != null) {
        try {
          final list = jsonDecode(charsRaw) as List;
          for (final e in list) {
            chars.add(
              CharacterEntry.fromJson(Map<String, dynamic>.from(e as Map)),
            );
          }
        } catch (e) {
          print('[SandboxSync] characters parse failed: $e');
          return null;
        }
      }

      return SandboxPull(worlds: worlds, characters: chars);
    } catch (e) {
      print('[SandboxSync] pull failed: $e');
      return null;
    }
  }
}