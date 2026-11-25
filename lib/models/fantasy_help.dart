import 'fantasy_character.dart';

typedef FantasyHelp = ({String description, String classes});

FantasyHelp abilityHelp(FantasyAbility ability) => switch (ability) {
  FantasyAbility.strength => (
    description:
        'Physical power for lifting, grappling and many melee attacks.',
    classes: 'Often important for Barbarians, Fighters and Paladins.',
  ),
  FantasyAbility.dexterity => (
    description:
        'Agility and reflexes; helps with initiative, defense and many ranged attacks.',
    classes: 'Often important for Rogues, Rangers and Monks.',
  ),
  FantasyAbility.constitution => (
    description:
        'Endurance; affects hit points and helps maintain concentration.',
    classes: 'Useful for every class, especially characters facing danger.',
  ),
  FantasyAbility.intelligence => (
    description:
        'Reasoning and knowledge; supports investigation and some magic.',
    classes: 'Especially important for Wizards.',
  ),
  FantasyAbility.wisdom => (
    description: 'Awareness and intuition; supports perception and some magic.',
    classes: 'Often important for Clerics, Druids, Rangers and Monks.',
  ),
  FantasyAbility.charisma => (
    description:
        'Presence and force of personality; supports social checks and some magic.',
    classes: 'Often important for Bards, Paladins, Sorcerers and Warlocks.',
  ),
};

FantasyHelp skillHelp(FantasySkill skill) => switch (skill) {
  FantasySkill.acrobatics => (
    description: 'Keep your balance or perform agile physical maneuvers.',
    classes: 'Often useful for Rogues and Monks.',
  ),
  FantasySkill.animalHandling => (
    description:
        'Calm or understand animals and guide their behavior; success does not guarantee taming.',
    classes: 'Often useful for Druids and Rangers.',
  ),
  FantasySkill.arcana => (
    description: 'Recall knowledge about magic and magical traditions.',
    classes: 'Often useful for Wizards, Sorcerers and Warlocks.',
  ),
  FantasySkill.athletics => (
    description:
        'Handle strenuous tasks such as climbing, jumping and swimming.',
    classes: 'Often useful for Barbarians and Fighters.',
  ),
  FantasySkill.deception => (
    description: 'Mislead someone through words, disguise or behavior.',
    classes: 'Often useful for Bards, Rogues and Warlocks.',
  ),
  FantasySkill.history => (
    description: 'Recall knowledge about past events, people and cultures.',
    classes: 'Often useful for Bards and Wizards.',
  ),
  FantasySkill.insight => (
    description: "Read behavior and infer a creature's intentions or feelings.",
    classes: 'Often useful for Clerics, Druids and Rogues.',
  ),
  FantasySkill.intimidation => (
    description: 'Influence someone through threats or a commanding presence.',
    classes: 'Often useful for Barbarians, Paladins and Warlocks.',
  ),
  FantasySkill.investigation => (
    description: 'Examine clues and reason out what they reveal.',
    classes: 'Often useful for Rogues, Wizards and Bards.',
  ),
  FantasySkill.medicine => (
    description: 'Assess injuries or illness and provide basic care.',
    classes: 'Often useful for Clerics and Druids.',
  ),
  FantasySkill.nature => (
    description:
        'Recall knowledge about plants, animals and the natural world.',
    classes: 'Often useful for Druids and Rangers.',
  ),
  FantasySkill.perception => (
    description: 'Notice sights, sounds and other details around you.',
    classes: 'Useful for everyone, especially Rangers and Rogues.',
  ),
  FantasySkill.performance => (
    description:
        'Entertain an audience through music, acting or another performance.',
    classes: 'Often useful for Bards.',
  ),
  FantasySkill.persuasion => (
    description: 'Influence others through conversation and good faith.',
    classes: 'Often useful for Bards and Paladins.',
  ),
  FantasySkill.religion => (
    description:
        'Recall knowledge about faiths, rituals and religious traditions.',
    classes: 'Often useful for Clerics and Paladins.',
  ),
  FantasySkill.sleightOfHand => (
    description:
        'Perform precise hand movements, such as concealing a small object.',
    classes: 'Often useful for Rogues and Bards.',
  ),
  FantasySkill.stealth => (
    description: 'Move or hide without drawing attention.',
    classes: 'Often useful for Rogues and Rangers.',
  ),
  FantasySkill.survival => (
    description: 'Navigate and cope with hazards in the wilderness.',
    classes: 'Often useful for Rangers and Druids.',
  ),
};
