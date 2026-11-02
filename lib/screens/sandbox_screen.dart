import 'package:flutter/material.dart';
import '../theme.dart';
import '../settings.dart';
import '../models/world.dart';
import '../services/firestore_service.dart';
import '../services/sandbox_sync.dart';
import '../widgets/colour_picker.dart';
import 'dart:math';

class IdeaGenerator {
  static final _rnd = Random();

  // ── WORLD LISTS ──
  static const _worldNames = ['Aethelgard', 'Oakhaven', 'The Shattered Reach', 'The Iron Spire', 'Umbral', 'The Verdant Abyss', 'Solara', 'The Ashlands', 'Eldergrove', 'New Tethys'];
  static const _genres = ['Fantasy', 'Sci-Fi', 'Cyberpunk', 'Gothic Horror', 'Steampunk', 'Modern', 'Post-Apocalyptic', 'Mythological'];
  static const _tones = ['Gritty and cynical', 'Hopeful but fragile', 'Dark and oppressive', 'Whimsical and strange', 'Epic and grand', 'Melancholic and quiet'];
  static const _worldSettings = [
    'A floating city powered by stolen memories.',
    'A desert where the sand is actually crushed bone.',
    'A forest where the trees move when you sleep.',
    'An underwater metropolis ruled by a drowned queen.',
    'A space station where time moves backwards.',
    'A town where everyone shares the same dream.',
  ];
  static const _worldHooks = [
    'The sun has stopped rising, and the crops are dying.',
    'Magic is real, but every spell costs a year of your life.',
    'A plague turns people into living statues of gold.',
    'The gods are dead, and their corpses are falling from the sky.',
    'A door appeared in the middle of the town square yesterday.',
  ];
  static const _worldRules = [
    'No iron or steel can be brought into the city.',
    'Lying causes physical pain.',
    'The dead must be burned before nightfall.',
    'Magic only works in the dark.',
    'Contracts are magically binding, with no exceptions.',
  ];
  static const _worldHistory = [
    'The old empire collapsed a century ago, leaving its ruins behind.',
    'A great war was fought over the control of the sun.',
    'The current ruler usurped the throne from their sibling.',
    'A cataclysmic event reshaped the continent, sinking half the world.',
  ];
  static const _factions = ['The Silver Syndicate', 'The Ashen Order', 'The Crown Guard', 'The Whispering Circle', 'The Iron Bank'];
  static const _locations = ['The Broken Bridge', 'The Underbelly Market', 'The Silent Cathedral', 'The Moonlit Docks', 'The Sunken Library'];

  // ── CHARACTER LISTS ──
  static const _firstNames = ['Kaelen', 'Lyra', 'Thorne', 'Elara', 'Dorian', 'Seraphina', 'Riven', 'Isolde', 'Vane', 'Maeve'];
  static const _lastNames = ['Blackwood', 'Ironheart', 'Stormwind', 'Vane', 'Shadowmere', 'Ashford', 'Moonfall', 'Greyjoy', 'Thorne', 'Silver'];
  static const _pronouns = ['she/her', 'he/him', 'they/them', 'any'];
  static const _ages = ['18', '22', '25', '30', '35', '40', '100+', 'Unknown'];
  static const _appearances = ['Tall and gaunt with scarred hands.', 'Short and compact, always wearing a heavy coat.', 'Elegant, with silver hair that glows faintly.', 'Rugged, with a mechanical eye.', 'Unremarkable, able to blend into any crowd.'];
  static const _personalities = ['Cold and calculating, but fiercely loyal.', 'Optimistic to a fault, even in the darkest times.', 'Quick to anger but equally quick to forgive.', 'Quiet, observant, and incredibly stubborn.', 'Charming and manipulative, always looking for an angle.'];
  static const _quirks = [
    'Cannot tell a lie, even to save their life.',
    'Collects the teeth of fallen enemies.',
    'Is deathly afraid of the dark, despite being a monster.',
    'Hears the thoughts of animals, but not humans.',
    'Has a mechanical arm that acts on its own.',
  ];
  static const _backstories = ['Orphaned at a young age and raised by thieves.', 'A former soldier who fled the battlefield.', 'Searching for a sibling who vanished years ago.', 'Escaped from a secret laboratory with no memory of before.', 'Born into nobility but disowned for a forbidden romance.'];
  static const _relationships = ['Has a rival who wants them dead.', 'Secretly in love with their partner.', 'Owes a massive debt to a dangerous crime lord.', 'Trusts no one but their pet.', 'Protects a younger sibling at all costs.'];

  static String get randomWorldName => _worldNames[_rnd.nextInt(_worldNames.length)];
  static String get randomGenre => _genres[_rnd.nextInt(_genres.length)];
  static String get randomTone => _tones[_rnd.nextInt(_tones.length)];
  static String get randomSetting => _worldSettings[_rnd.nextInt(_worldSettings.length)];
  static String get randomHook => _worldHooks[_rnd.nextInt(_worldHooks.length)];
  static String get randomRule => _worldRules[_rnd.nextInt(_worldRules.length)];
  static String get randomHistory => _worldHistory[_rnd.nextInt(_worldHistory.length)];
  static String get randomFaction => _factions[_rnd.nextInt(_factions.length)];
  static String get randomLocation => _locations[_rnd.nextInt(_locations.length)];

  static String get randomCharName => '${_firstNames[_rnd.nextInt(_firstNames.length)]} ${_lastNames[_rnd.nextInt(_lastNames.length)]}';
  static String get randomPronouns => _pronouns[_rnd.nextInt(_pronouns.length)];
  static String get randomAge => _ages[_rnd.nextInt(_ages.length)];
  static String get randomAppearance => _appearances[_rnd.nextInt(_appearances.length)];
  static String get randomPersonality => _personalities[_rnd.nextInt(_personalities.length)];
  static String get randomQuirk => _quirks[_rnd.nextInt(_quirks.length)];
  static String get randomBackstory => _backstories[_rnd.nextInt(_backstories.length)];
  static String get randomRelationship => _relationships[_rnd.nextInt(_relationships.length)];
}

// ════════════════════════════════════════
// SANDBOX SCREEN  (top-level, two tabs)
// ════════════════════════════════════════
class SandboxScreen extends StatefulWidget {
  const SandboxScreen({super.key});
  @override
  State<SandboxScreen> createState() => _SandboxScreenState();
}

class _SandboxScreenState extends State<SandboxScreen>
    with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();
  late TabController _tab;
  List<WorldEntry> _worlds = [];
  List<CharacterEntry> _characters = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    appSettings.addListener(_rebuild);
    _loadData();
  }

  Future<void> _loadData() async {
    final worlds = await SandboxStorage.loadWorlds();
    final chars = await SandboxStorage.loadCharacters();
    if (mounted) {
      setState(() {
        _worlds = worlds;
        _characters = chars;
        _loaded = true;
      });
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appSettings.removeListener(_rebuild);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appSettings.bgColor,
    body: SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          _buildTabBar(),
          Expanded(
            child: !_loaded
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cSmoke,
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tab,
                    children: [
                      _WorldsTab(
                        worlds: _worlds,
                        onAdd: _addWorld,
                        onEdit: _editWorld,
                        onDelete: _deleteWorld,
                      ),
                      _CharactersTab(
                        characters: _characters,
                        worlds: _worlds,
                        onAdd: _addCharacter,
                        onEdit: _editCharacter,
                        onDelete: _deleteCharacter,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
    floatingActionButton: _buildFAB(),
  );

  Widget _buildTopBar() => Container(
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
        const SizedBox(width: 12),
        const Text(
          'Sandbox',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.italic,
            color: cParchment,
          ),
        ),
        const Spacer(),
              GestureDetector(
        onTap: _showIdeaGenerator,
        child: Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: cGold.withValues(alpha: 0.5)),
            color: cGold.withValues(alpha: 0.1),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: cGold),
              SizedBox(width: 6),
              Text('SPARK', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 2)),
            ],
          ),
        ),
      ),
        const Text(
          'L o r e',
          style: TextStyle(
            fontSize: 11,
            color: cGold,
            letterSpacing: 5,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    ),
    
  );

  Widget _buildTabBar() => Container(
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
        fontSize: 10,
        letterSpacing: 3,
      ),
      tabs: const [
        Tab(text: 'WORLDS'),
        Tab(text: 'CHARACTERS'),
      ],
    ),
  );

  Widget _buildFAB() => AnimatedBuilder(
    animation: _tab,
    builder: (_, _) => GestureDetector(
      onTap: _tab.index == 0 ? _addWorld : _addCharacter,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: cInk,
          border: Border.all(color: cGold),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: cGold, size: 22),
      ),
    ),
  );

  // ── World CRUD ──
  void _addWorld() => _openWorldEditor(null);
  void _editWorld(WorldEntry w) => _openWorldEditor(w);
  void _deleteWorld(String id) {
    setState(() => _worlds.removeWhere((w) => w.id == id));
    SandboxStorage.saveWorlds(_worlds);
    SandboxSync.pushWorlds(_worlds);
    _fs.incrementUserCounter('worldsCreated', -1);
  }

  void _openWorldEditor(WorldEntry? existing) {
    Navigator.of(context).push(
      fadeRoute(
        WorldEditorScreen(
          world: existing,
          onSave: (w) {
            final isNew = existing == null;
            setState(() {
              if (existing != null) {
                final i = _worlds.indexWhere((x) => x.id == existing.id);
                if (i != -1) {
                  _worlds[i] = w;
                } else {
                  _worlds.insert(0, w);
                }
              } else {
                _worlds.insert(0, w);
              }
            });
            SandboxStorage.saveWorlds(_worlds);
            SandboxSync.pushWorlds(_worlds);
            if (isNew) _fs.incrementUserCounter('worldsCreated', 1);
          },
        ),
      ),
    );
  }

  // ── Character CRUD ──
  void _addCharacter() => _openCharacterEditor(null);
  void _editCharacter(CharacterEntry c) => _openCharacterEditor(c);
  void _deleteCharacter(String id) {
    setState(() => _characters.removeWhere((c) => c.id == id));
    SandboxStorage.saveCharacters(_characters);
    SandboxSync.pushCharacters(_characters);
    _fs.incrementUserCounter('charactersCreated', -1);
  }

  void _openCharacterEditor(CharacterEntry? existing) {
    Navigator.of(context).push(
      fadeRoute(
        CharacterEditorScreen(
          character: existing,
          worlds: _worlds,
          onSave: (c) {
            final isNew = existing == null;
            setState(() {
              if (existing != null) {
                final i = _characters.indexWhere((x) => x.id == existing.id);
                if (i != -1) {
                  _characters[i] = c;
                } else {
                  _characters.insert(0, c);
                }
              } else {
                _characters.insert(0, c);
              }
            });
            SandboxStorage.saveCharacters(_characters);
            SandboxSync.pushCharacters(_characters);
            if (isNew) _fs.incrementUserCounter('charactersCreated', 1);
          },
        ),
      ),
    );
  }
    void _showIdeaGenerator() {
    // ── STATE VARIABLES (Moved outside the builder) ──
    String wName = IdeaGenerator.randomWorldName;
    String wGenre = IdeaGenerator.randomGenre;
    String wTone = IdeaGenerator.randomTone;
    String wSetting = IdeaGenerator.randomSetting;
    String wHook = IdeaGenerator.randomHook;
    String wRule = IdeaGenerator.randomRule;
    String wHistory = IdeaGenerator.randomHistory;
    String f1 = IdeaGenerator.randomFaction;
    String f2 = IdeaGenerator.randomFaction;
    String l1 = IdeaGenerator.randomLocation;
    String l2 = IdeaGenerator.randomLocation;

    String cName = IdeaGenerator.randomCharName;
    String cPronouns = IdeaGenerator.randomPronouns;
    String cAge = IdeaGenerator.randomAge;
    String cAppearance = IdeaGenerator.randomAppearance;
    String cPersonality = IdeaGenerator.randomPersonality;
    String cQuirk = IdeaGenerator.randomQuirk;
    String cBackstory = IdeaGenerator.randomBackstory;
    String cRelationship = IdeaGenerator.randomRelationship;

    bool isWorld = true;
    // ────────────────────────────────────────────────

    showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SPARK AN IDEA', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: cGold, letterSpacing: 4)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isWorld = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isWorld ? cGold.withValues(alpha: 0.1) : Colors.transparent,
                            border: Border.all(color: isWorld ? cGold : cAsh),
                          ),
                          child: Center(child: Text('WORLD', style: TextStyle(color: isWorld ? cGold : cSmoke, fontFamily: 'monospace', fontSize: 10))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isWorld = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isWorld ? cGold.withValues(alpha: 0.1) : Colors.transparent,
                            border: Border.all(color: !isWorld ? cGold : cAsh),
                          ),
                          child: Center(child: Text('CHARACTER', style: TextStyle(color: !isWorld ? cGold : cSmoke, fontFamily: 'monospace', fontSize: 10))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cVoid, border: Border.all(color: cAsh)),
                      child: isWorld
                          ? _buildWorldPrompt(wName, wGenre, wTone, wSetting, wHook, wRule, wHistory, f1, f2, l1, l2)
                          : _buildCharPrompt(cName, cPronouns, cAge, cAppearance, cPersonality, cQuirk, cBackstory, cRelationship),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setModalState(() {
                            wName = IdeaGenerator.randomWorldName;
                            wGenre = IdeaGenerator.randomGenre;
                            wTone = IdeaGenerator.randomTone;
                            wSetting = IdeaGenerator.randomSetting;
                            wHook = IdeaGenerator.randomHook;
                            wRule = IdeaGenerator.randomRule;
                            wHistory = IdeaGenerator.randomHistory;
                            f1 = IdeaGenerator.randomFaction;
                            f2 = IdeaGenerator.randomFaction;
                            l1 = IdeaGenerator.randomLocation;
                            l2 = IdeaGenerator.randomLocation;

                            cName = IdeaGenerator.randomCharName;
                            cPronouns = IdeaGenerator.randomPronouns;
                            cAge = IdeaGenerator.randomAge;
                            cAppearance = IdeaGenerator.randomAppearance;
                            cPersonality = IdeaGenerator.randomPersonality;
                            cQuirk = IdeaGenerator.randomQuirk;
                            cBackstory = IdeaGenerator.randomBackstory;
                            cRelationship = IdeaGenerator.randomRelationship;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(border: Border.all(color: cAsh)),
                          child: const Center(child: Text('Reroll', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cSmoke, letterSpacing: 2))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          if (isWorld) {
                            final newWorld = WorldEntry(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              name: wName,
                              genre: wGenre,
                              tone: wTone,
                              overview: '$wSetting\n\n$wHook',
                              history: wHistory,
                              rules: wRule,
                              locations: [WorldLocation(name: l1, description: 'A key location in $wName.'), WorldLocation(name: l2, description: 'A dangerous place.')],
                              factions: [WorldFaction(name: f1, description: 'Controls the region.'), WorldFaction(name: f2, description: 'A secret society.')],
                            );
                            _openWorldEditor(newWorld);
                          } else {
                            final newChar = CharacterEntry(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              name: cName,
                              pronouns: cPronouns,
                              age: cAge,
                              appearance: cAppearance,
                              personality: '$cPersonality\n\nQuirk: $cQuirk',
                              backstory: cBackstory,
                              relationships: cRelationship,
                            );
                            _openCharacterEditor(newChar);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: cGold,
                          child: const Center(child: Text('Use this idea', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cVoid, letterSpacing: 1))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorldPrompt(String name, String genre, String tone, String setting, String hook, String rule, String history, String f1, String f2, String l1, String l2) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 2)),
        Text('$genre · $tone', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: cSmoke)),
        const SizedBox(height: 16),
        Text(setting, style: const TextStyle(fontSize: 15, color: cParchment, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, height: 1.5)),
        const SizedBox(height: 12),
        Text('HOOK: $hook', style: const TextStyle(fontSize: 13, color: cMist, height: 1.5)),
        const SizedBox(height: 12),
        Text('RULE: $rule', style: const TextStyle(fontSize: 13, color: cMist, height: 1.5)),
        const SizedBox(height: 12),
        Text('HISTORY: $history', style: const TextStyle(fontSize: 13, color: cMist, height: 1.5)),
        const SizedBox(height: 12),
        Text('LOCATIONS: $l1, $l2', style: const TextStyle(fontSize: 13, color: cMist, height: 1.5)),
        const SizedBox(height: 12),
        Text('FACTIONS: $f1, $f2', style: const TextStyle(fontSize: 13, color: cMist, height: 1.5)),
      ],
    );
  }

  Widget _buildCharPrompt(String name, String pronouns, String age, String appearance, String personality, String quirk, String backstory, String relationship) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 2)),
        Text('$pronouns · $age', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: cSmoke)),
        const SizedBox(height: 16),
        Text(appearance, style: const TextStyle(fontSize: 15, color: cParchment, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, height: 1.5)),
        const SizedBox(height: 12),
        Text('PERSONALITY: $personality', style: const TextStyle(fontSize: 13, color: cMist, height: 1.5)),
        const SizedBox(height: 12),
        Text('QUIRK: $quirk', style: const TextStyle(fontSize: 13, color: cMist, height: 1.5)),
        const SizedBox(height: 12),
        Text('BACKSTORY: $backstory', style: const TextStyle(fontSize: 13, color: cMist, height: 1.5)),
        const SizedBox(height: 12),
        Text('RELATIONSHIP: $relationship', style: const TextStyle(fontSize: 13, color: cMist, height: 1.5)),
      ],
    );
  }
} // <--- THIS CLOSES _SandboxScreenState

// ════════════════════════════════════════
// WORLDS TAB
// ════════════════════════════════════════
class _WorldsTab extends StatelessWidget {
  final List<WorldEntry> worlds;
  final VoidCallback onAdd;
  final void Function(WorldEntry) onEdit;
  final void Function(String) onDelete;
  const _WorldsTab({
    required this.worlds,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (worlds.isEmpty) {
      return _emptyState('No worlds yet.', 'Tap + to start building one.');
    }
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: worlds.length,
        itemBuilder: (_, i) => _WorldCard(
          world: worlds[i],
          onTap: () => onEdit(worlds[i]),
          onDelete: () => onDelete(worlds[i].id),
        ),
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  final WorldEntry world;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _WorldCard({
    required this.world,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onLongPress: () => _showActions(context),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cInk,
        border: Border.all(
          color: world.isDraft ? cAsh : cGold.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  world.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                    color: cParchment,
                  ),
                ),
              ),
              if (world.isDraft)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(border: Border.all(color: cAsh)),
                  child: const Text(
                    'DRAFT',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8,
                      color: cSmoke,
                      letterSpacing: 2,
                    ),
                  ),
                ),
            ],
          ),
          if (world.genre.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              world.genre,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: cGold,
                letterSpacing: 2,
              ),
            ),
          ],
          if (world.overview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              world.overview.length > 120
                  ? '${world.overview.substring(0, 120)}...'
                  : world.overview,
              style: const TextStyle(
                fontSize: 13,
                color: cMist,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _pill('${world.locations.length} locations', cSmoke),
              const SizedBox(width: 6),
              _pill('${world.factions.length} factions', cSmoke),
              const Spacer(),
              const Icon(Icons.chevron_right, color: cSmoke, size: 16),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 9,
        color: color,
        letterSpacing: 1,
      ),
    ),
  );

  void _showActions(BuildContext context) => showModalBottomSheet(
    context: context,
    backgroundColor: cInk,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: cAsh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          _sheetAction(context, Icons.edit_outlined, 'Edit world', onTap),
          _sheetAction(
            context,
            Icons.delete_outline,
            'Delete world',
            onDelete,
            color: cEmber,
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════
// CHARACTERS TAB
// ════════════════════════════════════════
class _CharactersTab extends StatelessWidget {
  final List<CharacterEntry> characters;
  final List<WorldEntry> worlds;
  final VoidCallback onAdd;
  final void Function(CharacterEntry) onEdit;
  final void Function(String) onDelete;
  const _CharactersTab({
    required this.characters,
    required this.worlds,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) {
      return _emptyState('No characters yet.', 'Tap + to create one.');
    }
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: characters.length,
        itemBuilder: (_, i) {
          final c = characters[i];
          final linkedWorld = worlds
              .where((w) => w.id == c.linkedWorldId)
              .firstOrNull;
          return _CharacterCard(
            character: c,
            linkedWorld: linkedWorld,
            onTap: () => onEdit(c),
            onDelete: () => onDelete(c.id),
          );
        },
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final CharacterEntry character;
  final WorldEntry? linkedWorld;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _CharacterCard({
    required this.character,
    required this.linkedWorld,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onLongPress: () => _showActions(context),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cInk,
        border: Border(
          left: BorderSide(color: character.accentColor, width: 2),
          top: const BorderSide(color: cAsh),
          right: const BorderSide(color: cAsh),
          bottom: const BorderSide(color: cAsh),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Initials circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: character.accentColor.withValues(alpha: 0.5),
                ),
              ),
              child: Center(
                child: Text(
                  character.name.isNotEmpty
                      ? character.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 18,
                    color: character.accentColor,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        character.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w300,
                          fontStyle: FontStyle.italic,
                          color: cParchment,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                character.type == CharacterType.playerCharacter
                                ? cGold.withValues(alpha: 0.4)
                                : cMagic.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          character.type == CharacterType.playerCharacter
                              ? 'PC'
                              : 'NPC',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 8,
                            letterSpacing: 1,
                            color:
                                character.type == CharacterType.playerCharacter
                                ? cGold
                                : cMagic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (character.pronouns.isNotEmpty ||
                      character.age.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (character.pronouns.isNotEmpty) character.pronouns,
                        if (character.age.isNotEmpty) character.age,
                      ].join(' · '),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: cSmoke,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                  if (linkedWorld != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '↳ ${linkedWorld!.name}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: cSmoke,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: cSmoke, size: 16),
          ],
        ),
      ),
    ),
  );

  void _showActions(BuildContext context) => showModalBottomSheet(
    context: context,
    backgroundColor: cInk,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: cAsh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          _sheetAction(context, Icons.edit_outlined, 'Edit character', onTap),
          _sheetAction(
            context,
            Icons.delete_outline,
            'Delete character',
            onDelete,
            color: cEmber,
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════
// WORLD EDITOR SCREEN
// ════════════════════════════════════════
class WorldEditorScreen extends StatefulWidget {
  final WorldEntry? world;
  final void Function(WorldEntry) onSave;
  const WorldEditorScreen({super.key, this.world, required this.onSave});
  @override
  State<WorldEditorScreen> createState() => _WorldEditorScreenState();
}

class _WorldEditorScreenState extends State<WorldEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late WorldEntry _working;

  // Controllers for each field
  late TextEditingController _nameCtrl,
      _genreCtrl,
      _overviewCtrl,
      _toneCtrl,
      _historyCtrl,
      _rulesCtrl,
      _notesCtrl;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    final w = widget.world;
    _working = w != null
        ? WorldEntry(
            id: w.id,
            name: w.name,
            genre: w.genre,
            overview: w.overview,
            tone: w.tone,
            locations: List.from(w.locations),
            factions: List.from(w.factions),
            history: w.history,
            rules: w.rules,
            notes: w.notes,
            isDraft: w.isDraft,
          )
        : WorldEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: '',
          );
    _nameCtrl = TextEditingController(text: _working.name);
    _genreCtrl = TextEditingController(text: _working.genre);
    _overviewCtrl = TextEditingController(text: _working.overview);
    _toneCtrl = TextEditingController(text: _working.tone);
    _historyCtrl = TextEditingController(text: _working.history);
    _rulesCtrl = TextEditingController(text: _working.rules);
    _notesCtrl = TextEditingController(text: _working.notes);
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [
      _nameCtrl,
      _genreCtrl,
      _overviewCtrl,
      _toneCtrl,
      _historyCtrl,
      _rulesCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    _working.name = _nameCtrl.text.trim();
    _working.genre = _genreCtrl.text.trim();
    _working.overview = _overviewCtrl.text.trim();
    _working.tone = _toneCtrl.text.trim();
    _working.history = _historyCtrl.text.trim();
    _working.rules = _rulesCtrl.text.trim();
    _working.notes = _notesCtrl.text.trim();
    widget.onSave(_working);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appSettings.bgColor,
    body: SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: cAsh)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: cSmoke, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(
                      fontSize: 20,
                      color: cParchment,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'World name...',
                      hintStyle: TextStyle(
                        color: cSmoke,
                        fontStyle: FontStyle.italic,
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                      ),
                      border: InputBorder.none,
                    ),
                    cursorColor: cGold,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          setState(() => _working.isDraft = !_working.isDraft),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _working.isDraft ? cAsh : cGold,
                          ),
                        ),
                        child: Text(
                          _working.isDraft ? 'DRAFT' : 'READY',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            letterSpacing: 2,
                            color: _working.isDraft ? cSmoke : cGold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        color: cParchment,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: cVoid,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tab bar
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: cAsh)),
            ),
            child: TabBar(
              controller: _tab,
              isScrollable: true,
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
                Tab(text: 'OVERVIEW'),
                Tab(text: 'LOCATIONS'),
                Tab(text: 'FACTIONS'),
                Tab(text: 'HISTORY'),
                Tab(text: 'RULES'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Overview tab
                _editorScrollable([
                  _field(
                    'Genre',
                    _genreCtrl,
                    hint: 'e.g. Dark Fantasy, Sci-Fi Noir',
                  ),
                  _field(
                    'Overview',
                    _overviewCtrl,
                    maxLines: 6,
                    hint: 'The world in a paragraph...',
                  ),
                  _field(
                    'Tone',
                    _toneCtrl,
                    hint: 'e.g. Dark, morally grey, slow burn',
                  ),
                ]),
                // Locations
                _ListEditor<WorldLocation>(
                  items: _working.locations,
                  labelField: (l) => l.name,
                  descField: (l) => l.description,
                  emptyLabel: 'No locations yet',
                  addLabel: 'Add location',
                  newItem: () => WorldLocation(name: ''),
                  onUpdate: () => setState(() {}),
                ),
                // Factions
                _ListEditor<WorldFaction>(
                  items: _working.factions,
                  labelField: (f) => f.name,
                  descField: (f) => f.description,
                  emptyLabel: 'No factions yet',
                  addLabel: 'Add faction',
                  newItem: () => WorldFaction(name: ''),
                  onUpdate: () => setState(() {}),
                ),
                // History
                _editorScrollable([
                  _field(
                    'History',
                    _historyCtrl,
                    maxLines: 12,
                    hint: 'What happened before the story begins...',
                  ),
                ]),
                // Rules
                _editorScrollable([
                  _field(
                    'World rules',
                    _rulesCtrl,
                    maxLines: 12,
                    hint:
                        'Magic systems, physical laws, what death means here...',
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _editorScrollable(List<Widget> children) => ScrollConfiguration(
    behavior: NoGlowBehavior(),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: children),
    ),
  );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    String hint = '',
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 9,
          color: cGold,
          letterSpacing: 3,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(
          fontSize: 14,
          color: cParchment,
          fontStyle: FontStyle.italic,
          height: 1.7,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: cSmoke,
            fontStyle: FontStyle.italic,
            fontSize: 13,
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: cAsh),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: cSmoke),
          ),
          filled: true,
          fillColor: cInk,
        ),
        cursorColor: cGold,
      ),
      const SizedBox(height: 20),
    ],
  );
}

// Generic list editor for locations/factions
class _ListEditor<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) labelField;
  final String Function(T) descField;
  final String emptyLabel;
  final String addLabel;
  final T Function() newItem;
  final VoidCallback onUpdate;
  const _ListEditor({
    required this.items,
    required this.labelField,
    required this.descField,
    required this.emptyLabel,
    required this.addLabel,
    required this.newItem,
    required this.onUpdate,
  });
  @override
  State<_ListEditor<T>> createState() => _ListEditorState<T>();
}

class _ListEditorState<T> extends State<_ListEditor<T>> {
  int? _editingIndex;

  void _setName(T item, String v) {
    if (item is WorldLocation) item.name = v;
    if (item is WorldFaction) item.name = v;
  }

  void _setDesc(T item, String v) {
    if (item is WorldLocation) item.description = v;
    if (item is WorldFaction) item.description = v;
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: NoGlowBehavior(),
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...List.generate(widget.items.length, (i) {
          final item = widget.items[i];
          final editing = _editingIndex == i;
          final nameCtrl = TextEditingController(text: widget.labelField(item));
          final descCtrl = TextEditingController(text: widget.descField(item));
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: editing ? cSmoke : cAsh),
            ),
            child: editing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(
                          fontSize: 14,
                          color: cParchment,
                          fontStyle: FontStyle.italic,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Name...',
                          hintStyle: TextStyle(color: cSmoke),
                          border: InputBorder.none,
                        ),
                        cursorColor: cGold,
                        onChanged: (v) => _setName(item, v),
                      ),
                      const Divider(color: cAsh),
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        style: const TextStyle(
                          fontSize: 13,
                          color: cMist,
                          fontStyle: FontStyle.italic,
                          height: 1.6,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Description...',
                          hintStyle: TextStyle(color: cSmoke),
                          border: InputBorder.none,
                        ),
                        cursorColor: cGold,
                        onChanged: (v) => _setDesc(item, v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _setName(item, nameCtrl.text);
                              _setDesc(item, descCtrl.text);
                              setState(() => _editingIndex = null);
                              widget.onUpdate();
                            },
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: cGold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() {
                              widget.items.removeAt(i);
                              _editingIndex = null;
                              widget.onUpdate();
                            }),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: cEmber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: () => setState(() => _editingIndex = i),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.labelField(item).isEmpty
                                    ? '(unnamed)'
                                    : widget.labelField(item),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: cParchment,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              if (widget.descField(item).isNotEmpty)
                                Text(
                                  widget.descField(item).length > 60
                                      ? '${widget.descField(item).substring(0, 60)}...'
                                      : widget.descField(item),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: cSmoke,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: cSmoke,
                        ),
                      ],
                    ),
                  ),
          );
        }),
        GestureDetector(
          onTap: () => setState(() {
            widget.items.add(widget.newItem());
            _editingIndex = widget.items.length - 1;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: cAsh, style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, size: 14, color: cSmoke),
                const SizedBox(width: 8),
                Text(
                  widget.addLabel,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: cSmoke,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════
// CHARACTER EDITOR SCREEN
// ════════════════════════════════════════
class CharacterEditorScreen extends StatefulWidget {
  final CharacterEntry? character;
  final List<WorldEntry> worlds;
  final void Function(CharacterEntry) onSave;
  const CharacterEditorScreen({
    super.key,
    this.character,
    required this.worlds,
    required this.onSave,
  });
  @override
  State<CharacterEditorScreen> createState() => _CharacterEditorScreenState();
}

class _CharacterEditorScreenState extends State<CharacterEditorScreen> {
  late CharacterEntry _working;
  late TextEditingController _nameCtrl,
      _pronounsCtrl,
      _ageCtrl,
      _appearanceCtrl,
      _personalityCtrl,
      _backstoryCtrl,
      _relationshipsCtrl,
      _notesCtrl;

  final _accentColors = [
    cGold,
    cIce,
    cEmber,
    cMagic,
    cVine,
    const Color(0xFFa0c4a0),
    const Color(0xFFc4a0a0),
    Colors.white70,
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _working = c != null
        ? CharacterEntry(
            id: c.id,
            name: c.name,
            pronouns: c.pronouns,
            age: c.age,
            appearance: c.appearance,
            personality: c.personality,
            backstory: c.backstory,
            relationships: c.relationships,
            notes: c.notes,
            type: c.type,
            linkedWorldId: c.linkedWorldId,
            accentColor: c.accentColor,
          )
        : CharacterEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: '',
          );
    _nameCtrl = TextEditingController(text: _working.name);
    _pronounsCtrl = TextEditingController(text: _working.pronouns);
    _ageCtrl = TextEditingController(text: _working.age);
    _appearanceCtrl = TextEditingController(text: _working.appearance);
    _personalityCtrl = TextEditingController(text: _working.personality);
    _backstoryCtrl = TextEditingController(text: _working.backstory);
    _relationshipsCtrl = TextEditingController(text: _working.relationships);
    _notesCtrl = TextEditingController(text: _working.notes);
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _pronounsCtrl,
      _ageCtrl,
      _appearanceCtrl,
      _personalityCtrl,
      _backstoryCtrl,
      _relationshipsCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    _working.name = _nameCtrl.text.trim();
    _working.pronouns = _pronounsCtrl.text.trim();
    _working.age = _ageCtrl.text.trim();
    _working.appearance = _appearanceCtrl.text.trim();
    _working.personality = _personalityCtrl.text.trim();
    _working.backstory = _backstoryCtrl.text.trim();
    _working.relationships = _relationshipsCtrl.text.trim();
    _working.notes = _notesCtrl.text.trim();
    widget.onSave(_working);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appSettings.bgColor,
    body: SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: cAsh)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: cSmoke, size: 18),
                ),
                const SizedBox(width: 12),
                // Accent colour dot
                GestureDetector(
                  onTap: _pickAccentColor,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _working.accentColor,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),

                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(
                      fontSize: 20,
                      color: cParchment,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Character name...',
                      hintStyle: TextStyle(
                        color: cSmoke,
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w300,
                      ),
                      border: InputBorder.none,
                    ),
                    cursorColor: cGold,
                  ),
                ),
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    color: cParchment,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: cVoid,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Quick meta row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: cAsh)),
            ),
            child: Row(
              children: [
                // PC / NPC toggle
                GestureDetector(
                  onTap: () => setState(
                    () => _working.type =
                        _working.type == CharacterType.playerCharacter
                        ? CharacterType.npc
                        : CharacterType.playerCharacter,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _working.type == CharacterType.playerCharacter
                            ? cGold
                            : cMagic,
                      ),
                    ),
                    child: Text(
                      _working.type == CharacterType.playerCharacter
                          ? 'Player Character'
                          : 'NPC',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        letterSpacing: 2,
                        color: _working.type == CharacterType.playerCharacter
                            ? cGold
                            : cMagic,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _pronounsCtrl,
                    style: const TextStyle(fontSize: 12, color: cSmoke),
                    decoration: const InputDecoration(
                      hintText: 'Pronouns',
                      hintStyle: TextStyle(color: cSmoke, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    cursorColor: cGold,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _ageCtrl,
                    style: const TextStyle(fontSize: 12, color: cSmoke),
                    decoration: const InputDecoration(
                      hintText: 'Age',
                      hintStyle: TextStyle(color: cSmoke, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    cursorColor: cGold,
                  ),
                ),
              ],
            ),
          ),
          // Linked world
          if (widget.worlds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: cAsh)),
              ),
              child: Row(
                children: [
                  const Text(
                    'World',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: cSmoke,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: NoGlowBehavior(),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _worldChip(null, 'None'),
                            ...widget.worlds.map(
                              (w) => _worldChip(w.id, w.name),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Fields
          Expanded(
            child: ScrollConfiguration(
              behavior: NoGlowBehavior(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _field('Appearance', _appearanceCtrl, maxLines: 4),
                    _field('Personality', _personalityCtrl, maxLines: 4),
                    _field('Backstory', _backstoryCtrl, maxLines: 6),
                    _field('Relationships', _relationshipsCtrl, maxLines: 4),
                    _field('Notes', _notesCtrl, maxLines: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _worldChip(String? id, String label) {
    final active = _working.linkedWorldId == id;
    return GestureDetector(
      onTap: () => setState(() => _working.linkedWorldId = id),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 1,
            color: active ? cGold : cSmoke,
          ),
        ),
      ),
    );
  }

  void _pickAccentColor() {
    LoreColourPicker.show(
      context,
      current: _working.accentColor,
      onPicked: (c) {
        setState(() => _working.accentColor = c);
      },
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cGold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: appSettings.baseFontSize,
              color: cParchment,
              fontStyle: FontStyle.italic,
              height: 1.7,
            ),
            decoration: const InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: cAsh),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: cSmoke),
              ),
              filled: true,
              fillColor: cInk,
            ),
            cursorColor: cGold,
          ),
          const SizedBox(height: 20),
        ],
      );
}

// ── Shared helpers ──
Widget _emptyState(String title, String subtitle) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
          color: cMist,
        ),
      ),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(fontSize: 12, color: cSmoke)),
    ],
  ),
);

Widget _sheetAction(
  BuildContext context,
  IconData icon,
  String label,
  VoidCallback onTap, {
  Color color = cMist,
}) => GestureDetector(
  onTap: () {
    Navigator.of(context).pop();
    onTap();
  },
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: cAsh)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    ),
  ),
);
