import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme.dart';
import '../settings.dart';
import '../models/world.dart';
import '../services/firestore_service.dart';
import '../services/sandbox_sync.dart';
import '../widgets/colour_picker.dart';
import '../widgets/card_frame.dart';
import '../widgets/holo_card_v2.dart';
import 'dart:math';
import 'map_selection_screen.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';

class IdeaGenerator {
  static final _rnd = Random();

  // ── WORLD LISTS ──
  static const _worldNames = [
    'Aethelgard', 'Oakhaven', 'The Shattered Reach', 'The Iron Spire', 'Umbral', 
    'The Verdant Abyss', 'Solara', 'The Ashlands', 'Eldergrove', 'New Tethys',
    'Xylos', 'The Cinder Wastes', 'Nova Roma', 'The Ghostlands', 'Mechanus',
    'Aetheria', 'The Obsidian Spire', 'New Avalon', 'The Shattered Expanse',
    'The Dread Wastes', 'The Sunken Kingdoms', 'Verdantia', 'The Glass Desert', 
    'Nyx', 'The Whispering Steppes', 'Elysium', 'The Bleeding Edge', 'Tartarus', 
    'The Clockwork City', 'Arcadia', 'The Frozen Spires', 'Zion', 'The Neon Underbelly', 
    'Dunwall', 'The Shadow Marches', 'Highwall', 'The Deep', 'Oasis', 'The Ruined Citadel', 
    'Sanctuary', 'The Rust Belt', 'Eventide', 'The Hollow Earth', 'Avalon', 'The Blacksite', 
    'Silent Hill', 'The Celestial Forge', 'Khepri', 'Starlight Bastion', 'The Maw', 'Carcosa',
    'Lumen', 'The Salt Flats', 'The Second Skin', 'Neonshade', 'The Gloaming Sea', 'Ferrum',
    'The Pale City', 'Sunder', 'The Emberfield', 'Chrysalis', 'The Quiet Year'
  ];
  
  static const _genres = [
    'Fantasy', 'Sci-Fi', 'Cyberpunk', 'Gothic Horror', 'Steampunk', 'Modern', 
    'Post-Apocalyptic', 'Mythological', 'Dark Fantasy', 'Space Opera', 'Weird West',
    'Solarpunk', 'Dieselpunk', 'Hard Sci-Fi', 'Urban Fantasy', 'Cosmic Horror',
    'Wuxia', 'Gaslamp Fantasy', 'Biopunk', 'Sword and Sorcery', 'Magitech',
    'Alternate History', 'Dystopian', 'Fairy Tale', 'Noir', 'Superhero',
    'Time Travel', 'Isekai', 'Grimdark', 'Hopepunk', 'Romantic Fantasy', 'Mecha',
    'Atomic Punk', 'Oceanpunk', 'Mythic Sci-Fi', 'Low Fantasy', 'High Fantasy',
    'Folk Horror', 'Sword & Planet', 'Dungeonpunk', 'Mythpunk', 'Cottagecore Horror'
  ];
  
  static const _tones = [
    'Gritty and cynical', 'Hopeful but fragile', 'Dark and oppressive', 
    'Whimsical and strange', 'Epic and grand', 'Melancholic and quiet',
    'Satirical and absurd', 'Tense and paranoid', 'Romantic and lush',
    'Cold and clinical', 'Feral and chaotic', 'Nostalgic and bittersweet',
    'Eerie and unsettling', 'Triumphant and heroic', 'Morally grey',
    'Surreal and dreamlike', 'Brutal and unforgiving', 'Cozy and intimate',
    'Mysterious and elusive', 'Savage and primal', 'Elegant and decadent',
    'Desperate and survivalist', 'Grand and mythic', 'Playful and adventurous',
    'Deadpan and bleakly funny', 'Operatic and tragic', 'Intimate and claustrophobic',
    'Lyrical and hallucinatory', 'Blood-soaked and reverent', 'Clinical and conspiratorial'
  ];

  static const _worldSettings = [
    'A floating city powered by stolen memories.', 
    'A desert where the sand is actually crushed bone.', 
    'A forest where the trees move when you sleep.', 
    'An underwater metropolis ruled by a drowned queen.', 
    'A space station where time moves backwards.', 
    'A town where everyone shares the same dream.',
    'A cyberpunk mega-city built atop the ruins of an older civilization.',
    'A world where magic is drawn from the color of the sky.',
    'A prison dimension where gods are held captive.',
    'A continent that floats in a sea of clouds, held up by ancient engines.',
    'A city that only appears during a solar eclipse.',
    'A realm where the sun never sets, and the shadows are alive.',
    'A frozen wasteland where warmth is the highest currency.',
    'A labyrinthine library that contains every book ever written.',
    'A wild west frontier on a planet with three moons.',
    'A magical academy where students are taught to control their inner demons.',
    'A world that is actually a massive, living creature drifting through space.',
    'A utopian society built on the backs of a hidden underclass.',
    'A war-torn landscape where the trenches have been dug for centuries.',
    'A seaside town where the tide brings in things from other worlds.',
    'A clockwork city where every citizen is assigned a role at birth.',
    'A dreamscape where the boundaries between reality and imagination blur.',
    'A planet where the flora is sentient and the fauna is mechanical.',
    'A post-scarcity society that is slowly going mad from boredom.',
    'A shadowy metropolis where the sun is a myth and the rain never stops.',
    'A train that never stops, circling a dead world with the last city on its back.',
    'A cathedral the size of a continent, abandoned mid-construction.',
    'A desert of black glass that hums with trapped souls.',
    'A city built inside the skeleton of a dead titan.'
  ];

  static const _worldHooks = [
    'The sun has stopped rising, and the crops are dying.', 
    'Magic is real, but every spell costs a year of your life.', 
    'A plague turns people into living statues of gold.', 
    'The gods are dead, and their corpses are falling from the sky.', 
    'A door appeared in the middle of the town square yesterday.',
    'Every time a king is crowned, a star goes out.',
    'The moon is an egg that is about to hatch.',
    'A portal to the afterlife is open, but no one is coming back.',
    'The ocean has turned to glass, and something is moving beneath it.',
    'A forgotten technology has been unearthed, and it is demanding a blood sacrifice.',
    'The dead have begun to vote in the elections.',
    'A wandering planet has entered the solar system, and it is broadcasting a message.',
    'Every citizen is born with a clock counting down to their death, but the clocks are malfunctioning.',
    'The rain has been falling for a thousand years, and it sings.',
    'A sentient virus is rewriting the DNA of the population to make them perfect.',
    'The shadows of the city have begun to detach from their owners.',
    'A cult has successfully summoned a god, but it is a god of bureaucracy.',
    'The stars have started to go out, one by one.',
    'A massive creature is sleeping beneath the capital city, and it is starting to wake up.',
    'Reality is a simulation, and the developers are about to shut it down.',
    'The children have stopped dreaming.',
    'All maps of the outer provinces have gone blank overnight.',
    'A second moon has appeared, and it is getting closer.',
    'The dead god in the harbor has started bleeding again.'
  ];

  static const _worldRules = [
    'No iron or steel can be brought into the city.', 
    'Lying causes physical pain.', 
    'The dead must be burned before nightfall.', 
    'Magic only works in the dark.', 
    'Contracts are magically binding, with no exceptions.',
    'Never look a dragon in the eye.',
    'Blood is the only currency the spirits accept.',
    'A promise made under the full moon cannot be broken.',
    'The royal family is immune to all magic.',
    'You must always leave a bowl of milk out for the fae.',
    'Technology fails in the presence of magic.',
    'The souls of the dead are recycled into new life.',
    'There is no such thing as a free lunch, especially with wizards.',
    'Do not speak the true name of the king.',
    'The forest is a living entity, and it must be respected.',
    'Any weapon drawn in the temple will shatter.',
    'Dreams can be harvested and traded like commodities.',
    'The higher you go, the stronger the gravity.',
    'Time moves differently in different parts of the world.',
    'You can only tell the truth on Sundays.',
    'No one is allowed to die within the city walls.',
    'To enter the library, you must leave a memory at the door.',
    'Names have power; give yours to no one.',
    'The city feeds on secrets; the more you share, the safer you are.'
  ];

  static const _worldHistory = [
    'The old empire collapsed a century ago, leaving its ruins behind.', 
    'A great war was fought over the control of the sun.', 
    'The current ruler usurped the throne from their sibling.', 
    'A cataclysmic event reshaped the continent, sinking half the world.',
    'The gods abandoned the world after a great betrayal.',
    'A plague wiped out half the population, and the survivors are immune.',
    'A terrible curse was placed on the land by a dying witch.',
    'A powerful artifact was shattered into pieces and hidden across the world.',
    'The first settlers were refugees from a dying planet.',
    'A rebellion was crushed, but its leaders became martyrs.',
    'A great library was burned, and most of the world\'s history was lost.',
    'A portal to another dimension was opened, and it never closed.',
    'A machine was built that could predict the future, and it went mad.',
    'A royal bloodline was wiped out, leaving a power vacuum.',
    'A treaty was signed with a demon lord, and it is about to expire.',
    'A great dragon was slain, and its bones now form the city walls.',
    'An ancient AI woke up and decided to reorganize society.',
    'The old king went mad, and the kingdom was shattered into warring factions.',
    'The world was terraformed, but the terraformers made it for something else.',
    'Humanity won a war against the machines by becoming more machine than them.'
  ];

  static const _conflicts = [
    'A resource that makes magic possible is running out.',
    'Two timelines are merging and only one can survive.',
    'The immortal ruling class is starting to die of old age for the first time.',
    'The prophecy was fulfilled, but the wrong person fulfilled it.',
    'The city\'s AI god has fallen in love with a mortal.',
  ];

  static const _artifacts = [
    'A sword that cuts through lies', 'A compass that points to what you fear most',
    'A book that rewrites itself to be true', 'A crown made of frozen time',
    'The last seed from the first tree', 'A gun that shoots your own future',
    'A mirror that shows you how you will die'
  ];

  static const _factions = [
    'The Silver Syndicate', 'The Ashen Order', 'The Crown Guard', 'The Whispering Circle', 'The Iron Bank',
    'The Shadow Hand', 'The Keepers of the Flame', 'The Obsidian Pact', 'The Order of the Sun', 'The Crimson Court',
    'The Chained God Cult', 'The Free Traders Guild', 'The Royal Inquisitors', 'The Wandering Stars', 'The Black Lotus',
    'The Gilded Talon', 'The Frostborn Tribe', 'The Ember Knights', 'The Seekers of Truth', 'The Veiled Ones',
    'The Clockwork Guild', 'The Dragon\'s Chosen', 'The Necromancer\'s Union', 'The Beast Tamers', 'The Void Watchers',
    'The Emerald Sisterhood', 'The Steel Legion', 'The Sunken Court', 'The Star Gazers', 'The Pale Librarians',
    'The Choir of Rust', 'The Kindred of Salt', 'The Children of the Second Sun'
  ];

  static const _locations = [
    'The Broken Bridge', 'The Underbelly Market', 'The Silent Cathedral', 'The Moonlit Docks', 'The Sunken Library',
    'The Weeping Falls', 'The Crimson Gate', 'The Iron Fortress', 'The Whispering Woods', 'The Ashen Wastes',
    'The Floating Market', 'The Clockwork Tower', 'The Shadowed Alley', 'The Gilded Palace', 'The Ruins of Eldoria',
    'The Abyssal Chasm', 'The Frozen Peaks', 'The Whispering Dunes', 'The Crystal Caverns', 'The Shattered Plains',
    'The Serpent\'s Spine', 'The Temple of Echoes', 'The Drowned Cathedral', 'The Burning Sands', 'The Black Spire',
    'The Hall of Heroes', 'The Forbidden Archives', 'The Forgotten Dungeon', 'The Starfall Crater', 'The Veiled Citadel',
    'The Bone Orchard', 'The Inkwell Sea', 'The Glassworks', 'The Night Bazaar', 'The Throat'
  ];

  // ── CHARACTER LISTS ──
  static const _firstNames = [
    'Kaelen', 'Lyra', 'Thorne', 'Elara', 'Dorian', 'Seraphina', 'Riven', 'Isolde', 'Vane', 'Maeve',
    'Silas', 'Octavia', 'Cassian', 'Freya', 'Alaric', 'Morrigan', 'Gideon', 'Ophelia', 'Ezra', 'Clara',
    'Zane', 'Nova', 'Kael', 'Luna', 'Orion', 'Sage', 'Fenris', 'Aria', 'Balthazar', 'Selene',
    'Cyrus', 'Vesper', 'Magnus', 'Willow', 'Dante', 'Iris', 'Lucian', 'Nyx', 'Zephyr', 'Aurora',
    'Aether', 'Vex', 'Echo', 'Sora', 'Xander', 'Raven', 'Thalia', 'Jasper', 'Ruby', 'Felix',
    'Ivy', 'Leo', 'Flora', 'Kestrel', 'Wren', 'Ash', 'Ember', 'Juno', 'Mira', 'Corin'
  ];
  
  static const _lastNames = [
    'Blackwood', 'Ironheart', 'Stormwind', 'Shadowmere', 'Ashford', 'Moonfall', 'Thorne', 'Silver',
    'Dragonslayer', 'Nightshade', 'Wilder', 'Starfall', 'Burnham', 'Cross', 'Graves', 'Hawthorne', 
    'Kane', 'Lockhart', 'Mercer', 'Pryce', 'Quinn', 'Rook', 'Snow', 'Wolfe', 'Frost', 'Stone', 
    'Rivera', 'Windsor', 'Sterling', 'Castellan', 'DeLune', 'Voss', 'Kryze', 'Reynolds', 'Harrow',
    'Quill', 'Vale', 'Emberfall', 'Dusk', 'Lightbringer', 'Void', 'Gallowglass'
  ];

  static const _occupations = [
    'Memory smuggler', 'Corpse cartographer', 'God butcher', 'Starlight thief', 'Bone singer',
    'Rust priest', 'Dream auditor', 'Grave architect', 'Storm shepherd', 'Chronology repairer',
    'Exorcist for machines', 'Royal food taster', 'Ink witch', 'Oathbreaker', 'Void diver'
  ];

  static const _pronouns = ['she/her', 'he/him', 'they/them', 'any', 'she/they', 'he/they', 'it/its'];
  static const _ages = ['18', '22', '25', '30', '35', '40', '50', '100+', 'Unknown', 'Immortal', 'Ancient', 'Teenager', 'Middle-aged', 'Elderly'];

  static const _appearances = [
    'Tall and gaunt with scarred hands.', 
    'Short and compact, always wearing a heavy coat.', 
    'Elegant, with silver hair that glows faintly.', 
    'Rugged, with a mechanical eye.', 
    'Unremarkable, able to blend into any crowd.',
    'Covered in glowing tattoos that shift when they speak.',
    'Has a cybernetic arm made of dark metal and gold.',
    'Eyes that change color with their mood.',
    'Wears a mask at all times to hide a terrible scar.',
    'Constantly followed by a faint scent of ozone and rain.',
    'Half their face is covered in burn scars.',
    'Has small horns protruding from their forehead.',
    'Looks like a child, but is actually centuries old.',
    'Covered in intricate, glowing runes.',
    'Skin is made of cracked porcelain that is slowly falling off.',
    'Teeth filed to points, smiles too much.',
    'Never casts a shadow.',
    'Carries a coffin on their back, but claims it is empty.'
  ];

  static const _personalities = [
    'Cold and calculating, but fiercely loyal.', 
    'Optimistic to a fault, even in the darkest times.', 
    'Quick to anger but equally quick to forgive.', 
    'Quiet, observant, and incredibly stubborn.', 
    'Charming and manipulative, always looking for an angle.',
    'Jaded and cynical, but with a soft spot for underdogs.',
    'Wildly unpredictable, driven by impulse and emotion.',
    'Meticulous and logical, terrified of chaos.',
    'Haunted by their past, but determined to do better.',
    'Kind and gentle, but with a core of steel.',
    'Fiercely independent, refuses to rely on anyone.',
    'Deeply religious, guided by a strict moral code.',
    'Protective and maternal, treats everyone like a child.',
    'Timid and anxious, but capable of great bravery.',
  ];

  static const _quirks = [
    'Cannot tell a lie, even to save their life.', 
    'Collects the teeth of fallen enemies.', 
    'Is deathly afraid of the dark, despite being a monster.', 
    'Hears the thoughts of animals, but not humans.', 
    'Has a mechanical arm that acts on its own.',
    'Speaks to an imaginary friend who might be real.',
    'Insists on counting everything they see.',
    'Only sleeps during the day and is awake at night.',
    'Never takes off their gloves.',
    'Is obsessed with collecting rare flowers.',
    'Can only eat food they have cooked themselves.',
    'Has a pet rock they treat like a real animal.',
    'Refuses to use contractions when speaking.',
    'Believes every statue is watching them.'
  ];

  static const _motivations = [
    'Wants to prove the gods are fraudulent',
    'Wants to buy back their own name',
    'Wants to die, but the world won\'t let them',
    'Wants to build a place where no one has to leave',
    'Wants to become the monster they fear',
    'Wants to erase a single day from history'
  ];

  static const _secrets = [
    'They are the one who caused the current crisis',
    'They are not actually alive',
    'They have been replacing their memories with someone else\'s',
    'They are in love with the enemy leader',
    'They are slowly turning into the thing they hunt'
  ];

  static const _flaws = [
    'Cannot resist helping, even when it ruins them',
    'Addicted to borrowed memories',
    'Would rather be feared than forgotten',
    'Cannot say no to a bet',
    'Believes mercy is a weakness they can\'t afford'
  ];

  static const _abilities = [
    'Can steal the weight of things', 'Can speak to extinct animals',
    'Can fold a city like paper for 7 seconds', 'Bleeds light that reveals lies',
    'Can unmake any lock by singing to it'
  ];

  static const _backstories = [
    'Orphaned at a young age and raised by thieves.', 
    'A former soldier who fled the battlefield.', 
    'Searching for a sibling who vanished years ago.', 
    'Escaped from a secret laboratory with no memory of before.', 
    'Born into nobility but disowned for a forbidden romance.',
    'Betrayed by their closest friend and left for dead.',
    'Was cursed by a witch and is searching for a cure.',
    'Was raised by wolves in the deep forest.',
    'Sold their memories to survive poverty.',
    'Awoke with no memory in the middle of a battlefield.',
    'Exiled for inventing a magic the church declared heresy.',
    'The only person who remembers the previous version of the world.'
  ];

  static const _relationships = [
    'Has a rival who wants them dead.', 
    'Secretly in love with their partner.', 
    'Owes a massive debt to a dangerous crime lord.', 
    'Trusts no one but their pet.', 
    'Protects a younger sibling at all costs.',
    'Has a mentor who is secretly their parent.',
    'Is being hunted by an assassin hired by a family member.',
    'Found a family in their crew.',
    'Is haunted by the ghost of their former lover.',
    'Is secretly working for the enemy.',
  ];

  // ── GETTERS ──
  static String get randomWorldName => _worldNames[_rnd.nextInt(_worldNames.length)];
  static String get randomGenre => _genres[_rnd.nextInt(_genres.length)];
  static String get randomTone => _tones[_rnd.nextInt(_tones.length)];
  static String get randomSetting => _worldSettings[_rnd.nextInt(_worldSettings.length)];
  static String get randomHook => _worldHooks[_rnd.nextInt(_worldHooks.length)];
  static String get randomRule => _worldRules[_rnd.nextInt(_worldRules.length)];
  static String get randomHistory => _worldHistory[_rnd.nextInt(_worldHistory.length)];
  static String get randomConflict => _conflicts[_rnd.nextInt(_conflicts.length)];
  static String get randomArtifact => _artifacts[_rnd.nextInt(_artifacts.length)];
  static String get randomFaction => _factions[_rnd.nextInt(_factions.length)];
  static String get randomLocation => _locations[_rnd.nextInt(_locations.length)];
  
  static String get randomCharName => '${_firstNames[_rnd.nextInt(_firstNames.length)]} ${_lastNames[_rnd.nextInt(_lastNames.length)]}';
  static String get randomOccupation => _occupations[_rnd.nextInt(_occupations.length)];
  static String get randomPronouns => _pronouns[_rnd.nextInt(_pronouns.length)];
  static String get randomAge => _ages[_rnd.nextInt(_ages.length)];
  static String get randomAppearance => _appearances[_rnd.nextInt(_appearances.length)];
  static String get randomPersonality => _personalities[_rnd.nextInt(_personalities.length)];
  static String get randomQuirk => _quirks[_rnd.nextInt(_quirks.length)];
  static String get randomMotivation => _motivations[_rnd.nextInt(_motivations.length)];
  static String get randomSecret => _secrets[_rnd.nextInt(_secrets.length)];
  static String get randomFlaw => _flaws[_rnd.nextInt(_flaws.length)];
  static String get randomAbility => _abilities[_rnd.nextInt(_abilities.length)];
  static String get randomBackstory => _backstories[_rnd.nextInt(_backstories.length)];
  static String get randomRelationship => _relationships[_rnd.nextInt(_relationships.length)];

  // ── COMPOSITE GENERATORS ──
  static Map<String, String> generateWorld() => {
    'name': randomWorldName,
    'genre': randomGenre,
    'tone': randomTone,
    'setting': randomSetting,
    'hook': randomHook,
    'rule': randomRule,
    'history': randomHistory,
    'conflict': randomConflict,
    'artifact': randomArtifact,
    'faction': randomFaction,
    'location': randomLocation,
  };

  static Map<String, String> generateCharacter() => {
    'name': randomCharName,
    'occupation': randomOccupation,
    'pronouns': randomPronouns,
    'age': randomAge,
    'appearance': randomAppearance,
    'personality': randomPersonality,
    'quirk': randomQuirk,
    'motivation': randomMotivation,
    'secret': randomSecret,
    'flaw': randomFlaw,
    'ability': randomAbility,
    'backstory': randomBackstory,
    'relationship': randomRelationship,
  };

  static Map<String, dynamic> generateEverything() {
    final world = generateWorld();
    final character = generateCharacter();
    return {
      'world': world,
      'character': character,
      'plot': generatePlot(world: world, character: character),
    };
  }

  static String generatePlot({Map<String, String>? world, Map<String, String>? character}) {
    world ??= generateWorld();
    character ??= generateCharacter();
    return "${world['name']} is a ${world['genre']} world - ${world['setting']} "
        "Tone: ${world['tone']}. Hook: ${world['hook']} "
        "Amid this, ${character['name']} (${character['occupation']}, ${character['pronouns']}) "
        "${character['backstory']} Now ${character['motivation']}, but ${character['secret']}. "
        "They must face ${world['conflict']} while hunted by ${world['faction']} "
        "at ${world['location']}. They hold ${world['artifact']}.";
  }
}

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
  bool _isImporting = false;

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

  void _rebuild() { if (mounted) setState(() {}); }

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
      child: Stack(
        children: [
          // 1. Your main screen content
          Column(
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
                            onUpdate: _updateWorldSilently,
                          ),
                          _CharactersTab(
                            characters: _characters,
                            worlds: _worlds,
                            onAdd: _addCharacter,
                            onEdit: _editCharacter,
                            onDelete: _deleteCharacter,
                            onUpdateCharacter: (updatedChar) {
                              setState(() {
                                final i = _characters.indexWhere((x) => x.id == updatedChar.id);
                                if (i != -1) _characters[i] = updatedChar;
                              });
                              SandboxStorage.saveCharacters(_characters);
                              SandboxSync.pushCharacters(_characters);
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
          
          // 2. The Loading Overlay (Drawn on top of the Column)
          if (_isImporting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: const Center(
                  child: CircularProgressIndicator(color: cGold),
                ),
              ),
            ),
        ],
      ),
    ),
        floatingActionButton: AnimatedBuilder(
      animation: _tab,
      builder: (context, child) {
        return Stack(
          children: [
            // Left Button (Decode JSON)
            if (_tab.index == 1)
              Positioned(
                left: 16,
                bottom: 16,
                child: FloatingActionButton(
                  heroTag: 'decodeBtn',
                  backgroundColor: cInk,
                  shape: const CircleBorder(side: BorderSide(color: cGold)),
                  onPressed: _copyDeorumJsonFromFile,
                  child: const Icon(Icons.file_download_outlined, color: cGold),
                ),
              ),

            // Middle Button (Visit Deorum)
            if (_tab.index == 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18, // Slightly adjusted to align with the FABs
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      final Uri url = Uri.parse('https://deorum.vercel.app/');
                      try {
                        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                          throw 'Could not launch $url';
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: cEmber,
                            content: Text('Could not open browser: $e'),
                          ));
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: cInk,
                        border: Border.all(color: cGold.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'DEORUM',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: cGold,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            
            // Right Button (+)
            Positioned(
              right: 16,
              bottom: 16,
              child: GestureDetector(
                onTap: _tab.index == 0 ? _addWorld : _addCharacter,
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: cInk, border: Border.all(color: cGold), shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: cGold, size: 22),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _buildTopBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: cAsh))),
    child: Row(
      children: [
        GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.arrow_back_ios, color: cSmoke, size: 16)),
        const SizedBox(width: 12),
        const Text('Sandbox', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: cParchment)),
        const Spacer(),
        GestureDetector(
          onTap: _showIdeaGenerator,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: cGold.withValues(alpha: 0.5)), color: cGold.withValues(alpha: 0.1)),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: cGold),
                SizedBox(width: 6),
                Text('SPARK', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 2)),
              ],
            ),
          ),
        ),
        const Text('L o r e', style: TextStyle(fontSize: 11, color: cGold, letterSpacing: 5, fontWeight: FontWeight.w300)),
      ],
    ),
  );

  Widget _buildTabBar() => Container(
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: cAsh))),
    child: TabBar(
      controller: _tab,
      indicatorColor: cGold,
      indicatorWeight: 1,
      labelColor: cGold,
      unselectedLabelColor: cSmoke,
      labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 3),
      tabs: const [Tab(text: 'WORLDS'), Tab(text: 'CHARACTERS')],
    ),
  );

  Widget _buildFAB() => AnimatedBuilder(
    animation: _tab,
    builder: (_, _) => GestureDetector(
      onTap: _tab.index == 0 ? _addWorld : _addCharacter,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: cInk, border: Border.all(color: cGold), shape: BoxShape.circle),
        child: const Icon(Icons.add, color: cGold, size: 22),
      ),
    ),
  );

  void _addWorld() => _openWorldEditor(null);
  void _editWorld(WorldEntry w) => _openWorldEditor(w);
  void _deleteWorld(String id) {
    setState(() => _worlds.removeWhere((w) => w.id == id));
    SandboxStorage.saveWorlds(_worlds);
    SandboxSync.pushWorlds(_worlds);
    _fs.incrementUserCounter('worldsCreated', -1);
  }

  void _updateWorldSilently(WorldEntry updatedWorld) {
    setState(() {
      final i = _worlds.indexWhere((w) => w.id == updatedWorld.id);
      if (i != -1) _worlds[i] = updatedWorld;
    });
  }

  void _openWorldEditor(WorldEntry? existing) {
    Navigator.of(context).push(fadeRoute(WorldEditorScreen(
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
    )));
  }

  void _addCharacter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 32, height: 3, decoration: BoxDecoration(color: cAsh, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            _sheetAction(context, Icons.edit_outlined, 'Create Custom Character', () {
              // Navigator.pop(ctx); <--- REMOVED THIS
              _openCharacterEditor(null);
            }),
            _sheetAction(context, Icons.paste, 'Import from Clipboard', () {
              // Navigator.pop(ctx); <--- REMOVED THIS
              _importFromClipboard(); 
            }, color: cIce),
          ],
        ),
      ),
    );
  }

  void _editCharacter(CharacterEntry c) => _openCharacterEditor(c);

  void _deleteCharacter(String id) {
    setState(() => _characters.removeWhere((c) => c.id == id));
    SandboxStorage.saveCharacters(_characters);
    SandboxSync.pushCharacters(_characters);
    _fs.incrementUserCounter('charactersCreated', -1);
  }

  Future<void> _copyDeorumJsonFromFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'JSON',
        extensions: <String>['json', 'txt'],
        mimeTypes: <String>['*/*'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file == null) return;

      final text = await file.readAsString();
      
      // Copy the raw text to the clipboard
      await Clipboard.setData(ClipboardData(text: text));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: cGold,
          duration: Duration(seconds: 4),
          content: Text(
            'JSON copied to clipboard! Tap + to import.', 
            style: TextStyle(color: cVoid, fontWeight: FontWeight.bold),
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: cEmber,
          content: Text('Failed to read file: $e', style: const TextStyle(color: Colors.white)),
        ));
      }
    }
  }
  

  // 1. IMPORT DIRECTLY FROM FILE
  Future<void> _importFromClipboard() async {
    final ClipboardData? clipData = await Clipboard.getData(Clipboard.kTextPlain);
    final String? jsonString = clipData?.text;

    if (jsonString == null || jsonString.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: cEmber, 
          content: Text('Clipboard is empty! Copy the JSON text first.'),
        ));
      }
      return;
    }

    if (!mounted) return;
    
    // 1. Show the custom loading overlay
    setState(() => _isImporting = true);

    try {
      String cleanJson = jsonString.trim();
      if (cleanJson.startsWith('\uFEFF')) cleanJson = cleanJson.substring(1);

      dynamic decoded = jsonDecode(cleanJson);
      Map<String, dynamic> data = (decoded is List) ? decoded.first : decoded;

      final newChar = CharacterEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: data['name'] ?? data['char_name'] ?? 'Unknown Name',
        pronouns: data['gender'] ?? data['pronouns'] ?? '',
        age: data['age']?.toString() ?? '',
        appearance: 'Race: ${data['race'] ?? ''}\nHeight: ${data['height'] ?? '?'}cm\nWeight: ${data['weight'] ?? '?'}kg',
        personality: 'Archetype: ${data['archetype'] ?? ''}\nBackground: ${data['background'] ?? ''}',
        backstory: data['bio'] ?? data['backstory'] ?? '',
        notes: 'Imported from Deorum',
        avatarUrl: null, // Image fetching is completely removed
      );

      if (mounted) {
        setState(() {
          _characters.insert(0, newChar);
          _isImporting = false; // Hide loading overlay
        });
        
        try { await SandboxStorage.saveCharacters(_characters); } catch (e) { debugPrint("Storage save failed: $e"); }
        try { SandboxSync.pushCharacters(_characters); } catch (e) { debugPrint("Sync failed: $e"); }
        try { _fs.incrementUserCounter('charactersCreated', 1); } catch (e) { debugPrint("Counter failed: $e"); }
        
        // 2. The Pop-Up Box (No more SnackBars)
        showDialog(
          context: context,
          barrierDismissible: false, 
          builder: (ctx) => AlertDialog(
            backgroundColor: cInk,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: cGold, width: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            title: const Text('Import Successful', style: TextStyle(color: cGold, fontSize: 18, fontStyle: FontStyle.italic)),
            content: const Text(
              'Your character has been added to the Sandbox!\n\n'
              'Note: Deorum locks images to their own servers. If you want the character portrait, please download it directly from Deorum and add it manually in the character editor.',
              style: TextStyle(color: cParchment, fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Confirm', style: TextStyle(color: cGold, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false); // Hide overlay on error
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: cEmber, 
          duration: const Duration(seconds: 10), 
          content: Text('Parse Error: $e', style: const TextStyle(color: Colors.white, fontSize: 16)),
        ));
      }
    }
  }

  void _openCharacterEditor(CharacterEntry? existing) {
    Navigator.of(context).push(fadeRoute(CharacterEditorScreen(
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
    )));
  }

  void _saveWorldDirectly(Map<String, String> map) {
    final newWorld = _mapToWorldEntry(map);
    setState(() => _worlds.insert(0, newWorld));
    SandboxStorage.saveWorlds(_worlds);
    SandboxSync.pushWorlds(_worlds);
    _fs.incrementUserCounter('worldsCreated', 1);
  }

  void _saveCharacterDirectly(Map<String, String> map, {String? plotText}) {
    String notes = 'Occupation: ${map['occupation']}\nSecret: ${map['secret']}\nQuirk: ${map['quirk']}';
    if (plotText != null) notes += '\n\n--- STORY PLOT ---\n$plotText';
    
    final newChar = _mapToCharacterEntry(map);
    newChar.notes = notes;
    
    setState(() => _characters.insert(0, newChar));
    SandboxStorage.saveCharacters(_characters);
    SandboxSync.pushCharacters(_characters);
    _fs.incrementUserCounter('charactersCreated', 1);
  }

  void _showIdeaGenerator() {
    Map<String, String> currentWorld = IdeaGenerator.generateWorld();
    Map<String, String> currentChar = IdeaGenerator.generateCharacter();
    String currentPlot = IdeaGenerator.generatePlot(world: currentWorld, character: currentChar);
    
    int activeTab = 0;

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
                    _sparkTab('WORLD', 0, activeTab, () => setModalState(() => activeTab = 0)),
                    const SizedBox(width: 8),
                    _sparkTab('CHARACTER', 1, activeTab, () => setModalState(() => activeTab = 1)),
                    const SizedBox(width: 8),
                    _sparkTab('PLOT', 2, activeTab, () => setModalState(() => activeTab = 2)),
                  ],
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cVoid, border: Border.all(color: cAsh)),
                      child: activeTab == 0
                          ? _buildWorldPrompt(currentWorld)
                          : activeTab == 1
                              ? _buildCharPrompt(currentChar)
                              : _buildPlotPrompt(currentWorld, currentChar, currentPlot),
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
                            if (activeTab == 0) {
                              currentWorld = IdeaGenerator.generateWorld();
                            } else if (activeTab == 1) {
                              currentChar = IdeaGenerator.generateCharacter();
                            } else {
                              currentWorld = IdeaGenerator.generateWorld();
                              currentChar = IdeaGenerator.generateCharacter();
                              currentPlot = IdeaGenerator.generatePlot(world: currentWorld, character: currentChar);
                            }
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
                          if (activeTab == 0) {
                            _openWorldEditor(_mapToWorldEntry(currentWorld));
                          } else if (activeTab == 1) {
                            _openCharacterEditor(_mapToCharacterEntry(currentChar));
                          } else {
                            _saveWorldDirectly(currentWorld);
                            _saveCharacterDirectly(currentChar, plotText: currentPlot);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              backgroundColor: cInk,
                              content: Text('World, Character, and Plot saved to Sandbox!', style: TextStyle(color: cGold)),
                            ));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: cGold,
                          child: Center(child: Text(activeTab == 2 ? 'Save All 3' : 'Use this idea', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: cVoid, letterSpacing: 1))),
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

  Widget _sparkTab(String label, int index, int activeIndex, VoidCallback onTap) {
    final isActive = index == activeIndex;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? cGold.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(color: isActive ? cGold : cAsh),
          ),
          child: Center(
            child: Text(
              label, 
              style: TextStyle(color: isActive ? cGold : cSmoke, fontFamily: 'monospace', fontSize: 9, letterSpacing: 1)
            )
          ),
        ),
      ),
    );
  }

  Widget _buildWorldPrompt(Map<String, String> world) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(world['name']!.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: cGold, letterSpacing: 2)),
        Text('${world['genre']} · ${world['tone']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: cSmoke)),
        const SizedBox(height: 16),
        Text(world['setting']!, style: const TextStyle(fontSize: 15, color: cParchment, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, height: 1.5)),
        const SizedBox(height: 16),
        _promptSection('HOOK', world['hook']!),
        _promptSection('CONFLICT', world['conflict']!),
        _promptSection('ARTIFACT', world['artifact']!),
        _promptSection('RULE', world['rule']!),
        _promptSection('HISTORY', world['history']!),
        _promptSection('LOCATION', world['location']!),
        _promptSection('FACTION', world['faction']!),
      ],
    );
  }

  Widget _buildCharPrompt(Map<String, String> char) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(char['name']!.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: cGold, letterSpacing: 2)),
        Text('${char['pronouns']} · ${char['age']} · ${char['occupation']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: cSmoke)),
        const SizedBox(height: 16),
        Text(char['appearance']!, style: const TextStyle(fontSize: 15, color: cParchment, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, height: 1.5)),
        const SizedBox(height: 16),
        _promptSection('PERSONALITY', char['personality']!),
        _promptSection('MOTIVATION', char['motivation']!),
        _promptSection('FLAW', char['flaw']!),
        _promptSection('SECRET', char['secret']!),
        _promptSection('ABILITY', char['ability']!),
        _promptSection('QUIRK', char['quirk']!),
        _promptSection('BACKSTORY', char['backstory']!),
        _promptSection('RELATIONSHIP', char['relationship']!),
      ],
    );
  }

  Widget _buildPlotPrompt(Map<String, String> world, Map<String, String> char, String plot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('STORY PLOT', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: cGold, letterSpacing: 2)),
        const SizedBox(height: 16),
        Text(plot, style: const TextStyle(fontSize: 15, color: cParchment, height: 1.7, fontStyle: FontStyle.italic)),
        const SizedBox(height: 24),
        
        const Text('LINKED ASSETS', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text('World: ${world['name']}', style: const TextStyle(fontSize: 13, color: cMist)),
        Text('Character: ${char['name']}', style: const TextStyle(fontSize: 13, color: cMist)),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _saveWorldDirectly(world);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    backgroundColor: cInk, content: Text('World saved to Sandbox!', style: TextStyle(color: cGold)),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: cGold.withValues(alpha: 0.5))),
                  child: const Center(child: Text('Save World', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 1))),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _saveCharacterDirectly(char);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    backgroundColor: cInk, content: Text('Character saved to Sandbox!', style: TextStyle(color: cIce)),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: cIce.withValues(alpha: 0.5))),
                  child: const Center(child: Text('Save Character', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cIce, letterSpacing: 1))),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _promptSection(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: cGold, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 13, color: cMist, height: 1.5)),
        ],
      ),
    );
  }

  WorldEntry _mapToWorldEntry(Map<String, String> map) => WorldEntry(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    name: map['name']!,
    genre: map['genre']!,
    tone: map['tone']!,
    overview: '${map['setting']}\n\nHOOK: ${map['hook']}\n\nCONFLICT: ${map['conflict']}\n\nARTIFACT: ${map['artifact']}',
    history: map['history']!,
    rules: map['rule']!,
    locations: [WorldLocation(name: map['location']!, description: 'A notable location.')],
    factions: [WorldFaction(name: map['faction']!, description: 'A powerful faction.')],
  );

  CharacterEntry _mapToCharacterEntry(Map<String, String> map) => CharacterEntry(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    name: map['name']!,
    pronouns: map['pronouns']!,
    age: map['age']!,
    appearance: map['appearance']!,
    personality: '${map['personality']}\n\nMotivation: ${map['motivation']}\n\nFlaw: ${map['flaw']}\n\nAbility: ${map['ability']}',
    backstory: map['backstory']!,
    relationships: map['relationship']!,
    notes: 'Occupation: ${map['occupation']}\nSecret: ${map['secret']}\nQuirk: ${map['quirk']}',
  );
}

// ════════════════════════════════════════
// WORLDS TAB
// ════════════════════════════════════════
class _WorldsTab extends StatelessWidget {
  final List<WorldEntry> worlds;
  final VoidCallback onAdd;
  final void Function(WorldEntry) onEdit;
  final void Function(String) onDelete;
  final void Function(WorldEntry) onUpdate;

  const _WorldsTab({
    required this.worlds, 
    required this.onAdd, 
    required this.onEdit, 
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    if (worlds.isEmpty) return _emptyState('No worlds yet.', 'Tap + to start building one.');
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: worlds.length,
        itemBuilder: (_, i) => _WorldCard(
          world: worlds[i], 
          onTap: () => onEdit(worlds[i]), 
          onDelete: () => onDelete(worlds[i].id),
          onUpdate: onUpdate, 
        ),
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  final WorldEntry world;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(WorldEntry) onUpdate;

  const _WorldCard({
    required this.world, 
    required this.onTap, 
    required this.onDelete,
    required this.onUpdate,
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
        border: Border.all(color: world.isDraft ? cAsh : cGold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  world.name, 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: cParchment),
                ),
              ),
              if (world.isDraft)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(border: Border.all(color: cAsh)),
                  child: const Text('DRAFT', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: cSmoke, letterSpacing: 2)),
                ),
            ],
          ),
          if (world.genre.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(world.genre, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: cGold, letterSpacing: 2)),
          ],
          if (world.overview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              world.overview.length > 120 ? '${world.overview.substring(0, 120)}...' : world.overview, 
              style: const TextStyle(fontSize: 13, color: cMist, fontStyle: FontStyle.italic, height: 1.6),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (world.mapUrl != null)
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(10),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          InteractiveViewer(
                            panEnabled: true,
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Image.network(world.mapUrl!, fit: BoxFit.contain),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 30),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: _pill('VIEW MAP', cVine),
                ),

              if (world.mapUrl != null) const SizedBox(width: 6),
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
    decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: color, letterSpacing: 1)),
  );

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
          _sheetAction(context, Icons.edit_outlined, 'Edit world', onTap),
          _sheetAction(context, Icons.delete_outline, 'Delete world', onDelete, color: cEmber),
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
  final void Function(CharacterEntry) onUpdateCharacter;

  const _CharactersTab({
    required this.characters,
    required this.worlds,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdateCharacter,
  });

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) return _emptyState('No characters yet.', 'Tap + to create one.');
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: characters.length,
        itemBuilder: (_, i) {
          final c = characters[i];
          final linkedWorld = worlds.where((w) => w.id == c.linkedWorldId).firstOrNull;
          return _SandboxCharacterCard(
            character: c,
            linkedWorld: linkedWorld,
            onTap: () => onEdit(c),
            onLongPress: () => _showActions(context, c),
          );
        },
      ),
    );
  }

  void _showActions(BuildContext context, CharacterEntry c) => showModalBottomSheet(
    context: context,
    backgroundColor: cInk,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 32, height: 3, decoration: BoxDecoration(color: cAsh, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          _sheetAction(context, Icons.colorize, 'Card Color', () {
            LoreColourPicker.show(
              context,
              current: c.accentColor,
              onPicked: (newColor) {
                c.accentColor = newColor;
                onUpdateCharacter(c);
              },
            );
          }),
          _sheetAction(context, Icons.edit_outlined, 'Edit character', () => onEdit(c)),
          _sheetAction(context, Icons.delete_outline, 'Delete character', () => onDelete(c.id), color: cEmber),
        ],
      ),
    ),
  );
}

class _SandboxCharacterCard extends StatelessWidget {
  final CharacterEntry character;
  final WorldEntry? linkedWorld;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SandboxCharacterCard({
    required this.character,
    required this.linkedWorld,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final accent = character.accentColor;
    final seed = character.id.hashCode;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: HoloCardV2(
        accent: accent,
        intensity: 0.4,
        seed: seed,
        bgColor: cInk,
        child: Container(
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
                    if (character.avatarUrl != null)
                      Image.network(character.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
                    
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: 0.85), Colors.black.withValues(alpha: 0.5), Colors.black.withValues(alpha: 0.9)],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  character.name,
                                  style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: cParchment, height: 1.1),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(border: Border.all(color: character.type == CharacterType.playerCharacter ? cGold : cMagic)),
                                child: Text(
                                  character.type == CharacterType.playerCharacter ? 'PC' : 'NPC',
                                  style: TextStyle(fontFamily: 'monospace', fontSize: 7, color: character.type == CharacterType.playerCharacter ? cGold : cMagic),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [if (character.pronouns.isNotEmpty) character.pronouns, if (character.age.isNotEmpty) character.age].join(' · '),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: cSmoke),
                          ),
                          const Spacer(),
                          if (character.personality.isNotEmpty)
                            Text(
                              character.personality,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'serif', fontSize: 9, color: cMist, fontStyle: FontStyle.italic, height: 1.4),
                            ),
                          const Spacer(),
                          if (linkedWorld != null) ...[
                            Container(
                              padding: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(border: Border(top: BorderSide(color: accent.withValues(alpha: 0.3)))),
                              child: Text(
                                '↳ ${linkedWorld!.name}',
                                style: TextStyle(fontFamily: 'monospace', fontSize: 7.5, color: accent, letterSpacing: 1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
    );
  }
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

  String? _mapUrl;
  bool _uploadingMap = false;

  late TextEditingController _nameCtrl, _genreCtrl, _overviewCtrl, _toneCtrl, _historyCtrl, _rulesCtrl, _notesCtrl;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    final w = widget.world;
    _working = w != null
        ? WorldEntry(
            id: w.id, name: w.name, genre: w.genre, overview: w.overview, tone: w.tone,
            locations: List.from(w.locations), factions: List.from(w.factions),
            history: w.history, rules: w.rules, notes: w.notes, isDraft: w.isDraft, mapUrl: w.mapUrl,
          )
        : WorldEntry(id: DateTime.now().millisecondsSinceEpoch.toString(), name: '');
    
    _mapUrl = _working.mapUrl;
    
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
    for (final c in [_nameCtrl, _genreCtrl, _overviewCtrl, _toneCtrl, _historyCtrl, _rulesCtrl, _notesCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickMapImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _uploadingMap = true);

    try {
      final ref = FirebaseStorage.instance.ref().child('worlds/${_working.id}_map.jpg');
      await ref.putData(await image.readAsBytes());
      final url = await ref.getDownloadURL();
      
      final freshUrl = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
      await NetworkImage(url).evict();
      
      setState(() {
        _mapUrl = freshUrl;
        _uploadingMap = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingMap = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: cInk, 
          content: Text('Upload failed: $e', style: const TextStyle(color: cEmber))
        ));
      }
    }
  }

  void _save() {
    _working.name = _nameCtrl.text.trim();
    _working.genre = _genreCtrl.text.trim();
    _working.overview = _overviewCtrl.text.trim();
    _working.tone = _toneCtrl.text.trim();
    _working.history = _historyCtrl.text.trim();
    _working.rules = _rulesCtrl.text.trim();
    _working.notes = _notesCtrl.text.trim();
    
    _working.mapUrl = _mapUrl;

    widget.onSave(_working);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appSettings.bgColor,
    body: SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: cAsh))),
            child: Row(
              children: [
                GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close, color: cSmoke, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(fontSize: 20, color: cParchment, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic),
                    decoration: const InputDecoration(hintText: 'World name...', hintStyle: TextStyle(color: cSmoke, fontStyle: FontStyle.italic, fontSize: 20, fontWeight: FontWeight.w300), border: InputBorder.none),
                    cursorColor: cGold,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MapSelectionScreen(worldName: _working.name),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: cGold.withValues(alpha: 0.5)), 
                          color: cGold.withValues(alpha: 0.1),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.map_outlined, size: 12, color: cGold),
                            SizedBox(width: 4),
                            Text('MAP', style: TextStyle(fontFamily: 'monospace', fontSize: 9, letterSpacing: 2, color: cGold)),
                          ],
                        ),
                      ),
                    ),
                    
                    GestureDetector(
                      onTap: () => setState(() => _working.isDraft = !_working.isDraft),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(border: Border.all(color: _working.isDraft ? cAsh : cGold)),
                        child: Text(_working.isDraft ? 'DRAFT' : 'READY', style: TextStyle(fontFamily: 'monospace', fontSize: 9, letterSpacing: 2, color: _working.isDraft ? cSmoke : cGold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: cParchment,
                        child: const Text('Save', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cVoid, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: cAsh))),
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              indicatorColor: cGold,
              indicatorWeight: 1,
              labelColor: cGold,
              unselectedLabelColor: cSmoke,
              labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 9, letterSpacing: 2),
              tabs: const [Tab(text: 'OVERVIEW'), Tab(text: 'LOCATIONS'), Tab(text: 'FACTIONS'), Tab(text: 'HISTORY'), Tab(text: 'RULES')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _editorScrollable([
                  const Text('WORLD MAP IMAGE', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 3)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _uploadingMap ? null : _pickMapImage,
                    child: Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: cVoid,
                        border: Border.all(color: cAsh),
                        image: _mapUrl != null 
                            ? DecorationImage(image: NetworkImage(_mapUrl!), fit: BoxFit.cover) 
                            : null,
                      ),
                      child: _uploadingMap
                          ? const Center(child: CircularProgressIndicator(color: cGold))
                          : (_mapUrl == null
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.map_outlined, size: 32, color: cSmoke),
                                      SizedBox(height: 8),
                                      Text('Tap to upload map screenshot', style: TextStyle(fontSize: 12, color: cSmoke, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                )
                              : null),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  _field('Genre', _genreCtrl, hint: 'e.g. Dark Fantasy, Sci-Fi Noir'), 
                  _field('Overview', _overviewCtrl, maxLines: 6, hint: 'The world in a paragraph...'), 
                  _field('Tone', _toneCtrl, hint: 'e.g. Dark, morally grey, slow burn')
                ]),
                
                _ListEditor<WorldLocation>(items: _working.locations, labelField: (l) => l.name, descField: (l) => l.description, emptyLabel: 'No locations yet', addLabel: 'Add location', newItem: () => WorldLocation(name: ''), onUpdate: () => setState(() {})),
                _ListEditor<WorldFaction>(items: _working.factions, labelField: (f) => f.name, descField: (f) => f.description, emptyLabel: 'No factions yet', addLabel: 'Add faction', newItem: () => WorldFaction(name: ''), onUpdate: () => setState(() {})),
                _editorScrollable([_field('History', _historyCtrl, maxLines: 12, hint: 'What happened before the story begins...')]),
                _editorScrollable([_field('World rules', _rulesCtrl, maxLines: 12, hint: 'Magic systems, physical laws, what death means here...')]),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _editorScrollable(List<Widget> children) => ScrollConfiguration(
    behavior: NoGlowBehavior(),
    child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: children)),
  );

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1, String hint = ''}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 3)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl, maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: cParchment, fontStyle: FontStyle.italic, height: 1.7),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: cSmoke, fontStyle: FontStyle.italic, fontSize: 13), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: cAsh)), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: cSmoke)), filled: true, fillColor: cInk),
        cursorColor: cGold,
      ),
      const SizedBox(height: 20),
    ],
  );
}

class _ListEditor<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) labelField;
  final String Function(T) descField;
  final String emptyLabel;
  final String addLabel;
  final T Function() newItem;
  final VoidCallback onUpdate;
  const _ListEditor({required this.items, required this.labelField, required this.descField, required this.emptyLabel, required this.addLabel, required this.newItem, required this.onUpdate});
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
            decoration: BoxDecoration(color: cInk, border: Border.all(color: editing ? cSmoke : cAsh)),
            child: editing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(controller: nameCtrl, style: const TextStyle(fontSize: 14, color: cParchment, fontStyle: FontStyle.italic), decoration: const InputDecoration(hintText: 'Name...', hintStyle: TextStyle(color: cSmoke), border: InputBorder.none), cursorColor: cGold, onChanged: (v) => _setName(item, v)),
                      const Divider(color: cAsh),
                      TextField(controller: descCtrl, maxLines: 3, style: const TextStyle(fontSize: 13, color: cMist, fontStyle: FontStyle.italic, height: 1.6), decoration: const InputDecoration(hintText: 'Description...', hintStyle: TextStyle(color: cSmoke), border: InputBorder.none), cursorColor: cGold, onChanged: (v) => _setDesc(item, v)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () { _setName(item, nameCtrl.text); _setDesc(item, descCtrl.text); setState(() => _editingIndex = null); widget.onUpdate(); },
                            child: const Text('Done', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cGold, letterSpacing: 1)),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() { widget.items.removeAt(i); _editingIndex = null; widget.onUpdate(); }),
                            child: const Icon(Icons.delete_outline, size: 16, color: cEmber),
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
                              Text(widget.labelField(item).isEmpty ? '(unnamed)' : widget.labelField(item), style: const TextStyle(fontSize: 14, color: cParchment, fontStyle: FontStyle.italic)),
                              if (widget.descField(item).isNotEmpty)
                                Text(widget.descField(item).length > 60 ? '${widget.descField(item).substring(0, 60)}...' : widget.descField(item), style: const TextStyle(fontSize: 12, color: cSmoke, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_outlined, size: 14, color: cSmoke),
                      ],
                    ),
                  ),
          );
        }),
        GestureDetector(
          onTap: () => setState(() { widget.items.add(widget.newItem()); _editingIndex = widget.items.length - 1; }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(border: Border.all(color: cAsh, style: BorderStyle.solid)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add, size: 14, color: cSmoke), const SizedBox(width: 8), Text(widget.addLabel, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: cSmoke, letterSpacing: 2))]),
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
  const CharacterEditorScreen({super.key, this.character, required this.worlds, required this.onSave});
  @override
  State<CharacterEditorScreen> createState() => _CharacterEditorScreenState();
}

class _CharacterEditorScreenState extends State<CharacterEditorScreen> {
  late CharacterEntry _working;
  late TextEditingController _nameCtrl, _pronounsCtrl, _ageCtrl, _appearanceCtrl, _personalityCtrl, _backstoryCtrl, _relationshipsCtrl, _notesCtrl;
  
  String? _avatarUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _working = c != null
        ? CharacterEntry(id: c.id, name: c.name, pronouns: c.pronouns, age: c.age, appearance: c.appearance, personality: c.personality, backstory: c.backstory, relationships: c.relationships, notes: c.notes, type: c.type, linkedWorldId: c.linkedWorldId, accentColor: c.accentColor, avatarUrl: c.avatarUrl)
        : CharacterEntry(id: DateTime.now().millisecondsSinceEpoch.toString(), name: '');
    _avatarUrl = _working.avatarUrl;
    _nameCtrl = TextEditingController(text: _working.name);
    _pronounsCtrl = TextEditingController(text: _working.pronouns);
    _ageCtrl = TextEditingController(text: _working.age);
    _appearanceCtrl = TextEditingController(text: _working.appearance);
    _personalityCtrl = TextEditingController(text: _working.personality);
    _backstoryCtrl = TextEditingController(text: _working.backstory);
    _relationshipsCtrl = TextEditingController(text: _working.relationships);
    _notesCtrl = TextEditingController(text: _working.notes);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() => _uploading = true);

    try {
      final ref = FirebaseStorage.instance.ref().child('characters/${_working.id}.jpg');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();
      final freshUrl = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
      await NetworkImage(url).evict();

      setState(() {
        _avatarUrl = freshUrl;
        _working.avatarUrl = freshUrl;
        _uploading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: cInk, content: Text('Upload failed: $e', style: const TextStyle(color: cEmber))));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _pronounsCtrl, _ageCtrl, _appearanceCtrl, _personalityCtrl, _backstoryCtrl, _relationshipsCtrl, _notesCtrl]) { c.dispose(); }
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
    _working.avatarUrl = _avatarUrl;
    widget.onSave(_working);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appSettings.bgColor,
    body: SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: cAsh))),
            child: Row(
              children: [
                GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close, color: cSmoke, size: 18)),
                const SizedBox(width: 12),
                
                GestureDetector(
                  onTap: _uploading ? null : _pickImage,
                  child: Container(
                    width: 36, height: 36,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: cInk, border: Border.all(color: cAsh),
                      image: _avatarUrl != null ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover) : null,
                    ),
                    child: _uploading 
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: cGold))
                        : (_avatarUrl == null ? const Icon(Icons.add_a_photo_outlined, size: 16, color: cSmoke) : null),
                  ),
                ),

                GestureDetector(
                  onTap: _pickAccentColor,
                  child: Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: _working.accentColor, border: Border.all(color: Colors.white24))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(fontSize: 20, color: cParchment, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic),
                    decoration: const InputDecoration(hintText: 'Character name...', hintStyle: TextStyle(color: cSmoke, fontSize: 20, fontStyle: FontStyle.italic, fontWeight: FontWeight.w300), border: InputBorder.none),
                    cursorColor: cGold,
                  ),
                ),
                GestureDetector(
                  onTap: _save,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), color: cParchment, child: const Text('Save', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cVoid, letterSpacing: 1))),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: cAsh))),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _working.type = _working.type == CharacterType.playerCharacter ? CharacterType.npc : CharacterType.playerCharacter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(border: Border.all(color: _working.type == CharacterType.playerCharacter ? cGold : cMagic)),
                    child: Text(_working.type == CharacterType.playerCharacter ? 'Player Character' : 'NPC', style: TextStyle(fontFamily: 'monospace', fontSize: 9, letterSpacing: 2, color: _working.type == CharacterType.playerCharacter ? cGold : cMagic)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _pronounsCtrl, style: const TextStyle(fontSize: 12, color: cSmoke), decoration: const InputDecoration(hintText: 'Pronouns', hintStyle: TextStyle(color: cSmoke, fontSize: 12), border: InputBorder.none, isDense: true), cursorColor: cGold)),
                const SizedBox(width: 10),
                SizedBox(width: 60, child: TextField(controller: _ageCtrl, style: const TextStyle(fontSize: 12, color: cSmoke), decoration: const InputDecoration(hintText: 'Age', hintStyle: TextStyle(color: cSmoke, fontSize: 12), border: InputBorder.none, isDense: true), cursorColor: cGold)),
              ],
            ),
          ),
          if (widget.worlds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: cAsh))),
              child: Row(
                children: [
                  const Text('World', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 3)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: NoGlowBehavior(),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _worldChip(null, 'None'),
                            ...widget.worlds.map((w) => _worldChip(w.id, w.name)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
        decoration: BoxDecoration(border: Border.all(color: active ? cGold : cAsh), color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent),
        child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 9, letterSpacing: 1, color: active ? cGold : cSmoke)),
      ),
    );
  }

  void _pickAccentColor() {
    LoreColourPicker.show(context, current: _working.accentColor, onPicked: (c) { setState(() => _working.accentColor = c); });
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 3)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl, maxLines: maxLines,
        style: TextStyle(fontSize: appSettings.baseFontSize, color: cParchment, fontStyle: FontStyle.italic, height: 1.7),
        decoration: const InputDecoration(enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cAsh)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cSmoke)), filled: true, fillColor: cInk),
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
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: cMist)),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(fontSize: 12, color: cSmoke)),
    ],
  ),
);

Widget _sheetAction(BuildContext context, IconData icon, String label, VoidCallback onTap, {Color color = cMist}) => GestureDetector(
  onTap: () {
    Navigator.of(context).pop();
    onTap();
  },
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: cAsh))),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 16),
        Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w300)),
      ],
    ),
  ),
);