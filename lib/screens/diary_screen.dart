import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../widgets/colour_picker.dart';
import '../settings.dart';
import '../models/world.dart';
import 'sandbox_screen.dart';
import '../services/auth_service.dart';
import '../widgets/card_frame.dart';
import '../widgets/holo_card_v2.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Scales a base font size by the user's Settings text-size preference.
/// Medium (14pt, `appSettings.baseFontSize == 14.0`) is the reference.
/// Content surfaces only — mono chrome stays fixed so labels stay crisp.
double _dSize(double base) => base * (appSettings.baseFontSize / 14.0);


// ─────────────────────────────────────────
// NOTIFICATIONS SETUP
// ─────────────────────────────────────────
final _notifPlugin = FlutterLocalNotificationsPlugin();

Future<void> initDiaryNotifications() async {
  tz.initializeTimeZones();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  await _notifPlugin.initialize(settings);
}

Future<void> scheduleDiaryReminder(TimeOfDay time) async {
  await _notifPlugin.cancelAll();
  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute);
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  await _notifPlugin.zonedSchedule(
    0,
    'Time to write',
    'Your diary is waiting for you.',
    scheduled,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'diary_reminder',
        'Diary Reminder',
        channelDescription: 'Daily writing reminder',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

Future<void> cancelDiaryReminder() async {
  await _notifPlugin.cancelAll();
}

class DiaryStorage {
  static const _entriesKey = 'diary_entries';
  static const _reminderKey = 'diary_reminder_enabled';
  static const _reminderHourKey = 'diary_reminder_hour';
  static const _reminderMinKey = 'diary_reminder_min';
  static const _streakKey = 'diary_streak';
  static const _lastWrittenKey = 'diary_last_written';

  // ── Local ──
  static Future<List<DiaryEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final out = <DiaryEntry>[];
      for (final e in list) {
        try {
          out.add(DiaryEntry.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // One bad entry must not wipe the rest of the diary.
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveEntries(List<DiaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _entriesKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  static Future<bool> getReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reminderKey) ?? false;
  }

  static Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: (prefs.getInt(_reminderHourKey) ?? 20).clamp(0, 23),
      minute: (prefs.getInt(_reminderMinKey) ?? 0).clamp(0, 59),
    );
  }

  static Future<void> saveReminder(bool enabled, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderKey, enabled);
    await prefs.setInt(_reminderHourKey, time.hour);
    await prefs.setInt(_reminderMinKey, time.minute);
  }

  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  static Future<void> recordWrite() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final lastStr = prefs.getString(_lastWrittenKey);
    if (lastStr == todayStr) return; // already written today
    int streak = prefs.getInt(_streakKey) ?? 0;
    if (lastStr != null) {
      final last = DateTime.tryParse(lastStr);
      if (last == null) {
        streak = 1;
      } else {
        final diff = today.difference(last).inDays;
        streak = diff == 1 ? streak + 1 : 1;
      }
    } else {
      streak = 1;
    }
    await prefs.setInt(_streakKey, streak);
    await prefs.setString(_lastWrittenKey, todayStr);
  }

  // ── Firestore sync ──
  static Future<void> syncToFirestore(
      String userCode, List<DiaryEntry> entries) async {
    final db = FirebaseFirestore.instance;
    final collection =
        db.collection('users').doc(userCode).collection('diary');
    final existingDocs = await collection.get();
    final localIds = entries.map((e) => e.id).toSet();
    final batch = db.batch();
    for (final doc in existingDocs.docs) {
      if (!localIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (final e in entries) {
      final ref = collection.doc(e.id);
      batch.set(ref, e.toJson());
    }
    await batch.commit();
  }

  static Future<List<DiaryEntry>> loadFromFirestore(String userCode) async {
    final db = FirebaseFirestore.instance;
    final snap = await db
        .collection('users')
        .doc(userCode)
        .collection('diary')
        .get();
    final out = <DiaryEntry>[];
    for (final d in snap.docs) {
      try {
        out.add(DiaryEntry.fromJson(d.data()));
      } catch (_) {
        // One bad remote doc must not wipe the rest.
      }
    }
    return out;
  }
}

// ─────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────
enum DiaryMode { chapters, book }

class DiaryEntry {
  final String id;
  String title;
  String genre;
  int wordsPerChapter;
  int chapterCount;
  DiaryMode mode;
  List<DiaryChapter> chapters;
  List<String> linkedCharacterIds;
  List<String> linkedWorldIds;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isFolder;
  String? parentId;
  Color accentColor;
  String? coverImageUrl;

  DiaryEntry({
    required this.id,
    this.title = '',
    this.genre = '',
    this.wordsPerChapter = 500,
    this.chapterCount = 1,
    this.mode = DiaryMode.chapters,
    List<DiaryChapter>? chapters,
    List<String>? linkedCharacterIds,
    List<String>? linkedWorldIds,
    Color? accentColor,
    this.coverImageUrl,
    this.isFolder = false,
    this.parentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : chapters = chapters ?? [],
        linkedCharacterIds = linkedCharacterIds ?? [],
        linkedWorldIds = linkedWorldIds ?? [],
        accentColor = accentColor ?? const Color(0xFFC9A96E),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayTitle {
    if (title.isNotEmpty) return title;
    for (final ch in chapters) {
      if (ch.plainText.isNotEmpty) {
        final words = ch.plainText.trim().split(RegExp(r'\s+'));
        return words.take(4).join(' ');
      }
    }
    return 'Untitled entry';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'genre': genre,
        'wordsPerChapter': wordsPerChapter,
        'chapterCount': chapterCount,
        'mode': mode.name,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'linkedCharacterIds': linkedCharacterIds,
        'linkedWorldIds': linkedWorldIds,
        'isFolder': isFolder,
        'parentId': parentId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'accentColor': accentColor.toARGB32(),
        'coverImageUrl': coverImageUrl,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: j['id'] is String ? j['id'] as String : '',
        title: j['title'] as String? ?? '',
        genre: j['genre'] as String? ?? '',
        wordsPerChapter: j['wordsPerChapter'] is int
            ? j['wordsPerChapter'] as int
            : 500,
        chapterCount:
            j['chapterCount'] is int ? j['chapterCount'] as int : 1,
        mode: DiaryMode.values.firstWhere(
          (m) => m.name == j['mode'],
          orElse: () => DiaryMode.chapters,
        ),
        chapters: (j['chapters'] as List? ?? []).map((c) {
          try {
            return DiaryChapter.fromJson(c as Map<String, dynamic>);
          } catch (_) {
            return DiaryChapter(
              id: const Uuid().v4(),
              title: 'Recovered chapter',
            );
          }
        }).toList(),
        linkedCharacterIds: (j['linkedCharacterIds'] as List? ?? [])
            .whereType<String>()
            .toList(),
        linkedWorldIds: (j['linkedWorldIds'] as List? ?? [])
            .whereType<String>()
            .toList(),
        isFolder: j['isFolder'] as bool? ?? false,
        parentId: j['parentId'] as String?,
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ??
                DateTime.now(),
        updatedAt:
            DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
                DateTime.now(),
        accentColor:
            j['accentColor'] is int ? Color(j['accentColor'] as int) : null,
        coverImageUrl: j['coverImageUrl'] as String?,
      );
}

// ─────────────────────────────────────────
// DIARY STORAGE  (local + Firestore)
// ─────────────────────────────────────────
class DiaryChapter {
  final String id;
  String title;
  String deltaJson; // Quill Delta JSON
  String plainText; // for preview/word count

  DiaryChapter({
    required this.id,
    this.title = '',
    this.deltaJson = '',
    this.plainText = '',
  });

  int get wordCount {
    if (plainText.isEmpty) return 0;
    return plainText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'deltaJson': deltaJson,
    'plainText': plainText,
  };

  factory DiaryChapter.fromJson(Map<String, dynamic> j) => DiaryChapter(
    id: j['id'] is String ? j['id'] as String : const Uuid().v4(),
    title: j['title'] as String? ?? '',
    deltaJson: j['deltaJson'] as String? ?? '',
    plainText: j['plainText'] as String? ?? '',
  );
}

// ─────────────────────────────────────────
// DIARY SCREEN
// ─────────────────────────────────────────
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});
  @override State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<DiaryEntry> _entries = [];
  bool _loaded = false;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  int _streak = 0;
  final _auth = AuthService();
  String? _currentFolderId; 
  final List<CharacterEntry> _allChars = [];

    @override
  void initState() {
    super.initState();
    appSettings.addListener(_onSettingsChanged);
    _loadAll();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _loadAll() async {
    final local = await DiaryStorage.loadEntries();
    final reminderEnabled = await DiaryStorage.getReminderEnabled();
    final reminderTime = await DiaryStorage.getReminderTime();
    final streak = await DiaryStorage.getStreak(); 

    // Merge with Firestore
    final code = _auth.currentCode;
    List<DiaryEntry> merged = local;
    if (code != null) {
      try {
        final remote = await DiaryStorage.loadFromFirestore(code);
        // Merge: remote entries that aren't in local
        final localIds = local.map((e) => e.id).toSet();
        for (final r in remote) {
          if (!localIds.contains(r.id)) merged.add(r);
        }
        merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        await DiaryStorage.saveEntries(merged);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
      _entries = merged;
      _reminderEnabled = reminderEnabled;
      _reminderTime = reminderTime;
      _streak = streak;
      _loaded = true;
    });
    }
  }

  Future<void> _saveEntries() async {
    await DiaryStorage.saveEntries(_entries);
    final code = _auth.currentCode;
    if (code != null) {
      try {
        await DiaryStorage.syncToFirestore(code, _entries);
      } catch (e) {
        debugPrint('[Diary] syncToFirestore failed: $e');
      }
    }
  }

  Widget _dChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: active ? cGold : cAsh), color: active ? cGold.withValues(alpha: 0.08) : Colors.transparent),
        child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 9, letterSpacing: 1, color: active ? cGold : cSmoke)),
      ),
    );
  }
  Widget _dColorRow(String label, Color current, ValueChanged<Color> onPicked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: cMist, fontWeight: FontWeight.w300)),
        const Spacer(),
        GestureDetector(
          onTap: () => LoreColourPicker.show(context, current: current, onPicked: onPicked),
          child: Container(width: 28, height: 28, decoration: BoxDecoration(color: current, shape: BoxShape.circle, border: Border.all(color: Colors.white24))),
        ),
      ]),
    );
  }
  Widget _dToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: cMist, fontWeight: FontWeight.w300)),
        const Spacer(),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 36, height: 20, decoration: BoxDecoration(color: value ? cGold : cAsh, borderRadius: BorderRadius.circular(10)), child: Align(alignment: value ? Alignment.centerRight : Alignment.centerLeft, child: Container(width: 16, height: 16, margin: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))),
        ),
      ]),
    );
  }
  Widget _dSizeRow(String label, String current, ValueChanged<String> onPick) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: cMist, fontWeight: FontWeight.w300)),
        const Spacer(),
        _dChip('S', current == 'S', () => onPick('S')),
        const SizedBox(width: 6),
        _dChip('M', current == 'M', () => onPick('M')),
        const SizedBox(width: 6),
        _dChip('L', current == 'L', () => onPick('L')),
      ]),
    );
  }
  void _showDiaryCustomize() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void refresh() { setSheetState(() {}); }
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 32, height: 3, decoration: BoxDecoration(color: cAsh, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('DIARY CUSTOMIZE', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 4)),
                const SizedBox(height: 12),
                const Text('HEADER', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 3)),
                _dToggle('Show header', appSettings.diaryHeaderShow, (v) { appSettings.setDiaryHeaderShow(v); refresh(); }),
                if (appSettings.diaryHeaderShow) _dSizeRow('Header size', appSettings.diaryHeaderSize, (v) { appSettings.setDiaryHeaderSize(v); refresh(); }),
                const Text('BACKGROUND', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 3)),
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 6), child: Wrap(spacing: 6, children: [ _dChip('Global', appSettings.diaryBgMode == 'global', () { appSettings.setDiaryBgMode('global'); refresh(); }), _dChip('Fixed', appSettings.diaryBgMode == 'fixed', () { appSettings.setDiaryBgMode('fixed'); refresh(); }), ])),
                if (appSettings.diaryBgMode == 'fixed') _dColorRow('Background colour', appSettings.diaryBgColor, (c) { appSettings.setDiaryBgColor(c); refresh(); }),
                const Text('BOOKSHELF', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 3)),
                _dToggle('Show reminder bar', appSettings.diaryShowReminder, (v) { appSettings.setDiaryShowReminder(v); refresh(); }),
                _dToggle('Show streak', appSettings.diaryShowStreak, (v) { appSettings.setDiaryShowStreak(v); refresh(); }),
                _dSizeRow('Card size', appSettings.diaryCardSize, (v) { appSettings.setDiaryCardSize(v); refresh(); }),
                _dToggle('Show author on cards', appSettings.diaryShowAuthor, (v) { appSettings.setDiaryShowAuthor(v); refresh(); }),
                _dToggle('Show stats on cards', appSettings.diaryShowStats, (v) { appSettings.setDiaryShowStats(v); refresh(); }),
                _dToggle('Show character avatars', appSettings.diaryShowAvatars, (v) { appSettings.setDiaryShowAvatars(v); refresh(); }),
                const Text('INSIDE A BOOK', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 3)),
                _dToggle('Show entry header', appSettings.diaryEntryHeaderShow, (v) { appSettings.setDiaryEntryHeaderShow(v); refresh(); }),
                if (appSettings.diaryEntryHeaderShow) _dSizeRow('Entry header size', appSettings.diaryEntryHeaderSize, (v) { appSettings.setDiaryEntryHeaderSize(v); refresh(); }),
                _dToggle('Show genre + stats bar', appSettings.diaryShowGenreBar, (v) { appSettings.setDiaryShowGenreBar(v); refresh(); }),
                _dSizeRow('Chapter card size', appSettings.diaryChapterSize, (v) { appSettings.setDiaryChapterSize(v); refresh(); }),
                _dToggle('Show chapter preview', appSettings.diaryShowPreview, (v) { appSettings.setDiaryShowPreview(v); refresh(); }),
                _dToggle('Show progress bar', appSettings.diaryShowProgress, (v) { appSettings.setDiaryShowProgress(v); refresh(); }),
                _dSizeRow('Reading size', appSettings.diaryReadingSize, (v) { appSettings.setDiaryReadingSize(v); refresh(); }),
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 6), child: Row(children: [ const Text('Line height', style: TextStyle(fontSize: 12, color: cMist, fontWeight: FontWeight.w300)), const Spacer(), _dChip('Compact', appSettings.diaryLineHeight == 'compact', () { appSettings.setDiaryLineHeight('compact'); refresh(); }), const SizedBox(width: 6), _dChip('Comfortable', appSettings.diaryLineHeight == 'comfortable', () { appSettings.setDiaryLineHeight('comfortable'); refresh(); }), const SizedBox(width: 6), _dChip('Spacious', appSettings.diaryLineHeight == 'spacious', () { appSettings.setDiaryLineHeight('spacious'); refresh(); }), ])),
                const Text('EDITOR', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 3)),
                _dToggle('Show toolbar', appSettings.diaryShowToolbar, (v) { appSettings.setDiaryShowToolbar(v); refresh(); }),
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 6), child: Row(children: [ const Text('Editor padding', style: TextStyle(fontSize: 12, color: cMist, fontWeight: FontWeight.w300)), const Spacer(), _dChip('Compact', appSettings.diaryEditorPadding == 'compact', () { appSettings.setDiaryEditorPadding('compact'); refresh(); }), const SizedBox(width: 6), _dChip('Comfortable', appSettings.diaryEditorPadding == 'comfortable', () { appSettings.setDiaryEditorPadding('comfortable'); refresh(); }), ])),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _deleteEntry(String id) {
    if (!mounted) return;
    setState(() => _entries.removeWhere((e) => e.id == id));
    _saveEntries();
  }

  Future<void> _toggleReminder(bool v) async {
    setState(() => _reminderEnabled = v);
    await DiaryStorage.saveReminder(v, _reminderTime);
    if (v) {
      await scheduleDiaryReminder(_reminderTime);
    } else {
      await cancelDiaryReminder();
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: cGold, surface: cInk), 
          dialogTheme: const DialogThemeData(backgroundColor: cInk),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() => _reminderTime = picked);
      await DiaryStorage.saveReminder(_reminderEnabled, picked);
      if (_reminderEnabled) await scheduleDiaryReminder(picked);
    }
  }


  void _openEntry(DiaryEntry entry) {
    Navigator.of(context).push(fadeRoute(_EntryScreen(
      entry: entry,
      onSave: (updated) {
        setState(() {
          final i = _entries.indexWhere((e) => e.id == updated.id);
          if (i != -1) {
            _entries[i] = updated;
          } else {
            _entries.insert(0, updated);
          }
          _entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        });
        _saveEntries();
        DiaryStorage.recordWrite().then((_) async {
          final s = await DiaryStorage.getStreak();
          if (mounted) setState(() => _streak = s);
        });
      },
    )));
  }

      void _newEntry() async {
    // 1. Wait for the wizard to finish and return a DiaryEntry
    // We use PageRouteBuilder directly to guarantee the type is <DiaryEntry>
    final newEntry = await Navigator.of(context).push<DiaryEntry>(
      PageRouteBuilder<DiaryEntry>(
        pageBuilder: (context, animation, secondaryAnimation) => const _NewEntrySetup(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (newEntry == null) return; // User backed out of the wizard

    // 2. Duplicate Check
    final cleanNewTitle = newEntry.title.trim().toLowerCase();
    if (cleanNewTitle.isNotEmpty) {
      final isDuplicate = _entries.any((e) => 
        e.parentId == _currentFolderId && 
        e.title.trim().toLowerCase() == cleanNewTitle
      );
      
      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: cEmber,
            duration: Duration(seconds: 4),
            content: Text(
              'A book with this title already exists here!', 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ));
        }
        return; // 🛑 Stop here
      }
    }

    // 3. Save and Open
    if (!mounted) return;
    setState(() => _entries.insert(0, newEntry));
    _saveEntries();
    _openEntry(newEntry);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appSettings.diaryBgMode == 'fixed' ? appSettings.diaryBgColor : appSettings.bgColor,
    body: SafeArea(child: Column(children: [
      // Top bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: cAsh))),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios, color: cSmoke, size: 16),
          ),
          const SizedBox(width: 12),
          if (appSettings.diaryHeaderShow) Text('Diary', style: TextStyle(fontSize: appSettings.diaryHeaderSize == 'S' ? 16 : appSettings.diaryHeaderSize == 'L' ? 24 : 20,
              fontWeight: FontWeight.w300, fontStyle: FontStyle.italic,
              color: cParchment)),
          const Spacer(),
          // Streak
          if (_streak > 0 && appSettings.diaryShowStreak) Row(children: [
            const Icon(Icons.local_fire_department,
                size: 14, color: cEmber),
            const SizedBox(width: 4),
            Text('$_streak', style: const TextStyle(
                fontFamily: 'monospace', fontSize: 11,
                color: cEmber, letterSpacing: 1)),
            const SizedBox(width: 12),
          ]),
          GestureDetector(onTap: _showDiaryCustomize, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.tune, size: 18, color: cSmoke))),
          const SizedBox(width: 6),
          if (appSettings.diaryHeaderShow) const Text('L o r e', style: TextStyle(fontSize: 11,
              color: cGold, letterSpacing: 5, fontWeight: FontWeight.w300)),
        ]),
      ),

      // Reminder bar
      if (appSettings.diaryShowReminder) Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: cAsh))),
        child: Row(children: [
          const Icon(Icons.notifications_outlined, size: 14, color: cSmoke),
          const SizedBox(width: 10),
          const Text('Daily reminder', style: TextStyle(
              fontSize: 12, color: cSmoke, fontWeight: FontWeight.w300)),
          const Spacer(),
          if (_reminderEnabled)
            GestureDetector(
              onTap: _pickReminderTime,
              child: Text(
                _reminderTime.format(context),
                style: const TextStyle(fontFamily: 'monospace',
                    fontSize: 11, color: cGold, letterSpacing: 1),
              ),
            ),
          const SizedBox(width: 10),
          Switch(
            value: _reminderEnabled,
            onChanged: _toggleReminder,
            activeThumbColor: cGold,
            inactiveTrackColor: cAsh,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),

      // Entries list
            // Entries list
            Expanded(
        child: !_loaded
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5, color: cSmoke)))
            : _entries.where((e) => e.parentId == _currentFolderId).isEmpty
                ? _emptyState()
                : MediaQuery.sizeOf(context).width >= 900
                    ? ScrollConfiguration(
                        behavior: NoGlowBehavior(),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(24),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220, // Approx width of the diary card
                            childAspectRatio: 0.45, // Height ratio
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          itemCount: _entries.where((e) => e.parentId == _currentFolderId).length,
                          itemBuilder: (context, index) {
                            final filtered = _entries.where((e) => e.parentId == _currentFolderId).toList();
                            final e = filtered[index];
                            final linkedChars = _allChars.where((c) => e.linkedCharacterIds.contains(c.id)).toList();
                            
                            return _DiaryCard(
                              entry: e,
                              linkedChars: linkedChars,
                              onTap: () {
                                if (e.isFolder) {
                                  setState(() => _currentFolderId = e.id);
                                } else {
                                  _openEntry(e);
                                }
                              },
                              onDelete: () => _deleteEntry(e.id),
                            );
                          },
                        ),
                      )
                    : ScrollConfiguration(
                        behavior: NoGlowBehavior(),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                          children: [
                            // Back Button if we are inside a folder
                            if (_currentFolderId != null)
                              GestureDetector(
                                onTap: () => setState(() => _currentFolderId = null),
                                child: Container(
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 16),
                                  decoration: BoxDecoration(
                                    color: cInk,
                                    border: Border.all(color: cAsh),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_back, color: cGold, size: 24),
                                      SizedBox(height: 8),
                                      Text('BACK', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 2)),
                                    ],
                                  ),
                                ),
                              ),
                              
                            // The Cards
                            ..._entries
                                .where((e) => e.parentId == _currentFolderId)
                                .map((e) {
                                  final linkedChars = _allChars.where((c) => e.linkedCharacterIds.contains(c.id)).toList();
                                  return _DiaryCard(
                                    entry: e,
                                    linkedChars: linkedChars,
                                    onTap: () {
                                      if (e.isFolder) {
                                        setState(() => _currentFolderId = e.id);
                                      } else {
                                        _openEntry(e);
                                      }
                                    },
                                    onDelete: () => _deleteEntry(e.id),
                                  );
                                }),
                          ],
                        ),
                      ),
      ),

      // New Entry button
      GestureDetector(
        onTap: _newEntry,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              border: Border.all(color: cGold.withValues(alpha: 0.5))),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add, size: 16, color: cGold),
            SizedBox(width: 10),
            Text('Start a New Entry', style: TextStyle(
                fontFamily: 'monospace', fontSize: 11,
                color: cGold, letterSpacing: 2)),
          ]),
        ),
      ),
    ])),
  );

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min,
      children: [
    const Text('Nothing written yet.',
        style: TextStyle(fontSize: 16, color: cMist,
            fontStyle: FontStyle.italic, fontWeight: FontWeight.w300)),
    const SizedBox(height: 8),
    const Text('Tap below to start your first entry.',
        style: TextStyle(fontSize: 12, color: cSmoke)),
  ]));
}

// ─────────────────────────────────────────
// ENTRY CARD
// ─────────────────────────────────────────
class _DiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  final List<CharacterEntry> linkedChars;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DiaryCard({
    required this.entry,
    required this.linkedChars,
    required this.onTap,
    required this.onDelete,
  });

    @override
  Widget build(BuildContext context) {
    final seed = entry.id.hashCode;
    final accent = entry.accentColor;
    
    // Get your profile name for the "Author" field
    final authorName = AuthService().currentName ?? 'Unknown Author';
    
    // Calculate total words across all chapters
    final totalWords = entry.chapters.fold<int>(0, (total, ch) => total + ch.wordCount);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: HoloCardV2(
          accent: accent,
          intensity: 0.4,
          seed: seed,
          bgColor: cInk,
          child: Container(
            width: appSettings.diaryCardSize == 'S' ? 160 : appSettings.diaryCardSize == 'L' ? 240 : 200,
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: CardFrame(
                spec: CardFrameSpec(seed: seed, accent: accent, ornate: true, glow: false),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background Image or Gradient
                      if (entry.coverImageUrl != null && entry.coverImageUrl!.isNotEmpty)
                        Image.network(entry.coverImageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())
                      else if (entry.isFolder && linkedChars.isNotEmpty && linkedChars.first.avatarUrl != null)
                        Image.network(linkedChars.first.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [cInk, accent.withValues(alpha: 0.2)],
                            ),
                          ),
                        ),

                      // Dark Scrim for Readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4), // Slight tint at top
                              Colors.black.withValues(alpha: 0.85), // Darker in middle
                              Colors.black.withValues(alpha: 0.95), // Almost solid at bottom
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),

                      // Top Badge (Folder vs Book)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            border: Border.all(color: accent.withValues(alpha: 0.5)),
                          ),
                          child: Icon(
                            entry.isFolder ? Icons.folder_outlined : Icons.menu_book_outlined,
                            size: 12, color: accent,
                          ),
                        ),
                      ),

                      // Book Cover Text Layout
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author Name (like a book spine/cover)
                            if (appSettings.diaryShowAuthor) Text(
                              authorName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 7,
                                color: accent.withValues(alpha: 0.8),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            
                            // Book Title
                              Text(
                              entry.displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: _dSize(appSettings.diaryCardSize == 'S' ? 15 : appSettings.diaryCardSize == 'L' ? 21 : 18),
                                fontWeight: FontWeight.w300,
                                fontStyle: FontStyle.italic,
                                color: cParchment,
                                height: 1.1,
                              ),
                            ),
                            
                            const SizedBox(height: 6),
                            
                            // Stats Row (Chapters & Words)
                            if (appSettings.diaryShowStats) Row(
                              children: [
                                if (entry.isFolder)
                                  Text(
                                    '${entry.chapters.length} entries',
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: cSmoke),
                                  )
                                else ...[
                                  Text(
                                    '${entry.chapters.length} CH',
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: cSmoke),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Text('·', style: TextStyle(fontSize: 8, color: cSmoke)),
                                  ),
                                  Text(
                                    '${(totalWords / 1000).toStringAsFixed(1)}K WORDS',
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: cSmoke),
                                  ),
                                ],
                              ],
                            ),

                            // Character Avatar Chips
                            if (linkedChars.isNotEmpty && appSettings.diaryShowAvatars) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 20,
                                child: Stack(
                                  children: linkedChars.take(3).toList().asMap().entries.map((mapEntry) {
                                    final i = mapEntry.key;
                                    final c = mapEntry.value;
                                    return Positioned(
                                      left: i * 14.0,
                                      child: Container(
                                        width: 20, height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: cInk, width: 1.5),
                                          image: c.avatarUrl != null 
                                              ? DecorationImage(image: NetworkImage(c.avatarUrl!), fit: BoxFit.cover)
                                              : null,
                                          color: c.avatarUrl == null ? c.accentColor : null,
                                        ),
                                        child: c.avatarUrl == null 
                                            ? Center(child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 10, color: cVoid)))
                                            : null,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) => showModalBottomSheet(
    context: context,
    backgroundColor: cInk,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 32, height: 3, decoration: BoxDecoration(color: cAsh, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          _sheetAction(context, Icons.edit_outlined, 'Open', onTap),
          _sheetAction(context, Icons.delete_outline, 'Delete', onDelete, color: cEmber),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────
// NEW ENTRY SETUP
// ─────────────────────────────────────────
class _NewEntrySetup extends StatefulWidget {
  const _NewEntrySetup();
  @override State<_NewEntrySetup> createState() => _NewEntrySetupState();
}

class _NewEntrySetupState extends State<_NewEntrySetup> {
  int _step = 0; // 0=genre, 1=structure, 2=characters/worlds, 3=review

  String _genre = '';
  int _wordsPerChapter = 500;
  int _chapterCount = 1;
  DiaryMode _mode = DiaryMode.chapters;
  List<CharacterEntry> _allChars = [];
  List<WorldEntry> _allWorlds = [];
  final List<String> _selectedCharIds = [];
  final List<String> _selectedWorldIds = [];

  final _genreCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  static const _genres = [
    'Fantasy', 'Sci-Fi', 'Horror', 'Romance', 'Mystery',
    'Thriller', 'Historical', 'Literary', 'Journal', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadSandbox();
  }

  Future<void> _loadSandbox() async {
    final chars = await SandboxStorage.loadCharacters();
    final worlds = await SandboxStorage.loadWorlds();
    if (mounted) setState(() { _allChars = chars; _allWorlds = worlds; });
  }

  @override
  void dispose() {
    _genreCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

    void _start() {
    final entry = DiaryEntry(
      id: const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      genre: _genre.isEmpty ? _genreCtrl.text.trim() : _genre,
      wordsPerChapter: _wordsPerChapter,
      chapterCount: _chapterCount,
      mode: _mode,
      chapters: List.generate(_chapterCount, (i) => DiaryChapter(
        id: const Uuid().v4(),
        title: 'Chapter ${i + 1}',
      )),
      linkedCharacterIds: _selectedCharIds,
      linkedWorldIds: _selectedWorldIds,
    );
    Navigator.of(context).pop(entry); // Return the entry!
  }

  void _skip() {
    final entry = DiaryEntry(
      id: const Uuid().v4(),
      chapters: [DiaryChapter(id: const Uuid().v4(), title: 'Chapter 1')],
    );
    Navigator.of(context).pop(entry); // Return the entry!
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appSettings.diaryBgMode == 'fixed' ? appSettings.diaryBgColor : appSettings.bgColor,
    body: SafeArea(child: Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: cAsh))),
        child: Row(children: [
          GestureDetector(
            onTap: () => _step > 0
                ? setState(() => _step--)
                : Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios, color: cSmoke, size: 16),
          ),
          const SizedBox(width: 12),
          const Text('New Entry', style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.w300, fontStyle: FontStyle.italic,
              color: cParchment)),
          const Spacer(),
          GestureDetector(
            onTap: _skip,
            child: const Text('Skip', style: TextStyle(
                fontFamily: 'monospace', fontSize: 10,
                color: cSmoke, letterSpacing: 2)),
          ),
        ]),
      ),

      // Step indicator
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) => Container(
              width: i == _step ? 24 : 8, height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                  color: i == _step ? cGold : cAsh,
                  borderRadius: BorderRadius.circular(2)),
            ))),
      ),

      Expanded(child: ScrollConfiguration(
        behavior: NoGlowBehavior(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: [
            _buildStep0(),
            _buildStep1(),
            _buildStep2(),
          ][_step],
        ),
      )),

      // Next / Start button
      Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () {
            if (_step < 2) {
              setState(() => _step++);
            } else {
              _start();
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: cParchment,
            child: Text(_step < 2 ? 'Next' : 'Start Writing',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'monospace',
                    fontSize: 11, color: cVoid, letterSpacing: 2)),
          ),
        ),
      ),
    ])),
  );

  // ── Step 0: Genre + title ──
  Widget _buildStep0() => Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
    const Text('TITLE (OPTIONAL)', style: TextStyle(fontFamily: 'monospace',
        fontSize: 9, color: cGold, letterSpacing: 3)),
    const SizedBox(height: 8),
    TextField(
      controller: _titleCtrl,
      style: TextStyle(fontSize: appSettings.diaryReadingSize == 'S' ? appSettings.baseFontSize - 2 : appSettings.diaryReadingSize == 'L' ? appSettings.baseFontSize + 2 : appSettings.baseFontSize, color: cParchment,
          fontStyle: FontStyle.italic),
      decoration: const InputDecoration(
          hintText: 'Leave blank to auto-title from content...',
          hintStyle: TextStyle(color: cSmoke, fontSize: 13,
              fontStyle: FontStyle.italic),
          enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: cAsh)),
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: cSmoke)),
          filled: true, fillColor: cInk),
      cursorColor: cGold,
    ),
    const SizedBox(height: 24),
    const Text('GENRE', style: TextStyle(fontFamily: 'monospace',
        fontSize: 9, color: cGold, letterSpacing: 3)),
    const SizedBox(height: 12),
    Wrap(spacing: 8, runSpacing: 8, children: _genres.map((g) {
      final active = _genre == g;
      return GestureDetector(
        onTap: () => setState(() => _genre = active ? '' : g),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              border: Border.all(color: active ? cGold : cAsh),
              color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent),
          child: Text(g, style: TextStyle(fontFamily: 'monospace',
              fontSize: 10, letterSpacing: 1,
              color: active ? cGold : cSmoke)),
        ),
      );
    }).toList()),
    const SizedBox(height: 16),
    TextField(
      controller: _genreCtrl,
      style: const TextStyle(fontSize: 14, color: cParchment,
          fontStyle: FontStyle.italic),
      decoration: const InputDecoration(
          hintText: 'Or type your own...',
          hintStyle: TextStyle(color: cSmoke, fontSize: 13),
          enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: cAsh)),
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: cSmoke)),
          filled: true, fillColor: cInk),
      cursorColor: cGold,
    ),
  ]);

  // ── Step 1: Structure ──
  Widget _buildStep1() => Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
    const Text('MODE', style: TextStyle(fontFamily: 'monospace',
        fontSize: 9, color: cGold, letterSpacing: 3)),
    const SizedBox(height: 4),
    const Text('Chapters: each chapter is edited separately.\nBook: all chapters in one continuous view.',
        style: TextStyle(fontSize: 12, color: cSmoke, height: 1.6)),
    const SizedBox(height: 12),
    Row(children: [
      _modeChip('Chapters', DiaryMode.chapters),
      const SizedBox(width: 10),
      _modeChip('Book', DiaryMode.book),
    ]),
    const SizedBox(height: 28),
    const Text('CHAPTERS', style: TextStyle(fontFamily: 'monospace',
        fontSize: 9, color: cGold, letterSpacing: 3)),
    const SizedBox(height: 12),
    Row(children: [
      GestureDetector(
        onTap: () => setState(() =>
            _chapterCount = (_chapterCount - 1).clamp(1, 99)),
        child: Container(width: 36, height: 36,
            decoration: BoxDecoration(border: Border.all(color: cAsh)),
            child: const Icon(Icons.remove, size: 16, color: cSmoke)),
      ),
      const SizedBox(width: 16),
      Text('$_chapterCount', style: const TextStyle(
          fontSize: 20, color: cParchment, fontWeight: FontWeight.w300)),
      const SizedBox(width: 16),
      GestureDetector(
        onTap: () => setState(() =>
            _chapterCount = (_chapterCount + 1).clamp(1, 99)),
        child: Container(width: 36, height: 36,
            decoration: BoxDecoration(border: Border.all(color: cAsh)),
            child: const Icon(Icons.add, size: 16, color: cSmoke)),
      ),
    ]),
    const SizedBox(height: 28),
    const Text('WORDS PER CHAPTER (TARGET)', style: TextStyle(
        fontFamily: 'monospace', fontSize: 9,
        color: cGold, letterSpacing: 3)),
    const SizedBox(height: 12),
    Wrap(spacing: 8, runSpacing: 8,
        children: [250, 500, 1000, 2000, 5000].map((w) {
      final active = _wordsPerChapter == w;
      return GestureDetector(
        onTap: () => setState(() => _wordsPerChapter = w),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              border: Border.all(color: active ? cGold : cAsh),
              color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent),
          child: Text('$w', style: TextStyle(fontFamily: 'monospace',
              fontSize: 10, letterSpacing: 1,
              color: active ? cGold : cSmoke)),
        ),
      );
    }).toList()),
  ]);

  Widget _modeChip(String label, DiaryMode m) {
    final active = _mode == m;
    return GestureDetector(
      onTap: () => setState(() => _mode = m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
            border: Border.all(color: active ? cGold : cAsh),
            color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent),
        child: Text(label, style: TextStyle(fontFamily: 'monospace',
            fontSize: 10, letterSpacing: 1,
            color: active ? cGold : cSmoke)),
      ),
    );
  }

  // ── Step 2: Characters + worlds ──
  Widget _buildStep2() => Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
    const Text('CHARACTERS', style: TextStyle(fontFamily: 'monospace',
        fontSize: 9, color: cGold, letterSpacing: 3)),
    const SizedBox(height: 4),
    const Text('Import from Sandbox or create a new one.',
        style: TextStyle(fontSize: 12, color: cSmoke)),
    const SizedBox(height: 12),
    if (_allChars.isEmpty)
      const Text('No characters in Sandbox yet.',
          style: TextStyle(fontSize: 12, color: cSmoke,
              fontStyle: FontStyle.italic))
    else
      ..._allChars.map((c) {
        final selected = _selectedCharIds.contains(c.id);
        return GestureDetector(
          onTap: () => setState(() => selected
              ? _selectedCharIds.remove(c.id)
              : _selectedCharIds.add(c.id)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: selected ? c.accentColor : cAsh,
                      width: selected ? 2 : 1),
                  top: BorderSide(color: selected ? cSmoke : cAsh),
                  right: BorderSide(color: selected ? cSmoke : cAsh),
                  bottom: BorderSide(color: selected ? cSmoke : cAsh),
                )),
            child: Row(children: [
              Expanded(child: Text(c.name, style: TextStyle(
                  fontSize: 14, color: selected ? cParchment : cSmoke,
                  fontWeight: FontWeight.w300))),
              if (selected) Icon(Icons.check, size: 14, color: c.accentColor),
            ]),
          ),
        );
      }),
    GestureDetector(
      onTap: () => Navigator.of(context)
          .push(fadeRoute(CharacterEditorScreen(
            worlds: _allWorlds,
            onSave: (c) {
              setState(() => _allChars.add(c));
              SandboxStorage.saveCharacters(_allChars);
            },
          ))),
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 24),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border.all(
            color: cAsh, style: BorderStyle.solid)),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.add, size: 13, color: cSmoke),
          SizedBox(width: 8),
          Text('Create new character', style: TextStyle(
              fontFamily: 'monospace', fontSize: 9,
              color: cSmoke, letterSpacing: 2)),
        ]),
      ),
    ),
    const Text('WORLDS', style: TextStyle(fontFamily: 'monospace',
        fontSize: 9, color: cGold, letterSpacing: 3)),
    const SizedBox(height: 4),
    const Text('Import from Sandbox or create a new one.',
        style: TextStyle(fontSize: 12, color: cSmoke)),
    const SizedBox(height: 12),
    if (_allWorlds.isEmpty)
      const Text('No worlds in Sandbox yet.',
          style: TextStyle(fontSize: 12, color: cSmoke,
              fontStyle: FontStyle.italic))
    else
      ..._allWorlds.map((w) {
        final selected = _selectedWorldIds.contains(w.id);
        return GestureDetector(
          onTap: () => setState(() => selected
              ? _selectedWorldIds.remove(w.id)
              : _selectedWorldIds.add(w.id)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                border: Border.all(color: selected ? cGold : cAsh)),
            child: Row(children: [
              Expanded(child: Text(w.name, style: TextStyle(
                  fontSize: 14, color: selected ? cParchment : cSmoke,
                  fontWeight: FontWeight.w300))),
              if (selected)
                const Icon(Icons.check, size: 14, color: cGold),
            ]),
          ),
        );
      }),
    GestureDetector(
      onTap: () => Navigator.of(context)
          .push(fadeRoute(WorldEditorScreen(
            onSave: (w) {
              setState(() => _allWorlds.add(w));
              SandboxStorage.saveWorlds(_allWorlds);
            },
          ))),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border.all(
            color: cAsh, style: BorderStyle.solid)),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.add, size: 13, color: cSmoke),
          SizedBox(width: 8),
          Text('Create new world', style: TextStyle(
              fontFamily: 'monospace', fontSize: 9,
              color: cSmoke, letterSpacing: 2)),
        ]),
      ),
    ),
  ]);
}

// ─────────────────────────────────────────
// ENTRY SCREEN (chapters or book view)
// ─────────────────────────────────────────
class _EntryScreen extends StatefulWidget {
  final DiaryEntry entry;
  final void Function(DiaryEntry) onSave;

  const _EntryScreen({required this.entry, required this.onSave});

  @override
  State<_EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<_EntryScreen> {
  late DiaryEntry _entry;
  bool _bookScrollMode = true; // true = scroll, false = page flip

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    appSettings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _showCustomizeSheet() {
    bool isUploading = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CUSTOMIZE BOOK',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: cGold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Accent Colour',
                  style: TextStyle(color: cSmoke, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    cGold,
                    cIce,
                    cEmber,
                    cMagic,
                    cVine,
                    Colors.blueAccent,
                    Colors.purpleAccent,
                  ].map((color) {
                    return GestureDetector(
                      onTap: () {
                        setModalState(() => _entry.accentColor = color);
                        widget.onSave(_entry); // Auto-save
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _entry.accentColor == color
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      if (!ctx.mounted) return;
                      setModalState(() => isUploading = true);
                      try {
                        final bytes = await image.readAsBytes();
                        final ref = FirebaseStorage.instance
                            .ref()
                            .child('diary_covers/${_entry.id}.jpg');
                        await ref.putData(bytes);
                        final url = await ref.getDownloadURL();

                        if (!ctx.mounted) return;
                        setModalState(() {
                          _entry.coverImageUrl = url;
                          isUploading = false;
                        });
                        widget.onSave(_entry); // Save to local storage/Firestore

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: cVine, // Green for success
                              content: Text(
                                'Cover image updated!',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setModalState(() => isUploading = false);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: cEmber,
                              content: Text('Upload failed: $e'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: cAsh),
                    ),
                    child: Center(
                      child: isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: cGold,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Upload Cover Image',
                              style: TextStyle(color: cGold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(_entry.displayTitle, style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold)),
              if (_entry.genre.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(_entry.genre, style: const pw.TextStyle(fontSize: 18, color: PdfColors.grey)),
              ]
            ],
          ),
        ),
      ),
    );

    for (final chapter in _entry.chapters) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(chapter.title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text(chapter.plainText, style: const pw.TextStyle(fontSize: 14, lineSpacing: 4)),
            ],
          ),
        ),
      );
    }

    try {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${_entry.displayTitle.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: cEmber,
          content: Text('Export failed: $e'),
        ));
      }
    }
  }



    void _showLinkSelector() async {
    // 1. Load sandbox data
    final allChars = await SandboxStorage.loadCharacters();
    final allWorlds = await SandboxStorage.loadWorlds();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LINK TO STORY', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: cGold, letterSpacing: 3)),
                const SizedBox(height: 16),
                const Text('These characters and worlds will be attached to this book.', style: TextStyle(fontSize: 12, color: cSmoke)),
                const SizedBox(height: 24),
                
                Expanded(
                  child: ListView(
                    children: [
                      const Text('CHARACTERS', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 2)),
                      const SizedBox(height: 12),
                      ...allChars.map((c) {
                        final selected = _entry.linkedCharacterIds.contains(c.id);
                        return CheckboxListTile(
                          title: Text(c.name, style: TextStyle(color: selected ? cGold : cParchment)),
                          activeColor: cGold,
                          checkColor: cVoid,
                          value: selected,
                          onChanged: (v) {
                            setModalState(() {
                              if (v == true) {
                                _entry.linkedCharacterIds.add(c.id);
                              } else {
                                _entry.linkedCharacterIds.remove(c.id);
                              }
                            });
                            widget.onSave(_entry); // Auto-save when changed
                          },
                        );
                      }),
                      
                      const SizedBox(height: 24),
                      const Text('WORLDS', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 2)),
                      const SizedBox(height: 12),
                      ...allWorlds.map((w) {
                        final selected = _entry.linkedWorldIds.contains(w.id);
                        return CheckboxListTile(
                          title: Text(w.name, style: TextStyle(color: selected ? cGold : cParchment)),
                          activeColor: cGold,
                          checkColor: cVoid,
                          value: selected,
                          onChanged: (v) {
                            setModalState(() {
                              if (v == true) {
                                _entry.linkedWorldIds.add(w.id);
                              } else {
                                _entry.linkedWorldIds.remove(w.id);
                              }
                            });
                            widget.onSave(_entry); // Auto-save when changed
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  

  void _saveAndPop() {
    _entry.updatedAt = DateTime.now();
    widget.onSave(_entry);
    Navigator.of(context).pop();
  }

  void _openChapter(int index) {
    Navigator.of(context).push(fadeRoute(_ChapterEditor(
      chapter: _entry.chapters[index],
      chapterNumber: index + 1,
      wordTarget: _entry.wordsPerChapter,
      onSave: (updated) {
        setState(() => _entry.chapters[index] = updated);
        _entry.updatedAt = DateTime.now();
        widget.onSave(_entry);
      },
    )));
  }

  void _addChapter() {
    setState(() => _entry.chapters.add(DiaryChapter(
      id: const Uuid().v4(),
      title: 'Chapter ${_entry.chapters.length + 1}',
    )));
    _entry.updatedAt = DateTime.now();
    widget.onSave(_entry);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appSettings.diaryBgMode == 'fixed' ? appSettings.diaryBgColor : appSettings.bgColor,
    body: SafeArea(child: Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: cAsh))),
                        child: Row(children: [
          // 1. Go to Book List Button (Replaces the back arrow)
          GestureDetector(
            onTap: _saveAndPop,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: cGold.withValues(alpha: 0.5)),
                color: cGold.withValues(alpha: 0.1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.library_books_outlined, size: 14, color: cGold),
                  SizedBox(width: 6),
                  Text('ALL BOOKS', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          
                    if (appSettings.diaryEntryHeaderShow) Expanded(child: Text(_entry.displayTitle, style: TextStyle(
              fontSize: _dSize(appSettings.diaryEntryHeaderSize == 'S' ? 15 : appSettings.diaryEntryHeaderSize == 'L' ? 21 : 18), fontWeight: FontWeight.w300,
              fontStyle: FontStyle.italic, color: cParchment),
              overflow: TextOverflow.ellipsis)),

          // 2. Scroll / Page Toggle
          if (_entry.mode == DiaryMode.book)
            GestureDetector(
              onTap: () => setState(() => _bookScrollMode = !_bookScrollMode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: cAsh)),
                child: Text(_bookScrollMode ? 'SCROLL' : 'PAGES',
                    style: const TextStyle(fontFamily: 'monospace',
                        fontSize: 8, color: cSmoke, letterSpacing: 2)),
              ),
            ),

          // 3. Link Button
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showLinkSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: cGold.withValues(alpha: 0.5))),
              child: const Row(
                children: [
                  Icon(Icons.link, size: 14, color: cGold),
                  SizedBox(width: 6),
                  Text('LINK', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 1)),
                ],
              ),
            ),
          ),
                    // 4. Customize Button
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showCustomizeSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: cGold.withValues(alpha: 0.5))),
              child: const Icon(Icons.color_lens_outlined, size: 14, color: cGold),
            ),
          ),

          // 5. Export Button
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _exportToPdf,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: cGold.withValues(alpha: 0.5))),
              child: const Icon(Icons.download_outlined, size: 14, color: cGold),
            ),
          ),
        ]),
      ),

      // Genre + stats bar
      if (_entry.genre.isNotEmpty && appSettings.diaryShowGenreBar)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: cAsh))),
          child: Row(children: [
            Text(_entry.genre, style: const TextStyle(fontFamily: 'monospace',
                fontSize: 10, color: cGold, letterSpacing: 2)),
            const Spacer(),
            Text('${_entry.chapters.fold(0, (s, c) => s + c.wordCount)} words',
                style: const TextStyle(fontFamily: 'monospace',
                    fontSize: 9, color: cSmoke)),
          ]),
        ),

      Expanded(child: _entry.mode == DiaryMode.chapters
          ? _buildChaptersView()
          : _buildBookView()),
    ])),
  );

  // Chapters mode: list of chapter cards
  Widget _buildChaptersView() => ScrollConfiguration(
    behavior: NoGlowBehavior(),
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._entry.chapters.asMap().entries.map((e) {
          final i = e.key;
          final ch = e.value;
          final progress = _entry.wordsPerChapter > 0
              ? (ch.wordCount / _entry.wordsPerChapter).clamp(0.0, 1.0)
              : 0.0;
          return GestureDetector(
            onTap: () => _openChapter(i),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(appSettings.diaryChapterSize == 'S' ? 10 : appSettings.diaryChapterSize == 'L' ? 22 : 16),
              decoration: BoxDecoration(
                  color: cInk, border: Border.all(color: cAsh)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(child: Text(
                      ch.title.isNotEmpty ? ch.title : 'Chapter ${i + 1}',
                      style: TextStyle(fontSize: appSettings.diaryChapterSize == 'S' ? 13 : appSettings.diaryChapterSize == 'L' ? 17 : 15, color: cParchment,
                          fontWeight: FontWeight.w300,
                          fontStyle: FontStyle.italic))),
                  Text('${ch.wordCount} / ${_entry.wordsPerChapter} w',
                      style: const TextStyle(fontFamily: 'monospace',
                          fontSize: 9, color: cSmoke)),
                ]),
                if (ch.plainText.isNotEmpty && appSettings.diaryShowPreview) ...[
                  const SizedBox(height: 8),
                  Text(ch.plainText.length > 80
                      ? '${ch.plainText.substring(0, 80)}...'
                      : ch.plainText,
                      style: TextStyle(fontSize: _dSize(12), color: cMist,
                          fontStyle: FontStyle.italic, height: 1.5)),
                ],
                if (appSettings.diaryShowProgress) const SizedBox(height: 10),
                if (appSettings.diaryShowProgress) ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: cAsh,
                    color: progress >= 1.0 ? cVine : cGold,
                    minHeight: 2,
                  ),
                ),
              ]),
            ),
          );
        }),
        GestureDetector(
          onTap: _addChapter,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                border: Border.all(color: cAsh, style: BorderStyle.solid)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Icon(Icons.add, size: 13, color: cSmoke),
              SizedBox(width: 8),
              Text('Add chapter', style: TextStyle(fontFamily: 'monospace',
                  fontSize: 9, color: cSmoke, letterSpacing: 2)),
            ]),
          ),
        ),
      ],
    ),
  );

  // Book mode: all chapters in one scroll or page view
  Widget _buildBookView() {
    if (_bookScrollMode) {
      return ScrollConfiguration(
        behavior: NoGlowBehavior(),
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _entry.chapters.length,
          itemBuilder: (_, i) {
            final ch = _entry.chapters[i];
            return GestureDetector(
              onTap: () => _openChapter(i),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(ch.title.isNotEmpty ? ch.title : 'Chapter ${i + 1}',
                    style: const TextStyle(fontFamily: 'monospace',
                        fontSize: 10, color: cGold, letterSpacing: 3)),
                const SizedBox(height: 12),
                Text(ch.plainText.isEmpty ? '(empty)' : ch.plainText,
                    style: TextStyle(fontSize: appSettings.diaryReadingSize == 'S' ? appSettings.baseFontSize - 2 : appSettings.diaryReadingSize == 'L' ? appSettings.baseFontSize + 2 : appSettings.baseFontSize,
                        color: cParchment, height: appSettings.diaryLineHeight == 'compact' ? 1.4 : appSettings.diaryLineHeight == 'spacious' ? 2.2 : 1.8,
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 32),
                const Divider(color: cAsh),
                const SizedBox(height: 32),
              ]),
            );
          },
        ),
      );
    } else {
      // Page flip
      return PageView.builder(
        itemCount: _entry.chapters.length,
        itemBuilder: (_, i) {
          final ch = _entry.chapters[i];
          return GestureDetector(
            onTap: () => _openChapter(i),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(ch.title.isNotEmpty ? ch.title : 'Chapter ${i + 1}',
                    style: const TextStyle(fontFamily: 'monospace',
                        fontSize: 10, color: cGold, letterSpacing: 3)),
                const SizedBox(height: 16),
                Expanded(child: ScrollConfiguration(
                  behavior: NoGlowBehavior(),
                  child: SingleChildScrollView(
                    child: Text(ch.plainText.isEmpty ? '(empty — tap to write)' : ch.plainText,
                        style: TextStyle(fontSize: appSettings.diaryReadingSize == 'S' ? appSettings.baseFontSize - 2 : appSettings.diaryReadingSize == 'L' ? appSettings.baseFontSize + 2 : appSettings.baseFontSize,
                            color: cParchment, height: appSettings.diaryLineHeight == 'compact' ? 1.4 : appSettings.diaryLineHeight == 'spacious' ? 2.2 : 1.8,
                            fontStyle: FontStyle.italic)),
                  ),
                )),
                Center(child: Text('${i + 1} / ${_entry.chapters.length}',
                    style: const TextStyle(fontFamily: 'monospace',
                        fontSize: 9, color: cSmoke))),
              ]),
            ),
          );
        },
      );
    }
  }
}

// ─────────────────────────────────────────
// CHAPTER EDITOR (Quill rich text)
// ─────────────────────────────────────────
class _ChapterEditor extends StatefulWidget {
  final DiaryChapter chapter;
  final int chapterNumber;
  final int wordTarget;
  final void Function(DiaryChapter) onSave;
  const _ChapterEditor({required this.chapter, required this.chapterNumber,
      required this.wordTarget, required this.onSave});
  @override State<_ChapterEditor> createState() => _ChapterEditorState();
}

class _ChapterEditorState extends State<_ChapterEditor> {
  late QuillController _quill;
  late TextEditingController _titleCtrl;
  final _editorFocus = FocusNode();
  final _editorScroll = ScrollController();
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.chapter.title);
    // Load existing delta or start fresh
    if (widget.chapter.deltaJson.isNotEmpty) {
      try {
        final json = jsonDecode(widget.chapter.deltaJson) as List;
        _quill = QuillController(
            document: Document.fromJson(json),
            selection: const TextSelection.collapsed(offset: 0));
      } catch (_) {
        _quill = QuillController.basic();
      }
    } else {
      _quill = QuillController.basic();
    }
    _wordCount = widget.chapter.wordCount;
    _quill.addListener(_onTextChanged);
    appSettings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onTextChanged() {
    final plain = _quill.document.toPlainText();
    final wc = plain.trim().isEmpty ? 0
        : plain.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wc != _wordCount && mounted) setState(() => _wordCount = wc);
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    _quill.removeListener(_onTextChanged);
    _quill.dispose();
    _titleCtrl.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  void _save() {
    final delta = _quill.document.toDelta();
    final plain = _quill.document.toPlainText();
    final updated = DiaryChapter(
      id: widget.chapter.id,
      title: _titleCtrl.text.trim(),
      deltaJson: jsonEncode(delta.toJson()),
      plainText: plain.trim(),
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appSettings.diaryBgMode == 'fixed' ? appSettings.diaryBgColor : appSettings.bgColor,
    body: SafeArea(child: Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: cAsh))),
                        child: Row(children: [
          // 1. Back to Chapters
          GestureDetector(
            onTap: _save,
            child: const Icon(Icons.arrow_back_ios, color: cSmoke, size: 16),
          ),
          const SizedBox(width: 12),
          
          // 2. Escape hatch directly to the Book List
          GestureDetector(
            onTap: () {
              _save(); // Save this chapter
              // Pop twice: Once to leave editor, once to leave the book
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) Navigator.of(context).pop();
              });
            },
            child: const Icon(Icons.library_books_outlined, color: cGold, size: 18),
          ),
          const SizedBox(width: 12),

          Expanded(child: TextField(
            controller: _titleCtrl,
            style: TextStyle(fontSize: _dSize(18), color: cParchment,
                fontWeight: FontWeight.w300, fontStyle: FontStyle.italic),
            decoration: InputDecoration(
                hintText: 'Chapter ${widget.chapterNumber}',
                hintStyle: TextStyle(color: cSmoke,
                    fontStyle: FontStyle.italic, fontSize: _dSize(18),
                    fontWeight: FontWeight.w300),
                border: InputBorder.none),
            cursorColor: cGold,
          )),
          // Word count
          Text('$_wordCount / ${widget.wordTarget}',
              style: TextStyle(fontFamily: 'monospace', fontSize: 9,
                  color: _wordCount >= widget.wordTarget ? cVine : cSmoke,
                  letterSpacing: 1)),
          const SizedBox(width: 10),
          // Toolbar toggle
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: cParchment,
              child: const Text('Save', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 10,
                  color: cVoid, letterSpacing: 1)),
            ),
          ),
        ]),
      ),

            // Quill toolbar
      if (appSettings.diaryShowToolbar) Container(
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: cAsh))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: QuillSimpleToolbar(
            controller: _quill,
            config: const QuillSimpleToolbarConfig(
              showDividers: false,
              showFontFamily: false,
              showFontSize: false,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: false,
              showInlineCode: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: true,
              showAlignmentButtons: true,
              showLeftAlignment: true,
              showCenterAlignment: true,
              showRightAlignment: true,
              showJustifyAlignment: false,
              showHeaderStyle: true,
              showListNumbers: true,
              showListBullets: true,
              showListCheck: false,
              showCodeBlock: false,
              showQuote: true,
              showIndent: false,
              showLink: false,
              showUndo: true,
              showRedo: true,
            ),
          ),
        ),
      ),

      // Quill editor
      Expanded(child: ScrollConfiguration(
        behavior: NoGlowBehavior(),
        child: QuillEditor(
            controller: _quill,
            focusNode: _editorFocus,
            scrollController: _editorScroll,
            config: QuillEditorConfig(
              scrollable: true,
              padding: EdgeInsets.all(appSettings.diaryEditorPadding == 'compact' ? 10 : 20),
              autoFocus: widget.chapter.deltaJson.isEmpty,
              placeholder: 'Begin writing...',
              customStyles: DefaultStyles(
                paragraph: DefaultTextBlockStyle(
                  TextStyle(
                    fontSize: appSettings.diaryReadingSize == 'S' ? appSettings.baseFontSize - 2 : appSettings.diaryReadingSize == 'L' ? appSettings.baseFontSize + 2 : appSettings.baseFontSize,
                    color: cParchment,
                    fontStyle: FontStyle.italic,
                    height: appSettings.diaryLineHeight == 'compact' ? 1.4 : appSettings.diaryLineHeight == 'spacious' ? 2.2 : 1.8,
                  ),
                  const HorizontalSpacing(0, 0),
                  const VerticalSpacing(0, 0),
                  const VerticalSpacing(0, 0),
                  null,
                ),
                placeHolder: DefaultTextBlockStyle(
                  const TextStyle(
                    fontSize: 14,
                    color: cSmoke,
                    fontStyle: FontStyle.italic,
                  ),
                  const HorizontalSpacing(0, 0),
                  const VerticalSpacing(0, 0),
                  const VerticalSpacing(0, 0),
                  null,
                ),
              ),
            ),
          ),
        ),
      ),
    ]),
  ),
);
}

// ── Shared helpers (re-used from main) ──
Widget _sheetAction(BuildContext context, IconData icon, String label,
    VoidCallback onTap, {Color color = cMist}) =>
    GestureDetector(
      onTap: () { Navigator.of(context).pop(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: cAsh))),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(fontSize: 14, color: color,
              fontWeight: FontWeight.w300)),
        ]),
      ),
    );
