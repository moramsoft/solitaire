import 'package:material_ui/material_ui.dart';

import '../engine/card.dart';

/// Deck suit coloring mode.
enum DeckColorMode {
  classicTwoColor,
  fourColor,
}

/// Distinct playing-card face styles combining custom suit craft and
/// matching J/Q/K court artwork.
enum DeckFaceStyle {
  americanHeritage,
  botanicalGarden,
  artDecoParlor,
  maritimeClub,
  royalEmblem;

  String get displayName {
    switch (this) {
      case DeckFaceStyle.americanHeritage:
        return 'Heritage';
      case DeckFaceStyle.botanicalGarden:
        return 'Botanical';
      case DeckFaceStyle.artDecoParlor:
        return 'Art Deco';
      case DeckFaceStyle.maritimeClub:
        return 'Maritime';
      case DeckFaceStyle.royalEmblem:
        return 'Classic Emblem';
    }
  }

  String get subtitle {
    switch (this) {
      case DeckFaceStyle.americanHeritage:
        return 'Vintage copperplate';
      case DeckFaceStyle.botanicalGarden:
        return 'Garden engravings';
      case DeckFaceStyle.artDecoParlor:
        return '1925 geometric gold';
      case DeckFaceStyle.maritimeClub:
        return 'Coastal heritage';
      case DeckFaceStyle.royalEmblem:
        return 'Clean royal crests';
    }
  }
}

/// Parlor-inspired classic card back patterns.
enum CardBackStyle {
  crimsonLattice,
  royalNavy,
  botanicalFern,
  heritageGold,
  artDecoSunburst,
  coastalCompass,
  plumDamask,
  sageTrellis;

  String get displayName {
    switch (this) {
      case CardBackStyle.crimsonLattice:
        return 'Classic Red';
      case CardBackStyle.royalNavy:
        return 'Royal Navy';
      case CardBackStyle.botanicalFern:
        return 'Botanical';
      case CardBackStyle.heritageGold:
        return 'Heritage Gold';
      case CardBackStyle.artDecoSunburst:
        return 'Deco Sunburst';
      case CardBackStyle.coastalCompass:
        return 'Compass Rose';
      case CardBackStyle.plumDamask:
        return 'Parlor Plum';
      case CardBackStyle.sageTrellis:
        return 'Garden Trellis';
    }
  }
}

/// Supported heritage card-room table colorways.
enum TableThemeId {
  heritageGreen,
  warmParlor,
  coastalSlate,
  midnightMahogany;

  String get displayName {
    switch (this) {
      case TableThemeId.heritageGreen:
        return 'Heritage Green';
      case TableThemeId.warmParlor:
        return 'Warm Linen';
      case TableThemeId.coastalSlate:
        return 'Coastal Blue';
      case TableThemeId.midnightMahogany:
        return 'Warm Night';
    }
  }

  /// Parses persisted theme IDs including legacy v0.1 values.
  static TableThemeId parseOrFallback(String? name) {
    switch (name) {
      case 'classicGreen':
      case 'heritageGreen':
        return TableThemeId.heritageGreen;
      case 'warmIvory':
      case 'warmParlor':
        return TableThemeId.warmParlor;
      case 'coastalSlate':
        return TableThemeId.coastalSlate;
      case 'warmNightOled':
      case 'midnightMahogany':
        return TableThemeId.midnightMahogany;
      default:
        return TableThemeId.heritageGreen;
    }
  }
}

/// Senior-friendly card face scale options.
enum CardScale {
  large,
  jumbo;

  String get displayName => this == CardScale.large ? 'Large' : 'Jumbo';
}

/// High-contrast WCAG AAA heritage deck suit color palette.
class DeckPalette {
  const DeckPalette._();

  static Color suitColor(Suit suit, {required bool fourColor}) {
    if (!fourColor) {
      return suit.isRed
          ? const Color(0xFFB21E24) // Warm Vintage Crimson
          : const Color(0xFF161A20); // Deep Ink Charcoal
    }

    switch (suit) {
      case Suit.spades:
        return const Color(0xFF161A20); // Deep Ink Charcoal
      case Suit.hearts:
        return const Color(0xFFB21E24); // Warm Vintage Crimson
      case Suit.diamonds:
        return const Color(0xFF1B56B8); // Rich Heritage Blue
      case Suit.clubs:
        return const Color(0xFF146E3A); // Deep Parlor Green
    }
  }
}
