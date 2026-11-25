import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../engine/card.dart';
import '../../theme/deck_palette.dart';

/// Sculpted custom Bezier playing-card suit icon supporting distinct parlor
/// silhouettes per [DeckFaceStyle] (zero OS font or emoji inconsistency).
class SuitIcon extends StatelessWidget {
  const SuitIcon({
    super.key,
    required this.suit,
    required this.size,
    required this.color,
    this.deckFaceStyle = DeckFaceStyle.americanHeritage,
  });

  final Suit suit;
  final double size;
  final Color color;
  final DeckFaceStyle deckFaceStyle;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SuitPainter(
        suit: suit,
        color: color,
        deckFaceStyle: deckFaceStyle,
      ),
    );
  }
}

class _SuitPainter extends CustomPainter {
  const _SuitPainter({
    required this.suit,
    required this.color,
    required this.deckFaceStyle,
  });

  final Suit suit;
  final Color color;
  final DeckFaceStyle deckFaceStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    switch (suit) {
      case Suit.hearts:
        _drawHeart(canvas, w, h, paint);
      case Suit.diamonds:
        _drawDiamond(canvas, w, h, paint);
      case Suit.spades:
        _drawSpade(canvas, w, h, paint);
      case Suit.clubs:
        _drawClub(canvas, w, h, paint);
    }
  }

  void _drawHeart(Canvas canvas, double w, double h, Paint paint) {
    if (deckFaceStyle == DeckFaceStyle.artDecoParlor) {
      // Sculpted geometric 1920s Art Deco heart
      final path = Path()
        ..moveTo(w * 0.5, h * 0.92)
        ..lineTo(w * 0.08, h * 0.42)
        ..quadraticBezierTo(w * 0.08, h * 0.14, w * 0.30, h * 0.14)
        ..lineTo(w * 0.50, h * 0.30)
        ..lineTo(w * 0.70, h * 0.14)
        ..quadraticBezierTo(w * 0.92, h * 0.14, w * 0.92, h * 0.42)
        ..close();
      canvas.drawPath(path, paint);
      return;
    }

    if (deckFaceStyle == DeckFaceStyle.botanicalGarden) {
      // Soft floral petal-cleft heart
      final path = Path()
        ..moveTo(w * 0.5, h * 0.93)
        ..cubicTo(w * 0.10, h * 0.68, w * 0.04, h * 0.30, w * 0.25, h * 0.14)
        ..cubicTo(w * 0.40, h * 0.04, w * 0.50, h * 0.21, w * 0.50, h * 0.32)
        ..cubicTo(w * 0.50, h * 0.21, w * 0.60, h * 0.04, w * 0.75, h * 0.14)
        ..cubicTo(w * 0.96, h * 0.30, w * 0.90, h * 0.68, w * 0.5, h * 0.93)
        ..close();
      canvas.drawPath(path, paint);
      return;
    }

    if (deckFaceStyle == DeckFaceStyle.royalEmblem) {
      // Full high-contrast bold silhouette
      final path = Path()
        ..moveTo(w * 0.5, h * 0.94)
        ..cubicTo(w * 0.05, h * 0.66, w * 0.01, h * 0.32, w * 0.24, h * 0.13)
        ..cubicTo(w * 0.39, h * 0.02, w * 0.50, h * 0.16, w * 0.50, h * 0.27)
        ..cubicTo(w * 0.50, h * 0.16, w * 0.61, h * 0.02, w * 0.76, h * 0.13)
        ..cubicTo(w * 0.99, h * 0.32, w * 0.95, h * 0.66, w * 0.5, h * 0.94)
        ..close();
      canvas.drawPath(path, paint);
      return;
    }

    // Heritage & Maritime classic balanced curves
    final shoulder = deckFaceStyle == DeckFaceStyle.maritimeClub ? 0.14 : 0.16;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.92)
      ..cubicTo(w * 0.08, h * 0.64, w * 0.02, h * 0.34, w * 0.24, h * shoulder)
      ..cubicTo(w * 0.38, h * 0.05, w * 0.50, h * 0.18, w * 0.50, h * 0.28)
      ..cubicTo(w * 0.50, h * 0.18, w * 0.62, h * 0.05, w * 0.76, h * shoulder)
      ..cubicTo(w * 0.98, h * 0.34, w * 0.92, h * 0.64, w * 0.5, h * 0.92)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, double w, double h, Paint paint) {
    if (deckFaceStyle == DeckFaceStyle.artDecoParlor) {
      // Crisp straight-faceted 1925 Art Deco lozenge
      final path = Path()
        ..moveTo(w * 0.50, h * 0.05)
        ..lineTo(w * 0.91, h * 0.50)
        ..lineTo(w * 0.50, h * 0.95)
        ..lineTo(w * 0.09, h * 0.50)
        ..close();
      canvas.drawPath(path, paint);
      return;
    }

    if (deckFaceStyle == DeckFaceStyle.botanicalGarden) {
      // Slender deeply pinched petal-lozenge
      final path = Path()
        ..moveTo(w * 0.50, h * 0.05)
        ..quadraticBezierTo(w * 0.58, h * 0.36, w * 0.87, h * 0.50)
        ..quadraticBezierTo(w * 0.58, h * 0.64, w * 0.50, h * 0.95)
        ..quadraticBezierTo(w * 0.42, h * 0.64, w * 0.13, h * 0.50)
        ..quadraticBezierTo(w * 0.42, h * 0.36, w * 0.50, h * 0.05)
        ..close();
      canvas.drawPath(path, paint);
      return;
    }

    if (deckFaceStyle == DeckFaceStyle.maritimeClub) {
      // Crisp 4-point compass rose diamond
      final path = Path()
        ..moveTo(w * 0.50, h * 0.04)
        ..lineTo(w * 0.62, h * 0.38)
        ..lineTo(w * 0.93, h * 0.50)
        ..lineTo(w * 0.62, h * 0.62)
        ..lineTo(w * 0.50, h * 0.96)
        ..lineTo(w * 0.38, h * 0.62)
        ..lineTo(w * 0.07, h * 0.50)
        ..lineTo(w * 0.38, h * 0.38)
        ..close();
      canvas.drawPath(path, paint);
      return;
    }

    // Classic concave Bicycle-style diamond (with fuller curves on Royal Emblem)
    final pinch = deckFaceStyle == DeckFaceStyle.royalEmblem ? 0.34 : 0.38;
    final outerX = deckFaceStyle == DeckFaceStyle.royalEmblem ? 0.93 : 0.90;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..quadraticBezierTo(w * (1.0 - pinch), h * 0.34, w * outerX, h * 0.50)
      ..quadraticBezierTo(w * (1.0 - pinch), h * 0.66, w * 0.50, h * 0.94)
      ..quadraticBezierTo(w * pinch, h * 0.66, w * (1.0 - outerX), h * 0.50)
      ..quadraticBezierTo(w * pinch, h * 0.34, w * 0.50, h * 0.06)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawSpade(Canvas canvas, double w, double h, Paint paint) {
    if (deckFaceStyle == DeckFaceStyle.artDecoParlor) {
      // Geometric spearhead spade with stepped Deco base
      final body = Path()
        ..moveTo(w * 0.50, h * 0.05)
        ..lineTo(w * 0.90, h * 0.46)
        ..quadraticBezierTo(w * 0.90, h * 0.74, w * 0.68, h * 0.74)
        ..lineTo(w * 0.50, h * 0.60)
        ..lineTo(w * 0.32, h * 0.74)
        ..quadraticBezierTo(w * 0.10, h * 0.74, w * 0.10, h * 0.46)
        ..close();
      canvas.drawPath(body, paint);

      final stem = Path()
        ..moveTo(w * 0.43, h * 0.60)
        ..lineTo(w * 0.57, h * 0.60)
        ..lineTo(w * 0.68, h * 0.93)
        ..lineTo(w * 0.32, h * 0.93)
        ..close();
      canvas.drawPath(stem, paint);
      return;
    }

    final baseWidth = deckFaceStyle == DeckFaceStyle.maritimeClub ? 0.38 : 0.33;
    final tipHeight = deckFaceStyle == DeckFaceStyle.botanicalGarden ? 0.05 : 0.06;
    final body = Path()
      ..moveTo(w * 0.5, h * tipHeight)
      ..cubicTo(w * 0.94, h * 0.42, w * 0.96, h * 0.68, w * 0.72, h * 0.75)
      ..cubicTo(w * 0.58, h * 0.79, w * 0.52, h * 0.68, w * 0.50, h * 0.62)
      ..cubicTo(w * 0.48, h * 0.68, w * 0.42, h * 0.79, w * 0.28, h * 0.75)
      ..cubicTo(w * 0.04, h * 0.68, w * 0.06, h * 0.42, w * 0.50, h * tipHeight)
      ..close();
    canvas.drawPath(body, paint);

    final stem = Path()
      ..moveTo(w * 0.50, h * 0.55)
      ..quadraticBezierTo(w * 0.48, h * 0.80, w * baseWidth, h * 0.92)
      ..lineTo(w * (1.0 - baseWidth), h * 0.92)
      ..quadraticBezierTo(w * 0.52, h * 0.80, w * 0.50, h * 0.55)
      ..close();
    canvas.drawPath(stem, paint);
  }

  void _drawClub(Canvas canvas, double w, double h, Paint paint) {
    final r = switch (deckFaceStyle) {
      DeckFaceStyle.royalEmblem || DeckFaceStyle.maritimeClub => w * 0.225,
      DeckFaceStyle.botanicalGarden => w * 0.20,
      _ => w * 0.21,
    };
    canvas.drawCircle(Offset(w * 0.50, h * 0.28), r, paint);
    canvas.drawCircle(Offset(w * 0.29, h * 0.55), r, paint);
    canvas.drawCircle(Offset(w * 0.71, h * 0.55), r, paint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.49), r * 0.65, paint);

    if (deckFaceStyle == DeckFaceStyle.artDecoParlor) {
      final stem = Path()
        ..moveTo(w * 0.44, h * 0.50)
        ..lineTo(w * 0.56, h * 0.50)
        ..lineTo(w * 0.68, h * 0.93)
        ..lineTo(w * 0.32, h * 0.93)
        ..close();
      canvas.drawPath(stem, paint);
      return;
    }

    final stem = Path()
      ..moveTo(w * 0.50, h * 0.48)
      ..quadraticBezierTo(w * 0.48, h * 0.78, w * 0.33, h * 0.92)
      ..lineTo(w * 0.67, h * 0.92)
      ..quadraticBezierTo(w * 0.52, h * 0.78, w * 0.50, h * 0.48)
      ..close();
    canvas.drawPath(stem, paint);
  }

  @override
  bool shouldRepaint(_SuitPainter oldDelegate) =>
      oldDelegate.suit != suit ||
      oldDelegate.color != color ||
      oldDelegate.deckFaceStyle != deckFaceStyle;
}

/// Vintage court portraits for Jack, Queen, and King cards matching the
/// active [DeckFaceStyle], paper-blended with `theme.cardFace` and retaining
/// crisp heraldic vector engraving for [DeckFaceStyle.royalEmblem] or fallback.
class CourtCrestWidget extends StatelessWidget {
  const CourtCrestWidget({
    super.key,
    required this.rank,
    required this.suit,
    required this.suitColor,
    required this.goldColor,
    this.deckFaceStyle = DeckFaceStyle.americanHeritage,
    this.cardFaceColor = const Color(0xFFFAF6EC),
  });

  final int rank;
  final Suit suit;
  final Color suitColor;
  final Color goldColor;
  final DeckFaceStyle deckFaceStyle;
  final Color cardFaceColor;

  /// Returns the bundled raster court asset path for [style] and [rank],
  /// or `null` when the vector heraldic emblem should render directly.
  static String? assetPathFor(DeckFaceStyle style, int rank) {
    final role = switch (rank) {
      11 => 'jack',
      12 => 'queen',
      _ => 'king',
    };
    switch (style) {
      case DeckFaceStyle.americanHeritage:
        return 'assets/images/court_$role.png';
      case DeckFaceStyle.botanicalGarden:
        return 'assets/images/court_botanical_$role.png';
      case DeckFaceStyle.artDecoParlor:
        return 'assets/images/court_artdeco_$role.png';
      case DeckFaceStyle.maritimeClub:
        return 'assets/images/court_maritime_$role.png';
      case DeckFaceStyle.royalEmblem:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = assetPathFor(deckFaceStyle, rank);
    if (assetPath == null) {
      return _buildVectorCrest();
    }

    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      alignment: const Alignment(0.0, -0.68),
      color: cardFaceColor,
      colorBlendMode: BlendMode.multiply,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => _buildVectorCrest(),
    );
  }

  Widget _buildVectorCrest() {
    return CustomPaint(
      painter: _CourtCrestPainter(
        rank: rank,
        suitColor: suitColor,
        goldColor: goldColor,
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.54,
          heightFactor: 0.54,
          child: Align(
            alignment: const Alignment(0, 0.24),
            child: LayoutBuilder(
              builder: (context, c) {
                final s = math.min(c.maxWidth, c.maxHeight).clamp(8.0, 34.0);
                return SuitIcon(
                  suit: suit,
                  size: s,
                  color: suitColor,
                  deckFaceStyle: deckFaceStyle,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CourtCrestPainter extends CustomPainter {
  const _CourtCrestPainter({
    required this.rank,
    required this.suitColor,
    required this.goldColor,
  });

  final int rank;
  final Color suitColor;
  final Color goldColor;

  void _drawDiamondPip(Canvas canvas, Offset center, double r, Paint paint) {
    final diamond = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r, center.dy)
      ..close();
    canvas.drawPath(diamond, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final strokeW = (w * 0.026).clamp(0.9, 1.7);

    final brassStroke = Paint()
      ..color = goldColor.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final inkStroke = Paint()
      ..color = suitColor.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (strokeW * 0.8).clamp(0.7, 1.3)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final brassWash = Paint()
      ..color = goldColor.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final suitWash = Paint()
      ..color = suitColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final brassSolid = Paint()
      ..color = goldColor.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cornerPipR = (w * 0.036).clamp(1.2, 2.8);
    final cornerInsetX = w * 0.12;
    final cornerInsetY = h * 0.09;
    final cornerFill = Paint()
      ..color = goldColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final pt in <Offset>[
      Offset(cornerInsetX, cornerInsetY),
      Offset(w - cornerInsetX, cornerInsetY),
      Offset(cornerInsetX, h - cornerInsetY),
      Offset(w - cornerInsetX, h - cornerInsetY),
    ]) {
      _drawDiamondPip(canvas, pt, cornerPipR, cornerFill);
    }

    final pipR = (w * 0.045).clamp(1.5, 3.4);

    if (rank == 13) {
      final crown = Path()
        ..moveTo(cx - w * 0.24, h * 0.30)
        ..lineTo(cx - w * 0.27, h * 0.15)
        ..lineTo(cx - w * 0.12, h * 0.23)
        ..lineTo(cx, h * 0.10)
        ..lineTo(cx + w * 0.12, h * 0.23)
        ..lineTo(cx + w * 0.27, h * 0.15)
        ..lineTo(cx + w * 0.24, h * 0.30)
        ..close();
      canvas.drawPath(crown, brassWash);
      canvas.drawPath(crown, brassStroke);

      final band = Rect.fromCenter(
        center: Offset(cx, h * 0.33),
        width: w * 0.48,
        height: h * 0.055,
      );
      canvas.drawRect(band, suitWash);
      canvas.drawRect(band, inkStroke);
      _drawDiamondPip(canvas, Offset(cx, h * 0.085), pipR * 0.85, brassSolid);
    } else if (rank == 12) {
      final coronet = Path()
        ..moveTo(cx - w * 0.24, h * 0.30)
        ..quadraticBezierTo(cx - w * 0.22, h * 0.17, cx - w * 0.11, h * 0.22)
        ..quadraticBezierTo(cx - w * 0.04, h * 0.11, cx, h * 0.11)
        ..quadraticBezierTo(cx + w * 0.04, h * 0.11, cx + w * 0.11, h * 0.22)
        ..quadraticBezierTo(cx + w * 0.22, h * 0.17, cx + w * 0.24, h * 0.30)
        ..close();
      canvas.drawPath(coronet, suitWash);
      canvas.drawPath(coronet, brassStroke);
      canvas.drawLine(
        Offset(cx - w * 0.22, h * 0.335),
        Offset(cx + w * 0.22, h * 0.335),
        inkStroke,
      );
      _drawDiamondPip(canvas, Offset(cx, h * 0.095), pipR * 0.9, brassSolid);
    } else {
      final shield = Path()
        ..moveTo(cx, h * 0.10)
        ..lineTo(cx + w * 0.18, h * 0.20)
        ..lineTo(cx + w * 0.14, h * 0.31)
        ..lineTo(cx, h * 0.25)
        ..lineTo(cx - w * 0.14, h * 0.31)
        ..lineTo(cx - w * 0.18, h * 0.20)
        ..close();
      canvas.drawPath(shield, suitWash);
      canvas.drawPath(shield, brassStroke);
      _drawDiamondPip(canvas, Offset(cx, h * 0.205), pipR * 0.9, brassSolid);
    }

    final ruleY = h * 0.84;
    canvas.drawLine(
      Offset(cx - w * 0.26, ruleY),
      Offset(cx - w * 0.06, ruleY),
      brassStroke,
    );
    canvas.drawLine(
      Offset(cx + w * 0.06, ruleY),
      Offset(cx + w * 0.26, ruleY),
      brassStroke,
    );
    _drawDiamondPip(canvas, Offset(cx, ruleY), pipR * 0.85, brassSolid);
  }

  @override
  bool shouldRepaint(_CourtCrestPainter oldDelegate) =>
      oldDelegate.rank != rank ||
      oldDelegate.suitColor != suitColor ||
      oldDelegate.goldColor != goldColor;
}
