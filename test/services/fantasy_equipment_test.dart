import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/fantasy_character.dart';
import 'package:lore/models/fantasy_equipment.dart';
import 'package:lore/models/world.dart';

void main() {
  test('weapon attack abilities and bonuses respect weapon and training', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    );
    expect(
      () => draft.weaponAttackAbilities(FantasyWeapon.dagger),
      throwsStateError,
    );
    draft.characterClass = FantasyClass.wizard;
    draft.setScore(FantasyAbility.dexterity, 14);
    expect(draft.weaponAttackAbilities(FantasyWeapon.dagger), {
      FantasyAbility.strength,
      FantasyAbility.dexterity,
    });
    expect(
      draft.weaponAttackBonus(FantasyWeapon.dagger, FantasyAbility.dexterity),
      4,
    );
    expect(
      draft.weaponAttackBonus(
        FantasyWeapon.greatsword,
        FantasyAbility.strength,
      ),
      0,
    );
    expect(draft.weaponAttackAbilities(FantasyWeapon.spear), {
      FantasyAbility.strength,
    });
    expect(draft.weaponAttackAbilities(FantasyWeapon.longbow), {
      FantasyAbility.dexterity,
    });
    expect(draft.weaponAttackAbilities(FantasyWeapon.dart), {
      FantasyAbility.strength,
      FantasyAbility.dexterity,
    });
    expect(
      () => draft.weaponAttackBonus(
        FantasyWeapon.longbow,
        FantasyAbility.strength,
      ),
      throwsArgumentError,
    );
    draft.characterClass = FantasyClass.fighter;
    draft.level = 5;
    expect(
      draft.weaponAttackBonus(FantasyWeapon.longbow, FantasyAbility.dexterity),
      5,
    );
  });

  test('Monk weapon options follow armor and level requirements', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    )..characterClass = FantasyClass.monk;
    expect(draft.weaponAttackAbilities(FantasyWeapon.spear), {
      FantasyAbility.strength,
      FantasyAbility.dexterity,
    });
    expect(draft.monkWeaponDie(FantasyWeapon.spear), 6);
    expect(draft.monkWeaponDie(FantasyWeapon.dart), isNull);
    draft.level = 5;
    expect(draft.monkWeaponDie(FantasyWeapon.spear), 8);
    draft.level = 11;
    expect(draft.monkWeaponDie(FantasyWeapon.spear), 10);
    draft.level = 17;
    expect(draft.monkWeaponDie(FantasyWeapon.spear), 12);
    draft.shield = true;
    expect(draft.monkWeaponDie(FantasyWeapon.spear), isNull);
    expect(draft.weaponAttackAbilities(FantasyWeapon.spear), {
      FantasyAbility.strength,
    });
    expect(draft.weaponAttackDisadvantage(FantasyWeapon.spear), isTrue);
    draft.shield = false;
    draft.armor = FantasyArmor.leather;
    expect(draft.monkWeaponDie(FantasyWeapon.spear), isNull);
    expect(draft.weaponAttackDisadvantage(FantasyWeapon.spear), isTrue);
  });

  test('heavy weapon and untrained armor disadvantage apply independently', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    )..characterClass = FantasyClass.fighter;
    expect(draft.weaponAttackDisadvantage(FantasyWeapon.greatsword), isTrue);
    draft.setScore(FantasyAbility.strength, 13);
    expect(draft.weaponAttackDisadvantage(FantasyWeapon.greatsword), isFalse);
    draft.characterClass = FantasyClass.wizard;
    draft.armor = FantasyArmor.plate;
    expect(draft.weaponAttackDisadvantage(FantasyWeapon.dagger), isTrue);
    draft.armor = null;
    draft.shield = true;
    expect(draft.weaponAttackDisadvantage(FantasyWeapon.dagger), isTrue);
    draft.shield = false;
    expect(draft.weaponAttackDisadvantage(FantasyWeapon.dagger), isFalse);
  });

  test('equipment training follows the selected starting class', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    );
    expect(draft.weaponProficient(FantasyWeapon.dagger), isNull);
    expect(draft.shieldTrained, isNull);
    expect(draft.armorClass, isNull);
    draft.characterClass = FantasyClass.rogue;
    expect(draft.weaponProficient(FantasyWeapon.rapier), isTrue);
    expect(draft.weaponProficient(FantasyWeapon.greatsword), isFalse);
    expect(draft.armorTrained(FantasyArmor.leather), isTrue);
    expect(draft.armorTrained(FantasyArmor.chainShirt), isFalse);
    draft.characterClass = FantasyClass.monk;
    expect(draft.weaponProficient(FantasyWeapon.shortsword), isTrue);
    expect(draft.weaponProficient(FantasyWeapon.rapier), isFalse);
    draft.characterClass = FantasyClass.druid;
    expect(draft.armorTrained(FantasyArmor.leather), isTrue);
    expect(draft.armorTrained(FantasyArmor.chainShirt), isFalse);
    expect(draft.shieldTrained, isTrue);
    draft.characterClass = FantasyClass.fighter;
    expect(draft.weaponProficient(FantasyWeapon.greatsword), isTrue);
    expect(draft.armorTrained(FantasyArmor.plate), isTrue);
  });

  test('armor class respects armor, shields and unarmored defense', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    );
    draft.setScore(FantasyAbility.dexterity, 14);
    draft.setScore(FantasyAbility.constitution, 14);
    draft.setScore(FantasyAbility.wisdom, 14);
    draft.characterClass = FantasyClass.barbarian;
    expect(draft.armorClass, 14);
    draft.shield = true;
    expect(draft.armorClass, 16);
    draft.characterClass = FantasyClass.monk;
    expect(draft.armorClass, 12);
    draft.shield = false;
    expect(draft.armorClass, 14);
    draft.characterClass = FantasyClass.fighter;
    draft.setBackground(FantasyBackground.soldier);
    draft.setBackgroundTwo(FantasyAbility.dexterity);
    draft.armor = FantasyArmor.halfPlate;
    expect(draft.armorClass, 17);
    draft.shield = true;
    expect(draft.armorClass, 19);
    draft.armor = FantasyArmor.plate;
    expect(draft.armorClass, 20);
    draft.characterClass = FantasyClass.wizard;
    expect(draft.armorClass, 18);
    expect(draft.armorTrained(FantasyArmor.plate), isFalse);
    draft.armor = FantasyArmor.leather;
    expect(draft.armorClass, 14);
    draft.setBackground(null);
    draft.setScore(FantasyAbility.dexterity, 8);
    draft.armor = FantasyArmor.chainShirt;
    expect(draft.armorClass, 12);
  });

  test('equipment ability warnings use the effective appropriate score', () {
    final draft = FantasyCharacterDraft.fromSandbox(
      CharacterEntry(id: 'hero', name: 'Griam'),
    );
    expect(draft.heavyWeaponRequirementMet(FantasyWeapon.dagger), isNull);
    expect(draft.heavyWeaponRequirementMet(FantasyWeapon.greatsword), isFalse);
    expect(draft.heavyWeaponRequirementMet(FantasyWeapon.longbow), isFalse);
    expect(draft.armorStrengthMet(FantasyArmor.plate), isFalse);
    expect(draft.armorStrengthMet(FantasyArmor.leather), isTrue);
    draft.setScore(FantasyAbility.strength, 13);
    draft.setScore(FantasyAbility.dexterity, 13);
    expect(draft.heavyWeaponRequirementMet(FantasyWeapon.greatsword), isTrue);
    expect(draft.heavyWeaponRequirementMet(FantasyWeapon.longbow), isTrue);
    expect(draft.armorStrengthMet(FantasyArmor.chainMail), isTrue);
    expect(draft.armorStrengthMet(FantasyArmor.plate), isFalse);
    draft.setBackground(FantasyBackground.soldier);
    expect(draft.armorStrengthMet(FantasyArmor.plate), isTrue);
    draft.setScore(FantasyAbility.dexterity, 11);
    expect(draft.heavyWeaponRequirementMet(FantasyWeapon.longbow), isFalse);
  });
}
