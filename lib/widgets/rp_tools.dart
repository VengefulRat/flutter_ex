import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../settings.dart';
import '../models/world.dart';
import '../note_editor_screen.dart';

// ════════════════════════════════════════
// RP TOOLS PANEL  (slide-up sheet)
// ════════════════════════════════════════
class RPToolsPanel extends StatefulWidget {
  final List<RPNote> notes;
  final StatBlock? myStats;
  final StatBlock? partnerStats;
  final String partnerName;
  final List<WorldEntry> importedWorlds;
  final List<CharacterEntry> importedCharacters;
  final List<WorldEntry> availableWorlds;
  final List<CharacterEntry> availableCharacters;
  final void Function(String oocMessage) onDiceRolled;
  final void Function(StatBlock?) onMyStatsChanged;
  final void Function(WorldEntry) onImportWorld;
  final void Function(CharacterEntry) onImportCharacter;
  final void Function(WorldEntry) onRemoveWorld;
  final void Function(CharacterEntry) onRemoveCharacter;

  final bool isSidebar;

  const RPToolsPanel({
    super.key,
    required this.notes,
    this.myStats,
    this.partnerStats,
    required this.partnerName,
    required this.importedWorlds,
    required this.importedCharacters,
    required this.availableWorlds,
    required this.availableCharacters,
    required this.onDiceRolled,
    required this.onMyStatsChanged,
    required this.onImportWorld,
    required this.onImportCharacter,
    required this.onRemoveWorld,
    required this.onRemoveCharacter,
    this.isSidebar = false,
  });

  @override
  State<RPToolsPanel> createState() => _RPToolsPanelState();
}

class _RPToolsPanelState extends State<RPToolsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int? _lastRoll;
  DiceType _selectedDice = DiceType.d20;
  int _diceCount = 1;
  bool _showRollResult = false;
  String _rollLabel = '';
  final _rnd = Random();

  // Note editing
    int _statsRevision = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

Future<void> _openNoteEditor({RPNote? note}) async {
  final result = await Navigator.of(context).push<NoteEditorResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => NoteEditorScreen(note: note),
    ),
  );
  if (result == null) return;
  setState(() {
    if (result.deleted) {
      widget.notes.removeWhere((n) => n.id == note?.id);
    } else {
      final saved = result.note!;
      final idx = widget.notes.indexWhere((n) => n.id == saved.id);
      if (idx >= 0) {
        widget.notes[idx] = saved;
      } else {
        widget.notes.insert(0, saved);
      }
    }
  });
}

  @override
  Widget build(BuildContext context) => Container(
    // If it's in the sidebar, let the parent Expanded widget control the height.
    // Otherwise, keep the 80% height for mobile bottom sheets.
    height: widget.isSidebar ? null : MediaQuery.of(context).size.height * 0.80, 
    decoration: const BoxDecoration(
      color: cInk,
      border: Border(top: BorderSide(color: cAsh)),
    ),
    child: Column(
      children: [
        // Handle + header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Spacer(),
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: cAsh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Tab bar
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: cAsh)),
          ),
          child: TabBar(
            controller: _tab,
            indicatorColor: cGold,
            indicatorWeight: 1,
            labelColor: cGold,
            unselectedLabelColor: cSmoke,
            labelStyle: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              letterSpacing: 2,
            ),
            tabs: const [
              Tab(text: 'NOTES'),
              Tab(text: 'STATS'),
              Tab(text: 'DICE'),
              Tab(text: 'IMPORT'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildNotesTab(),
              _buildStatsTab(),
              _buildDiceTab(),
              _buildImportTab(),
            ],
          ),
        ),
      ],
    ),
  );

  // ════════════ NOTES ════════════
  Widget _buildNotesTab() => Column(
    children: [
      Expanded(
        child: ScrollConfiguration(
          behavior: NoGlowBehavior(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Pinned first
              ...widget.notes.where((n) => n.isPinned).map(_buildNoteCard),
              if (widget.notes.any((n) => n.isPinned) &&
                  widget.notes.any((n) => !n.isPinned))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(color: cAsh),
                ),
              ...widget.notes.where((n) => !n.isPinned).map(_buildNoteCard),
              if (widget.notes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'No notes yet.\nJot down what matters — names,\nplaces, details you\'ll want later.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: cSmoke,
                        fontStyle: FontStyle.italic,
                        height: 1.7,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      // Add note bar
      _buildAddNoteBar(),
    ],
  );

    Widget _buildNoteCard(RPNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: note.isPinned ? cAsh.withValues(alpha: 0.3) : cVoid,
        border: Border(
          left: BorderSide(
            color: note.isPinned ? cGold : cAsh,
            width: note.isPinned ? 2 : 1,
          ),
          top: const BorderSide(color: cAsh),
          right: const BorderSide(color: cAsh),
          bottom: const BorderSide(color: cAsh),
        ),
      ),
      child: GestureDetector(
        onTap: () => _openNoteEditor(note: note),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.tag != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        note.tag!.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 8,
                          color: cGold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  Text(
                    note.content,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: appSettings.baseFontSize - 1,
                      color: cMist,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => note.isPinned = !note.isPinned),
              child: Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 14,
                color: note.isPinned ? cGold : cSmoke,
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildAddNoteBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: cAsh)),
    ),
    child: GestureDetector(
      onTap: () => _openNoteEditor(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: cAsh)),
        child: const Row(
          children: [
            Icon(Icons.add, size: 14, color: cSmoke),
            SizedBox(width: 8),
            Text(
              'Add a note...',
              style: TextStyle(
                fontSize: 13,
                color: cSmoke,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ════════════ STATS ════════════
  Widget _buildStatsTab() => ScrollConfiguration(
    behavior: NoGlowBehavior(),
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // My stats
        Row(
          children: [
            const Text(
              'MY STATS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: cGold,
                letterSpacing: 4,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StatsViewerScreen(
                      myStats: widget.myStats,
                      partnerStats: widget.partnerStats,
                      partnerName: widget.partnerName, // see note below
                    ),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.fullscreen, size: 16, color: cSmoke),
              ),
            ),
            if (widget.myStats == null)
              GestureDetector(
                onTap: _addStats,
                child: const Text(
                  '+ Add',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 2,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: _confirmDeleteStats,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Remove',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: cEmber,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.myStats != null)
          _StatBlockWidget(
            key: ValueKey('my_stats_$_statsRevision'),
            block: widget.myStats!,
            editable: true,
            onChanged: () => widget.onMyStatsChanged(widget.myStats!),
            onAddStat: () => _addStatEntry(widget.myStats!),
          )
        else
          _emptyStatState(_addStats),

        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 12),

        // Partner stats (read-only view)
        const Text(
          'PARTNER STATS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cSmoke,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Read only — your partner controls these',
          style: TextStyle(
            fontSize: 11,
            color: cSmoke,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.partnerStats != null)
          _StatBlockWidget(
            block: widget.partnerStats!,
            editable: false,
            onChanged: () {},
            onAddStat: () {},
          )
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Partner hasn\'t set up stats yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _confirmDeleteStats() async {
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
              const Text('REMOVE STAT BLOCK',
                  style: TextStyle(
                      fontFamily: 'monospace', fontSize: 9,
                      color: cEmber, letterSpacing: 4)),
              const SizedBox(height: 12),
              const Text(
                'This clears your stats for this session. Your partner will '
                'no longer see them. You can set up a new block any time.',
                style: TextStyle(fontSize: 13, color: cMist,
                    fontStyle: FontStyle.italic, height: 1.7),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        border: Border.all(color: cAsh)),
                    child: const Center(child: Text('Cancel',
                        style: TextStyle(fontFamily: 'monospace',
                            fontSize: 9, color: cSmoke, letterSpacing: 2))),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: cEmber.withValues(alpha: 0.8),
                    child: const Center(child: Text('Remove',
                        style: TextStyle(fontFamily: 'monospace',
                            fontSize: 9, color: cParchment, letterSpacing: 2))),
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirm == true) {
      widget.onMyStatsChanged(null);
    }
  }


  void _addStats() => showModalBottomSheet(
    context: context,
    backgroundColor: cInk,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHOOSE A PRESET',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cGold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 16),
          _presetOption(
            'D&D Style',
            'STR · DEX · CON · INT · WIS · CHA · HP · AC',
            () {
              widget.onMyStatsChanged(StatBlock.dndPreset());
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 10),
          _presetOption(
            'Custom',
            'Start with Health and Stamina — add your own',
            () {
              widget.onMyStatsChanged(StatBlock.customPreset());
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    ),
  );

  Widget _presetOption(String name, String desc, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: cAsh)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        color: cParchment,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: cSmoke,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: cSmoke, size: 18),
            ],
          ),
        ),
      );

  Widget _emptyStatState(VoidCallback onAdd) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No stat block yet.',
            style: TextStyle(
              fontSize: 13,
              color: cSmoke,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: cAsh)),
              child: const Text(
                'Set up stats',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: cSmoke,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  void _addStatEntry(StatBlock block) {
    final nameCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '10');
    bool isPool = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDState) => Dialog(
          backgroundColor: cInk,
          shape: const RoundedRectangleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NEW STAT', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 4)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 15, color: cParchment, fontStyle: FontStyle.italic),
                  decoration: const InputDecoration(
                    hintText: 'Stat name...',
                    hintStyle: TextStyle(color: cSmoke, fontStyle: FontStyle.italic),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cAsh)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cSmoke)),
                  ),
                  cursorColor: cGold,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _statTypeChip('Static', !isPool, () => setDState(() => isPool = false))),
                    const SizedBox(width: 10),
                    Expanded(child: _statTypeChip('Current / Max', isPool, () => setDState(() => isPool = true))),
                  ],
                ),
                if (isPool) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 15, color: cParchment, fontStyle: FontStyle.italic),
                    decoration: const InputDecoration(
                      hintText: 'Max value...',
                      hintStyle: TextStyle(color: cSmoke, fontStyle: FontStyle.italic),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cAsh)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cSmoke)),
                    ),
                    cursorColor: cGold,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(border: Border.all(color: cAsh)),
                          child: const Center(child: Text('Cancel', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cSmoke, letterSpacing: 2))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          if (isPool) {
                            final max = int.tryParse(maxCtrl.text.trim()) ?? 10;
                            block.stats.add(StatEntry(name: name, value: max, isPool: true, maxValue: max));
                          } else {
                            block.stats.add(StatEntry(name: name, value: 10));
                          }
                          widget.onMyStatsChanged(block);
                          setState(() => _statsRevision++);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: cParchment,
                          child: const Center(child: Text('Add', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cVoid, letterSpacing: 2))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statTypeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cParchment : Colors.transparent,
          border: Border.all(color: selected ? cParchment : cAsh),
        ),
        child: Center(child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: selected ? cVoid : cSmoke, letterSpacing: 1))),
      ),
    );
  }


  // ════════════ DICE ════════════
    Widget _buildDiceTab() => Column(
    children: [
      Expanded(
        child: ScrollConfiguration(
          behavior: NoGlowBehavior(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Result display
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _showRollResult ? cGold : cAsh,
                    ),
                    color: _showRollResult
                        ? cGold.withValues(alpha: 0.03)
                        : Colors.transparent,
                  ),
                  child: _showRollResult && _lastRoll != null
                      ? Column(
                          children: [
                            Text(
                              '$_lastRoll',
                              style: const TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.w200,
                                color: cParchment,
                                letterSpacing: -2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _rollLabel,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: cGold,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Opacity(
                              opacity: 0.20,
                              child: _DiceGlyph(
                                sides: _selectedDice.sides,
                                color: cSmoke,
                                size: 56,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'READY TO ROLL',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: cSmoke,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 24),

                // Dice selector
                const Text(
                  'SELECT DIE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: DiceType.values.map((d) {
                    final active = _selectedDice == d;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDice = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 62,
                        height: 72,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: active ? cGold : cAsh,
                            width: active ? 1.5 : 1,
                          ),
                          color: active
                              ? cGold.withValues(alpha: 0.08)
                              : Colors.transparent,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _DiceGlyph(
                              sides: d.sides,
                              color: active ? cGold : cSmoke,
                              size: 26,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              d.label,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: active ? cGold : cSmoke,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Count selector
                const Text(
                  'HOW MANY',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(
                        () => _diceCount = (_diceCount - 1).clamp(1, 10),
                      ),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          border: Border.all(color: cAsh),
                        ),
                        child: const Icon(
                          Icons.remove,
                          color: cSmoke,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$_diceCount',
                      style: const TextStyle(
                        fontSize: 22,
                        color: cParchment,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => setState(
                        () => _diceCount = (_diceCount + 1).clamp(1, 10),
                      ),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          border: Border.all(color: cAsh),
                        ),
                        child: const Icon(Icons.add, color: cSmoke, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      // Roll button
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: GestureDetector(
          onTap: _roll,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            color: cParchment,
            child: Center(
              child: Text(
                'Roll $_diceCount${_selectedDice.label}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: cVoid,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  void _roll() {
    int total = 0;
    final rolls = <int>[];
    for (int i = 0; i < _diceCount; i++) {
      final r = _rnd.nextInt(_selectedDice.sides) + 1;
      rolls.add(r);
      total += r;
    }
    final label = _diceCount == 1
        ? _selectedDice.label
        : '$_diceCount${_selectedDice.label}';
    final detail = _diceCount > 1 ? ' (${rolls.join(' + ')})' : '';
    setState(() {
      _lastRoll = total;
      _rollLabel = label;
      _showRollResult = true;
    });
    widget.onDiceRolled('🎲 Rolled $label: **$total**$detail');
  }

  // ════════════ IMPORT ════════════
  Widget _buildImportTab() => ScrollConfiguration(
    behavior: NoGlowBehavior(),
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Imported worlds
        const Text(
          'WORLDS IN THIS RP',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Imported for quick reference during the session.',
          style: TextStyle(
            fontSize: 11,
            color: cSmoke,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.importedWorlds.map((w) => _importedWorldCard(w)),
        // Available to import
        ...widget.availableWorlds
            .where((w) => !widget.importedWorlds.any((i) => i.id == w.id))
            .map((w) => _availableWorldCard(w)),
        if (widget.availableWorlds.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No worlds in your sandbox yet.',
              style: TextStyle(
                fontSize: 12,
                color: cSmoke,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        const SizedBox(height: 20),
        const Divider(color: cAsh),
        const SizedBox(height: 12),

        // Imported characters
        const Text(
          'CHARACTERS IN THIS RP',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.importedCharacters.map((c) => _importedCharacterCard(c)),
        ...widget.availableCharacters
            .where((c) => !widget.importedCharacters.any((i) => i.id == c.id))
            .map((c) => _availableCharacterCard(c)),
        if (widget.availableCharacters.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No characters in your sandbox yet.',
              style: TextStyle(
                fontSize: 12,
                color: cSmoke,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 40),
      ],
    ),
  );

  Widget _importedWorldCard(WorldEntry w) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      border: Border.all(color: cGold.withValues(alpha: 0.4)),
      color: cGold.withValues(alpha: 0.05),
    ),
    child: Row(
      children: [
        const Icon(Icons.public, size: 14, color: cGold),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: cParchment,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w300,
                ),
              ),
              if (w.genre.isNotEmpty)
                Text(
                  w.genre,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => widget.onRemoveWorld(w),
          child: const Icon(
            Icons.remove_circle_outline,
            size: 16,
            color: cSmoke,
          ),
        ),
      ],
    ),
  );

  Widget _availableWorldCard(WorldEntry w) => GestureDetector(
    onTap: () => widget.onImportWorld(w),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: cAsh)),
      child: Row(
        children: [
          const Icon(Icons.public_outlined, size: 14, color: cSmoke),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              w.name,
              style: const TextStyle(
                fontSize: 14,
                color: cMist,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          const Text(
            'Import',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cSmoke,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _importedCharacterCard(CharacterEntry c) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: c.accentColor, width: 2),
        top: BorderSide(color: c.accentColor.withValues(alpha: 0.3)),
        right: BorderSide(color: c.accentColor.withValues(alpha: 0.3)),
        bottom: BorderSide(color: c.accentColor.withValues(alpha: 0.3)),
      ),
      color: c.accentColor.withValues(alpha: 0.05),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: cParchment,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w300,
                ),
              ),
              Text(
                c.type == CharacterType.playerCharacter ? 'PC' : 'NPC',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cSmoke,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        // Remove net as dit MY character is (in my Sandbox by naam).
        // Partner se characters wys GEEN Remove nie - jy kan hulle nie uit die RP haal nie.
        if (widget.availableCharacters.any((a) => a.name.trim().toLowerCase() == c.name.trim().toLowerCase()))
          GestureDetector(
            onTap: () => widget.onRemoveCharacter(c),
            child: const Icon(
              Icons.remove_circle_outline,
              size: 16,
              color: cSmoke,
            ),
          ),
      ],
    ),
  );

  Widget _availableCharacterCard(CharacterEntry c) => GestureDetector(
    onTap: () => widget.onImportCharacter(c),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: cAsh)),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accentColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              c.name,
              style: const TextStyle(
                fontSize: 14,
                color: cMist,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          const Text(
            'Import',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cSmoke,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════
// STAT BLOCK WIDGET
// ════════════════════════════════════════
class _StatBlockWidget extends StatefulWidget {
  final StatBlock block;
  final bool editable;
  final VoidCallback onChanged;
  final VoidCallback onAddStat;
  const _StatBlockWidget({
    super.key,
    required this.block,
    required this.editable,
    required this.onChanged,
    required this.onAddStat,
  });
  @override
  State<_StatBlockWidget> createState() => _StatBlockWidgetState();
}

class _StatBlockWidgetState extends State<_StatBlockWidget> {
  void _openStyle(StatEntry stat) {
    StatStyleSheet.show(context, stat, () {
      if (mounted) setState(() {});
      widget.onChanged();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Block name
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          widget.block.name,
          style: const TextStyle(
            fontSize: 13,
            color: cMist,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
      if (widget.block.useTiles) _buildTiles() else _buildBars(),
      if (widget.editable) ...[
        const SizedBox(height: 10),
        GestureDetector(
          onTap: widget.onAddStat,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: cAsh)),
            child: const Text(
              '+ Add stat',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: cSmoke,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    ],
  );

  Widget _buildTiles() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: widget.block.stats
        .map(
          (stat) => _StatTile(
            stat: stat,
            editable: widget.editable,
            onChanged: () {
              setState(() {});
              widget.onChanged();
            },
          ),
        )
        .toList(),
  );

  Widget _buildBars() {
    final maxOfBlock = widget.block.maxDisplayValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.block.stats
          .map(
            (stat) => _StatBar(
              stat: stat,
              maxOfBlock: maxOfBlock,
              editable: widget.editable,
              onChanged: () {
                setState(() {});
                widget.onChanged();
              },
              onLongPress:
                  widget.editable ? () => _openStyle(stat) : null,
              onDelete: widget.editable
                  ? () {
                      widget.block.stats.remove(stat);
                      setState(() {});
                      widget.onChanged();
                    }
                  : null,
            ),
          )
          .toList(),
    );
  }
}

// ════════════════════════════════════════
// STAT BAR  (custom blocks)
// ════════════════════════════════════════
class _StatBar extends StatelessWidget {
  final StatEntry stat;
  final int maxOfBlock;
  final bool editable;
  final VoidCallback onChanged;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  const _StatBar({
    required this.stat,
    required this.maxOfBlock,
    required this.editable,
    required this.onChanged,
    this.onLongPress,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final trackRatio = (stat.ceiling / maxOfBlock).clamp(0.0, 1.0);
    final valueRatio = (stat.value / maxOfBlock).clamp(0.0, 1.0);

    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name | [-] value [+] | [x]
            Row(
              children: [
                Expanded(
                  child: Text(
                    stat.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: cSmoke,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                if (editable)
                  GestureDetector(
                    onTap: () {
                      if (stat.value > 0) stat.value--;
                      onChanged();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.remove, size: 12, color: cSmoke),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    stat.isPool
                        ? '${stat.value} / ${stat.maxValue}'
                        : '${stat.value}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: cParchment,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                if (editable)
                  GestureDetector(
                    onTap: () {
                      if (!stat.isPool || stat.value < stat.maxValue) {
                        stat.value++;
                      }
                      onChanged();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.add, size: 12, color: cSmoke),
                    ),
                  ),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: cSmoke.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 14,
              width: double.infinity,
              child: CustomPaint(
                painter: _StatBarPainter(
                  trackRatio: trackRatio,
                  valueRatio: valueRatio,
                  color: stat.barColor,
                  style: stat.barStyle,
                  segments: stat.segments,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBarPainter extends CustomPainter {
  final double trackRatio; // 0..1, total width of the bar
  final double valueRatio; // 0..1, filled portion
  final Color color;
  final StatBarStyle style;
  final int segments;

  _StatBarPainter({
    required this.trackRatio,
    required this.valueRatio,
    required this.color,
    required this.style,
    required this.segments,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackW = size.width * trackRatio;
    final valueW = size.width * valueRatio;
    final trackPaint = Paint()..color = cAsh.withValues(alpha: 0.15);
    final fillPaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    switch (style) {
      case StatBarStyle.stripe:
        canvas.drawRect(
            Rect.fromLTWH(0, 0, trackW, size.height), trackPaint);
        canvas.drawRect(
            Rect.fromLTWH(0, 0, valueW, size.height), fillPaint);
        canvas.drawRect(
          Rect.fromLTWH(0.5, 0.5, trackW - 1, size.height - 1),
          borderPaint,
        );
        break;

      case StatBarStyle.cuts:
        canvas.drawRect(
            Rect.fromLTWH(0, 0, trackW, size.height), trackPaint);
        canvas.drawRect(
            Rect.fromLTWH(0, 0, valueW, size.height), fillPaint);
        final cutPaint = Paint()
          ..color = cVoid.withValues(alpha: 0.8)
          ..strokeWidth = 1;
        for (int i = 1; i < segments; i++) {
          final x = trackW * i / segments;
          canvas.drawLine(
              Offset(x, 0), Offset(x, size.height), cutPaint);
        }
        canvas.drawRect(
          Rect.fromLTWH(0.5, 0.5, trackW - 1, size.height - 1),
          borderPaint,
        );
        break;

      case StatBarStyle.blocks:
        const gap = 2.0;
        final blockW = (trackW - gap * (segments - 1)) / segments;
        if (blockW <= 0) return;
        final emptyPaint = Paint()..color = cAsh.withValues(alpha: 0.15);
        for (int i = 0; i < segments; i++) {
          final x = i * (blockW + gap);
          final blockStart = x;
          final blockEnd = x + blockW;

          if (blockEnd <= valueW) {
            canvas.drawRect(
                Rect.fromLTWH(blockStart, 0, blockW, size.height),
                fillPaint);
          } else if (blockStart < valueW) {
            final partialW = valueW - blockStart;
            canvas.drawRect(
                Rect.fromLTWH(blockStart, 0, blockW, size.height),
                emptyPaint);
            canvas.drawRect(
                Rect.fromLTWH(blockStart, 0, partialW, size.height),
                fillPaint);
          } else {
            canvas.drawRect(
                Rect.fromLTWH(blockStart, 0, blockW, size.height),
                emptyPaint);
          }

          canvas.drawRect(
            Rect.fromLTWH(
                blockStart + 0.5, 0.5, blockW - 1, size.height - 1),
            Paint()
              ..color = color.withValues(alpha: 0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _StatBarPainter old) =>
      old.trackRatio != trackRatio ||
      old.valueRatio != valueRatio ||
      old.color != color ||
      old.style != style ||
      old.segments != segments;
}

class _StatTile extends StatelessWidget {
  final StatEntry stat;
  final bool editable;
  final VoidCallback onChanged;
  const _StatTile({
    required this.stat,
    required this.editable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 96,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    decoration: BoxDecoration(
      color: cVoid,
      border: Border.all(color: cAsh),
    ),
    child: Column(
      children: [
        Text(
          stat.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            color: cSmoke,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        if (stat.isPool)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (editable)
                GestureDetector(
                  onTap: () {
                    if (stat.value > 0) stat.value--;
                    onChanged();
                  },
                  child: const Icon(Icons.remove, size: 11, color: cSmoke),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  '${stat.value}/${stat.maxValue}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: cParchment,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              if (editable)
                GestureDetector(
                  onTap: () {
                    if (stat.value < stat.maxValue) stat.value++;
                    onChanged();
                  },
                  child: const Icon(Icons.add, size: 11, color: cSmoke),
                ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (editable)
                GestureDetector(
                  onTap: () {
                    stat.value--;
                    onChanged();
                  },
                  child: const Icon(Icons.remove, size: 11, color: cSmoke),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    Text(
                      '${stat.value}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: cParchment,
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                    if (stat.value != 10)
                      Text(
                        stat.modifier >= 0
                            ? '+${stat.modifier}'
                            : '${stat.modifier}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: cSmoke,
                        ),
                      ),
                  ],
                ),
              ),
              if (editable)
                GestureDetector(
                  onTap: () {
                    stat.value++;
                    onChanged();
                  },
                  child: const Icon(Icons.add, size: 11, color: cSmoke),
                ),
            ],
          ),
      ],
    ),
  );
}


// ════════════════════════════════════════
// DICE GLYPH
// ════════════════════════════════════════
class _DiceGlyph extends StatelessWidget {
  final int sides;
  final Color color;
  final double size;
  const _DiceGlyph({
    required this.sides,
    required this.color,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _DiceGlyphPainter(sides: sides, color: color),
    ),
  );
}

class _DiceGlyphPainter extends CustomPainter {
  final int sides;
  final Color color;
  _DiceGlyphPainter({required this.sides, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(size.width, size.height) / 2 - 2;

    // d2 — a coin
    if (sides == 2) {
      canvas.drawCircle(Offset(cx, cy), r, fill);
      canvas.drawCircle(Offset(cx, cy), r, stroke);
      return;
    }

    // d100 — two overlapped coins
    if (sides == 100) {
      canvas.drawCircle(Offset(cx, cy - r * 0.28), r * 0.72, fill);
      canvas.drawCircle(Offset(cx, cy - r * 0.28), r * 0.72, stroke);
      canvas.drawCircle(Offset(cx, cy + r * 0.28), r * 0.72, fill);
      canvas.drawCircle(Offset(cx, cy + r * 0.28), r * 0.72, stroke);
      return;
    }

    int pts;
    double rotation;
    switch (sides) {
      case 4:  pts = 3; rotation = -pi / 2; break;   // triangle, point up
      case 6:  pts = 4; rotation = -pi / 4; break;   // square
      case 8:  pts = 4; rotation = -pi / 2; break;   // diamond
      case 10: pts = 5; rotation = -pi / 2; break;   // pentagon, point up
      case 12: pts = 5; rotation =  pi / 2; break;   // pentagon, point down
      case 20: pts = 6; rotation = -pi / 2; break;   // hexagon
      default: pts = 6; rotation = -pi / 2; break;
    }

    final path = Path();
    for (int i = 0; i < pts; i++) {
      final angle = rotation + (2 * pi * i / pts);
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    // Inner detail for d20 — reads as an icosahedron
    if (sides == 20) {
      final inner = Path();
      for (int i = 0; i < pts; i++) {
        final angle = rotation + (2 * pi * i / pts);
        final x = cx + r * 0.45 * cos(angle);
        final y = cy + r * 0.45 * sin(angle);
        if (i == 0) {
          inner.moveTo(x, y);
        } else {
          inner.lineTo(x, y);
        }
      }
      inner.close();
      canvas.drawPath(inner, stroke);
    }
  }

  @override
  bool shouldRepaint(_DiceGlyphPainter old) =>
      old.sides != sides || old.color != color;
}


// ════════════════════════════════════════
// STAT STYLE SHEET
// ════════════════════════════════════════
class StatStyleSheet extends StatefulWidget {
  final StatEntry stat;
  final VoidCallback onChanged;
  const StatStyleSheet({
    super.key,
    required this.stat,
    required this.onChanged,
  });

  static Future<void> show(
      BuildContext context, StatEntry stat, VoidCallback onChanged) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (_) =>
          StatStyleSheet(stat: stat, onChanged: onChanged),
    );
  }

  @override
  State<StatStyleSheet> createState() => _StatStyleSheetState();
}

class _StatStyleSheetState extends State<StatStyleSheet> {
  late TextEditingController _nameCtrl;
  late Color _color;
  late StatBarStyle _style;
  late int _segments;

  static const _colorOptions = [
    Color(0xFFD4614A), // red / health
    Color(0xFF7AB8D4), // blue / stamina
    Color(0xFFC9A96E), // gold
    Color(0xFF7BAF7B), // green
    Color(0xFF9B7BC4), // purple
    Color(0xFFE0C9A0), // parchment
    Color(0xFFB0B0B0), // grey
    Color(0xFFFFFFFF), // white
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.stat.name);
    _color = widget.stat.barColor;
    _style = widget.stat.barStyle;
    _segments = widget.stat.segments;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final trimmed = _nameCtrl.text.trim();
    if (trimmed.isNotEmpty) widget.stat.name = trimmed;
    widget.stat.barColor = _color;
    widget.stat.barStyle = _style;
    widget.stat.segments = _segments;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
        decoration: const BoxDecoration(
          color: cInk,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: cAsh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'STAT STYLE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: cGold,
                      letterSpacing: 4,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        size: 18, color: cSmoke),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Live preview
              _buildPreview(),
              const SizedBox(height: 20),

              // Name
              _label('Name'),
              TextField(
                controller: _nameCtrl,
                onChanged: (_) {
                  setState(() {});
                  _apply();
                },
                style: const TextStyle(
                  fontSize: 15,
                  color: cParchment,
                  fontStyle: FontStyle.italic,
                ),
                decoration: const InputDecoration(
                  hintText: 'HP, Armour, Sanity...',
                  hintStyle: TextStyle(
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

              // Colour
              _label('Colour'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colorOptions
                    .map((c) => GestureDetector(
                          onTap: () {
                            setState(() => _color = c);
                            _apply();
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color == c
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Style
              _label('Style'),
              const SizedBox(height: 10),
              Row(
                children: [
                  _styleChip('Stripe', StatBarStyle.stripe),
                  const SizedBox(width: 6),
                  _styleChip('Cuts', StatBarStyle.cuts),
                  const SizedBox(width: 6),
                  _styleChip('Blocks', StatBarStyle.blocks),
                ],
              ),
              const SizedBox(height: 20),

              // Segments
              if (_style != StatBarStyle.stripe) ...[
                _label('Segments'),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _segments.toDouble().clamp(2, 50),
                        min: 2,
                        max: 50,
                        divisions: 48,
                        activeColor: cGold,
                        inactiveColor: cAsh,
                        label: '$_segments',
                        onChanged: (v) {
                          setState(() => _segments = v.round());
                          _apply();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$_segments',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: cSmoke,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              const SizedBox(height: 8),
              const Text(
                'Long-press any bar to edit it later.',
                style: TextStyle(
                  fontSize: 11,
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),

              // Done
              GestureDetector(
                onTap: () {
                  _apply();
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: cParchment,
                  child: const Center(
                    child: Text(
                      'Done',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    // Show the bar at full width so the user can see their style.
    return SizedBox(
      height: 22,
      child: CustomPaint(
        painter: _StatBarPainter(
          trackRatio: 1.0,
          valueRatio: widget.stat.value /
              (widget.stat.ceiling == 0 ? 1 : widget.stat.ceiling),
          color: _color,
          style: _style,
          segments: _segments,
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cSmoke,
            letterSpacing: 3,
          ),
        ),
      );

  Widget _styleChip(String label, StatBarStyle style) {
    final active = _style == style;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _style = style);
          _apply();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                active ? cGold.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(color: active ? cGold : cAsh),
          ),
          child: Center(
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
        ),
      ),
    );
  }
}


// ════════════════════════════════════════
// FULL SCREEN STATS VIEWER
// ════════════════════════════════════════
class StatsViewerScreen extends StatelessWidget {
  final StatBlock? myStats;
  final StatBlock? partnerStats;
  final String partnerName;

  const StatsViewerScreen({
    super.key,
    required this.myStats,
    required this.partnerStats,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appSettings.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: cAsh)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back_ios, color: cSmoke, size: 16),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'SESSION STATS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: cGold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ScrollConfiguration(
                behavior: NoGlowBehavior(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── MY STATS ──
                      _sectionHeader('YOUR STATS'),
                      const SizedBox(height: 12),
                      if (myStats != null)
                        _StatBlockWidget(
                          block: myStats!,
                          editable: false,
                          onChanged: () {},
                          onAddStat: () {},
                        )
                      else
                        const _EmptyStatState(message: 'You haven\'t set up your stats yet.'),
                      
                      const SizedBox(height: 32),
                      const Divider(color: cAsh),
                      const SizedBox(height: 32),

                      // ── PARTNER STATS ──
                      _sectionHeader('$partnerName\'S STATS'),
                      const SizedBox(height: 12),
                      if (partnerStats != null)
                        _StatBlockWidget(
                          block: partnerStats!,
                          editable: false,
                          onChanged: () {},
                          onAddStat: () {},
                        )
                      else
                        _EmptyStatState(message: '$partnerName hasn\'t set up their stats yet.'),
                        
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: cGold,
        letterSpacing: 4,
      ),
    );
  }
}

class _EmptyStatState extends StatelessWidget {
  final String message;
  const _EmptyStatState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: cAsh),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          color: cSmoke,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}