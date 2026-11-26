import 'fantasy_character.dart';

enum FantasySubclass {
  berserker(FantasyClass.barbarian, 'Path of the Berserker'),
  lore(FantasyClass.bard, 'College of Lore'),
  life(FantasyClass.cleric, 'Life Domain'),
  land(FantasyClass.druid, 'Circle of the Land'),
  champion(FantasyClass.fighter, 'Champion'),
  openHand(FantasyClass.monk, 'Warrior of the Open Hand'),
  devotion(FantasyClass.paladin, 'Oath of Devotion'),
  hunter(FantasyClass.ranger, 'Hunter'),
  thief(FantasyClass.rogue, 'Thief'),
  draconic(FantasyClass.sorcerer, 'Draconic Sorcery'),
  fiend(FantasyClass.warlock, 'Fiend Patron'),
  evoker(FantasyClass.wizard, 'Evoker'),
  necromancer(FantasyClass.wizard, 'School of Necromancy (2014 legacy)');

  const FantasySubclass(this.characterClass, this.label);
  final FantasyClass characterClass;
  final String label;
}

enum FantasyLand { arid, polar, temperate, tropical }

Map<int, List<String>> subclassSpells(
  FantasySubclass? subclass,
  FantasyLand? land,
) => switch (subclass) {
  FantasySubclass.life => {
    3: ['aid', 'bless', 'cure-wounds', 'lesser-restoration'],
    5: ['mass-healing-word', 'revivify'],
    7: ['aura-of-life', 'death-ward'],
    9: ['greater-restoration', 'mass-cure-wounds'],
  },
  FantasySubclass.devotion => {
    3: ['protection-from-evil-and-good', 'shield-of-faith'],
    5: ['aid', 'zone-of-truth'],
    9: ['beacon-of-hope', 'dispel-magic'],
    13: ['freedom-of-movement', 'guardian-of-faith'],
    17: ['commune', 'flame-strike'],
  },
  FantasySubclass.fiend => {
    3: ['burning-hands', 'command', 'scorching-ray', 'suggestion'],
    5: ['fireball', 'stinking-cloud'],
    7: ['fire-shield', 'wall-of-fire'],
    9: ['geas', 'insect-plague'],
  },
  FantasySubclass.draconic => {
    3: ['alter-self', 'chromatic-orb', 'command', 'dragons-breath'],
    5: ['fear', 'fly'],
    7: ['arcane-eye', 'charm-monster'],
    9: ['legend-lore', 'summon-dragon'],
  },
  FantasySubclass.land => switch (land) {
    FantasyLand.arid => {
      3: ['blur', 'burning-hands', 'fire-bolt'],
      5: ['fireball'],
      7: ['blight'],
      9: ['wall-of-stone'],
    },
    FantasyLand.polar => {
      3: ['fog-cloud', 'hold-person', 'ray-of-frost'],
      5: ['sleet-storm'],
      7: ['ice-storm'],
      9: ['cone-of-cold'],
    },
    FantasyLand.temperate => {
      3: ['misty-step', 'shocking-grasp', 'sleep'],
      5: ['lightning-bolt'],
      7: ['freedom-of-movement'],
      9: ['tree-stride'],
    },
    FantasyLand.tropical => {
      3: ['acid-splash', 'ray-of-sickness', 'web'],
      5: ['stinking-cloud'],
      7: ['polymorph'],
      9: ['insect-plague'],
    },
    null => {},
  },
  _ => {},
};
