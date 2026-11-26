import 'package:flutter/material.dart';

import '../models/fantasy_character.dart';
import '../models/fantasy_equipment.dart';
import '../models/fantasy_help.dart';
import '../models/fantasy_spells.dart';
import '../models/fantasy_subclass.dart';
import '../models/world.dart';
import '../theme.dart';

class FantasyRoomPreview extends StatefulWidget {
  const FantasyRoomPreview({super.key, required this.backgroundColor});

  final Color backgroundColor;

  @override
  State<FantasyRoomPreview> createState() => _FantasyRoomPreviewState();
}

class _FantasyRoomPreviewState extends State<FantasyRoomPreview> {
  late final Future<List<CharacterEntry>> _characters;
  final Map<CharacterEntry, FantasyCharacterDraft> _drafts = {};
  final ScrollController _scrollController = ScrollController();
  FantasyCharacterDraft? _draft;

  @override
  void initState() {
    super.initState();
    _characters = SandboxStorage.loadCharacters();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showCharacters() {
    setState(() => _draft = null);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _selectCharacter(CharacterEntry character) {
    setState(() {
      _draft = _drafts.putIfAbsent(
        character,
        () => FantasyCharacterDraft.fromSandbox(character),
      );
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  String _label(String name) => name
      .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
      .replaceFirstMapped(
        RegExp(r'^.'),
        (match) => match.group(0)!.toUpperCase(),
      );

  String _bonus(int value) => value >= 0 ? '+$value' : '$value';

  String _equipmentTraining(bool? trained) => switch (trained) {
    true => 'Trained',
    false => 'Untrained',
    null => 'Choose class',
  };

  Widget _equipmentOption(String label, String status) => Tooltip(
    message: '$label: $status',
    child: Row(
      children: [
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text(status, style: const TextStyle(fontSize: 10, color: cMist)),
      ],
    ),
  );

  Future<void> _adjustHitPoints(
    FantasyCharacterDraft draft, {
    required bool healing,
  }) async {
    final formKey = GlobalKey<FormState>();
    var amountText = '';
    var necrotic = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text(healing ? 'Heal' : 'Take damage'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('hit-points-amount'),
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hit points'),
                  onChanged: (value) => amountText = value,
                  validator: (value) {
                    final amount = int.tryParse((value ?? '').trim());
                    return amount == null || amount <= 0
                        ? 'Enter a positive whole number.'
                        : null;
                  },
                ),
                if (!healing && draft.hasNecroticResistance)
                  CheckboxListTile(
                    key: const ValueKey('necrotic-damage'),
                    title: const Text('Necrotic damage'),
                    subtitle: const Text('Resistance halves this damage.'),
                    value: necrotic,
                    onChanged: (value) =>
                        updateDialog(() => necrotic = value == true),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('hit-points-confirm'),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final amount = int.parse(amountText.trim());
                setState(() {
                  if (healing) {
                    draft.heal(amount);
                  } else {
                    draft.takeDamage(amount, necrotic: necrotic);
                  }
                });
                Navigator.pop(dialogContext);
              },
              child: Text(healing ? 'Heal' : 'Apply damage'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyGrimHarvest(FantasyCharacterDraft draft) async {
    var spellLevel = 1;
    var necromancy = false;
    var confirmed = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Grim Harvest'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select the spell’s level at casting.'),
                DropdownButton<int>(
                  key: const ValueKey('grim-harvest-level'),
                  value: spellLevel,
                  items: [
                    for (var level = 1; level <= 9; level++)
                      DropdownMenuItem(
                        value: level,
                        child: Text('Level $level'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) updateDialog(() => spellLevel = value);
                  },
                ),
                CheckboxListTile(
                  key: const ValueKey('grim-harvest-necromancy'),
                  title: const Text('Necromancy spell'),
                  value: necromancy,
                  onChanged: (value) =>
                      updateDialog(() => necromancy = value == true),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  key: const ValueKey('grim-harvest-confirm-kill'),
                  title: const Text(
                    'The spell killed a creature that was not a construct or undead.',
                  ),
                  value: confirmed,
                  onChanged: (value) =>
                      updateDialog(() => confirmed = value == true),
                  contentPadding: EdgeInsets.zero,
                ),
                const Text(
                  'Combat events and spell casting are confirmed manually.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('grim-harvest-apply'),
              onPressed: confirmed
                  ? () {
                      setState(
                        () => draft.applyGrimHarvest(
                          spellLevel: spellLevel,
                          necromancy: necromancy,
                          eligibleKill: confirmed,
                        ),
                      );
                      Navigator.pop(dialogContext);
                    }
                  : null,
              child: Text('Heal ${spellLevel * (necromancy ? 3 : 2)} HP'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp(String title, FantasyHelp help) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cInk,
        title: Text(title, style: const TextStyle(color: cGold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(help.description, style: const TextStyle(color: cParchment)),
              const SizedBox(height: 12),
              Text(help.classes, style: const TextStyle(color: cMist)),
              const SizedBox(height: 8),
              const Text(
                'These are examples, not class restrictions.',
                style: TextStyle(color: cSmoke),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSpells(
    FantasyCharacterDraft draft,
    SpellChoice choice,
  ) async {
    final casting = draft.spellcasting;
    final title = switch (choice) {
      SpellChoice.cantrip => 'Choose cantrips',
      SpellChoice.prepared => 'Prepare spells',
      SpellChoice.spellbook => 'Edit spellbook',
      SpellChoice.arcanum => 'Choose Mystic Arcanum',
      SpellChoice.discovery => 'Choose Magical Discoveries',
    };
    var search = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) {
          final selected = switch (choice) {
            SpellChoice.cantrip => casting.cantrips,
            SpellChoice.prepared => casting.prepared,
            SpellChoice.spellbook => casting.spellbook,
            SpellChoice.arcanum => casting.arcana,
            SpellChoice.discovery => casting.discoveries,
          };
          final options = casting
              .options(choice)
              .where((spell) => spell.name.toLowerCase().contains(search))
              .toList();
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 540,
              height: 440,
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('spell-search'),
                    decoration: const InputDecoration(
                      labelText: 'Search spells',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        updateDialog(() => search = value.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: options.isEmpty
                        ? const Center(child: Text('No matching spells.'))
                        : ListView.builder(
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final spell = options[index];
                              final reason = casting.reasonUnavailable(
                                spell,
                                choice,
                              );
                              return CheckboxListTile(
                                key: ValueKey(
                                  'spell-${choice.name}-${spell.id}',
                                ),
                                title: Text(spell.name),
                                subtitle: Text(
                                  '${spell.level == 0 ? 'Cantrip' : 'Level ${spell.level}'}'
                                  '${reason == null ? '' : ' · $reason'}',
                                ),
                                value: selected.contains(spell),
                                onChanged: reason == null
                                    ? (value) {
                                        setState(() {
                                          casting.setSelected(
                                            spell,
                                            choice,
                                            value ?? false,
                                          );
                                        });
                                        updateDialog(() {});
                                      }
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _spellSummary(String label, Set<FantasySpell> spells) {
    final sorted = spells.toList()
      ..sort((a, b) {
        final level = a.level.compareTo(b.level);
        return level != 0 ? level : a.name.compareTo(b.name);
      });
    return Text(
      '$label: ${sorted.isEmpty ? 'None selected' : sorted.map((spell) => spell.name).join(', ')}',
      style: const TextStyle(color: cParchment),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: _draft == null,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _draft != null) _showCharacters();
    },
    child: Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        title: const Text('Fantasy room preview'),
        backgroundColor: cInk,
        foregroundColor: cParchment,
        leading: _draft == null ? null : BackButton(onPressed: _showCharacters),
      ),
      body: FutureBuilder<List<CharacterEntry>>(
        future: _characters,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load characters: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final characters = snapshot.data!;
          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'LOCAL PREVIEW',
                style: TextStyle(color: cGold, letterSpacing: 3),
              ),
              const SizedBox(height: 8),
              const Text(
                'Drafts are temporary: they are not saved, synced or shared, '
                'and are discarded when you leave. '
                'Dice rolls will be added when secure server-side rolls are ready.',
                style: TextStyle(color: cMist),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Rules credit'),
                      content: const SingleChildScrollView(
                        child: SelectableText(
                          'This preview adapts material from the System '
                          'Reference Document 5.2.1 by Wizards of the Coast '
                          'LLC: https://www.dndbeyond.com/srd\n\n'
                          'The SRD is licensed under Creative Commons '
                          'Attribution 4.0 International: '
                          'https://creativecommons.org/licenses/by/4.0/',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Rules credit'),
                ),
              ),
              const SizedBox(height: 20),
              if (_draft == null && characters.isEmpty)
                const Text(
                  'Create a character in Sandbox to try a sheet.',
                  style: TextStyle(color: cParchment),
                )
              else if (_draft == null) ...[
                const Text(
                  'IMPORT FROM SANDBOX',
                  style: TextStyle(color: cGold),
                ),
                const SizedBox(height: 8),
                ...characters.map(
                  (character) => ListTile(
                    title: Text(
                      character.name,
                      style: const TextStyle(color: cParchment),
                    ),
                    subtitle: Text(
                      character.type == CharacterType.npc ? 'NPC' : 'Character',
                      style: const TextStyle(color: cSmoke),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: cGold),
                    onTap: () => _selectCharacter(character),
                  ),
                ),
              ],
              if (_draft case final draft?) ...[
                const Divider(color: cAsh),
                Text(
                  draft.name,
                  style: const TextStyle(color: cParchment, fontSize: 24),
                ),
                const SizedBox(height: 8),
                DropdownButton<FantasyRole>(
                  value: draft.role,
                  dropdownColor: cInk,
                  style: const TextStyle(color: cParchment),
                  items: FantasyRole.values.map((role) {
                    final name = role == FantasyRole.npc
                        ? 'NPC'
                        : _label(role.name);
                    return DropdownMenuItem(value: role, child: Text(name));
                  }).toList(),
                  onChanged: (role) {
                    if (role != null) setState(() => draft.role = role);
                  },
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Level', style: TextStyle(color: cParchment)),
                    IconButton(
                      tooltip: 'Decrease level',
                      onPressed: draft.level > 1
                          ? () => setState(() => draft.level--)
                          : null,
                      icon: const Icon(Icons.remove),
                      color: cGold,
                    ),
                    Text(
                      '${draft.level}',
                      style: const TextStyle(color: cParchment),
                    ),
                    IconButton(
                      tooltip: 'Increase level',
                      onPressed: draft.level < 20
                          ? () => setState(() => draft.level++)
                          : null,
                      icon: const Icon(Icons.add),
                      color: cGold,
                    ),
                    Text(
                      'Proficiency ${_bonus(draft.proficiencyBonus)}',
                      style: const TextStyle(color: cSmoke),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'STARTING ABILITIES',
                  style: TextStyle(color: cGold, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                const Text('Background', style: TextStyle(color: cParchment)),
                DropdownButton<FantasyBackground?>(
                  key: const ValueKey('background'),
                  value: draft.background,
                  isExpanded: true,
                  dropdownColor: cInk,
                  style: const TextStyle(color: cParchment),
                  items: [
                    const DropdownMenuItem<FantasyBackground?>(
                      value: null,
                      child: Text('Choose a background'),
                    ),
                    ...FantasyBackground.values.map(
                      (background) => DropdownMenuItem<FantasyBackground?>(
                        value: background,
                        child: Text(_label(background.name)),
                      ),
                    ),
                  ],
                  onChanged: (background) =>
                      setState(() => draft.setBackground(background)),
                ),
                if (draft.background case final background?) ...[
                  Text(
                    'Available: ${background.abilities.map((a) => _label(a.name)).join(', ')}',
                    style: const TextStyle(color: cMist),
                  ),
                  Text(
                    'Skills: ${background.skills.map((skill) => _label(skill.name)).join(', ')}',
                    key: const ValueKey('background-skills'),
                    style: const TextStyle(color: cMist),
                  ),
                  DropdownButton<BackgroundBonusMethod>(
                    key: const ValueKey('background-method'),
                    value: draft.backgroundMethod,
                    dropdownColor: cInk,
                    style: const TextStyle(color: cParchment),
                    items: const [
                      DropdownMenuItem(
                        value: BackgroundBonusMethod.twoAndOne,
                        child: Text('+2 and +1'),
                      ),
                      DropdownMenuItem(
                        value: BackgroundBonusMethod.oneEach,
                        child: Text('+1 to each'),
                      ),
                    ],
                    onChanged: (method) {
                      if (method != null) {
                        setState(() => draft.setBackgroundMethod(method));
                      }
                    },
                  ),
                  if (draft.backgroundMethod == BackgroundBonusMethod.twoAndOne)
                    Wrap(
                      spacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ...[2, 1].map(
                          (amount) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '+$amount ',
                                style: const TextStyle(color: cMist),
                              ),
                              DropdownButton<FantasyAbility>(
                                key: ValueKey('background-plus-$amount'),
                                value: amount == 2
                                    ? draft.backgroundTwo
                                    : draft.backgroundOne,
                                dropdownColor: cInk,
                                style: const TextStyle(color: cParchment),
                                items: background.abilities
                                    .map(
                                      (ability) => DropdownMenuItem(
                                        value: ability,
                                        child: Text(_label(ability.name)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (ability) {
                                  if (ability != null) {
                                    setState(() {
                                      if (amount == 2) {
                                        draft.setBackgroundTwo(ability);
                                      } else {
                                        draft.setBackgroundOne(ability);
                                      }
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
                const Text(
                  'Changing background resets its ability choices and removes '
                  'overlapping class skill choices. Background feats, tools '
                  'and equipment are not yet included.',
                  style: TextStyle(color: cSmoke),
                ),
                const SizedBox(height: 8),
                DropdownButton<AbilityScoreMethod>(
                  key: const ValueKey('ability-score-method'),
                  value: draft.scoreMethod,
                  dropdownColor: cInk,
                  style: const TextStyle(color: cParchment),
                  items: const [
                    DropdownMenuItem(
                      value: AbilityScoreMethod.pointBuy,
                      child: Text('Point buy'),
                    ),
                    DropdownMenuItem(
                      value: AbilityScoreMethod.standardArray,
                      child: Text('Standard array'),
                    ),
                  ],
                  onChanged: (method) {
                    if (method != null) {
                      setState(() => draft.scoreMethod = method);
                    }
                  },
                ),
                Text(
                  draft.scoreMethod == AbilityScoreMethod.pointBuy
                      ? '${draft.pointsRemaining} of 27 points remaining'
                      : 'Each standard score is used once; changing one swaps it.',
                  style: const TextStyle(color: cMist),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Adjust base scores below. Modifiers include background '
                  'bonuses; later improvements are not yet included.',
                  style: TextStyle(color: cSmoke),
                ),
                ...FantasyAbility.values.map(
                  (ability) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _label(ability.name),
                              style: const TextStyle(color: cParchment),
                            ),
                          ),
                          IconButton(
                            tooltip: 'About ${_label(ability.name)}',
                            onPressed: () => _showHelp(
                              _label(ability.name),
                              abilityHelp(ability),
                            ),
                            icon: const Icon(Icons.info_outline, size: 18),
                            color: cGold,
                          ),
                          if (draft.scoreMethod ==
                              AbilityScoreMethod.pointBuy) ...[
                            IconButton(
                              tooltip: 'Decrease ${_label(ability.name)}',
                              onPressed:
                                  draft.canSetScore(
                                    ability,
                                    draft.score(ability) - 1,
                                  )
                                  ? () => setState(
                                      () => draft.setScore(
                                        ability,
                                        draft.score(ability) - 1,
                                      ),
                                    )
                                  : null,
                              icon: const Icon(Icons.remove),
                              color: cGold,
                            ),
                            Text(
                              '${draft.score(ability)}',
                              style: const TextStyle(color: cParchment),
                            ),
                            IconButton(
                              tooltip: 'Increase ${_label(ability.name)}',
                              onPressed:
                                  draft.canSetScore(
                                    ability,
                                    draft.score(ability) + 1,
                                  )
                                  ? () => setState(
                                      () => draft.setScore(
                                        ability,
                                        draft.score(ability) + 1,
                                      ),
                                    )
                                  : null,
                              icon: const Icon(Icons.add),
                              color: cGold,
                            ),
                          ] else
                            DropdownButton<int>(
                              key: ValueKey('ability-${ability.name}-array'),
                              value: draft.score(ability),
                              dropdownColor: cInk,
                              style: const TextStyle(color: cParchment),
                              items: FantasyCharacterDraft.standardArray
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text('$value'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(
                                    () => draft.assignStandardScore(
                                      ability,
                                      value,
                                    ),
                                  );
                                }
                              },
                            ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              _bonus(draft.abilityModifier(ability)),
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: cSmoke),
                            ),
                          ),
                        ],
                      ),
                      if (draft.backgroundBonus(ability) > 0)
                        Text(
                          '${_label(ability.name)}: ${draft.score(ability)} base + '
                          '${draft.backgroundBonus(ability)} background = ${draft.totalScore(ability)}',
                          key: ValueKey('ability-${ability.name}-total'),
                          style: const TextStyle(color: cMist),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SKILLS',
                  style: TextStyle(color: cGold, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Starting class',
                  style: TextStyle(color: cParchment),
                ),
                DropdownButton<FantasyClass?>(
                  key: const ValueKey('starting-class'),
                  value: draft.characterClass,
                  dropdownColor: cInk,
                  style: const TextStyle(color: cParchment),
                  items: [
                    const DropdownMenuItem<FantasyClass?>(
                      value: null,
                      child: Text('Choose a class'),
                    ),
                    ...FantasyClass.values.map(
                      (characterClass) => DropdownMenuItem<FantasyClass?>(
                        value: characterClass,
                        child: Text(_label(characterClass.name)),
                      ),
                    ),
                  ],
                  onChanged: (characterClass) =>
                      setState(() => draft.characterClass = characterClass),
                ),
                if (draft.characterClass case final characterClass?) ...[
                  const Text('Subclass', style: TextStyle(color: cParchment)),
                  DropdownButton<FantasySubclass?>(
                    key: const ValueKey('subclass'),
                    value: draft.subclass,
                    isExpanded: true,
                    dropdownColor: cInk,
                    style: const TextStyle(color: cParchment),
                    items: [
                      DropdownMenuItem<FantasySubclass?>(
                        value: null,
                        child: Text(
                          draft.level < 3
                              ? 'Available at level 3'
                              : 'Choose a subclass',
                        ),
                      ),
                      ...FantasySubclass.values
                          .where(
                            (subclass) =>
                                subclass.characterClass == characterClass,
                          )
                          .map(
                            (subclass) => DropdownMenuItem<FantasySubclass?>(
                              value: subclass,
                              child: Text(subclass.label),
                            ),
                          ),
                    ],
                    onChanged: draft.level < 3
                        ? null
                        : (subclass) =>
                              setState(() => draft.setSubclass(subclass)),
                  ),
                  if (draft.subclass == FantasySubclass.land) ...[
                    const Text(
                      'Choose a land after a long rest; rest timing is not tracked.',
                      style: TextStyle(color: cMist),
                    ),
                    DropdownButton<FantasyLand?>(
                      key: const ValueKey('druid-land'),
                      value: draft.land,
                      isExpanded: true,
                      dropdownColor: cInk,
                      style: const TextStyle(color: cParchment),
                      items: [
                        const DropdownMenuItem<FantasyLand?>(
                          value: null,
                          child: Text('Choose a land'),
                        ),
                        ...FantasyLand.values.map(
                          (land) => DropdownMenuItem<FantasyLand?>(
                            value: land,
                            child: Text(_label(land.name)),
                          ),
                        ),
                      ],
                      onChanged: (land) => setState(() => draft.setLand(land)),
                    ),
                  ],
                  if (draft.subclass == FantasySubclass.necromancer)
                    const Text(
                      'Legacy Necromancers can still learn spells from other '
                      'schools. At level 6, Animate Dead is added to the spellbook.',
                      style: TextStyle(color: cMist),
                    ),
                  const Text(
                    'Changing subclass or land can change prepared spells. '
                    'Dropping below level 3 clears the subclass.',
                    style: TextStyle(color: cSmoke),
                  ),
                  Text(
                    'Starting class skills: ${draft.classSkills.length} '
                    'of ${characterClass.skillCount} selected',
                    style: const TextStyle(color: cMist),
                  ),
                  const Text(
                    'Skills already granted by your background cannot also '
                    'use a class choice.',
                    style: TextStyle(color: cSmoke),
                  ),
                  Wrap(
                    spacing: 6,
                    children: FantasySkill.values
                        .where(characterClass.skillChoices.contains)
                        .map((skill) {
                          final selected = draft.classSkills.contains(skill);
                          final fromBackground = draft.backgroundSkills
                              .contains(skill);
                          final canSelect =
                              selected ||
                              (!fromBackground &&
                                  draft.classSkills.length <
                                      characterClass.skillCount);
                          return FilterChip(
                            key: ValueKey('class-skill-${skill.name}'),
                            label: Text(
                              '${_label(skill.name)}${fromBackground ? ' (background)' : ''}',
                            ),
                            selected: selected,
                            onSelected: canSelect
                                ? (value) => setState(
                                    () => draft.setClassSkill(skill, value),
                                  )
                                : null,
                          );
                        })
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'SPELLS',
                  style: TextStyle(color: cGold, letterSpacing: 2),
                ),
                if (!draft.spellcasting.available)
                  const Text(
                    'Choose a base spellcasting class to select spells. '
                    'Subclass spellcasting is not yet included.',
                    style: TextStyle(color: cMist),
                  )
                else ...[
                  if (draft.spellcasting.spellcastingAbility
                      case final ability?) ...[
                    Text(
                      'Spellcasting ability: ${_label(ability.name)}',
                      key: const ValueKey('spellcasting-ability'),
                      style: const TextStyle(color: cParchment),
                    ),
                    Text(
                      'Spell attack: ${_bonus(draft.spellcasting.spellAttackBonus!)}',
                      key: const ValueKey('spell-attack-bonus'),
                      style: const TextStyle(color: cParchment),
                    ),
                    Text(
                      'Spell save DC: ${draft.spellcasting.spellSaveDc}',
                      key: const ValueKey('spell-save-dc'),
                      style: const TextStyle(color: cParchment),
                    ),
                    const Text(
                      'Based on starting class, ability modifier and '
                      'proficiency; magic items and other bonuses are not tracked.',
                      style: TextStyle(color: cSmoke),
                    ),
                  ],
                  const Text(
                    'Changing class clears spell '
                    'selections; lowering level removes ineligible or excess '
                    'choices. Subclass bonus spells and a limited Necromancer '
                    'preview are shown; other subclass abilities, feats, species, '
                    'multiclassing, spell descriptions, and '
                    'rest/level-up replacement restrictions are not tracked. '
                    'Wizard Spell Mastery and Signature Spells are not yet tracked.',
                    style: TextStyle(color: cSmoke),
                  ),
                  ExpansionTile(
                    key: const ValueKey('spell-slots'),
                    title: const Text(
                      'Spell slots',
                      style: TextStyle(color: cParchment),
                    ),
                    children: [
                      const Text(
                        'Track slots manually; this does not cast spells or '
                        'apply their effects. Changing class resets slots. '
                        'Level changes preserve spent slots.',
                        style: TextStyle(color: cSmoke),
                      ),
                      for (var level = 1; level <= 9; level++)
                        if (draft.spellcasting.slotMaximum(level) > 0)
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Level $level: '
                                '${draft.spellcasting.remainingSlots(level)} / '
                                '${draft.spellcasting.slotMaximum(level)}',
                                key: ValueKey('spell-slots-$level'),
                                style: const TextStyle(color: cParchment),
                              ),
                              OutlinedButton(
                                key: ValueKey('expend-slot-$level'),
                                onPressed:
                                    draft.spellcasting.remainingSlots(level) > 0
                                    ? () => setState(
                                        () => draft.spellcasting.expendSlot(
                                          level,
                                        ),
                                      )
                                    : null,
                                child: const Text('Use'),
                              ),
                              OutlinedButton(
                                key: ValueKey('restore-slot-$level'),
                                onPressed:
                                    draft.spellcasting.spentSlots(level) > 0
                                    ? () => setState(
                                        () => draft.spellcasting.restoreSlot(
                                          level,
                                        ),
                                      )
                                    : null,
                                child: const Text('Undo'),
                              ),
                            ],
                          ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (draft.characterClass == FantasyClass.warlock)
                            OutlinedButton(
                              key: const ValueKey('short-rest-slots'),
                              onPressed: () => setState(
                                draft.spellcasting.restoreSlotsAfterShortRest,
                              ),
                              child: const Text('Short rest: restore slots'),
                            ),
                          OutlinedButton(
                            key: const ValueKey('long-rest-slots'),
                            onPressed: () => setState(
                              draft.spellcasting.restoreSlotsAfterLongRest,
                            ),
                            child: const Text('Long rest: restore slots'),
                          ),
                        ],
                      ),
                      const Text(
                        'Rest buttons only restore slots, not other abilities '
                        'or hit points. Mystic Arcanum and other slot recovery '
                        'features are not tracked.',
                        style: TextStyle(color: cSmoke),
                      ),
                    ],
                  ),
                  if (draft.spellcasting.cantripLimit > 0) ...[
                    _spellSummary('Cantrips', draft.spellcasting.cantrips),
                    Text(
                      '${draft.spellcasting.cantrips.length} / '
                      '${draft.spellcasting.cantripLimit} cantrips',
                      style: const TextStyle(color: cMist),
                    ),
                    OutlinedButton(
                      key: const ValueKey('choose-cantrips'),
                      onPressed: () => _showSpells(draft, SpellChoice.cantrip),
                      child: const Text('Choose cantrips'),
                    ),
                  ],
                  _spellSummary('Prepared', draft.spellcasting.prepared),
                  Text(
                    '${draft.spellcasting.prepared.length} / '
                    '${draft.spellcasting.preparedLimit} prepared spells',
                    style: const TextStyle(color: cMist),
                  ),
                  if (draft.spellcasting.alwaysPrepared.isNotEmpty)
                    _spellSummary(
                      'Always prepared (class or subclass)',
                      draft.spellcasting.alwaysPrepared,
                    ),
                  if (draft.subclass == FantasySubclass.lore &&
                      draft.level >= 6) ...[
                    Text(
                      '${draft.spellcasting.discoveries.length} / 2 Magical Discoveries',
                      style: const TextStyle(color: cMist),
                    ),
                    OutlinedButton(
                      key: const ValueKey('choose-discoveries'),
                      onPressed: () =>
                          _showSpells(draft, SpellChoice.discovery),
                      child: const Text('Choose Magical Discoveries'),
                    ),
                  ],
                  if (draft.characterClass == FantasyClass.wizard) ...[
                    Text(
                      'Spellbook: ${draft.spellcasting.spellbook.length} '
                      '${draft.spellcasting.spellbook.length == 1 ? 'spell' : 'spells'}. '
                      'Start with six; gain two per Wizard level. Additional '
                      'spells may be copied; acquisition is not tracked.',
                      style: const TextStyle(color: cMist),
                    ),
                    OutlinedButton(
                      key: const ValueKey('edit-spellbook'),
                      onPressed: () =>
                          _showSpells(draft, SpellChoice.spellbook),
                      child: const Text('Edit spellbook'),
                    ),
                  ],
                  OutlinedButton(
                    key: const ValueKey('prepare-spells'),
                    onPressed: () => _showSpells(draft, SpellChoice.prepared),
                    child: const Text('Prepare spells'),
                  ),
                  if (draft.characterClass == FantasyClass.warlock) ...[
                    Text(
                      'Pact Magic uses level ${draft.spellcasting.maximumSpellLevel} '
                      'slots. Mystic Arcanum is separate from Pact Magic.',
                      style: const TextStyle(color: cMist),
                    ),
                    if (draft.level >= 11) ...[
                      _spellSummary(
                        'Mystic Arcanum',
                        draft.spellcasting.arcana,
                      ),
                      OutlinedButton(
                        key: const ValueKey('choose-arcanum'),
                        onPressed: () =>
                            _showSpells(draft, SpellChoice.arcanum),
                        child: const Text('Choose Mystic Arcanum'),
                      ),
                    ],
                  ],
                  const Text(
                    'Spell names and class lists follow the SRD; '
                    'some listed spells have no description in the SRD.',
                    style: TextStyle(color: cSmoke),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'HIT POINTS',
                  style: TextStyle(color: cGold, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                Text(
                  draft.currentHitPoints == null
                      ? 'Choose a class to calculate hit points.'
                      : '${draft.currentHitPoints} / ${draft.hitPointMaximum} HP',
                  key: const ValueKey('hit-points-total'),
                  style: const TextStyle(color: cParchment, fontSize: 18),
                ),
                if (draft.characterClass case final characterClass?) ...[
                  Text(
                    'Level 1: d${characterClass.hitDie} maximum + Constitution. '
                    'Later levels use the fixed value '
                    '${characterClass.hitDie ~/ 2 + 1} + Constitution per level.',
                    style: const TextStyle(color: cMist),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        key: const ValueKey('take-damage'),
                        onPressed: draft.currentHitPoints! > 0
                            ? () => _adjustHitPoints(draft, healing: false)
                            : null,
                        child: const Text('Take damage'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('heal'),
                        onPressed:
                            draft.currentHitPoints! < draft.hitPointMaximum!
                            ? () => _adjustHitPoints(draft, healing: true)
                            : null,
                        child: const Text('Heal'),
                      ),
                    ],
                  ),
                  const Text(
                    'When the maximum changes, a full character stays full; '
                    'otherwise current HP stays the same, capped at the new '
                    'maximum. Temporary HP, conditions, massive damage and '
                    'death saves are not tracked. Resistance is only applied '
                    'for the Necromancer option described below.',
                    style: TextStyle(color: cSmoke),
                  ),
                ],
                if (draft.subclass == FantasySubclass.necromancer)
                  ExpansionTile(
                    key: const ValueKey('necromancer-abilities'),
                    title: const Text(
                      'Necromancer abilities',
                      style: TextStyle(color: cGold),
                    ),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      const Text(
                        'Necromancy Savant: copying Necromancy spells takes '
                        'half the usual time and gold. Copying is not tracked.',
                        style: TextStyle(color: cMist),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Grim Harvest: once per game turn, a qualifying spell '
                        'kill restores HP. Confirm the event and mark each new '
                        'game turn manually; combat is not tracked.',
                        style: TextStyle(color: cMist),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            key: const ValueKey('grim-harvest'),
                            onPressed: draft.grimHarvestUsed
                                ? null
                                : () => _applyGrimHarvest(draft),
                            child: const Text('Use Grim Harvest'),
                          ),
                          OutlinedButton(
                            key: const ValueKey('grim-harvest-new-turn'),
                            onPressed: draft.grimHarvestUsed
                                ? () => setState(draft.startNecromancerTurn)
                                : null,
                            child: const Text('Mark new game turn'),
                          ),
                        ],
                      ),
                      if (draft.level >= 6) ...[
                        Text(
                          'Undead Thralls: undead you create with a Necromancy '
                          'spell gain +${draft.level} maximum HP and '
                          '+${draft.proficiencyBonus} weapon damage. Animate '
                          'Dead can create one additional undead. Creature '
                          'records and casting are not tracked.',
                          style: const TextStyle(color: cMist),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (draft.level >= 10) ...[
                        const Text(
                          'Inured to Undeath: choose Necrotic damage in the '
                          'damage dialog to apply resistance. Prevention of '
                          'maximum-HP reduction is not tracked.',
                          style: TextStyle(color: cMist),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (draft.level >= 14)
                        const Text(
                          'Command Undead can attempt to control an undead '
                          'creature. Targets, saving throws and control are '
                          'not tracked.',
                          style: TextStyle(color: cMist),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Extra training below can represent other sources, such as '
                  'species or feats. Those sources and expertise requirements '
                  'are not yet checked. Proficiency does not stack.',
                  style: TextStyle(color: cSmoke),
                ),
                ...FantasySkill.values.map(
                  (skill) => Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _label(skill.name),
                              style: const TextStyle(color: cParchment),
                            ),
                            if (draft.backgroundSkills.contains(skill))
                              const Text(
                                'Background',
                                style: TextStyle(color: cSmoke, fontSize: 11),
                              )
                            else if (draft.classSkills.contains(skill))
                              const Text(
                                'Class',
                                style: TextStyle(color: cSmoke, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'About ${_label(skill.name)}',
                        onPressed: () =>
                            _showHelp(_label(skill.name), skillHelp(skill)),
                        icon: const Icon(Icons.info_outline, size: 18),
                        color: cGold,
                      ),
                      DropdownButton<SkillTraining>(
                        key: ValueKey('skill-${skill.name}-training'),
                        value: draft.extraTraining(skill),
                        dropdownColor: cInk,
                        style: const TextStyle(color: cParchment),
                        items: SkillTraining.values
                            .map(
                              (training) => DropdownMenuItem(
                                value: training,
                                child: Text(
                                  training == SkillTraining.untrained
                                      ? 'None'
                                      : _label(training.name),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (training) {
                          if (training != null) {
                            setState(() => draft.setTraining(skill, training));
                          }
                        },
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          _bonus(draft.skillBonus(skill)),
                          key: ValueKey('skill-${skill.name}-bonus'),
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: cGold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'EQUIPMENT PREVIEW',
                  style: TextStyle(color: cGold, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose one weapon, one suit of armor and a shield to try. '
                  'This is not an inventory: starting gear, purchases, magic '
                  'items, class options and other sources of training are not '
                  'yet tracked.',
                  style: TextStyle(color: cSmoke),
                ),
                const Text(
                  'The pickers show starting-class training and low ability '
                  'scores. Untrained gear can still be selected, with penalties.',
                  style: TextStyle(color: cMist),
                ),
                const SizedBox(height: 12),
                const Text('Weapon', style: TextStyle(color: cParchment)),
                DropdownButton<FantasyWeapon?>(
                  key: const ValueKey('equipment-weapon'),
                  value: draft.weapon,
                  isExpanded: true,
                  dropdownColor: cInk,
                  style: const TextStyle(color: cParchment),
                  items: [
                    const DropdownMenuItem<FantasyWeapon?>(
                      value: null,
                      child: Text('No weapon selected'),
                    ),
                    ...FantasyWeapon.values.map(
                      (weapon) => DropdownMenuItem<FantasyWeapon?>(
                        value: weapon,
                        child: _equipmentOption(
                          '${_label(weapon.name)} (${weapon.category.name})',
                          [
                            if (draft.heavyWeaponRequirementMet(weapon) ==
                                false)
                              weapon.heavyAbility == HeavyWeaponAbility.strength
                                  ? 'Low Str'
                                  : 'Low Dex',
                            _equipmentTraining(draft.weaponProficient(weapon)),
                          ].join(' · '),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (weapon) => setState(() => draft.weapon = weapon),
                ),
                if (draft.weapon case final weapon?) ...[
                  Text(
                    'Base damage: ${weapon.damage}'
                    '${weapon.properties.isEmpty ? '' : ' · ${weapon.properties}'}',
                    key: const ValueKey('equipment-weapon-details'),
                    style: const TextStyle(color: cMist),
                  ),
                  Text(
                    switch (draft.weaponProficient(weapon)) {
                      true => 'Proficient from starting class.',
                      false =>
                        'Not proficient from starting class; you can '
                            'still use it, but do not add proficiency to attacks.',
                      null => 'Choose a class to check proficiency.',
                    },
                    key: const ValueKey('equipment-weapon-training'),
                    style: const TextStyle(color: cSmoke),
                  ),
                  if (draft.characterClass != null) ...[
                    for (final ability in draft.weaponAttackAbilities(weapon))
                      Text(
                        '${_label(ability.name)}: attack '
                        '${_bonus(draft.weaponAttackBonus(weapon, ability))}; '
                        'damage modifier ${_bonus(draft.abilityModifier(ability))}',
                        key: ValueKey('weapon-attack-${ability.name}'),
                        style: const TextStyle(color: cParchment),
                      ),
                    if (draft.weaponAttackAbilities(weapon).length > 1)
                      const Text(
                        'Choose either ability; use the same one for the '
                        'attack and damage.',
                        style: TextStyle(color: cSmoke),
                      ),
                    if (draft.monkWeaponDie(weapon) case final die?)
                      Text(
                        'Monk Martial Arts: you may use 1d$die in place of '
                        'the weapon’s damage die.',
                        key: const ValueKey('monk-weapon-die'),
                        style: const TextStyle(color: cMist),
                      ),
                    if (draft.weaponAttackDisadvantage(weapon))
                      const Text(
                        'Attack disadvantage applies from untrained armor '
                        'or shield, or the heavy weapon requirement.',
                        key: ValueKey('weapon-attack-disadvantage'),
                        style: TextStyle(color: cMist),
                      ),
                    const Text(
                      'Starting-class bonuses only. These numbers do not '
                      'resolve attacks, range, two-weapon fighting, magic, '
                      'conditions, class options or other modifiers.',
                      style: TextStyle(color: cSmoke),
                    ),
                  ],
                  if (weapon.heavyAbility case final ability?)
                    Text(
                      '${ability == HeavyWeaponAbility.strength ? 'Strength' : 'Dexterity'} '
                      '13 is needed to avoid disadvantage on attacks with '
                      'this heavy weapon.'
                      '${draft.heavyWeaponRequirementMet(weapon) == false ? ' Requirement not met.' : ''}',
                      key: const ValueKey('equipment-heavy-requirement'),
                      style: const TextStyle(color: cMist),
                    ),
                  if (draft.shield && weapon.twoHanded)
                    Text(
                      weapon == FantasyWeapon.lance
                          ? 'A lance requires two hands unless mounted; '
                                'a wielded shield occupies one hand.'
                          : 'This weapon needs two hands to attack; '
                                'a wielded shield occupies one hand.',
                      style: const TextStyle(color: cMist),
                    ),
                ],
                const SizedBox(height: 12),
                const Text('Armor', style: TextStyle(color: cParchment)),
                DropdownButton<FantasyArmor?>(
                  key: const ValueKey('equipment-armor'),
                  value: draft.armor,
                  isExpanded: true,
                  dropdownColor: cInk,
                  style: const TextStyle(color: cParchment),
                  items: [
                    const DropdownMenuItem<FantasyArmor?>(
                      value: null,
                      child: Text('No armor'),
                    ),
                    ...FantasyArmor.values.map(
                      (armor) => DropdownMenuItem<FantasyArmor?>(
                        value: armor,
                        child: _equipmentOption(
                          '${_label(armor.name)} (${armor.category.name})',
                          [
                            if (!draft.armorStrengthMet(armor)) 'Low Str',
                            _equipmentTraining(draft.armorTrained(armor)),
                          ].join(' · '),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (armor) => setState(() => draft.armor = armor),
                ),
                if (draft.armor case final armor?) ...[
                  Text(
                    switch (draft.armorTrained(armor)) {
                      true => 'Armor training from starting class.',
                      false =>
                        'No training from starting class: Strength and '
                            'Dexterity D20 tests have disadvantage, and you '
                            'cannot cast spells while wearing it.',
                      null => 'Choose a class to check armor training.',
                    },
                    key: const ValueKey('equipment-armor-training'),
                    style: const TextStyle(color: cSmoke),
                  ),
                  if (armor.stealthDisadvantage)
                    const Text(
                      'This armor gives disadvantage on Stealth checks.',
                      style: TextStyle(color: cMist),
                    ),
                  if (armor.strengthRequired case final requiredStrength?)
                    Text(
                      'Strength $requiredStrength required to avoid a '
                      '10-foot speed reduction.'
                      '${!draft.armorStrengthMet(armor) ? ' Requirement not met.' : ''}',
                      style: const TextStyle(color: cMist),
                    ),
                ],
                SwitchListTile(
                  key: const ValueKey('equipment-shield'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Wield a shield',
                    style: TextStyle(color: cParchment),
                  ),
                  value: draft.shield,
                  onChanged: (value) => setState(() => draft.shield = value),
                ),
                if (draft.shield)
                  Text(
                    switch (draft.shieldTrained) {
                      true => 'Shield training from starting class: +2 AC.',
                      false =>
                        'No shield training from starting class: '
                            'the shield does not increase AC.',
                      null => 'Choose a class to check shield training.',
                    },
                    key: const ValueKey('equipment-shield-training'),
                    style: const TextStyle(color: cSmoke),
                  ),
                Text(
                  draft.armorClass == null
                      ? 'Choose a class to calculate armor class.'
                      : 'Armor class: ${draft.armorClass}',
                  key: const ValueKey('equipment-armor-class'),
                  style: const TextStyle(color: cGold),
                ),
                const Text(
                  'AC uses the selected equipment, ability scores and '
                  'starting class. Spells, magic items, feats and additional '
                  'class choices are not included.',
                  style: TextStyle(color: cSmoke),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}
