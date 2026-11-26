import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/fantasy_character.dart';
import 'package:lore/models/fantasy_spell_catalog.dart';
import 'package:lore/models/fantasy_spells.dart';
import 'package:lore/models/fantasy_subclass.dart';
import 'package:lore/models/world.dart';

FantasySpell spell(String id) =>
    fantasySpellCatalog.singleWhere((spell) => spell.id == id);

FantasyCharacterDraft character(FantasyClass characterClass, [int level = 1]) =>
    FantasyCharacterDraft.fromSandbox(CharacterEntry(id: '1', name: 'Test'))
      ..characterClass = characterClass
      ..level = level;

void main() {
  test('spellcasting statistics use the starting class ability', () {
    final abilities = {
      FantasyClass.bard: FantasyAbility.charisma,
      FantasyClass.cleric: FantasyAbility.wisdom,
      FantasyClass.druid: FantasyAbility.wisdom,
      FantasyClass.paladin: FantasyAbility.charisma,
      FantasyClass.ranger: FantasyAbility.wisdom,
      FantasyClass.sorcerer: FantasyAbility.charisma,
      FantasyClass.warlock: FantasyAbility.charisma,
      FantasyClass.wizard: FantasyAbility.intelligence,
    };
    for (final entry in abilities.entries) {
      final draft = character(entry.key);
      draft.setScore(entry.value, 14);
      expect(draft.spellcasting.spellcastingAbility, entry.value);
      expect(draft.spellcasting.spellAttackBonus, 4);
      expect(draft.spellcasting.spellSaveDc, 12);
    }
    final fighter = character(FantasyClass.fighter);
    expect(fighter.spellcasting.spellcastingAbility, isNull);
    expect(fighter.spellcasting.spellAttackBonus, isNull);
    expect(fighter.spellcasting.spellSaveDc, isNull);
    fighter.characterClass = null;
    expect(fighter.spellcasting.spellAttackBonus, isNull);
  });

  test('spellcasting statistics follow effective scores and proficiency', () {
    final draft = character(FantasyClass.wizard);
    draft.setScore(FantasyAbility.intelligence, 8);
    expect(draft.spellcasting.spellAttackBonus, 1);
    expect(draft.spellcasting.spellSaveDc, 9);
    draft.level = 5;
    expect(draft.spellcasting.spellAttackBonus, 2);
    draft.setBackground(FantasyBackground.sage);
    draft.setBackgroundTwo(FantasyAbility.intelligence);
    expect(draft.spellcasting.spellAttackBonus, 3);
    expect(draft.spellcasting.spellSaveDc, 11);
    draft.setScore(FantasyAbility.intelligence, 15);
    expect(draft.spellcasting.spellAttackBonus, 6);
    expect(draft.spellcasting.spellSaveDc, 14);
    draft.characterClass = FantasyClass.warlock;
    expect(draft.spellcasting.spellcastingAbility, FantasyAbility.charisma);
    expect(draft.spellcasting.spellAttackBonus, 3);
    expect(draft.spellcasting.spellSaveDc, 11);
  });

  test('base classes have the correct spell slot progression', () {
    for (final caster in [
      FantasyClass.bard,
      FantasyClass.cleric,
      FantasyClass.druid,
      FantasyClass.sorcerer,
      FantasyClass.wizard,
    ]) {
      final draft = character(caster);
      expect(draft.spellcasting.slotMaximum(1), 2);
      expect(draft.spellcasting.slotMaximum(2), 0);
      draft.level = 5;
      expect(
        [for (var i = 1; i <= 4; i++) draft.spellcasting.slotMaximum(i)],
        [4, 3, 2, 0],
      );
      draft.level = 20;
      expect(
        [for (var i = 1; i <= 9; i++) draft.spellcasting.slotMaximum(i)],
        [4, 3, 3, 3, 3, 2, 2, 1, 1],
      );
    }
    for (final caster in [FantasyClass.paladin, FantasyClass.ranger]) {
      final draft = character(caster);
      expect(draft.spellcasting.slotMaximum(1), 2);
      draft.level = 2;
      expect(draft.spellcasting.slotMaximum(1), 2);
      draft.level = 5;
      expect(draft.spellcasting.slotMaximum(2), 2);
      draft.level = 20;
      expect(
        [for (var i = 1; i <= 6; i++) draft.spellcasting.slotMaximum(i)],
        [4, 3, 3, 3, 2, 0],
      );
    }
    final fighter = character(FantasyClass.fighter);
    expect(fighter.spellcasting.slotMaximum(1), 0);
    expect(() => fighter.spellcasting.expendSlot(1), throwsStateError);
    expect(() => fighter.spellcasting.slotMaximum(0), throwsRangeError);
    expect(() => fighter.spellcasting.slotMaximum(10), throwsRangeError);
  });

  test('spell slots track use, level changes, rests and class changes', () {
    final draft = character(FantasyClass.wizard);
    final casting = draft.spellcasting;
    casting.expendSlot(1);
    casting.expendSlot(1);
    expect(casting.remainingSlots(1), 0);
    expect(() => casting.expendSlot(1), throwsStateError);
    expect(() => casting.restoreSlotsAfterShortRest(), throwsStateError);
    draft.level = 3;
    expect(casting.remainingSlots(1), 2);
    expect(casting.remainingSlots(2), 2);
    casting.expendSlot(2);
    draft.level = 1;
    draft.level = 3;
    expect(casting.remainingSlots(2), 1);
    casting.restoreSlot(2);
    expect(casting.remainingSlots(2), 2);
    expect(() => casting.restoreSlot(2), throwsStateError);
    casting.restoreSlotsAfterLongRest();
    expect(casting.remainingSlots(1), 4);
    casting.expendSlot(1);
    draft.characterClass = FantasyClass.cleric;
    expect(casting.remainingSlots(1), 4);
  });

  test('Pact Magic keeps spent slots when their level changes', () {
    final draft = character(FantasyClass.warlock);
    final casting = draft.spellcasting;
    expect(casting.slotMaximum(1), 1);
    casting.expendSlot(1);
    draft.level = 3;
    expect(casting.slotMaximum(1), 0);
    expect(casting.slotMaximum(2), 2);
    expect(casting.remainingSlots(2), 1);
    casting.expendSlot(2);
    draft.level = 11;
    expect(casting.slotMaximum(5), 3);
    expect(casting.remainingSlots(5), 1);
    casting.restoreSlotsAfterShortRest();
    expect(casting.remainingSlots(5), 3);
    draft.level = 17;
    expect(casting.slotMaximum(5), 4);
    expect(casting.slotMaximum(6), 0);
    casting.expendSlot(5);
    casting.restoreSlotsAfterLongRest();
    expect(casting.remainingSlots(5), 4);
  });

  test('every subclass bonus spell resolves to one catalog entry', () {
    for (final subclass in FantasySubclass.values) {
      for (final land in [null, ...FantasyLand.values]) {
        for (final ids in subclassSpells(subclass, land).values) {
          for (final id in ids) {
            expect(
              fantasySpellCatalog.where((spell) => spell.id == id),
              hasLength(1),
              reason: '${subclass.name}: $id',
            );
          }
        }
      }
    }
  });

  test('subclasses require level three and match the selected class', () {
    final draft = character(FantasyClass.wizard);
    expect(
      () => draft.setSubclass(FantasySubclass.necromancer),
      throwsStateError,
    );
    draft.level = 3;
    expect(() => draft.setSubclass(FantasySubclass.fiend), throwsStateError);
    draft.setSubclass(FantasySubclass.necromancer);
    draft.level = 2;
    expect(draft.subclass, isNull);
    draft.level = 3;
    draft.setSubclass(FantasySubclass.evoker);
    draft.characterClass = FantasyClass.warlock;
    expect(draft.subclass, isNull);
  });

  test('legacy Necromancer learns other schools and gains Animate Dead', () {
    final draft = character(FantasyClass.wizard, 5);
    draft.setSubclass(FantasySubclass.necromancer);
    final casting = draft.spellcasting;
    final fireball = spell('fireball');
    casting.setSelected(fireball, SpellChoice.spellbook, true);
    casting.setSelected(fireball, SpellChoice.prepared, true);
    expect(casting.spellbook, isNot(contains(spell('animate-dead'))));
    draft.level = 6;
    expect(casting.spellbook, contains(spell('animate-dead')));
    expect(casting.prepared, contains(fireball));
    expect(casting.prepared, isNot(contains(spell('animate-dead'))));
    casting.setSelected(spell('animate-dead'), SpellChoice.prepared, true);
    expect(casting.prepared, contains(spell('animate-dead')));
  });

  test('Grim Harvest requires a qualifying kill and is limited per turn', () {
    final draft = character(FantasyClass.wizard, 3);
    expect(
      () => draft.applyGrimHarvest(
        spellLevel: 1,
        necromancy: false,
        eligibleKill: true,
      ),
      throwsStateError,
    );
    draft.setSubclass(FantasySubclass.necromancer);
    draft.takeDamage(10);
    expect(
      () => draft.applyGrimHarvest(
        spellLevel: 0,
        necromancy: true,
        eligibleKill: true,
      ),
      throwsRangeError,
    );
    expect(
      () => draft.applyGrimHarvest(
        spellLevel: 1,
        necromancy: true,
        eligibleKill: false,
      ),
      throwsStateError,
    );
    expect(draft.grimHarvestUsed, false);
    draft.applyGrimHarvest(
      spellLevel: 2,
      necromancy: false,
      eligibleKill: true,
    );
    expect(draft.currentHitPoints, 8);
    expect(
      () => draft.applyGrimHarvest(
        spellLevel: 1,
        necromancy: true,
        eligibleKill: true,
      ),
      throwsStateError,
    );
    draft.startNecromancerTurn();
    draft.applyGrimHarvest(spellLevel: 2, necromancy: true, eligibleKill: true);
    expect(draft.currentHitPoints, draft.hitPointMaximum);
    draft.setSubclass(FantasySubclass.evoker);
    expect(() => draft.startNecromancerTurn(), throwsStateError);
    draft.setSubclass(FantasySubclass.necromancer);
    expect(draft.grimHarvestUsed, false);
  });

  test(
    'level 10 Necromancer resistance only halves marked necrotic damage',
    () {
      final draft = character(FantasyClass.wizard, 10)
        ..setSubclass(FantasySubclass.necromancer);
      final max = draft.hitPointMaximum!;
      draft.takeDamage(7, necrotic: true);
      expect(draft.currentHitPoints, max - 3);
      draft.takeDamage(1, necrotic: true);
      expect(draft.currentHitPoints, max - 3);
      draft.takeDamage(7);
      expect(draft.currentHitPoints, max - 10);
      draft.level = 9;
      final before = draft.currentHitPoints!;
      draft.takeDamage(7, necrotic: true);
      expect(draft.currentHitPoints, before - 7);
    },
  );

  test('domain and patron grant spells without using preparation choices', () {
    final cleric = character(FantasyClass.cleric, 2);
    cleric.spellcasting.setSelected(spell('bless'), SpellChoice.prepared, true);
    cleric.level = 3;
    cleric.setSubclass(FantasySubclass.life);
    expect(cleric.spellcasting.alwaysPrepared, contains(spell('bless')));
    expect(cleric.spellcasting.prepared, isEmpty);
    expect(cleric.spellcasting.preparedLimit, 6);
    final warlock = character(FantasyClass.warlock, 5);
    warlock.setSubclass(FantasySubclass.fiend);
    expect(warlock.spellcasting.alwaysPrepared, contains(spell('fireball')));
    expect(warlock.spellcasting.prepared, isEmpty);
    warlock.level = 4;
    expect(
      warlock.spellcasting.alwaysPrepared,
      isNot(contains(spell('fireball'))),
    );
  });

  test('land choice changes both bonus cantrips and spells', () {
    final druid = character(FantasyClass.druid, 5);
    druid.setSubclass(FantasySubclass.land);
    expect(
      druid.spellcasting.alwaysPrepared,
      isNot(contains(spell('fire-bolt'))),
    );
    druid.setLand(FantasyLand.arid);
    expect(
      druid.spellcasting.alwaysPrepared,
      containsAll([spell('fire-bolt'), spell('fireball')]),
    );
    druid.setLand(FantasyLand.polar);
    expect(druid.spellcasting.alwaysPrepared, contains(spell('ray-of-frost')));
    expect(
      druid.spellcasting.alwaysPrepared,
      isNot(contains(spell('fireball'))),
    );
    expect(
      druid.spellcasting.alwaysPrepared,
      contains(spell('speak-with-animals')),
    );
  });

  test(
    'Lore discoveries allow two eligible outside-list spells or cantrips',
    () {
      final bard = character(FantasyClass.bard, 6);
      bard.setSubclass(FantasySubclass.lore);
      final casting = bard.spellcasting;
      casting.setSelected(spell('fireball'), SpellChoice.discovery, true);
      casting.setSelected(spell('guidance'), SpellChoice.discovery, true);
      expect(
        casting.alwaysPrepared,
        containsAll([spell('fireball'), spell('guidance')]),
      );
      expect(casting.prepared, isEmpty);
      expect(
        casting.reasonUnavailable(spell('aid'), SpellChoice.discovery),
        'Both Magical Discoveries are selected.',
      );
      bard.level = 5;
      expect(casting.discoveries, isEmpty);
    },
  );

  test('base classes use their level-specific preparation limits', () {
    final levelOne = {
      FantasyClass.bard: [2, 4],
      FantasyClass.cleric: [3, 4],
      FantasyClass.druid: [2, 4],
      FantasyClass.paladin: [0, 2],
      FantasyClass.ranger: [0, 2],
      FantasyClass.sorcerer: [4, 2],
      FantasyClass.warlock: [2, 2],
      FantasyClass.wizard: [3, 4],
    };
    for (final entry in levelOne.entries) {
      final casting = character(entry.key).spellcasting;
      expect([casting.cantripLimit, casting.preparedLimit], entry.value);
      expect(casting.maximumSpellLevel, 1);
    }
    expect(character(FantasyClass.fighter).spellcasting.available, false);
    expect(character(FantasyClass.sorcerer, 2).spellcasting.preparedLimit, 4);
    expect(character(FantasyClass.bard, 14).spellcasting.preparedLimit, 17);
    expect(character(FantasyClass.wizard, 14).spellcasting.preparedLimit, 18);
    expect(character(FantasyClass.warlock, 20).spellcasting.preparedLimit, 15);
    expect(
      character(FantasyClass.paladin, 5).spellcasting.maximumSpellLevel,
      2,
    );
    expect(
      character(FantasyClass.ranger, 17).spellcasting.maximumSpellLevel,
      5,
    );
    expect(
      character(FantasyClass.wizard, 17).spellcasting.maximumSpellLevel,
      9,
    );
  });

  test('cantrips and spells enforce class, level and choice limits', () {
    final draft = character(FantasyClass.cleric);
    final casting = draft.spellcasting;
    expect(
      casting.reasonUnavailable(spell('fireball'), SpellChoice.prepared),
      'Not on this class spell list.',
    );
    expect(
      casting.reasonUnavailable(spell('aid'), SpellChoice.prepared),
      'Requires a higher-level spell slot.',
    );
    for (final id in ['guidance', 'light', 'sacred-flame']) {
      casting.setSelected(spell(id), SpellChoice.cantrip, true);
    }
    expect(
      casting.reasonUnavailable(spell('thaumaturgy'), SpellChoice.cantrip),
      'Cantrip limit reached.',
    );
    expect(
      () =>
          casting.setSelected(spell('thaumaturgy'), SpellChoice.cantrip, true),
      throwsStateError,
    );
    draft.level = 4;
    casting.setSelected(spell('thaumaturgy'), SpellChoice.cantrip, true);
    draft.level = 1;
    expect(casting.cantrips.length, 3);
    expect(casting.cantrips.contains(spell('thaumaturgy')), false);
    draft.characterClass = FantasyClass.wizard;
    expect(casting.cantrips, isEmpty);
  });

  test('prepared spell limit frees a choice when a spell is removed', () {
    final casting = character(FantasyClass.ranger).spellcasting;
    for (final id in ['cure-wounds', 'detect-magic']) {
      casting.setSelected(spell(id), SpellChoice.prepared, true);
    }
    expect(
      casting.reasonUnavailable(spell('goodberry'), SpellChoice.prepared),
      'Prepared spell limit reached.',
    );
    casting.setSelected(spell('cure-wounds'), SpellChoice.prepared, false);
    casting.setSelected(spell('goodberry'), SpellChoice.prepared, true);
    expect(casting.prepared, {spell('detect-magic'), spell('goodberry')});
    expect(casting.alwaysPrepared, contains(spell('hunters-mark')));
  });

  test('wizard preparation requires a spellbook and follows level changes', () {
    final draft = character(FantasyClass.wizard, 3);
    final casting = draft.spellcasting;
    final magicMissile = spell('magic-missile');
    final invisibility = spell('invisibility');
    expect(
      casting.reasonUnavailable(magicMissile, SpellChoice.prepared),
      'Add it to the spellbook first.',
    );
    casting.setSelected(magicMissile, SpellChoice.spellbook, true);
    casting.setSelected(invisibility, SpellChoice.spellbook, true);
    casting.setSelected(magicMissile, SpellChoice.prepared, true);
    casting.setSelected(invisibility, SpellChoice.prepared, true);
    casting.setSelected(magicMissile, SpellChoice.spellbook, false);
    expect(casting.prepared, {invisibility});
    draft.level = 1;
    expect(casting.spellbook, isEmpty);
    expect(casting.prepared, isEmpty);
  });

  test('warlock arcana are separate and unlock one per spell level', () {
    final draft = character(FantasyClass.warlock, 11);
    final casting = draft.spellcasting;
    final sixth = spell('eyebite');
    final seventh = spell('finger-of-death');
    expect(casting.maximumSpellLevel, 5);
    casting.setSelected(sixth, SpellChoice.arcanum, true);
    expect(casting.prepared, isEmpty);
    expect(
      casting.reasonUnavailable(seventh, SpellChoice.arcanum),
      'Requires Warlock level 13.',
    );
    expect(
      casting.reasonUnavailable(spell('circle-of-death'), SpellChoice.arcanum),
      'A level 6 arcanum is already selected.',
    );
    draft.level = 13;
    casting.setSelected(seventh, SpellChoice.arcanum, true);
    draft.level = 10;
    expect(casting.arcana, isEmpty);
  });

  test('class feature spells and Bard Magical Secrets have separate rules', () {
    final druid = character(FantasyClass.druid);
    expect(
      druid.spellcasting.alwaysPrepared,
      contains(spell('speak-with-animals')),
    );
    expect(
      druid.spellcasting.reasonUnavailable(
        spell('speak-with-animals'),
        SpellChoice.prepared,
      ),
      'Already prepared by a class feature.',
    );
    final ranger = character(FantasyClass.ranger);
    expect(ranger.spellcasting.alwaysPrepared, contains(spell('hunters-mark')));
    final paladin = character(FantasyClass.paladin, 5);
    expect(
      paladin.spellcasting.alwaysPrepared,
      containsAll([spell('divine-smite'), spell('find-steed')]),
    );
    final bard = character(FantasyClass.bard, 10);
    final fireball = spell('fireball');
    bard.spellcasting.setSelected(fireball, SpellChoice.prepared, true);
    bard.level = 9;
    expect(bard.spellcasting.prepared, isNot(contains(fireball)));
    bard.level = 20;
    expect(
      bard.spellcasting.alwaysPrepared,
      containsAll([spell('power-word-heal'), spell('power-word-kill')]),
    );
  });
}
