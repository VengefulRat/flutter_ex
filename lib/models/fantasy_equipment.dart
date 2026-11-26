enum ArmorCategory { light, medium, heavy }

enum FantasyArmor {
  padded(ArmorCategory.light, 11, stealthDisadvantage: true),
  leather(ArmorCategory.light, 11),
  studdedLeather(ArmorCategory.light, 12),
  hide(ArmorCategory.medium, 12),
  chainShirt(ArmorCategory.medium, 13),
  scaleMail(ArmorCategory.medium, 14, stealthDisadvantage: true),
  breastplate(ArmorCategory.medium, 14),
  halfPlate(ArmorCategory.medium, 15, stealthDisadvantage: true),
  ringMail(ArmorCategory.heavy, 14, stealthDisadvantage: true),
  chainMail(
    ArmorCategory.heavy,
    16,
    strengthRequired: 13,
    stealthDisadvantage: true,
  ),
  splint(
    ArmorCategory.heavy,
    17,
    strengthRequired: 15,
    stealthDisadvantage: true,
  ),
  plate(
    ArmorCategory.heavy,
    18,
    strengthRequired: 15,
    stealthDisadvantage: true,
  );

  const FantasyArmor(
    this.category,
    this.baseAc, {
    this.strengthRequired,
    this.stealthDisadvantage = false,
  });

  final ArmorCategory category;
  final int baseAc;
  final int? strengthRequired;
  final bool stealthDisadvantage;
}

enum WeaponCategory { simple, martial }

enum HeavyWeaponAbility { strength, dexterity }

enum FantasyWeapon {
  club(WeaponCategory.simple, '1d4 bludgeoning', 'Light', light: true),
  dagger(
    WeaponCategory.simple,
    '1d4 piercing',
    'Finesse, light, thrown 20/60 ft',
    finesse: true,
    light: true,
  ),
  greatclub(
    WeaponCategory.simple,
    '1d8 bludgeoning',
    'Two-handed',
    twoHanded: true,
  ),
  handaxe(
    WeaponCategory.simple,
    '1d6 slashing',
    'Light, thrown 20/60 ft',
    light: true,
  ),
  javelin(WeaponCategory.simple, '1d6 piercing', 'Thrown 30/120 ft'),
  lightHammer(
    WeaponCategory.simple,
    '1d4 bludgeoning',
    'Light, thrown 20/60 ft',
    light: true,
  ),
  mace(WeaponCategory.simple, '1d6 bludgeoning', ''),
  quarterstaff(WeaponCategory.simple, '1d6 bludgeoning', 'Versatile 1d8'),
  sickle(WeaponCategory.simple, '1d4 slashing', 'Light', light: true),
  spear(
    WeaponCategory.simple,
    '1d6 piercing',
    'Thrown 20/60 ft, versatile 1d8',
  ),
  dart(
    WeaponCategory.simple,
    '1d4 piercing',
    'Finesse, thrown 20/60 ft',
    finesse: true,
  ),
  lightCrossbow(
    WeaponCategory.simple,
    '1d8 piercing',
    'Ammunition 80/320 ft, loading, two-handed',
    twoHanded: true,
  ),
  shortbow(
    WeaponCategory.simple,
    '1d6 piercing',
    'Ammunition 80/320 ft, two-handed',
    twoHanded: true,
  ),
  sling(WeaponCategory.simple, '1d4 bludgeoning', 'Ammunition 30/120 ft'),
  battleaxe(WeaponCategory.martial, '1d8 slashing', 'Versatile 1d10'),
  flail(WeaponCategory.martial, '1d8 bludgeoning', ''),
  glaive(
    WeaponCategory.martial,
    '1d10 slashing',
    'Heavy, reach, two-handed',
    twoHanded: true,
    heavyAbility: HeavyWeaponAbility.strength,
  ),
  greataxe(
    WeaponCategory.martial,
    '1d12 slashing',
    'Heavy, two-handed',
    twoHanded: true,
    heavyAbility: HeavyWeaponAbility.strength,
  ),
  greatsword(
    WeaponCategory.martial,
    '2d6 slashing',
    'Heavy, two-handed',
    twoHanded: true,
    heavyAbility: HeavyWeaponAbility.strength,
  ),
  halberd(
    WeaponCategory.martial,
    '1d10 slashing',
    'Heavy, reach, two-handed',
    twoHanded: true,
    heavyAbility: HeavyWeaponAbility.strength,
  ),
  lance(
    WeaponCategory.martial,
    '1d10 piercing',
    'Heavy, reach, two-handed unless mounted',
    twoHanded: true,
    heavyAbility: HeavyWeaponAbility.strength,
  ),
  longsword(WeaponCategory.martial, '1d8 slashing', 'Versatile 1d10'),
  maul(
    WeaponCategory.martial,
    '2d6 bludgeoning',
    'Heavy, two-handed',
    twoHanded: true,
    heavyAbility: HeavyWeaponAbility.strength,
  ),
  morningstar(WeaponCategory.martial, '1d8 piercing', ''),
  pike(
    WeaponCategory.martial,
    '1d10 piercing',
    'Heavy, reach, two-handed',
    twoHanded: true,
    heavyAbility: HeavyWeaponAbility.strength,
  ),
  rapier(WeaponCategory.martial, '1d8 piercing', 'Finesse', finesse: true),
  scimitar(
    WeaponCategory.martial,
    '1d6 slashing',
    'Finesse, light',
    finesse: true,
    light: true,
  ),
  shortsword(
    WeaponCategory.martial,
    '1d6 piercing',
    'Finesse, light',
    finesse: true,
    light: true,
  ),
  trident(
    WeaponCategory.martial,
    '1d8 piercing',
    'Thrown 20/60 ft, versatile 1d10',
  ),
  warhammer(WeaponCategory.martial, '1d8 bludgeoning', 'Versatile 1d10'),
  warPick(WeaponCategory.martial, '1d8 piercing', 'Versatile 1d10'),
  whip(WeaponCategory.martial, '1d4 slashing', 'Finesse, reach', finesse: true),
  blowgun(
    WeaponCategory.martial,
    '1 piercing',
    'Ammunition 25/100 ft, loading',
  ),
  handCrossbow(
    WeaponCategory.martial,
    '1d6 piercing',
    'Ammunition 30/120 ft, light, loading',
    light: true,
  ),
  heavyCrossbow(
    WeaponCategory.martial,
    '1d10 piercing',
    'Ammunition 100/400 ft, heavy, loading, two-handed',
    twoHanded: true,
    heavyAbility: HeavyWeaponAbility.dexterity,
  ),
  longbow(
    WeaponCategory.martial,
    '1d8 piercing',
    'Ammunition 150/600 ft, heavy, two-handed',
    twoHanded: true,
    heavyAbility: HeavyWeaponAbility.dexterity,
  ),
  musket(
    WeaponCategory.martial,
    '1d12 piercing',
    'Ammunition 40/120 ft, loading, two-handed',
    twoHanded: true,
  ),
  pistol(
    WeaponCategory.martial,
    '1d10 piercing',
    'Ammunition 30/90 ft, loading',
  );

  const FantasyWeapon(
    this.category,
    this.damage,
    this.properties, {
    this.finesse = false,
    this.light = false,
    this.twoHanded = false,
    this.heavyAbility,
  });

  final WeaponCategory category;
  final String damage;
  final String properties;
  final bool finesse;
  final bool light;
  final bool twoHanded;
  final HeavyWeaponAbility? heavyAbility;

  bool get isMelee => switch (this) {
    FantasyWeapon.dart ||
    FantasyWeapon.lightCrossbow ||
    FantasyWeapon.shortbow ||
    FantasyWeapon.sling ||
    FantasyWeapon.blowgun ||
    FantasyWeapon.handCrossbow ||
    FantasyWeapon.heavyCrossbow ||
    FantasyWeapon.longbow ||
    FantasyWeapon.musket ||
    FantasyWeapon.pistol => false,
    _ => true,
  };
}
