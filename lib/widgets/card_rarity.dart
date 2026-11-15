import 'package:flutter/material.dart';
import '../theme.dart';
import 'card_shape.dart';

/// Rarity tiers for Lore cards.
/// Every tier gets MORE of everything — more frame, more glow,
/// more tilt, more parallax, more colour. No tier is just a colour swap.
///
/// Legendary = Lore gold. Achievable with dedication.
/// Mythic = hidden gem. Only one. Shows as ??? until unlocked.
enum CardRarity {
  common,
  rare,
  epic,
  legendary,
  mythic;

  /// Safe parse for stored values (Firestore, prefs, JSON).
  /// Unknown / missing / old strings fall back to common instead of throwing.
  static CardRarity fromName(String? name) {
    if (name == null) return CardRarity.common;
    for (final rarity in CardRarity.values) {
      if (rarity.name == name) return rarity;
    }
    return CardRarity.common;
  }
}

extension CardRaritySpec on CardRarity {
  String get label {
    switch (this) {
      case CardRarity.common:
        return 'COMMON';
      case CardRarity.rare:
        return 'RARE';
      case CardRarity.epic:
        return 'EPIC';
      case CardRarity.legendary:
        return 'LEGENDARY';
      case CardRarity.mythic:
        return 'MYTHIC';
    }
  }

  /// What the picker shows BEFORE it's unlocked.
  /// Mythic stays hidden — that's the gem.
  String get displayLabel => this == CardRarity.mythic ? '???' : label;

  bool get isHidden => this == CardRarity.mythic;

  // ── Frame ──
  bool get ornate => this != CardRarity.common;
  bool get dense => switch (this) {
    CardRarity.epic || CardRarity.legendary || CardRarity.mythic => true,
    _ => false,
  };
  bool get glow => this != CardRarity.common;

  // ── How alive the card feels ──
  double get holoIntensity {
    switch (this) {
      case CardRarity.common:
        return 0.4;
      case CardRarity.rare:
        return 0.6;
      case CardRarity.epic:
        return 0.8;
      case CardRarity.legendary:
        return 1.0;
      case CardRarity.mythic:
        return 1.2;
    }
  }

  double get maxTiltDegrees {
    switch (this) {
      case CardRarity.common:
        return 10;
      case CardRarity.rare:
        return 12;
      case CardRarity.epic:
        return 14;
      case CardRarity.legendary:
        return 16;
      case CardRarity.mythic:
        return 18;
    }
  }

  double get parallaxStrength {
    switch (this) {
      case CardRarity.common:
        return 8;
      case CardRarity.rare:
        return 10;
      case CardRarity.epic:
        return 14;
      case CardRarity.legendary:
        return 18;
      case CardRarity.mythic:
        return 22;
    }
  }

  // ── Border ──
  double get borderWidth {
    switch (this) {
      case CardRarity.common:
        return 1.0;
      case CardRarity.rare:
        return 1.5;
      case CardRarity.epic:
        return 2.0;
      case CardRarity.legendary:
        return 2.5;
      case CardRarity.mythic:
        return 3.0;
    }
  }

  /// Accent override for the tier.
  /// null = use the card's own accent (Common).
  /// Legendary forces Lore gold. Mythic is iridescent — handled by the card.
  Color? get accentOverride {
    switch (this) {
      case CardRarity.common:
        return null;
      case CardRarity.rare:
        return cIce; // cool blue
      case CardRarity.epic:
        return cMagic; // purple / magenta
      case CardRarity.legendary:
        return cGold; // Lore gold
      case CardRarity.mythic:
        return null; // iridescent — special handling, not a single colour
    }
  }

  String get flavour {
    switch (this) {
      case CardRarity.common:
        return 'Clean. Quiet. Lore as you know it.';
      case CardRarity.rare:
        return 'A cool edge. A soft glow. Someone is paying attention.';
      case CardRarity.epic:
        return 'Dense, ornate, shimmering. This card has stories.';
      case CardRarity.legendary:
        return 'Gold. Heavy glow. This card has been earned.';
      case CardRarity.mythic:
        return '???';
    }
  }

  CardShape get shape {
    switch (this) {
      case CardRarity.common:
        return CardShape.square;
      case CardRarity.rare:
        return CardShape.bevelled;
      case CardRarity.epic:
        return CardShape.octagon;
      case CardRarity.legendary:
        return CardShape.jagged;
      case CardRarity.mythic:
        return CardShape.crystal;
    }
  }
}
