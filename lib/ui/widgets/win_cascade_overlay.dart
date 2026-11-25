import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../engine/card.dart';
import '../../theme/app_theme.dart';
import '../../theme/deck_palette.dart';

class _FlyingWinCard {
  _FlyingWinCard({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.suit,
    required this.rank,
  });

  double x;
  double y;
  double vx;
  double vy;
  final Suit suit;
  final int rank;
}

class _TrailStamp {
  const _TrailStamp({
    required this.x,
    required this.y,
    required this.suit,
    required this.rank,
  });

  final double x;
  final double y;
  final Suit suit;
  final int rank;
}

/// Iconic Windows-Solitaire-inspired bouncing card waterfall displayed over the
/// felt table when a hand is won.
class WinCascadeOverlay extends StatefulWidget {
  const WinCascadeOverlay({
    super.key,
    required this.cardWidth,
    required this.cardHeight,
    required this.theme,
    required this.fourColorDeck,
    required this.leftHanded,
    this.deckFaceStyle = DeckFaceStyle.americanHeritage,
    this.colGap = 4.0,
    this.boardWidth,
    this.topOffset = 12.0,
    this.foundations,
    this.onFoundationRemainingChanged,
  });

  final double cardWidth;
  final double cardHeight;
  final ClearDeckTheme theme;
  final bool fourColorDeck;
  final bool leftHanded;
  final DeckFaceStyle deckFaceStyle;
  final double colGap;
  final double? boardWidth;
  final double topOffset;
  final List<List<PlayingCard>>? foundations;
  final ValueChanged<List<int>>? onFoundationRemainingChanged;

  @override
  State<WinCascadeOverlay> createState() => _WinCascadeOverlayState();
}

class _WinCascadeOverlayState extends State<WinCascadeOverlay>
    with SingleTickerProviderStateMixin {
  static const int _maxStamps = 135;

  late final Ticker _ticker;
  final math.Random _rng = math.Random(1995);
  final List<_TrailStamp> _stamps = <_TrailStamp>[];
  final Map<int, TextPainter> _labelCache = <int, TextPainter>{};

  double? _cachedCardWidth;
  bool? _cachedFourColor;
  TableThemeId? _cachedThemeId;

  _FlyingWinCard? _activeCard;
  Duration _lastElapsed = Duration.zero;
  double _spawnCooldown = 0.15;
  late final List<List<PlayingCard>> _remainingPiles;
  int _nextFoundationIdx = 0;
  bool _cascadeComplete = false;
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _remainingPiles = _copyInitialFoundations();
    _syncLabelCache();
    _ticker = createTicker(_onTick)..start();
  }

  List<List<PlayingCard>> _copyInitialFoundations() {
    final source = widget.foundations;
    if (source != null) {
      return List<List<PlayingCard>>.generate(
        4,
        (i) => i < source.length
            ? List<PlayingCard>.from(source[i])
            : <PlayingCard>[],
      );
    }
    return List<List<PlayingCard>>.generate(
      4,
      (i) => List<PlayingCard>.generate(
        13,
        (r) => PlayingCard(suit: Suit.values[i % 4], rank: r + 1, isFaceUp: true),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant WinCascadeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLabelCache();
  }

  void _clearLabelCache() {
    for (final tp in _labelCache.values) {
      tp.dispose();
    }
    _labelCache.clear();
  }

  void _syncLabelCache() {
    if (_cachedCardWidth == widget.cardWidth &&
        _cachedFourColor == widget.fourColorDeck &&
        _cachedThemeId == widget.theme.id &&
        _labelCache.isNotEmpty) {
      return;
    }

    _clearLabelCache();
    _cachedCardWidth = widget.cardWidth;
    _cachedFourColor = widget.fourColorDeck;
    _cachedThemeId = widget.theme.id;

    final fontSize = (widget.cardWidth * 0.36).clamp(14.0, 30.0);
    final maxW = (widget.cardWidth - 4).clamp(8.0, 200.0);

    for (final suit in Suit.values) {
      final color = DeckPalette.suitColor(
        suit,
        fourColor: widget.fourColorDeck,
      );
      for (var rank = 1; rank <= 13; rank++) {
        final rankLabel = switch (rank) {
          1 => 'A',
          11 => 'J',
          12 => 'Q',
          13 => 'K',
          _ => '$rank',
        };
        final tp = TextPainter(
          text: TextSpan(
            text: rankLabel,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 0.96,
              letterSpacing: rank == 10 ? -1.2 : -0.2,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxW);
        _labelCache[suit.index * 16 + rank] = tp;
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clearLabelCache();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _viewportSize.isEmpty) return;
    final dtRaw = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    final dt = dtRaw.clamp(0.0, 0.05);

    if (_activeCard == null) {
      if (_cascadeComplete) {
        _ticker.stop();
        return;
      }
      _spawnCooldown -= dt;
      if (_spawnCooldown <= 0) {
        _spawnNextCard();
      }
    } else {
      final card = _activeCard!;
      const gravity = 1480.0;
      card.vy += gravity * dt;
      card.x += card.vx * dt;
      card.y += card.vy * dt;

      final floorY = _viewportSize.height - widget.cardHeight - 6;
      if (card.y >= floorY) {
        card.y = floorY;
        card.vy = -card.vy.abs() * 0.78;
        if (card.vy.abs() < 140) {
          card.vy = -280;
        }
      }

      _stamps.add(
        _TrailStamp(
          x: card.x,
          y: card.y,
          suit: card.suit,
          rank: card.rank,
        ),
      );
      if (_stamps.length > _maxStamps) {
        _stamps.removeAt(0);
      }

      if (card.x < -widget.cardWidth - 20 ||
          card.x > _viewportSize.width + 20) {
        _activeCard = null;
        _spawnCooldown = 0.06;
      }
    }

    setState(() {});
  }

  void _spawnNextCard() {
    int? slotIdx;
    for (var offset = 0; offset < 4; offset++) {
      final candidate = (_nextFoundationIdx + offset) % 4;
      if (_remainingPiles[candidate].isNotEmpty) {
        slotIdx = candidate;
        break;
      }
    }
    if (slotIdx == null) {
      _cascadeComplete = true;
      return;
    }

    final popped = _remainingPiles[slotIdx].removeLast();
    _nextFoundationIdx = (slotIdx + 1) % 4;

    final effectiveWidth =
        widget.boardWidth ?? (widget.cardWidth * 7 + widget.colGap * 6);
    final boardLeft = (_viewportSize.width - effectiveWidth) * 0.5;
    final foundationSlot = widget.leftHanded ? slotIdx : (3 + slotIdx);
    final maxStartX =
        math.max(8.0, _viewportSize.width - widget.cardWidth - 8.0);
    final startX =
        (boardLeft + foundationSlot * (widget.cardWidth + widget.colGap))
            .clamp(8.0, maxStartX);
    final startY = widget.topOffset;

    final dir = _rng.nextBool() ? 1.0 : -1.0;
    final speedX = (140.0 + _rng.nextDouble() * 190.0) * dir;
    final speedY = -60.0 - _rng.nextDouble() * 160.0;

    _activeCard = _FlyingWinCard(
      x: startX,
      y: startY,
      vx: speedX,
      vy: speedY,
      suit: popped.suit,
      rank: popped.rank,
    );

    widget.onFoundationRemainingChanged?.call(
      _remainingPiles.map((p) => p.length).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncLabelCache();
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        return IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              willChange: true,
              size: _viewportSize,
              painter: _WinCascadePainter(
                stamps: _stamps,
                activeCard: _activeCard,
                cardWidth: widget.cardWidth,
                cardHeight: widget.cardHeight,
                theme: widget.theme,
                fourColorDeck: widget.fourColorDeck,
                deckFaceStyle: widget.deckFaceStyle,
                labelCache: _labelCache,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WinCascadePainter extends CustomPainter {
  _WinCascadePainter({
    required this.stamps,
    required this.activeCard,
    required this.cardWidth,
    required this.cardHeight,
    required this.theme,
    required this.fourColorDeck,
    required this.deckFaceStyle,
    required this.labelCache,
  })  : _fillPaint = Paint()..color = theme.cardFace,
        _borderPaint = Paint()
          ..color = theme.cardBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
        _cornerRadius = Radius.circular((cardWidth * 0.11).clamp(6.0, 12.0)),
        _suitSize = (cardWidth * 0.27).clamp(10.0, 22.0),
        _suitPaints = List<Paint>.unmodifiable(
          Suit.values.map(
            (suit) => Paint()
              ..color = DeckPalette.suitColor(suit, fourColor: fourColorDeck)
              ..style = PaintingStyle.fill
              ..isAntiAlias = true,
          ),
        ),
        _heartPath = _buildHeartPath((cardWidth * 0.27).clamp(10.0, 22.0)),
        _diamondPath = _buildDiamondPath(
          (cardWidth * 0.27).clamp(10.0, 22.0),
          deckFaceStyle,
        ),
        _spadeBodyPath = _buildSpadeBodyPath((cardWidth * 0.27).clamp(10.0, 22.0)),
        _spadeStemPath = _buildSpadeStemPath((cardWidth * 0.27).clamp(10.0, 22.0)),
        _clubStemPath = _buildClubStemPath((cardWidth * 0.27).clamp(10.0, 22.0));

  final List<_TrailStamp> stamps;
  final _FlyingWinCard? activeCard;
  final double cardWidth;
  final double cardHeight;
  final ClearDeckTheme theme;
  final bool fourColorDeck;
  final DeckFaceStyle deckFaceStyle;
  final Map<int, TextPainter> labelCache;

  final Paint _fillPaint;
  final Paint _borderPaint;
  final Radius _cornerRadius;
  final double _suitSize;
  final List<Paint> _suitPaints;
  final Path _heartPath;
  final Path _diamondPath;
  final Path _spadeBodyPath;
  final Path _spadeStemPath;
  final Path _clubStemPath;

  static Path _buildHeartPath(double s) {
    return Path()
      ..moveTo(s * 0.5, s * 0.92)
      ..cubicTo(s * 0.08, s * 0.64, s * 0.02, s * 0.34, s * 0.24, s * 0.16)
      ..cubicTo(s * 0.38, s * 0.05, s * 0.50, s * 0.18, s * 0.50, s * 0.28)
      ..cubicTo(s * 0.50, s * 0.18, s * 0.62, s * 0.05, s * 0.76, s * 0.16)
      ..cubicTo(s * 0.98, s * 0.34, s * 0.92, s * 0.64, s * 0.5, s * 0.92)
      ..close();
  }

  static Path _buildDiamondPath(double s, DeckFaceStyle style) {
    if (style == DeckFaceStyle.artDecoParlor) {
      return Path()
        ..moveTo(s * 0.5, s * 0.05)
        ..lineTo(s * 0.91, s * 0.50)
        ..lineTo(s * 0.50, s * 0.95)
        ..lineTo(s * 0.09, s * 0.50)
        ..close();
    }
    return Path()
      ..moveTo(s * 0.5, s * 0.06)
      ..quadraticBezierTo(s * 0.62, s * 0.34, s * 0.90, s * 0.50)
      ..quadraticBezierTo(s * 0.62, s * 0.66, s * 0.50, s * 0.94)
      ..quadraticBezierTo(s * 0.38, s * 0.66, s * 0.10, s * 0.50)
      ..quadraticBezierTo(s * 0.38, s * 0.34, s * 0.50, s * 0.06)
      ..close();
  }

  static Path _buildSpadeBodyPath(double s) {
    return Path()
      ..moveTo(s * 0.5, s * 0.06)
      ..cubicTo(s * 0.94, s * 0.42, s * 0.96, s * 0.68, s * 0.72, s * 0.75)
      ..cubicTo(s * 0.58, s * 0.79, s * 0.52, s * 0.68, s * 0.50, s * 0.62)
      ..cubicTo(s * 0.48, s * 0.68, s * 0.42, s * 0.79, s * 0.28, s * 0.75)
      ..cubicTo(s * 0.04, s * 0.68, s * 0.06, s * 0.42, s * 0.50, s * 0.06)
      ..close();
  }

  static Path _buildSpadeStemPath(double s) {
    return Path()
      ..moveTo(s * 0.50, s * 0.55)
      ..quadraticBezierTo(s * 0.48, s * 0.80, s * 0.33, s * 0.92)
      ..lineTo(s * 0.67, s * 0.92)
      ..quadraticBezierTo(s * 0.52, s * 0.80, s * 0.50, s * 0.55)
      ..close();
  }

  static Path _buildClubStemPath(double s) {
    return Path()
      ..moveTo(s * 0.50, s * 0.48)
      ..quadraticBezierTo(s * 0.48, s * 0.78, s * 0.33, s * 0.92)
      ..lineTo(s * 0.67, s * 0.92)
      ..quadraticBezierTo(s * 0.52, s * 0.78, s * 0.50, s * 0.48)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stamps) {
      _drawStampCard(canvas, s.x, s.y, s.suit, s.rank);
    }
    if (activeCard != null) {
      _drawStampCard(
        canvas,
        activeCard!.x,
        activeCard!.y,
        activeCard!.suit,
        activeCard!.rank,
      );
    }
  }

  void _drawStampCard(
    Canvas canvas,
    double x,
    double y,
    Suit suit,
    int rank,
  ) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, cardWidth, cardHeight),
      _cornerRadius,
    );

    canvas.drawRRect(rrect, _fillPaint);
    canvas.drawRRect(rrect, _borderPaint);

    final leftPad = (cardWidth * 0.085).clamp(4.0, 7.0);
    final topPad = (cardHeight * 0.035).clamp(3.0, 6.0);
    final tp = labelCache[suit.index * 16 + rank];
    if (tp != null) {
      tp.paint(canvas, Offset(x + leftPad, y + topPad));
      final gap = (cardWidth * 0.04).clamp(1.5, 4.0);
      final suitX = x + leftPad + tp.width + gap;
      final suitY = y + topPad + (tp.height - _suitSize) * 0.5;
      _drawSuitShape(canvas, suit, suitX, suitY);
    }
  }

  void _drawSuitShape(Canvas canvas, Suit suit, double x, double y) {
    final paint = _suitPaints[suit.index];
    canvas.save();
    canvas.translate(x, y);
    switch (suit) {
      case Suit.hearts:
        canvas.drawPath(_heartPath, paint);
      case Suit.diamonds:
        canvas.drawPath(_diamondPath, paint);
      case Suit.spades:
        canvas.drawPath(_spadeBodyPath, paint);
        canvas.drawPath(_spadeStemPath, paint);
      case Suit.clubs:
        final s = _suitSize;
        final r = s * 0.21;
        canvas.drawCircle(Offset(s * 0.50, s * 0.28), r, paint);
        canvas.drawCircle(Offset(s * 0.29, s * 0.55), r, paint);
        canvas.drawCircle(Offset(s * 0.71, s * 0.55), r, paint);
        canvas.drawCircle(Offset(s * 0.50, s * 0.49), r * 0.65, paint);
        canvas.drawPath(_clubStemPath, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WinCascadePainter oldDelegate) =>
      oldDelegate.fourColorDeck != fourColorDeck ||
      oldDelegate.deckFaceStyle != deckFaceStyle ||
      oldDelegate.theme.id != theme.id ||
      oldDelegate.cardWidth != cardWidth ||
      oldDelegate.cardHeight != cardHeight ||
      stamps.isNotEmpty ||
      activeCard != null;
}
