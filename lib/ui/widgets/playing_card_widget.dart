import 'package:material_ui/material_ui.dart';

import '../../engine/card.dart';
import '../../engine/move.dart';
import '../../theme/app_theme.dart';
import '../../theme/deck_palette.dart';
import 'card_back_painter.dart';
import 'suit_painter.dart';

/// Drag payload attached to draggable single cards or multi-card tableau runs.
class CardDragPayload {
  const CardDragPayload({
    required this.sourceKind,
    required this.fromPileIndex,
    required this.cards,
  });

  final MoveKind sourceKind;
  final int fromPileIndex;
  final List<PlayingCard> cards;
}

/// Cascade-safe, high-contrast playing card widget styled after classic
/// American Heritage parlor decks.
class PlayingCardWidget extends StatelessWidget {
  const PlayingCardWidget({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    required this.theme,
    required this.fourColorDeck,
    required this.cardScale,
    this.deckFaceStyle = DeckFaceStyle.americanHeritage,
    this.cardBackStyle = CardBackStyle.crimsonLattice,
    this.isHighlighted = false,
    this.isElevated = false,
  });

  final PlayingCard card;
  final double width;
  final double height;
  final ClearDeckTheme theme;
  final bool fourColorDeck;
  final CardScale cardScale;
  final DeckFaceStyle deckFaceStyle;
  final CardBackStyle cardBackStyle;
  final bool isHighlighted;
  final bool isElevated;

  @override
  Widget build(BuildContext context) {
    if (!card.isFaceUp) {
      return CardBackPatternWidget(
        style: cardBackStyle,
        width: width,
        height: height,
        highlightColor: isHighlighted ? theme.hintHighlight : null,
        paperColor: theme.cardFace,
        borderColor: theme.cardBorder,
      );
    }

    final radius = (width * 0.11).clamp(6.0, 12.0);
    final suitColor = DeckPalette.suitColor(
      card.suit,
      fourColor: fourColorDeck,
    );
    final isJumbo = cardScale == CardScale.jumbo;
    final rankFontSize = (width * (isJumbo ? 0.49 : 0.43))
        .clamp(16.0, isJumbo ? 48.0 : 42.0);
    final cornerSuitSize = (width * (isJumbo ? 0.35 : 0.31))
        .clamp(12.0, isJumbo ? 32.0 : 28.0);
    final horizontalPad = (width * 0.065).clamp(2.5, 7.0);
    final specularColor = theme.id == TableThemeId.midnightMahogany
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.72);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[theme.cardFaceTop, theme.cardFaceBottom],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: theme.cardBorder, width: 1.0),
              boxShadow: <BoxShadow>[
                if (isElevated)
                  const BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: Offset(0, 7),
                  )
                else
                  const BoxShadow(
                    color: Color(0x2E000000),
                    blurRadius: 3.0,
                    offset: Offset(0, 1.5),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                (radius - 1.0).clamp(4.0, 11.0),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: specularColor, width: 1.0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Top index band remains visible even in deep stacked cascades.
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        (height * 0.024).clamp(1.5, 4.0),
                        horizontalPad,
                        0,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth:
                                (width - horizontalPad * 2 - 1.0).clamp(
                              18.0,
                              200.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  textScaler: TextScaler.noScaling,
                                ),
                                child: Text(
                                  card.rankLabel,
                                  style: TextStyle(
                                    color: suitColor,
                                    fontSize: rankFontSize,
                                    fontWeight: FontWeight.w800,
                                    height: 0.96,
                                    letterSpacing:
                                        card.rank == 10 ? -1.4 : -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 1),
                              SuitIcon(
                                suit: card.suit,
                                size: cornerSuitSize,
                                color: suitColor,
                                deckFaceStyle: deckFaceStyle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: card.rank >= 11
                            ? EdgeInsets.fromLTRB(
                                (width * 0.045).clamp(2.0, 5.0),
                                (height * 0.014).clamp(1.0, 3.0),
                                (width * 0.045).clamp(2.0, 5.0),
                                (height * 0.032).clamp(2.0, 5.0),
                              )
                            : EdgeInsets.fromLTRB(
                                (width * 0.07).clamp(2.5, 7.0),
                                (height * 0.015).clamp(1.0, 3.0),
                                (width * 0.07).clamp(2.5, 7.0),
                                (height * 0.04).clamp(2.0, 6.0),
                              ),
                        child: _buildCardCenterArtwork(suitColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isHighlighted)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: theme.hintHighlight,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardCenterArtwork(Color suitColor) {
    final isArtDeco = deckFaceStyle == DeckFaceStyle.artDecoParlor;
    final frameRadius = isArtDeco
        ? 2.0
        : (width * 0.06).clamp(4.0, 8.0);
    final goldTint = theme.goldTrim;
    final outerBorderColor = switch (deckFaceStyle) {
      DeckFaceStyle.botanicalGarden => const Color(0xFF3E6B52).withValues(alpha: 0.45),
      DeckFaceStyle.artDecoParlor => goldTint.withValues(alpha: 0.84),
      DeckFaceStyle.maritimeClub => const Color(0xFF1E446B).withValues(alpha: 0.45),
      _ => goldTint.withValues(alpha: 0.62),
    };

    if (card.rank >= 11) {
      // Court cards (J, Q, K): Single refined parlor frame maximizing bust visibility
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(frameRadius),
          border: Border.all(
            color: outerBorderColor,
            width: isArtDeco ? 1.3 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular((frameRadius - 1.0).clamp(1.5, 7.0)),
          child: CourtCrestWidget(
            rank: card.rank,
            suit: card.suit,
            suitColor: suitColor,
            goldColor: goldTint,
            deckFaceStyle: deckFaceStyle,
            cardFaceColor: theme.cardFace,
          ),
        ),
      );
    }

    if (card.rank == 1) {
      // Ace: Framed aperture + large high-contrast centerpiece suit pip
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(frameRadius),
          border: Border.all(
            color: outerBorderColor,
            width: isArtDeco ? 1.3 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Center(
          child: LayoutBuilder(
            builder: (context, c) {
              final s =
                  (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight) * 0.80;
              return SuitIcon(
                suit: card.suit,
                size: s.clamp(16.0, 66.0),
                color: suitColor,
                deckFaceStyle: deckFaceStyle,
              );
            },
          ),
        ),
      );
    }

    // Number cards (2–10): large bold suit pip centered cleanly on cardstock
    final isJumbo = cardScale == CardScale.jumbo;
    return Center(
      child: LayoutBuilder(
        builder: (context, c) {
          final s = (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight) *
              (isJumbo ? 0.84 : 0.78);
          return SuitIcon(
            suit: card.suit,
            size: s.clamp(16.0, 66.0),
            color: suitColor,
            deckFaceStyle: deckFaceStyle,
          );
        },
      ),
    );
  }
}

/// Clean sunken felt slot for empty Stock, Foundations, and Tableau columns.
class EmptyPileSlot extends StatelessWidget {
  const EmptyPileSlot({
    super.key,
    required this.width,
    required this.height,
    required this.theme,
    this.label,
    this.icon,
    this.isHighlighted = false,
    this.isFoundation = false,
  });

  final double width;
  final double height;
  final ClearDeckTheme theme;
  final String? label;
  final IconData? icon;
  final bool isHighlighted;
  final bool isFoundation;

  @override
  Widget build(BuildContext context) {
    final radius = (width * 0.11).clamp(6.0, 12.0);
    final borderColor =
        isHighlighted ? theme.hintHighlight : theme.slotBorder;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.slotFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor,
          width: isHighlighted ? 2.5 : 1.0,
        ),
      ),
      child: Center(
        child: icon != null
            ? Icon(
                icon,
                size: (width * 0.40).clamp(18.0, 30.0),
                color: theme.mutedOnTable.withValues(alpha: 0.72),
              )
            : Text(
                label ?? '',
                style: TextStyle(
                  color: isFoundation
                      ? theme.goldTrim.withValues(alpha: 0.55)
                      : theme.mutedOnTable.withValues(alpha: 0.42),
                  fontFamily: 'Georgia',
                  fontFamilyFallback: const <String>[
                    'Times New Roman',
                    'Noto Serif',
                    'serif',
                  ],
                  fontSize: (width * 0.34).clamp(14.0, 26.0),
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

/// Renders physical cardstock edge slices beneath a stacked pile's top card
/// so Stock, Waste, and Foundation piles communicate remaining card depth.
class DeckDepthStack extends StatelessWidget {
  const DeckDepthStack({
    super.key,
    required this.cardCount,
    required this.width,
    required this.height,
    required this.theme,
    required this.topCard,
    this.keyPrefix,
  });

  final int cardCount;
  final double width;
  final double height;
  final ClearDeckTheme theme;
  final Widget topCard;
  final String? keyPrefix;

  /// Returns how many physical cardstock edge slices to show for [count] cards.
  static int visibleLayersForCount(int count) {
    if (count <= 1) return 0;
    if (count <= 5) return 1;
    if (count <= 13) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final layers = visibleLayersForCount(cardCount);
    if (layers == 0) {
      return SizedBox(width: width, height: height, child: topCard);
    }

    final radius = (width * 0.11).clamp(6.0, 12.0);
    final edgeLayers = <Widget>[
      for (var i = 0; i < layers; i++)
        _buildEdgeSlice(
          index: i,
          depthStep: layers - i,
          radius: radius,
        ),
    ];

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          ...edgeLayers,
          Positioned.fill(child: topCard),
        ],
      ),
    );
  }

  Widget _buildEdgeSlice({
    required int index,
    required int depthStep,
    required double radius,
  }) {
    // Sub-gap offset (max 2.1px right, 5.4px down) avoids adjacent pile collisions.
    return Positioned(
      left: depthStep * 0.7,
      top: depthStep * 1.8,
      child: Container(
        key: keyPrefix != null ? Key('${keyPrefix}_depth_$index') : null,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Color.lerp(
            theme.cardFaceBottom,
            theme.cardBorder,
            0.22 + 0.14 * depthStep,
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: theme.cardBorder, width: 0.9),
        ),
      ),
    );
  }
}
