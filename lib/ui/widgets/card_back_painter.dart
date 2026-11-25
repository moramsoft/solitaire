import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/deck_palette.dart';

/// Parlor-inspired classic card back framed in a crisp paper margin so
/// stacked face-down cards read as physical layered card edges.
class CardBackPatternWidget extends StatelessWidget {
  const CardBackPatternWidget({
    super.key,
    required this.style,
    required this.width,
    required this.height,
    this.highlightColor,
    this.paperColor = const Color(0xFFFAF6EC),
    this.borderColor = const Color(0xFFD2C8B4),
  });

  final CardBackStyle style;
  final double width;
  final double height;
  final Color? highlightColor;
  final Color paperColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = (width * 0.11).clamp(6.0, 12.0);
    final outerMargin = (width * 0.065).clamp(2.5, 5.5);

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
              color: paperColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor, width: 1.0),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 3.0,
                  offset: Offset(0, 1.5),
                ),
              ],
            ),
            padding: EdgeInsets.all(outerMargin),
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  (radius - 1.0 - outerMargin).clamp(3.0, 9.0),
                ),
                child: CustomPaint(
                  isComplex: true,
                  willChange: false,
                  painter: _CardBackPainter(style: style),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          if (highlightColor != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: highlightColor!, width: 2.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  const _CardBackPainter({required this.style});

  final CardBackStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;

    final palette = _paletteFor(style);

    // Rich radial parlor fill
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: <Color>[palette.center, palette.edge],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Subtle style-specific background motif
    switch (style) {
      case CardBackStyle.crimsonLattice:
      case CardBackStyle.royalNavy:
      case CardBackStyle.heritageGold:
        _drawLatticeCrosshatch(canvas, w, h, palette.lattice);
      case CardBackStyle.botanicalFern:
        _drawLatticeCrosshatch(canvas, w, h, palette.lattice);
        _drawBotanicalSprays(canvas, w, h, palette.accent);
      case CardBackStyle.artDecoSunburst:
        _drawArtDecoSunburstRays(canvas, w, h, palette.lattice, palette.accent);
      case CardBackStyle.coastalCompass:
        _drawWaveFiligree(canvas, w, h, palette.lattice);
      case CardBackStyle.plumDamask:
        _drawDamaskOgee(canvas, w, h, palette.lattice, palette.accent);
      case CardBackStyle.sageTrellis:
        _drawLatticeCrosshatch(canvas, w, h, palette.lattice);
        _drawCornerBlossoms(canvas, w, h, palette.frame);
    }

    // Crisp double inner ornamental frame
    final outerInset = (w * 0.08).clamp(3.0, 7.0);
    final innerInset = outerInset + (w * 0.055).clamp(2.0, 5.0);

    final framePaint = Paint()
      ..color = palette.frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.026).clamp(1.0, 2.2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(outerInset, outerInset, w - outerInset, h - outerInset),
        Radius.circular((w * 0.06).clamp(2.0, 6.0)),
      ),
      framePaint,
    );

    final innerFramePaint = Paint()
      ..color = palette.accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.016).clamp(0.7, 1.4);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(innerInset, innerInset, w - innerInset, h - innerInset),
        Radius.circular((w * 0.04).clamp(1.5, 4.5)),
      ),
      innerFramePaint,
    );

    // Centerpiece medallion tailored to the deck back style
    if (style == CardBackStyle.artDecoSunburst) {
      _drawArtDecoDiamondMedallion(canvas, w, cx, cy, palette);
    } else if (style == CardBackStyle.coastalCompass) {
      _drawCompassMedallion(canvas, w, cx, cy, palette);
    } else {
      _drawClassicRosetteMedallion(canvas, w, cx, cy, palette);
    }
  }

  void _drawLatticeCrosshatch(
    Canvas canvas,
    double w,
    double h,
    Color latticeColor,
  ) {
    final latticePaint = Paint()
      ..color = latticeColor.withValues(alpha: latticeColor.a * 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.011).clamp(0.5, 1.0);

    final latticePath = Path();
    final spacing = (w * 0.14).clamp(6.0, 14.0);
    for (var d = -h; d < w + h; d += spacing) {
      latticePath.moveTo(d, 0);
      latticePath.lineTo(d - h, h);
      latticePath.moveTo(d, 0);
      latticePath.lineTo(d + h, h);
    }
    canvas.drawPath(latticePath, latticePaint);
  }

  void _drawArtDecoSunburstRays(
    Canvas canvas,
    double w,
    double h,
    Color latticeColor,
    Color accentColor,
  ) {
    final rayPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.015).clamp(0.6, 1.2);
    final rays = Path();
    const rayCount = 12;
    for (final originY in <double>[0.0, h]) {
      final origin = Offset(w * 0.5, originY);
      final targetY = originY == 0.0 ? h * 0.45 : h * 0.55;
      for (var i = 0; i <= rayCount; i++) {
        final tx = (i / rayCount) * w;
        rays.moveTo(origin.dx, origin.dy);
        rays.lineTo(tx, targetY);
      }
    }
    canvas.drawPath(rays, rayPaint);

    // Stepped Art Deco horizontal accent chevrons
    final chevronPaint = Paint()
      ..color = latticeColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.012).clamp(0.5, 1.0);
    for (final frac in const <double>[0.22, 0.78]) {
      final y = h * frac;
      final dir = frac < 0.5 ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.16, y)
          ..lineTo(w * 0.5, y + dir * h * 0.06)
          ..lineTo(w * 0.84, y),
        chevronPaint,
      );
    }
  }

  void _drawWaveFiligree(
    Canvas canvas,
    double w,
    double h,
    Color waveColor,
  ) {
    final paint = Paint()
      ..color = waveColor.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.013).clamp(0.5, 1.1);
    final rows = 9;
    final path = Path();
    for (var r = 1; r < rows; r++) {
      final y = (r / rows) * h;
      path.moveTo(0, y);
      const segments = 4;
      final segW = w / segments;
      final amp = (w * 0.04).clamp(1.5, 3.5);
      for (var s = 0; s < segments; s++) {
        final x0 = s * segW;
        final xMid = x0 + segW * 0.5;
        final xEnd = x0 + segW;
        final offset = (s.isEven ? -amp : amp);
        path.quadraticBezierTo(xMid, y + offset, xEnd, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawDamaskOgee(
    Canvas canvas,
    double w,
    double h,
    Color latticeColor,
    Color accentColor,
  ) {
    final paint = Paint()
      ..color = latticeColor.withValues(alpha: 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.014).clamp(0.6, 1.2);
    final stepX = (w * 0.25).clamp(10.0, 24.0);
    final stepY = (h * 0.18).clamp(10.0, 24.0);
    final path = Path();
    for (var x = 0.0; x < w + stepX; x += stepX) {
      path.moveTo(x, 0);
      for (var y = 0.0; y < h; y += stepY) {
        path.quadraticBezierTo(x + stepX * 0.3, y + stepY * 0.5, x, y + stepY);
      }
    }
    canvas.drawPath(path, paint);

    // Subtle corner accent pips
    final pipPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    final r = (w * 0.04).clamp(1.6, 3.2);
    for (final pt in <Offset>[
      Offset(w * 0.22, h * 0.17),
      Offset(w * 0.78, h * 0.17),
      Offset(w * 0.22, h * 0.83),
      Offset(w * 0.78, h * 0.83),
    ]) {
      final diamond = Path()
        ..moveTo(pt.dx, pt.dy - r)
        ..lineTo(pt.dx + r, pt.dy)
        ..lineTo(pt.dx, pt.dy + r)
        ..lineTo(pt.dx - r, pt.dy)
        ..close();
      canvas.drawPath(diamond, pipPaint);
    }
  }

  void _drawCornerBlossoms(
    Canvas canvas,
    double w,
    double h,
    Color petalColor,
  ) {
    final fill = Paint()
      ..color = petalColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    final pr = (w * 0.032).clamp(1.3, 2.8);
    for (final center in <Offset>[
      Offset(w * 0.23, h * 0.17),
      Offset(w * 0.77, h * 0.17),
      Offset(w * 0.23, h * 0.83),
      Offset(w * 0.77, h * 0.83),
    ]) {
      canvas.drawCircle(Offset(center.dx, center.dy - pr), pr * 0.7, fill);
      canvas.drawCircle(Offset(center.dx, center.dy + pr), pr * 0.7, fill);
      canvas.drawCircle(Offset(center.dx - pr, center.dy), pr * 0.7, fill);
      canvas.drawCircle(Offset(center.dx + pr, center.dy), pr * 0.7, fill);
    }
  }

  void _drawClassicRosetteMedallion(
    Canvas canvas,
    double w,
    double cx,
    double cy,
    ({Color center, Color edge, Color lattice, Color frame, Color accent})
        palette,
  ) {
    final medR = (w * 0.22).clamp(8.0, 22.0);
    canvas.drawCircle(
      Offset(cx, cy),
      medR,
      Paint()..color = palette.edge.withValues(alpha: 0.92),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      medR,
      Paint()
        ..color = palette.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.024).clamp(1.0, 2.0),
    );

    final star = Path();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final r = i.isEven ? medR * 0.72 : medR * 0.36;
      final pt = Offset(cx + math.cos(angle) * r, cy + math.sin(angle) * r);
      if (i == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = palette.accent.withValues(alpha: 0.9));
    canvas.drawCircle(
      Offset(cx, cy),
      medR * 0.18,
      Paint()..color = palette.frame,
    );
  }

  void _drawArtDecoDiamondMedallion(
    Canvas canvas,
    double w,
    double cx,
    double cy,
    ({Color center, Color edge, Color lattice, Color frame, Color accent})
        palette,
  ) {
    final rW = (w * 0.23).clamp(9.0, 24.0);
    final rH = rW * 1.35;
    final outer = Path()
      ..moveTo(cx, cy - rH)
      ..lineTo(cx + rW, cy)
      ..lineTo(cx, cy + rH)
      ..lineTo(cx - rW, cy)
      ..close();
    canvas.drawPath(outer, Paint()..color = palette.edge.withValues(alpha: 0.95));
    canvas.drawPath(
      outer,
      Paint()
        ..color = palette.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.024).clamp(1.0, 2.0),
    );

    final inner = Path()
      ..moveTo(cx, cy - rH * 0.65)
      ..lineTo(cx + rW * 0.65, cy)
      ..lineTo(cx, cy + rH * 0.65)
      ..lineTo(cx - rW * 0.65, cy)
      ..close();
    canvas.drawPath(inner, Paint()..color = palette.accent.withValues(alpha: 0.85));
    canvas.drawCircle(
      Offset(cx, cy),
      rW * 0.2,
      Paint()..color = palette.frame,
    );
  }

  void _drawCompassMedallion(
    Canvas canvas,
    double w,
    double cx,
    double cy,
    ({Color center, Color edge, Color lattice, Color frame, Color accent})
        palette,
  ) {
    final medR = (w * 0.23).clamp(8.5, 23.0);
    canvas.drawCircle(
      Offset(cx, cy),
      medR,
      Paint()..color = palette.edge.withValues(alpha: 0.94),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      medR,
      Paint()
        ..color = palette.frame
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.02).clamp(0.8, 1.8),
    );

    final compass = Path();
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final r = (i % 4 == 0)
          ? medR * 0.82
          : (i % 2 == 0 ? medR * 0.56 : medR * 0.26);
      final pt = Offset(cx + math.cos(angle) * r, cy + math.sin(angle) * r);
      if (i == 0) {
        compass.moveTo(pt.dx, pt.dy);
      } else {
        compass.lineTo(pt.dx, pt.dy);
      }
    }
    compass.close();
    canvas.drawPath(
      compass,
      Paint()..color = palette.accent.withValues(alpha: 0.92),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      medR * 0.16,
      Paint()..color = palette.frame,
    );
  }

  void _drawBotanicalSprays(
    Canvas canvas,
    double w,
    double h,
    Color goldColor,
  ) {
    final leafPaint = Paint()
      ..color = goldColor.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    final stemPaint = Paint()
      ..color = const Color(0xFFF3EAD3).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.02).clamp(0.8, 1.6);

    final cx = w * 0.5;
    final cy = h * 0.5;
    for (final dir in const <double>[-1.0, 1.0]) {
      final stem = Path()
        ..moveTo(cx, cy)
        ..quadraticBezierTo(
          cx + dir * w * 0.08,
          cy + dir * h * 0.16,
          cx,
          cy + dir * h * 0.34,
        );
      canvas.drawPath(stem, stemPaint);

      for (var k = 1; k <= 3; k++) {
        final t = k * 0.10;
        final ly = cy + dir * h * t;
        for (final side in const <double>[-1.0, 1.0]) {
          final oval = Rect.fromCenter(
            center: Offset(cx + side * w * 0.13, ly),
            width: w * 0.18,
            height: h * 0.055,
          );
          canvas.save();
          canvas.translate(oval.center.dx, oval.center.dy);
          canvas.rotate(side * dir * 0.45);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: oval.width,
              height: oval.height,
            ),
            leafPaint,
          );
          canvas.restore();
        }
      }
    }
  }

  ({Color center, Color edge, Color lattice, Color frame, Color accent})
      _paletteFor(CardBackStyle style) {
    switch (style) {
      case CardBackStyle.crimsonLattice:
        return (
          center: const Color(0xFFA71F27),
          edge: const Color(0xFF6B1016),
          lattice: const Color(0x3DF8ECD4),
          frame: const Color(0xFFF6EFE0),
          accent: const Color(0xFFD8B35A),
        );
      case CardBackStyle.royalNavy:
        return (
          center: const Color(0xFF20477D),
          edge: const Color(0xFF102442),
          lattice: const Color(0x3DEEE6D2),
          frame: const Color(0xFFF3EDE0),
          accent: const Color(0xFFD9BA73),
        );
      case CardBackStyle.botanicalFern:
        return (
          center: const Color(0xFF235C46),
          edge: const Color(0xFF103124),
          lattice: const Color(0x2AEEDCB3),
          frame: const Color(0xFFF2EAD4),
          accent: const Color(0xFFD8B35A),
        );
      case CardBackStyle.heritageGold:
        return (
          center: const Color(0xFF5D3122),
          edge: const Color(0xFF31160E),
          lattice: const Color(0x3DE8C87A),
          frame: const Color(0xFFF4E6C5),
          accent: const Color(0xFFE0B85C),
        );
      case CardBackStyle.artDecoSunburst:
        return (
          center: const Color(0xFF1E2840),
          edge: const Color(0xFF0E1320),
          lattice: const Color(0x45DFBC6B),
          frame: const Color(0xFFF3E6CA),
          accent: const Color(0xFFE0BA5F),
        );
      case CardBackStyle.coastalCompass:
        return (
          center: const Color(0xFF214E72),
          edge: const Color(0xFF0F263B),
          lattice: const Color(0x3CE8E2D0),
          frame: const Color(0xFFF4EFE4),
          accent: const Color(0xFFD7B568),
        );
      case CardBackStyle.plumDamask:
        return (
          center: const Color(0xFF64233F),
          edge: const Color(0xFF320F1E),
          lattice: const Color(0x3CF3DFC5),
          frame: const Color(0xFFF5ECE0),
          accent: const Color(0xFFD9B266),
        );
      case CardBackStyle.sageTrellis:
        return (
          center: const Color(0xFF31645A),
          edge: const Color(0xFF183630),
          lattice: const Color(0x36EDE2C8),
          frame: const Color(0xFFF4EDE0),
          accent: const Color(0xFFD6B467),
        );
    }
  }

  @override
  bool shouldRepaint(_CardBackPainter oldDelegate) => oldDelegate.style != style;
}
