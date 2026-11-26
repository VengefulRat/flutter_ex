import 'fantasy_equipment.dart';
import 'fantasy_spells.dart';
import 'fantasy_subclass.dart';
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

enum FantasyBackground {
  acolyte(
    [
      FantasyAbility.intelligence,
      FantasyAbility.wisdom,
      FantasyAbility.charisma,
    ],
    {FantasySkill.insight, FantasySkill.religion},
  ),
  criminal(
    [
      FantasyAbility.dexterity,
      FantasyAbility.constitution,
      FantasyAbility.intelligence,
    ],
    {FantasySkill.sleightOfHand, FantasySkill.stealth},
  ),
  sage(
    [
      FantasyAbility.constitution,
      FantasyAbility.intelligence,
      FantasyAbility.wisdom,
    ],
    {FantasySkill.arcana, FantasySkill.history},
  ),
  soldier(
    [
      FantasyAbility.strength,
      FantasyAbility.dexterity,
      FantasyAbility.constitution,
    ],
    {FantasySkill.athletics, FantasySkill.intimidation},
  );

  const FantasyBackground(this.abilities, this.skills);
  final List<FantasyAbility> abilities;
  final Set<FantasySkill> skills;
}

enum BackgroundBonusMethod { twoAndOne, oneEach }

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
  int get hitDie => switch (this) {
    FantasyClass.barbarian => 12,
    FantasyClass.fighter || FantasyClass.paladin || FantasyClass.ranger => 10,
    FantasyClass.sorcerer || FantasyClass.wizard => 6,
    _ => 8,
  };

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
  late final FantasySpellcasting spellcasting = FantasySpellcasting(this);
  FantasyClass? _characterClass;
  FantasyClass? get characterClass => _characterClass;
  set characterClass(FantasyClass? value) {
    if (_characterClass != value) {
      spellcasting.clear();
      _subclass = null;
      _land = null;
      _grimHarvestUsed = false;
    }
    _characterClass = value;
    _reconcileHitPoints();
  }

  FantasySubclass? _subclass;
  FantasySubclass? get subclass => _subclass;
  FantasyLand? _land;
  FantasyLand? get land => _land;

  void setSubclass(FantasySubclass? value) {
    if (value != null &&
        (level < 3 || value.characterClass != characterClass)) {
      throw StateError('Choose an eligible subclass at level 3 or higher.');
    }
    if (_subclass == value) return;
    _subclass = value;
    _land = null;
    _grimHarvestUsed = false;
    spellcasting.clearDiscoveries();
    if (value == FantasySubclass.necromancer && level >= 6) {
      spellcasting.grantNecromancerSpell();
    }
    spellcasting.reconcileLevel();
  }

  void setLand(FantasyLand? value) {
    if (_subclass != FantasySubclass.land) {
      throw StateError('Choose Circle of the Land first.');
    }
    _land = value;
    spellcasting.reconcileLevel();
  }

  FantasyWeapon? weapon;
  FantasyArmor? armor;
  bool shield = false;
  FantasyBackground? _background;
  BackgroundBonusMethod _backgroundMethod = BackgroundBonusMethod.twoAndOne;
  FantasyAbility? _backgroundTwo;
  FantasyAbility? _backgroundOne;
  int _level = 1;
  AbilityScoreMethod _scoreMethod = AbilityScoreMethod.pointBuy;
  AbilityScoreMethod get scoreMethod => _scoreMethod;
  set scoreMethod(AbilityScoreMethod value) {
    _scoreMethod = value;
    _reconcileHitPoints();
  }

  int? _currentHitPoints;
  int? _lastHitPointMaximum;
  bool _grimHarvestUsed = false;
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
    final oldLevel = _level;
    _level = value;
    if (value < 3) {
      _subclass = null;
      _land = null;
      _grimHarvestUsed = false;
      spellcasting.clearDiscoveries();
    }
    if (_subclass == FantasySubclass.necromancer &&
        oldLevel < 6 &&
        value >= 6) {
      spellcasting.grantNecromancerSpell();
    }
    spellcasting.reconcileLevel();
    _reconcileHitPoints();
  }

  int get proficiencyBonus => 2 + (_level - 1) ~/ 4;

  int? get hitPointMaximum {
    final selectedClass = characterClass;
    if (selectedClass == null) return null;
    final constitution = abilityModifier(FantasyAbility.constitution);
    final first = selectedClass.hitDie + constitution;
    final later = selectedClass.hitDie ~/ 2 + 1 + constitution;
    return (first < 1 ? 1 : first) + (_level - 1) * (later < 1 ? 1 : later);
  }

  int? get currentHitPoints =>
      hitPointMaximum == null ? null : _currentHitPoints;

  void _reconcileHitPoints() {
    final maximum = hitPointMaximum;
    if (maximum == null) return;
    final current = _currentHitPoints;
    if (current == null ||
        _lastHitPointMaximum == null ||
        current == _lastHitPointMaximum) {
      _currentHitPoints = maximum;
    } else if (current > maximum) {
      _currentHitPoints = maximum;
    }
    _lastHitPointMaximum = maximum;
  }

  bool get hasNecroticResistance =>
      subclass == FantasySubclass.necromancer && level >= 10;

  bool get grimHarvestUsed => _grimHarvestUsed;

  void startNecromancerTurn() {
    if (subclass != FantasySubclass.necromancer) {
      throw StateError('Choose the Necromancer subclass first.');
    }
    _grimHarvestUsed = false;
  }

  void applyGrimHarvest({
    required int spellLevel,
    required bool necromancy,
    required bool eligibleKill,
  }) {
    if (subclass != FantasySubclass.necromancer) {
      throw StateError('Choose the Necromancer subclass first.');
    }
    if (spellLevel < 1 || spellLevel > 9) {
      throw RangeError.range(spellLevel, 1, 9, 'spellLevel');
    }
    if (!eligibleKill) {
      throw StateError('Confirm a qualifying spell kill first.');
    }
    if (_grimHarvestUsed) {
      throw StateError('Grim Harvest has already been used this turn.');
    }
    heal(spellLevel * (necromancy ? 3 : 2));
    _grimHarvestUsed = true;
  }

  void takeDamage(int amount, {bool necrotic = false}) {
    if (amount <= 0) {
      throw RangeError.value(amount, 'amount', 'Must be positive.');
    }
    final current = currentHitPoints;
    if (current == null) throw StateError('Choose a class first.');
    final applied = necrotic && hasNecroticResistance ? amount ~/ 2 : amount;
    _currentHitPoints = applied >= current ? 0 : current - applied;
  }

  void heal(int amount) {
    if (amount <= 0) {
      throw RangeError.value(amount, 'amount', 'Must be positive.');
    }
    final current = currentHitPoints;
    final maximum = hitPointMaximum;
    if (current == null || maximum == null) {
      throw StateError('Choose a class first.');
    }
    _currentHitPoints = amount >= maximum - current
        ? maximum
        : current + amount;
  }

  FantasyBackground? get background => _background;
  BackgroundBonusMethod get backgroundMethod => _backgroundMethod;
  FantasyAbility? get backgroundTwo => _backgroundTwo;
  FantasyAbility? get backgroundOne => _backgroundOne;

  void setBackground(FantasyBackground? value) {
    if (_background == value) return;
    _background = value;
    _backgroundMethod = BackgroundBonusMethod.twoAndOne;
    _backgroundTwo = value?.abilities[0];
    _backgroundOne = value?.abilities[1];
    if (value != null) {
      for (final choices in _classSkills.values) {
        choices.removeAll(value.skills);
      }
    }
    _reconcileHitPoints();
  }

  void setBackgroundMethod(BackgroundBonusMethod value) {
    if (_background == null) throw StateError('Choose a background first.');
    _backgroundMethod = value;
    _reconcileHitPoints();
  }

  void setBackgroundTwo(FantasyAbility ability) {
    _validateBackgroundAbility(ability);
    if (ability == _backgroundOne) {
      _backgroundOne = _backgroundTwo;
    }
    _backgroundTwo = ability;
    _reconcileHitPoints();
  }

  void setBackgroundOne(FantasyAbility ability) {
    _validateBackgroundAbility(ability);
    if (ability == _backgroundTwo) {
      _backgroundTwo = _backgroundOne;
    }
    _backgroundOne = ability;
    _reconcileHitPoints();
  }

  void _validateBackgroundAbility(FantasyAbility ability) {
    if (_background == null) throw StateError('Choose a background first.');
    if (!_background!.abilities.contains(ability)) {
      throw ArgumentError.value(ability, 'ability', 'Not in this background.');
    }
  }

  int backgroundBonus(FantasyAbility ability) {
    if (!(_background?.abilities.contains(ability) ?? false)) return 0;
    if (_backgroundMethod == BackgroundBonusMethod.oneEach) return 1;
    if (ability == _backgroundTwo) return 2;
    if (ability == _backgroundOne) return 1;
    return 0;
  }

  int totalScore(FantasyAbility ability) =>
      score(ability) + backgroundBonus(ability);

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
    _reconcileHitPoints();
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
    _reconcileHitPoints();
  }

  int abilityModifier(FantasyAbility ability) =>
      ((totalScore(ability) - 10) / 2).floor();

  bool? weaponProficient(FantasyWeapon weapon) {
    final selectedClass = characterClass;
    if (selectedClass == null) return null;
    if (weapon.category == WeaponCategory.simple) return true;
    return switch (selectedClass) {
      FantasyClass.barbarian ||
      FantasyClass.fighter ||
      FantasyClass.paladin ||
      FantasyClass.ranger => true,
      FantasyClass.monk => weapon.light,
      FantasyClass.rogue => weapon.light || weapon.finesse,
      _ => false,
    };
  }

  bool usesMonkWeaponRules(FantasyWeapon weapon) =>
      characterClass == FantasyClass.monk &&
      armor == null &&
      !shield &&
      weapon.isMelee &&
      (weapon.category == WeaponCategory.simple || weapon.light);

  int? monkWeaponDie(FantasyWeapon weapon) {
    if (!usesMonkWeaponRules(weapon)) return null;
    if (level >= 17) return 12;
    if (level >= 11) return 10;
    if (level >= 5) return 8;
    return 6;
  }

  Set<FantasyAbility> weaponAttackAbilities(FantasyWeapon weapon) {
    if (characterClass == null) throw StateError('Choose a class first.');
    if (weapon.finesse || usesMonkWeaponRules(weapon)) {
      return {FantasyAbility.strength, FantasyAbility.dexterity};
    }
    return {
      weapon.isMelee ? FantasyAbility.strength : FantasyAbility.dexterity,
    };
  }

  int weaponAttackBonus(FantasyWeapon weapon, FantasyAbility ability) {
    if (!weaponAttackAbilities(weapon).contains(ability)) {
      throw ArgumentError.value(
        ability,
        'ability',
        'Not valid for this weapon.',
      );
    }
    return abilityModifier(ability) +
        (weaponProficient(weapon) == true ? proficiencyBonus : 0);
  }

  bool weaponAttackDisadvantage(FantasyWeapon weapon) {
    if (characterClass == null) throw StateError('Choose a class first.');
    final selectedArmor = armor;
    return heavyWeaponRequirementMet(weapon) == false ||
        (selectedArmor != null && armorTrained(selectedArmor) == false) ||
        (shield && shieldTrained == false);
  }

  bool? heavyWeaponRequirementMet(FantasyWeapon weapon) {
    final ability = switch (weapon.heavyAbility) {
      HeavyWeaponAbility.strength => FantasyAbility.strength,
      HeavyWeaponAbility.dexterity => FantasyAbility.dexterity,
      null => null,
    };
    return ability == null ? null : totalScore(ability) >= 13;
  }

  bool armorStrengthMet(FantasyArmor armor) =>
      armor.strengthRequired == null ||
      totalScore(FantasyAbility.strength) >= armor.strengthRequired!;

  bool? armorTrained(FantasyArmor armor) {
    final selectedClass = characterClass;
    if (selectedClass == null) return null;
    return switch (armor.category) {
      ArmorCategory.light => switch (selectedClass) {
        FantasyClass.sorcerer ||
        FantasyClass.wizard ||
        FantasyClass.monk => false,
        _ => true,
      },
      ArmorCategory.medium => switch (selectedClass) {
        FantasyClass.barbarian ||
        FantasyClass.cleric ||
        FantasyClass.fighter ||
        FantasyClass.paladin ||
        FantasyClass.ranger => true,
        _ => false,
      },
      ArmorCategory.heavy =>
        selectedClass == FantasyClass.fighter ||
            selectedClass == FantasyClass.paladin,
    };
  }

  bool? get shieldTrained {
    final selectedClass = characterClass;
    if (selectedClass == null) return null;
    return switch (selectedClass) {
      FantasyClass.barbarian ||
      FantasyClass.cleric ||
      FantasyClass.druid ||
      FantasyClass.fighter ||
      FantasyClass.paladin ||
      FantasyClass.ranger => true,
      _ => false,
    };
  }

  int? get armorClass {
    final selectedClass = characterClass;
    if (selectedClass == null) return null;
    final dexterity = abilityModifier(FantasyAbility.dexterity);
    final selectedArmor = armor;
    int base;
    if (selectedArmor == null) {
      base = 10 + dexterity;
      final defenseAbility = switch (selectedClass) {
        FantasyClass.barbarian => FantasyAbility.constitution,
        FantasyClass.monk when !shield => FantasyAbility.wisdom,
        _ => null,
      };
      if (defenseAbility != null) {
        final unarmored = base + abilityModifier(defenseAbility);
        if (unarmored > base) base = unarmored;
      }
    } else {
      base =
          selectedArmor.baseAc +
          switch (selectedArmor.category) {
            ArmorCategory.light => dexterity,
            ArmorCategory.medium => dexterity > 2 ? 2 : dexterity,
            ArmorCategory.heavy => 0,
          };
    }
    return base + (shield && shieldTrained == true ? 2 : 0);
  }

  Set<FantasySkill> get classSkills =>
      Set.unmodifiable(_classSkills[characterClass] ?? const <FantasySkill>{});

  Set<FantasySkill> get backgroundSkills =>
      _background?.skills ?? const <FantasySkill>{};

  void setClassSkill(FantasySkill skill, bool selected) {
    final selectedClass = characterClass;
    if (selectedClass == null) throw StateError('Choose a starting class.');
    if (!selectedClass.skillChoices.contains(skill)) {
      throw ArgumentError.value(skill, 'skill', 'Not a starting class skill.');
    }
    if (selected && backgroundSkills.contains(skill)) {
      throw StateError('This skill is already provided by the background.');
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
    if (extra == SkillTraining.proficient ||
        classSkills.contains(skill) ||
        backgroundSkills.contains(skill)) {
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
