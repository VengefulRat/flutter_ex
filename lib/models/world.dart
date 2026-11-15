import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Small parsing helpers ──
// Old / corrupt data must never take down a whole load. Each helper
// returns a safe default instead of throwing.
String _parseId(dynamic v) => v is String ? v : '';

DateTime _parseCreatedAt(dynamic v) {
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  if (v is String) {
    final asInt = int.tryParse(v);
    if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
    return DateTime.tryParse(v) ?? DateTime.now();
  }
  return DateTime.now();
}

Color _parseColor(dynamic v, Color fallback) {
  if (v is int) return Color(v);
  if (v is String) {
    final asInt = int.tryParse(v);
    if (asInt != null) return Color(asInt);
  }
  return fallback;
}

// ─────────────────────────────────────────
// SANDBOX STORAGE  (shared_preferences)
// ─────────────────────────────────────────
class SandboxStorage {
  static const _worldsKey = 'sandbox_worlds';
  static const _charsKey  = 'sandbox_characters';

  static Future<List<WorldEntry>> loadWorlds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_worldsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      // Skip corrupt entries instead of dropping the whole list.
      final out = <WorldEntry>[];
      for (final e in list) {
        try {
          out.add(WorldEntry.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // One bad world must not wipe the rest.
        }
      }
      return out;
    } catch (_) { return []; }
  }

  static Future<void> saveWorlds(List<WorldEntry> worlds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_worldsKey, jsonEncode(worlds.map((w) => w.toJson()).toList()));
  }

  static Future<List<CharacterEntry>> loadCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_charsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final out = <CharacterEntry>[];
      for (final e in list) {
        try {
          out.add(CharacterEntry.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // One bad character must not wipe the rest.
        }
      }
      return out;
    } catch (_) { return []; }
  }

  static Future<void> saveCharacters(List<CharacterEntry> chars) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_charsKey, jsonEncode(chars.map((c) => c.toJson()).toList()));
  }

  /// Wipes the local sandbox. Called on sign-out so the next account
  /// on this device starts empty. Cloud has the backup.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_worldsKey);
    await prefs.remove(_charsKey);
  }
}

// ── WORLD ──
class WorldEntry {
  final String id;
  String name;
  String genre;
  String overview;
  String tone;
  final List<WorldLocation> locations;
  final List<WorldFaction> factions;
  String history;
  String rules; // laws of physics, magic system, etc.
  String notes;
  final DateTime createdAt;
  bool isDraft;
  String? mapUrl;

  WorldEntry({
    required this.id,
    required this.name,
    this.genre = '',
    this.overview = '',
    this.tone = '',
    List<WorldLocation>? locations,
    List<WorldFaction>? factions,
    this.history = '',
    this.rules = '',
    this.notes = '',
    DateTime? createdAt,
    this.isDraft = true,
    this.mapUrl,
  })  : locations = locations ?? [],
        factions = factions ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'genre': genre, 'overview': overview,
    'tone': tone, 'history': history, 'rules': rules, 'notes': notes,
    'isDraft': isDraft,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'mapUrl': mapUrl,
    'locations': locations.map((l) => {'name': l.name, 'description': l.description}).toList(),
    'factions': factions.map((f) => {'name': f.name, 'description': f.description}).toList(),
  };

  factory WorldEntry.fromJson(Map<String, dynamic> j) => WorldEntry(
    id: _parseId(j['id']),
    name: j['name'] as String? ?? '',
    genre: j['genre'] as String? ?? '',
    overview: j['overview'] as String? ?? '',
    tone: j['tone'] as String? ?? '',
    history: j['history'] as String? ?? '',
    rules: j['rules'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    mapUrl: j['mapUrl'] as String?,
    isDraft: j['isDraft'] as bool? ?? true,
    createdAt: _parseCreatedAt(j['createdAt']),
    locations: (j['locations'] as List? ?? []).map((l) {
      final m = l is Map<String, dynamic> ? l : <String, dynamic>{};
      return WorldLocation(
        name: m['name'] as String? ?? '',
        description: m['description'] as String? ?? '',
      );
    }).toList(),
    factions: (j['factions'] as List? ?? []).map((f) {
      final m = f is Map<String, dynamic> ? f : <String, dynamic>{};
      return WorldFaction(
        name: m['name'] as String? ?? '',
        description: m['description'] as String? ?? '',
      );
    }).toList(),
  );
}

class WorldLocation {
  String name;
  String description;
  WorldLocation({required this.name, this.description = ''});
}

class WorldFaction {
  String name;
  String description;
  WorldFaction({required this.name, this.description = ''});
}

// ── CHARACTER ──
enum CharacterType { playerCharacter, npc }

class CharacterEntry {
  final String id;
  String name;
  String pronouns;
  String age;
  String appearance;
  String personality;
  String backstory;
  String relationships;
  String notes;
  CharacterType type;
  String? linkedWorldId;
  final DateTime createdAt;
  Color accentColor;
  String? avatarUrl; // <--- Added

  CharacterEntry({
    required this.id,
    required this.name,
    this.pronouns = '',
    this.age = '',
    this.appearance = '',
    this.personality = '',
    this.backstory = '',
    this.relationships = '',
    this.notes = '',
    this.type = CharacterType.playerCharacter,
    this.linkedWorldId,
    DateTime? createdAt,
    Color? accentColor,
    this.avatarUrl, // <--- Added
  })  : createdAt = createdAt ?? DateTime.now(),
        accentColor = accentColor ?? const Color(0xFFC9A96E);

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'pronouns': pronouns, 'age': age,
    'appearance': appearance, 'personality': personality,
    'backstory': backstory, 'relationships': relationships, 'notes': notes,
    'type': type.index,
    'linkedWorldId': linkedWorldId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'accentColor': accentColor.toARGB32(),
    'avatarUrl': avatarUrl, // <--- Added
  };

  factory CharacterEntry.fromJson(Map<String, dynamic> j) {
    final typeIndex = j['type'] is int ? j['type'] as int : 0;
    final safeTypeIndex = typeIndex.clamp(0, CharacterType.values.length - 1);
    return CharacterEntry(
      id: _parseId(j['id']),
      name: j['name'] as String? ?? '',
      pronouns: j['pronouns'] as String? ?? '',
      age: j['age'] as String? ?? '',
      appearance: j['appearance'] as String? ?? '',
      backstory: j['backstory'] as String? ?? '',
      relationships: j['relationships'] as String? ?? '',
      notes: j['notes'] as String? ?? '',
      personality: j['personality'] as String? ?? '',
      type: CharacterType.values[safeTypeIndex],
      linkedWorldId: j['linkedWorldId'] as String?,
      createdAt: _parseCreatedAt(j['createdAt']),
      accentColor: _parseColor(j['accentColor'], const Color(0xFFC9A96E)),
      avatarUrl: j['avatarUrl'] as String?, // <--- Added
    );
  }
}

// ── STAT BLOCK ──
enum StatBarStyle { stripe, cuts, blocks }

class StatBlock {
  String name; // e.g. "D&D Style" or "Custom"
  final List<StatEntry> stats;
  /// true → classic tile grid (D&D). false → horizontal bar stack.
  final bool useTiles;
  StatBlock({
    required this.name,
    List<StatEntry>? stats,
    this.useTiles = false,
  }) : stats = stats ?? [];

  /// The largest ceiling across all stats. Pools use their maxValue,
  /// plain stats use their value. Bars are scaled against this.
  int get maxDisplayValue {
    if (stats.isEmpty) return 1;
    int m = 1;
    for (final s in stats) {
      final v = s.isPool ? (s.maxValue > s.value ? s.maxValue : s.value) : s.value;
      if (v > m) m = v;
    }
    return m;
  }

  static StatBlock dndPreset() => StatBlock(
    name: 'D&D Style',
    useTiles: true,
    stats: [
      StatEntry(name: 'Strength',     value: 10),
      StatEntry(name: 'Dexterity',    value: 10),
      StatEntry(name: 'Constitution', value: 10),
      StatEntry(name: 'Intelligence', value: 10),
      StatEntry(name: 'Wisdom',       value: 10),
      StatEntry(name: 'Charisma',     value: 10),
      StatEntry(name: 'HP',           value: 20, isPool: true, maxValue: 20),
      StatEntry(name: 'AC',           value: 10),
    ],
  );

  static StatBlock customPreset() => StatBlock(
    name: 'Custom',
    useTiles: false,
    stats: [
      StatEntry(name: 'Health',  value: 1000, isPool: true, maxValue: 1000,
          barColor: const Color(0xFFD4614A)),
      StatEntry(name: 'Stamina', value: 200,  isPool: true, maxValue: 200,
          barColor: const Color(0xFF7AB8D4)),
      StatEntry(name: 'Hunger',  value: 50,   isPool: true, maxValue: 50,
          barColor: const Color(0xFFC9A96E)),
      StatEntry(name: 'Thirst',  value: 50,   isPool: true, maxValue: 50,
          barColor: const Color(0xFF7BAF7B)),
    ],
  );
}

class StatEntry {
  String name;
  int value;
  bool isPool; // shows current/max
  int maxValue;

  // ── Bar appearance (custom blocks only) ──
  Color barColor;
  StatBarStyle barStyle;
  int segments;

  StatEntry({
    required this.name,
    required this.value,
    this.isPool = false,
    this.maxValue = 0,
    Color? barColor,
    this.barStyle = StatBarStyle.stripe,
    this.segments = 10,
  })  : barColor = barColor ?? const Color(0xFFC9A96E);

  int get modifier => ((value - 10) / 2).floor(); // D&D style modifier

  /// The ceiling used for scaling the bar. Pools use maxValue; plain
  /// stats use their current value.
  int get ceiling => isPool ? (maxValue > value ? maxValue : value) : value;
}

// ── DICE ──
enum DiceType { d4, d6, d8, d10, d12, d20, d100 }

extension DiceTypeExt on DiceType {
  int get sides {
    switch (this) {
      case DiceType.d4:   return 4;
      case DiceType.d6:   return 6;
      case DiceType.d8:   return 8;
      case DiceType.d10:  return 10;
      case DiceType.d12:  return 12;
      case DiceType.d20:  return 20;
      case DiceType.d100: return 100;
    }
  }
  String get label {
    switch (this) {
      case DiceType.d4:   return 'd4';
      case DiceType.d6:   return 'd6';
      case DiceType.d8:   return 'd8';
      case DiceType.d10:  return 'd10';
      case DiceType.d12:  return 'd12';
      case DiceType.d20:  return 'd20';
      case DiceType.d100: return 'd100';
    }
  }
}

// ── RP NOTE ──
class RPNote {
  final String id;
  String content;
  String? tag; // e.g. "NPC", "Location", "Plot"
  final DateTime createdAt;
  bool isPinned;

  RPNote({
    required this.id,
    required this.content,
    this.tag,
    DateTime? createdAt,
    this.isPinned = false,
  }) : createdAt = createdAt ?? DateTime.now();
}

// ── SAMPLE DATA (empty — user creates their own) ──
final sampleWorlds = <WorldEntry>[];
final sampleCharacters = <CharacterEntry>[];