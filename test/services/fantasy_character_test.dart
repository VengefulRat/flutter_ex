import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/fantasy_character.dart';
import 'package:lore/models/world.dart';

void main() {
  test('imports a room draft without changing the Sandbox character', () {
    final source = CharacterEntry(
      id: 'hero',
      name: 'Griam',
      type: CharacterType.npc,
    );
    final draft = FantasyCharacterDraft.fromSandbox(source);
    draft.role = FantasyRole.main;
    draft.setScore(FantasyAbility.intelligence, 15);
    source.name = 'Changed in Sandbox';

    expect(draft.sourceId, 'hero');
    expect(draft.name, 'Griam');
    expect(source.type, CharacterType.npc);
    expect(draft.role, FantasyRole.main);
    expect(draft.abilityModifier(FantasyAbility.intelligence), 2);
  });

  test('point buy enforces score bounds and the 27-point budget', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    );
    draft.setScore(FantasyAbility.wisdom, 9);
    expect(draft.abilityModifier(FantasyAbility.wisdom), -1);
    expect(() => draft.setScore(FantasyAbility.wisdom, 7), throwsRangeError);
    expect(() => draft.setScore(FantasyAbility.wisdom, 16), throwsRangeError);
    for (final ability in FantasyAbility.values) {
      draft.setScore(ability, 8);
    }
    expect(draft.pointsRemaining, 27);
    draft.setScore(FantasyAbility.strength, 15);
    draft.setScore(FantasyAbility.dexterity, 15);
    draft.setScore(FantasyAbility.constitution, 15);
    expect(draft.pointsRemaining, 0);
    expect(draft.canSetScore(FantasyAbility.intelligence, 9), isFalse);
    expect(
      () => draft.setScore(FantasyAbility.intelligence, 9),
      throwsStateError,
    );
    draft.setScore(FantasyAbility.constitution, 14);
    expect(draft.pointsRemaining, 2);
    expect(draft.canSetScore(FantasyAbility.intelligence, 10), isTrue);
    expect(() => draft.level = 0, throwsRangeError);
    expect(() => draft.level = 21, throwsRangeError);
  });

  test('standard array swaps scores and keeps each method independent', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    );
    draft.setScore(FantasyAbility.intelligence, 14);
    draft.scoreMethod = AbilityScoreMethod.standardArray;
    draft.assignStandardScore(FantasyAbility.intelligence, 15);
    expect(draft.score(FantasyAbility.intelligence), 15);
    expect(draft.score(FantasyAbility.strength), 12);
    expect(
      FantasyAbility.values.map(draft.score).toSet(),
      FantasyCharacterDraft.standardArray.toSet(),
    );
    expect(
      () => draft.assignStandardScore(FantasyAbility.intelligence, 11),
      throwsArgumentError,
    );
    expect(
      () => draft.setScore(FantasyAbility.intelligence, 14),
      throwsStateError,
    );
    draft.scoreMethod = AbilityScoreMethod.pointBuy;
    expect(draft.score(FantasyAbility.intelligence), 14);
    expect(
      () => draft.assignStandardScore(FantasyAbility.intelligence, 15),
      throwsStateError,
    );
    draft.scoreMethod = AbilityScoreMethod.standardArray;
    expect(draft.score(FantasyAbility.intelligence), 15);
  });

  test('skill bonuses use the linked ability and level-based training', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    );
    draft.setScore(FantasyAbility.intelligence, 14);
    expect(draft.skillBonus(FantasySkill.investigation), 2);

    draft.setTraining(FantasySkill.investigation, SkillTraining.proficient);
    expect(draft.skillBonus(FantasySkill.investigation), 4);
    draft.level = 5;
    expect(draft.skillBonus(FantasySkill.investigation), 5);
    draft.setTraining(FantasySkill.investigation, SkillTraining.expertise);
    expect(draft.skillBonus(FantasySkill.investigation), 8);
    expect(draft.skillBonus(FantasySkill.perception), 0);
    draft.level = 20;
    expect(draft.proficiencyBonus, 6);
    expect(draft.skillBonus(FantasySkill.investigation), 14);
  });

  test('starting class skills are limited without blocking other sources', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    );
    expect(
      () => draft.setClassSkill(FantasySkill.arcana, true),
      throwsStateError,
    );
    draft.characterClass = FantasyClass.wizard;
    expect(
      () => draft.setClassSkill(FantasySkill.stealth, true),
      throwsArgumentError,
    );
    draft.setClassSkill(FantasySkill.arcana, true);
    draft.setClassSkill(FantasySkill.investigation, true);
    expect(draft.skillBonus(FantasySkill.arcana), 2);
    expect(
      () => draft.setClassSkill(FantasySkill.history, true),
      throwsStateError,
    );
    draft.setTraining(FantasySkill.stealth, SkillTraining.proficient);
    expect(draft.skillBonus(FantasySkill.stealth), 2);
    draft.setTraining(FantasySkill.arcana, SkillTraining.expertise);
    expect(draft.skillBonus(FantasySkill.arcana), 4);
    draft.setClassSkill(FantasySkill.investigation, false);
    draft.setClassSkill(FantasySkill.nature, true);
    expect(draft.classSkills, {FantasySkill.arcana, FantasySkill.nature});
    draft.characterClass = FantasyClass.ranger;
    expect(draft.classSkills, isEmpty);
    draft.characterClass = FantasyClass.wizard;
    expect(draft.classSkills, {FantasySkill.arcana, FantasySkill.nature});
  });
}
