import 'world.dart';

enum FantasyRole { main, side, npc }

enum FantasyAbility {
  strength,
  dexterity,
  constitution,
  intelligence,
  wisdom,
  charisma,
}

enum FantasySkill {
  acrobatics(FantasyAbility.dexterity),
  animalHandling(FantasyAbility.wisdom),
  arcana(FantasyAbility.intelligence),
  athletics(FantasyAbility.strength),
  deception(FantasyAbility.charisma),
  history(FantasyAbility.intelligence),
  insight(FantasyAbility.wisdom),
  intimidation(FantasyAbility.charisma),
  investigation(FantasyAbility.intelligence),
  medicine(FantasyAbility.wisdom),
  nature(FantasyAbility.intelligence),
  perception(FantasyAbility.wisdom),
  performance(FantasyAbility.charisma),
  persuasion(FantasyAbility.charisma),
  religion(FantasyAbility.intelligence),
  sleightOfHand(FantasyAbility.dexterity),
  stealth(FantasyAbility.dexterity),
  survival(FantasyAbility.wisdom);

  const FantasySkill(this.ability);
  final FantasyAbility ability;
}

enum SkillTraining { untrained, proficient, expertise }

enum AbilityScoreMethod { pointBuy, standardArray }

enum FantasyClass {
  barbarian,
  bard,
  cleric,
  druid,
  fighter,
  monk,
  paladin,
  ranger,
  rogue,
  sorcerer,
  warlock,
  wizard,
}

extension StartingClassSkills on FantasyClass {
  int get skillCount => switch (this) {
    FantasyClass.bard || FantasyClass.ranger => 3,
    FantasyClass.rogue => 4,
    _ => 2,
  };

  Set<FantasySkill> get skillChoices => switch (this) {
    FantasyClass.barbarian => {
      FantasySkill.animalHandling,
      FantasySkill.athletics,
      FantasySkill.intimidation,
      FantasySkill.nature,
      FantasySkill.perception,
      FantasySkill.survival,
    },
    FantasyClass.bard => FantasySkill.values.toSet(),
    FantasyClass.cleric => {
      FantasySkill.history,
      FantasySkill.insight,
      FantasySkill.medicine,
      FantasySkill.persuasion,
      FantasySkill.religion,
    },
    FantasyClass.druid => {
      FantasySkill.arcana,
      FantasySkill.animalHandling,
      FantasySkill.insight,
      FantasySkill.medicine,
      FantasySkill.nature,
      FantasySkill.perception,
      FantasySkill.religion,
      FantasySkill.survival,
    },
    FantasyClass.fighter => {
      FantasySkill.acrobatics,
      FantasySkill.animalHandling,
      FantasySkill.athletics,
      FantasySkill.history,
      FantasySkill.insight,
      FantasySkill.intimidation,
      FantasySkill.persuasion,
      FantasySkill.perception,
      FantasySkill.survival,
    },
    FantasyClass.monk => {
      FantasySkill.acrobatics,
      FantasySkill.athletics,
      FantasySkill.history,
      FantasySkill.insight,
      FantasySkill.religion,
      FantasySkill.stealth,
    },
    FantasyClass.paladin => {
      FantasySkill.athletics,
      FantasySkill.insight,
      FantasySkill.intimidation,
      FantasySkill.medicine,
      FantasySkill.persuasion,
      FantasySkill.religion,
    },
    FantasyClass.ranger => {
      FantasySkill.animalHandling,
      FantasySkill.athletics,
      FantasySkill.insight,
      FantasySkill.investigation,
      FantasySkill.nature,
      FantasySkill.perception,
      FantasySkill.stealth,
      FantasySkill.survival,
    },
    FantasyClass.rogue => {
      FantasySkill.acrobatics,
      FantasySkill.athletics,
      FantasySkill.deception,
      FantasySkill.insight,
      FantasySkill.intimidation,
      FantasySkill.investigation,
      FantasySkill.perception,
      FantasySkill.persuasion,
      FantasySkill.sleightOfHand,
      FantasySkill.stealth,
    },
    FantasyClass.sorcerer => {
      FantasySkill.arcana,
      FantasySkill.deception,
      FantasySkill.insight,
      FantasySkill.intimidation,
      FantasySkill.persuasion,
      FantasySkill.religion,
    },
    FantasyClass.warlock => {
      FantasySkill.arcana,
      FantasySkill.deception,
      FantasySkill.history,
      FantasySkill.intimidation,
      FantasySkill.investigation,
      FantasySkill.nature,
      FantasySkill.religion,
    },
    FantasyClass.wizard => {
      FantasySkill.arcana,
      FantasySkill.history,
      FantasySkill.insight,
      FantasySkill.investigation,
      FantasySkill.medicine,
      FantasySkill.nature,
      FantasySkill.religion,
    },
  };
}

/// A temporary room-specific draft; editing it never changes the Sandbox entry.
class FantasyCharacterDraft {
  FantasyCharacterDraft.fromSandbox(CharacterEntry character)
    : sourceId = character.id,
      name = character.name,
      pronouns = character.pronouns,
      avatarUrl = character.avatarUrl,
      role = character.type == CharacterType.npc
          ? FantasyRole.npc
          : FantasyRole.main;

  final String sourceId;
  final String name;
  final String pronouns;
  final String? avatarUrl;
  FantasyRole role;
  FantasyClass? characterClass;
  int _level = 1;
  AbilityScoreMethod scoreMethod = AbilityScoreMethod.pointBuy;
  final Map<FantasyAbility, int> _pointBuyScores = {
    for (final ability in FantasyAbility.values) ability: 10,
  };
  final Map<FantasyAbility, int> _standardScores = {
    FantasyAbility.strength: 15,
    FantasyAbility.dexterity: 14,
    FantasyAbility.constitution: 13,
    FantasyAbility.intelligence: 12,
    FantasyAbility.wisdom: 10,
    FantasyAbility.charisma: 8,
  };
  static const standardArray = [15, 14, 13, 12, 10, 8];
  static const _pointCosts = {
    8: 0,
    9: 1,
    10: 2,
    11: 3,
    12: 4,
    13: 5,
    14: 7,
    15: 9,
  };
  final Map<FantasySkill, SkillTraining> _training = {};
  final Map<FantasyClass, Set<FantasySkill>> _classSkills = {};

  int get level => _level;

  set level(int value) {
    if (value < 1 || value > 20) {
      throw RangeError.range(value, 1, 20, 'level');
    }
    _level = value;
  }

  int get proficiencyBonus => 2 + (_level - 1) ~/ 4;

  int score(FantasyAbility ability) =>
      (scoreMethod == AbilityScoreMethod.pointBuy
      ? _pointBuyScores
      : _standardScores)[ability]!;

  int get pointsRemaining =>
      27 -
      _pointBuyScores.values.fold(
        0,
        (total, score) => total + _pointCosts[score]!,
      );

  bool canSetScore(FantasyAbility ability, int value) {
    if (scoreMethod != AbilityScoreMethod.pointBuy ||
        !_pointCosts.containsKey(value)) {
      return false;
    }
    return _pointCosts[value]! - _pointCosts[_pointBuyScores[ability]]! <=
        pointsRemaining;
  }

  void setScore(FantasyAbility ability, int value) {
    if (scoreMethod != AbilityScoreMethod.pointBuy) {
      throw StateError('Scores must be assigned from the standard array.');
    }
    if (!_pointCosts.containsKey(value)) {
      throw RangeError.range(value, 8, 15, 'score');
    }
    if (!canSetScore(ability, value)) {
      throw StateError('Not enough points remaining.');
    }
    _pointBuyScores[ability] = value;
  }

  void assignStandardScore(FantasyAbility ability, int value) {
    if (scoreMethod != AbilityScoreMethod.standardArray) {
      throw StateError('Standard array is not selected.');
    }
    if (!standardArray.contains(value)) {
      throw ArgumentError.value(value, 'value', 'Not in the standard array.');
    }
    final other = _standardScores.entries
        .firstWhere((entry) => entry.value == value)
        .key;
    _standardScores[other] = _standardScores[ability]!;
    _standardScores[ability] = value;
  }

  int abilityModifier(FantasyAbility ability) =>
      ((score(ability) - 10) / 2).floor();

  Set<FantasySkill> get classSkills =>
      Set.unmodifiable(_classSkills[characterClass] ?? const <FantasySkill>{});

  void setClassSkill(FantasySkill skill, bool selected) {
    final selectedClass = characterClass;
    if (selectedClass == null) throw StateError('Choose a starting class.');
    if (!selectedClass.skillChoices.contains(skill)) {
      throw ArgumentError.value(skill, 'skill', 'Not a starting class skill.');
    }
    final chosen = _classSkills.putIfAbsent(selectedClass, () => {});
    if (selected) {
      if (!chosen.contains(skill) &&
          chosen.length >= selectedClass.skillCount) {
        throw StateError('All starting class skill choices have been used.');
      }
      chosen.add(skill);
    } else {
      chosen.remove(skill);
    }
  }

  SkillTraining extraTraining(FantasySkill skill) =>
      _training[skill] ?? SkillTraining.untrained;

  SkillTraining training(FantasySkill skill) {
    final extra = extraTraining(skill);
    if (extra == SkillTraining.expertise) return extra;
    if (extra == SkillTraining.proficient || classSkills.contains(skill)) {
      return SkillTraining.proficient;
    }
    return SkillTraining.untrained;
  }

  void setTraining(FantasySkill skill, SkillTraining value) {
    _training[skill] = value;
  }

  int skillBonus(FantasySkill skill) {
    final multiplier = switch (training(skill)) {
      SkillTraining.untrained => 0,
      SkillTraining.proficient => 1,
      SkillTraining.expertise => 2,
    };
    return abilityModifier(skill.ability) + multiplier * proficiencyBonus;
  }
}
