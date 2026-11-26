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

  test(
    'background bonuses affect totals and skills without changing base scores',
    () {
      final draft = FantasyCharacterDraft.fromSandbox(
        CharacterEntry(id: 'hero', name: 'Griam'),
      );
      draft.setScore(FantasyAbility.intelligence, 15);
      final remaining = draft.pointsRemaining;
      draft.setBackground(FantasyBackground.sage);
      draft.setBackgroundTwo(FantasyAbility.intelligence);
      expect(draft.score(FantasyAbility.intelligence), 15);
      expect(draft.totalScore(FantasyAbility.intelligence), 17);
      expect(draft.skillBonus(FantasySkill.investigation), 3);
      expect(draft.pointsRemaining, remaining);
      draft.setBackgroundOne(FantasyAbility.intelligence);
      expect(draft.backgroundBonus(FantasyAbility.intelligence), 1);
      expect(draft.backgroundBonus(FantasyAbility.constitution), 2);
      expect(
        () => draft.setBackgroundTwo(FantasyAbility.charisma),
        throwsArgumentError,
      );
      draft.setBackgroundMethod(BackgroundBonusMethod.oneEach);
      expect(FantasyAbility.values.map(draft.backgroundBonus).toList(), [
        0,
        0,
        1,
        1,
        1,
        0,
      ]);
      draft.scoreMethod = AbilityScoreMethod.standardArray;
      expect(draft.totalScore(FantasyAbility.intelligence), 13);
      draft.setBackground(FantasyBackground.soldier);
      expect(draft.backgroundBonus(FantasyAbility.intelligence), 0);
      expect(draft.totalScore(FantasyAbility.strength), 17);
      draft.setBackground(null);
      expect(draft.totalScore(FantasyAbility.strength), 15);
      expect(
        () => draft.setBackgroundMethod(BackgroundBonusMethod.oneEach),
        throwsStateError,
      );
    },
  );

  test(
    'background skills grant proficiency without stacking extra training',
    () {
      final draft = FantasyCharacterDraft.fromSandbox(
        CharacterEntry(id: 'hero', name: 'Griam'),
      );
      draft.setBackground(FantasyBackground.sage);
      expect(draft.training(FantasySkill.arcana), SkillTraining.proficient);
      expect(draft.training(FantasySkill.history), SkillTraining.proficient);
      expect(draft.skillBonus(FantasySkill.arcana), 2);
      draft.setTraining(FantasySkill.arcana, SkillTraining.proficient);
      expect(draft.skillBonus(FantasySkill.arcana), 2);
      draft.setTraining(FantasySkill.arcana, SkillTraining.expertise);
      expect(draft.skillBonus(FantasySkill.arcana), 4);
      draft.setTraining(FantasySkill.arcana, SkillTraining.untrained);
      draft.setBackground(FantasyBackground.criminal);
      expect(draft.training(FantasySkill.arcana), SkillTraining.untrained);
      expect(draft.training(FantasySkill.stealth), SkillTraining.proficient);
      expect(
        draft.training(FantasySkill.sleightOfHand),
        SkillTraining.proficient,
      );
      draft.setBackground(null);
      expect(draft.training(FantasySkill.stealth), SkillTraining.untrained);
    },
  );

  test(
    'changing background clears overlapping class choices across classes',
    () {
      final draft = FantasyCharacterDraft.fromSandbox(
        CharacterEntry(id: 'hero', name: 'Griam'),
      );
      draft.characterClass = FantasyClass.wizard;
      draft.setClassSkill(FantasySkill.arcana, true);
      draft.setClassSkill(FantasySkill.investigation, true);
      draft.characterClass = FantasyClass.cleric;
      draft.setClassSkill(FantasySkill.history, true);
      draft.setClassSkill(FantasySkill.insight, true);

      draft.setBackground(FantasyBackground.sage);
      expect(draft.classSkills, {FantasySkill.insight});
      expect(
        () => draft.setClassSkill(FantasySkill.history, true),
        throwsStateError,
      );
      draft.characterClass = FantasyClass.wizard;
      expect(draft.classSkills, {FantasySkill.investigation});
      expect(
        () => draft.setClassSkill(FantasySkill.arcana, true),
        throwsStateError,
      );
      draft.setClassSkill(FantasySkill.religion, true);
      draft.setBackground(FantasyBackground.acolyte);
      expect(draft.classSkills, {FantasySkill.investigation});
      expect(draft.training(FantasySkill.religion), SkillTraining.proficient);
      draft.characterClass = FantasyClass.cleric;
      expect(draft.classSkills, isEmpty);
      draft.setBackground(FantasyBackground.soldier);
      expect(draft.training(FantasySkill.athletics), SkillTraining.proficient);
      expect(
        draft.training(FantasySkill.intimidation),
        SkillTraining.proficient,
      );
    },
  );

  test('hit points use class, level and Constitution with fixed gains', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    );
    expect(draft.hitPointMaximum, isNull);
    expect(draft.currentHitPoints, isNull);
    expect(() => draft.takeDamage(1), throwsStateError);
    draft.characterClass = FantasyClass.wizard;
    expect(draft.hitPointMaximum, 6);
    expect(draft.currentHitPoints, 6);
    draft.level = 3;
    expect(draft.hitPointMaximum, 14);
    expect(draft.currentHitPoints, 14);
    draft.setScore(FantasyAbility.constitution, 14);
    expect(draft.hitPointMaximum, 20);
    expect(draft.currentHitPoints, 20);
    draft.takeDamage(5);
    expect(draft.currentHitPoints, 15);
    draft.level = 4;
    expect(draft.hitPointMaximum, 26);
    expect(draft.currentHitPoints, 15);
    draft.level = 1;
    expect(draft.hitPointMaximum, 8);
    expect(draft.currentHitPoints, 8);
    draft.setBackground(FantasyBackground.soldier);
    draft.setBackgroundTwo(FantasyAbility.constitution);
    expect(draft.hitPointMaximum, 9);
    expect(draft.currentHitPoints, 9);
    draft.characterClass = FantasyClass.barbarian;
    expect(draft.hitPointMaximum, 15);
    expect(draft.currentHitPoints, 15);
    draft.scoreMethod = AbilityScoreMethod.standardArray;
    expect(draft.hitPointMaximum, 14);
    expect(draft.currentHitPoints, 14);
    draft.assignStandardScore(FantasyAbility.constitution, 15);
    expect(draft.hitPointMaximum, 15);
    expect(draft.currentHitPoints, 15);
  });

  test('damage and healing clamp HP and reject invalid amounts', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    )..characterClass = FantasyClass.fighter;
    expect(() => draft.takeDamage(0), throwsRangeError);
    expect(() => draft.heal(-1), throwsRangeError);
    draft.takeDamage(100);
    expect(draft.currentHitPoints, 0);
    draft.heal(3);
    expect(draft.currentHitPoints, 3);
    draft.heal(100);
    expect(draft.currentHitPoints, 10);
    draft.takeDamage(4);
    draft.characterClass = null;
    expect(draft.currentHitPoints, isNull);
    expect(() => draft.heal(1), throwsStateError);
    draft.characterClass = FantasyClass.fighter;
    expect(draft.currentHitPoints, 6);
    draft.heal(4);
    draft.level = 2;
    expect(draft.currentHitPoints, 16);
  });
}
