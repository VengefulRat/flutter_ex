import 'fantasy_character.dart';
import 'fantasy_spell_catalog.dart';
import 'fantasy_subclass.dart';

class FantasySpell {
  const FantasySpell(this.id, this.name, this.level, this.classes);

  final String id;
  final String name;
  final int level;
  final Set<FantasyClass> classes;
}

enum SpellChoice { cantrip, prepared, spellbook, arcanum, discovery }

class FantasySpellcasting {
  FantasySpellcasting(this.draft);

  final FantasyCharacterDraft draft;
  final Set<FantasySpell> _cantrips = {};
  final Set<FantasySpell> _prepared = {};
  final Set<FantasySpell> _spellbook = {};
  final Set<FantasySpell> _arcana = {};
  final Set<FantasySpell> _discoveries = {};
  final Map<int, int> _spentSlots = {};

  Set<FantasySpell> get cantrips => Set.unmodifiable(_cantrips);
  Set<FantasySpell> get prepared => Set.unmodifiable(_prepared);
  Set<FantasySpell> get spellbook => Set.unmodifiable(_spellbook);
  Set<FantasySpell> get arcana => Set.unmodifiable(_arcana);
  Set<FantasySpell> get discoveries => Set.unmodifiable(_discoveries);

  FantasyAbility? get spellcastingAbility => switch (draft.characterClass) {
    FantasyClass.bard ||
    FantasyClass.paladin ||
    FantasyClass.sorcerer ||
    FantasyClass.warlock => FantasyAbility.charisma,
    FantasyClass.cleric ||
    FantasyClass.druid ||
    FantasyClass.ranger => FantasyAbility.wisdom,
    FantasyClass.wizard => FantasyAbility.intelligence,
    _ => null,
  };

  bool get available => spellcastingAbility != null;

  int? get spellAttackBonus {
    final ability = spellcastingAbility;
    return ability == null
        ? null
        : draft.abilityModifier(ability) + draft.proficiencyBonus;
  }

  int? get spellSaveDc {
    final attackBonus = spellAttackBonus;
    return attackBonus == null ? null : 8 + attackBonus;
  }

  int slotMaximum(int spellLevel) {
    RangeError.checkValueInInterval(spellLevel, 1, 9, 'spellLevel');
    final characterClass = draft.characterClass;
    if (characterClass == FantasyClass.warlock) {
      if (spellLevel != maximumSpellLevel) return 0;
      return draft.level >= 17
          ? 4
          : draft.level >= 11
          ? 3
          : draft.level >= 2
          ? 2
          : 1;
    }
    if (!available) return 0;
    const slots = [
      [2],
      [3],
      [4, 2],
      [4, 3],
      [4, 3, 2],
      [4, 3, 3],
      [4, 3, 3, 1],
      [4, 3, 3, 2],
      [4, 3, 3, 3, 1],
      [4, 3, 3, 3, 2],
      [4, 3, 3, 3, 2, 1],
      [4, 3, 3, 3, 2, 1],
      [4, 3, 3, 3, 2, 1, 1],
      [4, 3, 3, 3, 2, 1, 1],
      [4, 3, 3, 3, 2, 1, 1, 1],
      [4, 3, 3, 3, 2, 1, 1, 1],
      [4, 3, 3, 3, 2, 1, 1, 1, 1],
      [4, 3, 3, 3, 3, 1, 1, 1, 1],
      [4, 3, 3, 3, 3, 2, 1, 1, 1],
      [4, 3, 3, 3, 3, 2, 2, 1, 1],
    ];
    final casterLevel =
        characterClass == FantasyClass.paladin ||
            characterClass == FantasyClass.ranger
        ? (draft.level + 1) ~/ 2
        : draft.level;
    final row = slots[casterLevel - 1];
    return spellLevel <= row.length ? row[spellLevel - 1] : 0;
  }

  int _slotKey(int spellLevel) =>
      draft.characterClass == FantasyClass.warlock ? 0 : spellLevel;

  int spentSlots(int spellLevel) {
    if (slotMaximum(spellLevel) == 0) return 0;
    return _spentSlots[_slotKey(spellLevel)] ?? 0;
  }

  int remainingSlots(int spellLevel) =>
      (slotMaximum(spellLevel) - spentSlots(spellLevel)).clamp(0, 4);

  void expendSlot(int spellLevel) {
    if (remainingSlots(spellLevel) == 0) {
      throw StateError('No spell slots of that level remain.');
    }
    final key = _slotKey(spellLevel);
    _spentSlots[key] = (_spentSlots[key] ?? 0) + 1;
  }

  void restoreSlot(int spellLevel) {
    final spent = spentSlots(spellLevel);
    if (spent == 0) throw StateError('No spell slots of that level are spent.');
    final key = _slotKey(spellLevel);
    if (spent == 1) {
      _spentSlots.remove(key);
    } else {
      _spentSlots[key] = spent - 1;
    }
  }

  void restoreSlotsAfterLongRest() => _spentSlots.clear();

  void restoreSlotsAfterShortRest() {
    if (draft.characterClass != FantasyClass.warlock) {
      throw StateError('Only Pact Magic slots recover on a short rest.');
    }
    _spentSlots.clear();
  }

  int get cantripLimit {
    final base = switch (draft.characterClass) {
      FantasyClass.bard || FantasyClass.druid || FantasyClass.warlock => 2,
      FantasyClass.cleric || FantasyClass.wizard => 3,
      FantasyClass.sorcerer => 4,
      _ => 0,
    };
    if (base == 0) return 0;
    return base + (draft.level >= 4 ? 1 : 0) + (draft.level >= 10 ? 1 : 0);
  }

  int get preparedLimit {
    const full = [
      4,
      5,
      6,
      7,
      9,
      10,
      11,
      12,
      14,
      15,
      16,
      16,
      17,
      17,
      18,
      18,
      19,
      20,
      21,
      22,
    ];
    const wizard = [
      4,
      5,
      6,
      7,
      9,
      10,
      11,
      12,
      14,
      15,
      16,
      16,
      17,
      18,
      19,
      21,
      22,
      23,
      24,
      25,
    ];
    const half = [
      2,
      3,
      4,
      5,
      6,
      6,
      7,
      7,
      9,
      9,
      10,
      10,
      11,
      11,
      12,
      12,
      14,
      14,
      15,
      15,
    ];
    const warlock = [
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      10,
      11,
      11,
      12,
      12,
      13,
      13,
      14,
      14,
      15,
      15,
    ];
    final index = draft.level - 1;
    return switch (draft.characterClass) {
      FantasyClass.bard ||
      FantasyClass.cleric ||
      FantasyClass.druid => full[index],
      FantasyClass.sorcerer =>
        index == 0
            ? 2
            : index == 1
            ? 4
            : full[index],
      FantasyClass.wizard => wizard[index],
      FantasyClass.paladin || FantasyClass.ranger => half[index],
      FantasyClass.warlock => warlock[index],
      _ => 0,
    };
  }

  int get maximumSpellLevel {
    if (!available) return 0;
    if (draft.characterClass == FantasyClass.paladin ||
        draft.characterClass == FantasyClass.ranger) {
      return ((draft.level + 3) ~/ 4).clamp(1, 5);
    }
    if (draft.characterClass == FantasyClass.warlock) {
      return ((draft.level + 1) ~/ 2).clamp(1, 5);
    }
    return ((draft.level + 1) ~/ 2).clamp(1, 9);
  }

  Set<String> get alwaysPreparedIds => {
    ...switch (draft.characterClass) {
      FantasyClass.druid => {'speak-with-animals'},
      FantasyClass.ranger => {'hunters-mark'},
      FantasyClass.paladin => {
        if (draft.level >= 2) 'divine-smite',
        if (draft.level >= 5) 'find-steed',
      },
      FantasyClass.warlock => {if (draft.level >= 9) 'contact-other-plane'},
      FantasyClass.bard => {
        if (draft.level >= 20) 'power-word-heal',
        if (draft.level >= 20) 'power-word-kill',
      },
      _ => <String>{},
    },
    for (final entry in subclassSpells(draft.subclass, draft.land).entries)
      if (draft.level >= entry.key) ...entry.value,
    ..._discoveries.map((spell) => spell.id),
  };

  Set<FantasySpell> get alwaysPrepared => {
    for (final spell in fantasySpellCatalog)
      if (alwaysPreparedIds.contains(spell.id)) spell,
  };

  List<FantasySpell> options(SpellChoice choice) {
    final result = fantasySpellCatalog.where((spell) {
      if (!_onList(spell, choice)) return false;
      return switch (choice) {
        SpellChoice.cantrip => spell.level == 0,
        SpellChoice.prepared || SpellChoice.spellbook =>
          spell.level > 0 &&
              (draft.characterClass != FantasyClass.warlock ||
                  spell.level <= 5),
        SpellChoice.arcanum => spell.level >= 6,
        SpellChoice.discovery => true,
      };
    }).toList();
    result.sort((a, b) {
      final level = a.level.compareTo(b.level);
      return level != 0 ? level : a.name.compareTo(b.name);
    });
    return result;
  }

  Set<FantasySpell> _choices(SpellChoice choice) => switch (choice) {
    SpellChoice.cantrip => _cantrips,
    SpellChoice.prepared => _prepared,
    SpellChoice.spellbook => _spellbook,
    SpellChoice.arcanum => _arcana,
    SpellChoice.discovery => _discoveries,
  };

  bool _onList(FantasySpell spell, SpellChoice choice) {
    if (choice == SpellChoice.discovery) {
      return spell.classes.any(
        {FantasyClass.cleric, FantasyClass.druid, FantasyClass.wizard}.contains,
      );
    }
    final characterClass = draft.characterClass;
    if (spell.classes.contains(characterClass)) return true;
    return characterClass == FantasyClass.bard &&
        draft.level >= 10 &&
        choice == SpellChoice.prepared &&
        spell.level > 0 &&
        spell.classes.any(
          {
            FantasyClass.cleric,
            FantasyClass.druid,
            FantasyClass.wizard,
          }.contains,
        );
  }

  String? _eligibility(FantasySpell spell, SpellChoice choice) {
    if (!fantasySpellCatalog.contains(spell) || !available) {
      return 'Choose a spellcasting class.';
    }
    if (!_onList(spell, choice)) return 'Not on this class spell list.';
    if (choice == SpellChoice.discovery) {
      if (draft.subclass != FantasySubclass.lore || draft.level < 6) {
        return 'Requires College of Lore at level 6.';
      }
      if (spell.level > maximumSpellLevel) {
        return 'Requires a higher-level spell slot.';
      }
      return null;
    }
    if (choice == SpellChoice.cantrip) {
      if (spell.level != 0 || cantripLimit == 0) return 'Not a class cantrip.';
      if (alwaysPreparedIds.contains(spell.id)) {
        return 'Already prepared by a class feature.';
      }
      return null;
    }
    if (spell.level == 0) return 'Choose a level 1+ spell.';
    if (choice == SpellChoice.arcanum) {
      if (draft.characterClass != FantasyClass.warlock || spell.level < 6) {
        return 'Mystic Arcanum uses Warlock spells of levels 6–9.';
      }
      if (draft.level < 11 + (spell.level - 6) * 2) {
        return 'Requires Warlock level ${11 + (spell.level - 6) * 2}.';
      }
      return null;
    }
    if (spell.level > maximumSpellLevel) {
      return 'Requires a higher-level spell slot.';
    }
    if (choice == SpellChoice.spellbook &&
        draft.characterClass != FantasyClass.wizard) {
      return 'Only Wizards use this spellbook.';
    }
    if (choice == SpellChoice.prepared) {
      if (alwaysPreparedIds.contains(spell.id)) {
        return 'Already prepared by a class feature.';
      }
      if (draft.characterClass == FantasyClass.wizard &&
          !_spellbook.contains(spell)) {
        return 'Add it to the spellbook first.';
      }
    }
    return null;
  }

  String? reasonUnavailable(FantasySpell spell, SpellChoice choice) {
    if (_choices(choice).contains(spell)) return null;
    final reason = _eligibility(spell, choice);
    if (reason != null) return reason;
    if (choice == SpellChoice.cantrip && _cantrips.length >= cantripLimit) {
      return 'Cantrip limit reached.';
    }
    if (choice == SpellChoice.prepared && _prepared.length >= preparedLimit) {
      return 'Prepared spell limit reached.';
    }
    if (choice == SpellChoice.arcanum &&
        _arcana.any((selected) => selected.level == spell.level)) {
      return 'A level ${spell.level} arcanum is already selected.';
    }
    if (choice == SpellChoice.discovery && _discoveries.length >= 2) {
      return 'Both Magical Discoveries are selected.';
    }
    return null;
  }

  void setSelected(FantasySpell spell, SpellChoice choice, bool selected) {
    final choices = _choices(choice);
    if (!selected) {
      choices.remove(spell);
      if (choice == SpellChoice.spellbook) _prepared.remove(spell);
      if (choice == SpellChoice.discovery) reconcileLevel();
      return;
    }
    final reason = reasonUnavailable(spell, choice);
    if (reason != null) throw StateError(reason);
    choices.add(spell);
    if (choice == SpellChoice.discovery) reconcileLevel();
  }

  void clear() {
    _cantrips.clear();
    _prepared.clear();
    _spellbook.clear();
    _arcana.clear();
    _discoveries.clear();
    _spentSlots.clear();
  }

  void clearDiscoveries() => _discoveries.clear();

  void grantNecromancerSpell() {
    _spellbook.add(
      fantasySpellCatalog.singleWhere((spell) => spell.id == 'animate-dead'),
    );
  }

  void reconcileLevel() {
    _discoveries.removeWhere(
      (spell) => _eligibility(spell, SpellChoice.discovery) != null,
    );
    _cantrips.removeWhere(
      (spell) => _eligibility(spell, SpellChoice.cantrip) != null,
    );
    _spellbook.removeWhere(
      (spell) => _eligibility(spell, SpellChoice.spellbook) != null,
    );
    _prepared.removeWhere(
      (spell) => _eligibility(spell, SpellChoice.prepared) != null,
    );
    _arcana.removeWhere(
      (spell) => _eligibility(spell, SpellChoice.arcanum) != null,
    );
    while (_cantrips.length > cantripLimit) {
      _cantrips.remove(_cantrips.last);
    }
    while (_prepared.length > preparedLimit) {
      _prepared.remove(_prepared.last);
    }
  }
}
