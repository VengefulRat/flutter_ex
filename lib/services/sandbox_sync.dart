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
    _pendingWorlds = null;
    final code = _auth.currentCode;
    if (code == null) return;
    try {
      await _db.collection('users').doc(code).update({
        'sandboxWorlds': jsonEncode(worlds.map((w) => w.toJson()).toList()),
        'sandboxUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[SandboxSync] worlds push failed: $e');
    }
  }

  static Future<void> _flushChars() async {
    final chars = _pendingChars;
    if (chars == null) return;
    _pendingChars = null;
    final code = _auth.currentCode;
    if (code == null) return;
    try {
      await _db.collection('users').doc(code).update({
        'sandboxCharacters': jsonEncode(chars.map((c) => c.toJson()).toList()),
        'sandboxUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[SandboxSync] characters push failed: $e');
    }
  }

  static Future<void> syncOnLogin() async {
    final pull = await SandboxSync.pull();
    if (pull == null) {
      await SandboxStorage.saveWorlds(<WorldEntry>[]);
      await SandboxStorage.saveCharacters(<CharacterEntry>[]);
      return;
    }
    await SandboxStorage.saveWorlds(pull.worlds);
    await SandboxStorage.saveCharacters(pull.characters); // <-- uses pull.characters, which is correct
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
        }
      }

      return SandboxPull(worlds: worlds, characters: chars);
    } catch (e) {
      print('[SandboxSync] pull failed: $e');
      return null;
    }
  }
}
