import 'package:flutter/material.dart';

import '../models/fantasy_character.dart';
import '../models/fantasy_help.dart';
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
                  'These are base scores. Background bonuses and later '
                  'improvements are not yet included.',
                  style: TextStyle(color: cSmoke),
                ),
                ...FantasyAbility.values.map(
                  (ability) => Row(
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
                      if (draft.scoreMethod == AbilityScoreMethod.pointBuy) ...[
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
                                () => draft.assignStandardScore(ability, value),
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
                  Text(
                    'Starting class skills: ${draft.classSkills.length} '
                    'of ${characterClass.skillCount} selected',
                    style: const TextStyle(color: cMist),
                  ),
                  Wrap(
                    spacing: 6,
                    children: FantasySkill.values
                        .where(characterClass.skillChoices.contains)
                        .map((skill) {
                          final selected = draft.classSkills.contains(skill);
                          final canSelect =
                              selected ||
                              draft.classSkills.length <
                                  characterClass.skillCount;
                          return FilterChip(
                            key: ValueKey('class-skill-${skill.name}'),
                            label: Text(_label(skill.name)),
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
                const SizedBox(height: 12),
                const Text(
                  'Extra training below can represent other sources, such as '
                  'a background. Those sources and expertise requirements '
                  'are not yet checked.',
                  style: TextStyle(color: cSmoke),
                ),
                ...FantasySkill.values.map(
                  (skill) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          _label(skill.name),
                          style: const TextStyle(color: cParchment),
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
              ],
            ],
          );
        },
      ),
    ),
  );
}
