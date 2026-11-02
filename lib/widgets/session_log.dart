import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../models/world.dart';

// ─────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────
enum LogEntryType { rule, character, location, event, note }

enum CharacterRole { main, side, npc }

class LogEntry {
  final String id;
  final LogEntryType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final CharacterRole? role;
  final String? source;
  final Map<String, dynamic>? meta;
  final CharacterEntry? characterData; // NEW
  final WorldEntry? worldData; // NEW

  LogEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.role,
    this.source,
    this.meta,
    this.characterData,
    this.worldData,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.millisecondsSinceEpoch,
    if (role != null) 'role': role!.name,
    if (source != null) 'source': source,
    if (meta != null) 'meta': meta,
    if (characterData != null) 'characterData': characterData!.toJson(),
    if (worldData != null) 'worldData': worldData!.toJson(),
  };

  static LogEntry fromJson(Map<String, dynamic> j) => LogEntry(
    id: j['id'] as String,
    type: LogEntryType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => LogEntryType.note,
    ),
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
    role: j['role'] != null
        ? CharacterRole.values.firstWhere(
            (r) => r.name == j['role'],
            orElse: () => CharacterRole.side,
          )
        : null,
    source: j['source'] as String?,
    meta: j['meta'] != null
        ? Map<String, dynamic>.from(j['meta'] as Map)
        : null,
    characterData: j['characterData'] != null
        ? CharacterEntry.fromJson(
            Map<String, dynamic>.from(j['characterData'] as Map),
          )
        : null,
    worldData: j['worldData'] != null
        ? WorldEntry.fromJson(Map<String, dynamic>.from(j['worldData'] as Map))
        : null,
  );
}

// ─────────────────────────────────────────
// STORAGE — one log per session
// ─────────────────────────────────────────
class SessionLog extends ChangeNotifier {
  SessionLog._(this._storageKey);
  final String _storageKey;

  static final Map<String, SessionLog> _cache = {};

  factory SessionLog.forSession(String sessionId) {
    final key = sessionId.isEmpty ? 'default' : sessionId;
    return _cache.putIfAbsent(key, () => SessionLog._('lore_log_$key'));
  }

  final List<LogEntry> _entries = [];
  bool _loaded = false;
  Future<void>? _loading;

  List<LogEntry> get all => List.unmodifiable(_entries);

  Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= _doLoad();
  }

  Future<void> _doLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _entries
          ..clear()
          ..addAll(
            list.map(
              (e) => LogEntry.fromJson(Map<String, dynamic>.from(e as Map)),
            ),
          );
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> _add(LogEntry e) async {
    await load();
    _entries.insert(0, e);
    await _save();
  }

  Future<void> addRule(String title, String body) =>
      _add(_make(type: LogEntryType.rule, title: title, body: body));

  Future<void> addCharacter(String name, String desc, CharacterRole role) =>
      _add(
        _make(
          type: LogEntryType.character,
          title: name,
          body: desc,
          role: role,
        ),
      );

  Future<void> addLocation(String name, String desc) =>
      _add(_make(type: LogEntryType.location, title: name, body: desc));

  Future<void> addNote(String title, String body) =>
      _add(_make(type: LogEntryType.note, title: title, body: body));

  Future<void> addEvent({
    required String title,
    required String body,
    String? source,
    Map<String, dynamic>? meta,
  }) => _add(
    _make(
      type: LogEntryType.event,
      title: title,
      body: body,
      source: source,
      meta: meta,
    ),
  );

  Future<void> addCharacterEntry(CharacterEntry c) async {
    await load();
    if (_entries.any((e) => e.characterData?.id == c.id)) return;

    _entries.insert(
      0,
      LogEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
        type: LogEntryType.character,
        title: c.name,
        body: c.personality.isNotEmpty ? c.personality : c.backstory,
        createdAt: DateTime.now(),
        role: c.type == CharacterType.playerCharacter
            ? CharacterRole.main
            : CharacterRole.side,
        characterData: c,
      ),
    );
    await _save();
  }

  Future<void> addWorldEntry(WorldEntry w) async {
    await load();
    if (_entries.any((e) => e.worldData?.id == w.id)) return;

    _entries.insert(
      0,
      LogEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
        type: LogEntryType.location,
        title: w.name,
        body: w.overview,
        createdAt: DateTime.now(),
        worldData: w,
      ),
    );
    await _save();
  }

  Future<void> remove(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> update(LogEntry e) async {
    final i = _entries.indexWhere((x) => x.id == e.id);
    if (i != -1) {
      _entries[i] = e;
      await _save();
    }
  }

  LogEntry _make({
    required LogEntryType type,
    required String title,
    required String body,
    CharacterRole? role,
    String? source,
    Map<String, dynamic>? meta,
  }) => LogEntry(
    id: '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
    type: type,
    title: title,
    body: body,
    createdAt: DateTime.now(),
    role: role,
    source: source,
    meta: meta,
  );
}

// ─────────────────────────────────────────
// PUBLIC ENTRY POINTS
// ─────────────────────────────────────────
class SessionLogSheet {
  static Future<void> show(BuildContext context, String sessionId) async {
    final log = SessionLog.forSession(sessionId);
    await log.load();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SessionLogView(log: log),
      ),
    );
  }

  static Future<void> promptFromSelection({
    required BuildContext context,
    required String sessionId,
    required String selectedText,
  }) async {
    final log = SessionLog.forSession(sessionId);
    await log.load();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) =>
          _AddFromSelectionDialog(log: log, selectedText: selectedText),
    );
  }
}

// ─────────────────────────────────────────
// SHEET
// ─────────────────────────────────────────
class SessionLogView extends StatefulWidget {
  final SessionLog log;
  final bool isSidebar;
  const SessionLogView({super.key, required this.log, this.isSidebar = false});
  @override
  State<SessionLogView> createState() => _SessionLogViewState();
}

class _SessionLogViewState extends State<SessionLogView> {
  int _tab = 0;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _expandedId;

  static const _tabLabels = ['RULES', 'CAST', 'PLACES', 'LOG', 'NOTES'];

  @override
  void initState() {
    super.initState();
    widget.log.addListener(_onLogChanged);
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    widget.log.removeListener(_onLogChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onLogChanged() {
    if (mounted) setState(() {});
  }

  List<LogEntry> get _filtered {
    return widget.log.all.where((e) {
      switch (_tab) {
        case 0:
          if (e.type != LogEntryType.rule) return false;
          break;
        case 1:
          if (e.type != LogEntryType.character) return false;
          break;
        case 2:
          if (e.type != LogEntryType.location) return false;
          break;
        case 3:
          if (e.type != LogEntryType.event) return false;
          break;
        case 4:
          if (e.type != LogEntryType.note) return false;
          break;
      }
      if (_query.isEmpty) return true;
      final hay = '${e.title} ${e.body} ${e.source ?? ''}'.toLowerCase();
      return hay.contains(_query);
    }).toList();
  }

  Future<void> _addNew() async {
    final defaultType = (_tab == 3 || _tab == 4)
        ? LogEntryType.note
        : _tabToType(_tab);
    final result = await showDialog<_AddResult>(
      context: context,
      builder: (_) => _AddEntryDialog(type: defaultType),
    );
    if (result == null) return;
    await _commit(result);
  }

  LogEntryType _tabToType(int tab) {
    switch (tab) {
      case 0:
        return LogEntryType.rule;
      case 1:
        return LogEntryType.character;
      case 2:
        return LogEntryType.location;
      default:
        return LogEntryType.note;
    }
  }

  Future<void> _commit(_AddResult r) async {
    switch (r.type) {
      case LogEntryType.rule:
        await widget.log.addRule(r.title, r.body);
        break;
      case LogEntryType.character:
        await widget.log.addCharacter(
          r.title,
          r.body,
          r.role ?? CharacterRole.side,
        );
        break;
      case LogEntryType.location:
        await widget.log.addLocation(r.title, r.body);
        break;
      case LogEntryType.event:
      case LogEntryType.note:
        await widget.log.addNote(r.title, r.body);
        break;
    }
  }

  Future<void> _editEntry(LogEntry e) async {
    final result = await showDialog<_AddResult>(
      context: context,
      builder: (_) => _AddEntryDialog(
        type: e.type,
        initialTitle: e.title,
        initialBody: e.body,
        initialRole: e.role,
        isEditing: true,
      ),
    );
    if (result == null) return;
    await widget.log.update(
      LogEntry(
        id: e.id,
        type: result.type,
        title: result.title,
        body: result.body,
        createdAt: e.createdAt,
        role: result.role,
        source: e.source,
        meta: e.meta,
        characterData: e.characterData,
        worldData: e.worldData,
      ),
    );
  }

  Future<void> _deleteEntry(LogEntry e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cInk,
        shape: const RoundedRectangleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DELETE ENTRY',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cEmber,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                e.title.isEmpty ? '(untitled)' : e.title,
                style: const TextStyle(
                  fontSize: 14,
                  color: cMist,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: cAsh),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cSmoke,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cEmber.withValues(alpha: 0.8),
                        child: const Center(
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cParchment,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm == true) await widget.log.remove(e.id);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: widget.isSidebar
          ? const BoxConstraints()
          : BoxConstraints(maxHeight: mq.size.height * 0.85),
      decoration: BoxDecoration(
        color: cInk,
        borderRadius: widget.isSidebar
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.isSidebar)
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: cAsh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Text(
                  'SESSION LOG',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: cGold,
                    letterSpacing: 4,
                  ),
                ),
                const Spacer(),
                if (!widget.isSidebar)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18, color: cSmoke),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13, color: cParchment),
              decoration: InputDecoration(
                hintText: 'Search entries...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                ),
                prefixIcon: const Icon(Icons.search, size: 16, color: cSmoke),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: const Icon(Icons.close, size: 14, color: cSmoke),
                      )
                    : null,
                filled: true,
                fillColor: cVoid,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 8,
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: cAsh),
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: cSmoke),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              cursorColor: cGold,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: List.generate(_tabLabels.length, (i) {
                final active = _tab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _tab = i;
                      _expandedId = null;
                    }),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: i < _tabLabels.length - 1 ? 6 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? cGold.withValues(alpha: 0.1)
                            : Colors.transparent,
                        border: Border.all(color: active ? cGold : cAsh),
                      ),
                      child: Center(
                        child: Text(
                          _tabLabels[i],
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            letterSpacing: 1,
                            color: active ? cGold : cSmoke,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(color: cAsh, height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildEntryCard(_filtered[i]),
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: cAsh)),
            ),
            child: GestureDetector(
              onTap: _addNew,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: cParchment,
                child: const Center(
                  child: Text(
                    '+ ADD NEW ENTRY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: cVoid,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final label = _query.isEmpty
        ? 'Nothing in this section yet.'
        : 'No matches for "$_query".';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: cSmoke,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildEntryCard(LogEntry e) {
    final expanded = _expandedId == e.id;
    final (label, color) = _labelAndColor(e);
    return GestureDetector(
      onTap: () => setState(() => _expandedId = expanded ? null : e.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cVoid,
          border: Border(
            left: BorderSide(color: color, width: 2),
            top: const BorderSide(color: cAsh),
            right: const BorderSide(color: cAsh),
            bottom: const BorderSide(color: cAsh),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8,
                      color: color,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _humanTime(e.createdAt),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8,
                      color: cSmoke,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                e.title.isEmpty ? '(untitled)' : e.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  color: cParchment,
                ),
              ),
            ),
            if (e.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  expanded ? e.body : _preview(e.body),
                  style: const TextStyle(
                    fontSize: 13,
                    color: cMist,
                    height: 1.6,
                  ),
                ),
              ),

            // ── RICH DATA PREVIEW ──
            if (expanded && e.characterData != null) ...[
              _buildRichCharacter(e.characterData!),
            ] else if (expanded && e.worldData != null) ...[
              _buildRichWorld(e.worldData!),
            ],

            if (expanded) ...[
              Container(height: 1, color: cAsh),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _editEntry(e),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 12, color: cSmoke),
                            SizedBox(width: 6),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 11,
                                color: cSmoke,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _deleteEntry(e),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, size: 12, color: cEmber),
                            SizedBox(width: 6),
                            Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 11,
                                color: cEmber,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRichCharacter(CharacterEntry c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cInk,
        border: Border.all(color: cAsh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.pronouns.isNotEmpty || c.age.isNotEmpty) ...[
            Text(
              [
                if (c.pronouns.isNotEmpty) c.pronouns,
                if (c.age.isNotEmpty) c.age,
              ].join(' · '),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: cSmoke,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (c.appearance.isNotEmpty) ...[
            const Text(
              'APPEARANCE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                color: cGold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              c.appearance,
              style: const TextStyle(fontSize: 13, color: cMist, height: 1.5),
            ),
            const SizedBox(height: 8),
          ],
          if (c.backstory.isNotEmpty) ...[
            const Text(
              'BACKSTORY',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                color: cGold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              c.backstory,
              style: const TextStyle(fontSize: 13, color: cMist, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRichWorld(WorldEntry w) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cInk,
        border: Border.all(color: cAsh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (w.genre.isNotEmpty) ...[
            Text(
              w.genre,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: cGold,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (w.tone.isNotEmpty) ...[
            const Text(
              'TONE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                color: cGold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              w.tone,
              style: const TextStyle(fontSize: 13, color: cMist, height: 1.5),
            ),
            const SizedBox(height: 8),
          ],
          if (w.history.isNotEmpty) ...[
            const Text(
              'HISTORY',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                color: cGold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              w.history,
              style: const TextStyle(fontSize: 13, color: cMist, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  String _preview(String s) {
    if (s.length <= 120) return s;
    return '${s.substring(0, 120)}…';
  }

  (String, Color) _labelAndColor(LogEntry e) {
    switch (e.type) {
      case LogEntryType.rule:
        return ('RULE', cGold);
      case LogEntryType.character:
        switch (e.role ?? CharacterRole.side) {
          case CharacterRole.main:
            return ('MAIN CHARACTER', cEmber);
          case CharacterRole.side:
            return ('SIDE CHARACTER', cIce);
          case CharacterRole.npc:
            return ('NPC', cSmoke);
        }
      case LogEntryType.location:
        return ('LOCATION', cVine);
      case LogEntryType.event:
        final s = (e.source ?? '').toLowerCase();
        if (s == 'dice') return ('DICE ROLL', cMagic);
        if (s == 'mood') return ('MOOD', cIce);
        if (s == 'location') return ('LOCATION CHANGE', cVine);
        if (s == 'character') return ('CHARACTER SWITCH', cEmber);
        return ('EVENT', cMist);
      case LogEntryType.note:
        return ('NOTE', cMist);
    }
  }

  String _humanTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────
// ADD / EDIT DIALOG
// ─────────────────────────────────────────
class _AddResult {
  final LogEntryType type;
  final String title;
  final String body;
  final CharacterRole? role;
  _AddResult({
    required this.type,
    required this.title,
    required this.body,
    this.role,
  });
}

class _AddEntryDialog extends StatefulWidget {
  final LogEntryType type;
  final String? initialTitle;
  final String? initialBody;
  final CharacterRole? initialRole;
  final bool isEditing;

  const _AddEntryDialog({
    required this.type,
    this.initialTitle,
    this.initialBody,
    this.initialRole,
    this.isEditing = false,
  });

  @override
  State<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<_AddEntryDialog> {
  late LogEntryType _type;
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  CharacterRole _role = CharacterRole.side;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _bodyCtrl = TextEditingController(text: widget.initialBody ?? '');
    _role = widget.initialRole ?? CharacterRole.side;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  String _titleHint() {
    switch (_type) {
      case LogEntryType.rule:
        return 'Rule name...';
      case LogEntryType.character:
        return 'Character name...';
      case LogEntryType.location:
        return 'Place name...';
      case LogEntryType.event:
      case LogEntryType.note:
        return 'Title...';
    }
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty && body.isEmpty) return;
    Navigator.pop(
      context,
      _AddResult(
        type: _type,
        title: title.isEmpty ? _autoTitle(body) : title,
        body: body,
        role: _type == LogEntryType.character ? _role : null,
      ),
    );
  }

  String _autoTitle(String body) {
    final first = body.split(RegExp(r'[\n\.!?]')).first.trim();
    if (first.length <= 40) return first;
    return '${first.substring(0, 40)}…';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: cInk,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEditing ? 'EDIT ENTRY' : 'NEW ENTRY',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cGold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              if (!widget.isEditing) ...[
                const Text(
                  'TYPE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _typeChip('Rule', LogEntryType.rule),
                    _typeChip('Character', LogEntryType.character),
                    _typeChip('Location', LogEntryType.location),
                    _typeChip('Note', LogEntryType.note),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (_type == LogEntryType.character) ...[
                const Text(
                  'ROLE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _roleChip('Main', CharacterRole.main),
                    _roleChip('Side', CharacterRole.side),
                    _roleChip('NPC', CharacterRole.npc),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: cParchment),
                decoration: InputDecoration(
                  hintText: _titleHint(),
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: cSmoke,
                    fontStyle: FontStyle.italic,
                  ),
                  filled: true,
                  fillColor: cVoid,
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: cAsh),
                    borderRadius: BorderRadius.zero,
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: cGold),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                cursorColor: cGold,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyCtrl,
                maxLines: 6,
                minLines: 3,
                style: const TextStyle(fontSize: 13, color: cMist, height: 1.6),
                decoration: const InputDecoration(
                  hintText: 'Description or details...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: cSmoke,
                    fontStyle: FontStyle.italic,
                  ),
                  filled: true,
                  fillColor: cVoid,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cAsh),
                    borderRadius: BorderRadius.zero,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cGold),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                cursorColor: cGold,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: cAsh),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: cSmoke,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cParchment,
                        child: const Center(
                          child: Text(
                            'Save',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: cVoid,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String label, LogEntryType t) {
    final active = _type == t;
    return GestureDetector(
      onTap: () => setState(() => _type = t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1,
            color: active ? cGold : cSmoke,
          ),
        ),
      ),
    );
  }

  Widget _roleChip(String label, CharacterRole r) {
    final active = _role == r;
    return GestureDetector(
      onTap: () => setState(() => _role = r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1,
            color: active ? cGold : cSmoke,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// ADD FROM HIGHLIGHTED TEXT
// ─────────────────────────────────────────
class _AddFromSelectionDialog extends StatefulWidget {
  final SessionLog log;
  final String selectedText;
  const _AddFromSelectionDialog({
    required this.log,
    required this.selectedText,
  });
  @override
  State<_AddFromSelectionDialog> createState() =>
      _AddFromSelectionDialogState();
}

class _AddFromSelectionDialogState extends State<_AddFromSelectionDialog> {
  LogEntryType _type = LogEntryType.character;
  CharacterRole _role = CharacterRole.side;
  late TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: _autoTitle(widget.selectedText));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  String _autoTitle(String body) {
    final first = body.split(RegExp(r'[\n\.!?]')).first.trim();
    if (first.length <= 40) return first;
    return '${first.substring(0, 40)}…';
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final body = widget.selectedText.trim();
    if (title.isEmpty) return;

    switch (_type) {
      case LogEntryType.rule:
        await widget.log.addRule(title, body);
        break;
      case LogEntryType.character:
        await widget.log.addCharacter(title, body, _role);
        break;
      case LogEntryType.location:
        await widget.log.addLocation(title, body);
        break;
      case LogEntryType.event:
      case LogEntryType.note:
        await widget.log.addNote(title, body);
        break;
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.selectedText.length > 200
        ? '${widget.selectedText.substring(0, 200)}…'
        : widget.selectedText;

    return Dialog(
      backgroundColor: cInk,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ADD TO LOG',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cGold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: cSmoke, width: 2)),
                ),
                child: Text(
                  '"$preview"',
                  style: const TextStyle(
                    fontSize: 12,
                    color: cMist,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'TYPE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cSmoke,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip('Rule', LogEntryType.rule),
                  _chip('Character', LogEntryType.character),
                  _chip('Location', LogEntryType.location),
                  _chip('Note', LogEntryType.note),
                ],
              ),
              if (_type == LogEntryType.character) ...[
                const SizedBox(height: 16),
                const Text(
                  'ROLE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _rchip('Main', CharacterRole.main),
                    _rchip('Side', CharacterRole.side),
                    _rchip('NPC', CharacterRole.npc),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'TITLE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cSmoke,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(fontSize: 14, color: cParchment),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: cVoid,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cAsh),
                    borderRadius: BorderRadius.zero,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cGold),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                cursorColor: cGold,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: cAsh),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: cSmoke,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cParchment,
                        child: const Center(
                          child: Text(
                            'Save',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: cVoid,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, LogEntryType t) {
    final active = _type == t;
    return GestureDetector(
      onTap: () => setState(() => _type = t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1,
            color: active ? cGold : cSmoke,
          ),
        ),
      ),
    );
  }

  Widget _rchip(String label, CharacterRole r) {
    final active = _role == r;
    return GestureDetector(
      onTap: () => setState(() => _role = r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1,
            color: active ? cGold : cSmoke,
          ),
        ),
      ),
    );
  }
}
