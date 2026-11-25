import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../models/quest.dart';
import '../../theme/app_theme.dart';

/// Non-intrusive bottom ribbon displaying newly completed quests with a gentle
/// finite fanfare sparkle animation, tap-to-inspect action, and explicit dismiss button.
class QuestBannerStrip extends StatefulWidget {
  const QuestBannerStrip({
    super.key,
    required this.quest,
    required this.extraPendingCount,
    required this.theme,
    required this.onTapInspect,
    required this.onDismiss,
  });

  final QuestDefinition quest;
  final int extraPendingCount;
  final ClearDeckTheme theme;
  final VoidCallback onTapInspect;
  final VoidCallback onDismiss;

  @override
  State<QuestBannerStrip> createState() => _QuestBannerStripState();
}

class _QuestBannerStripState extends State<QuestBannerStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fanfareController;

  @override
  void initState() {
    super.initState();
    _fanfareController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant QuestBannerStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quest.id != widget.quest.id) {
      _fanfareController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _fanfareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final headerText = widget.extraPendingCount > 0
        ? 'Quest complete · +${widget.extraPendingCount} more'
        : 'Quest complete';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: theme.sheetCard,
              elevation: 4,
              shadowColor: const Color(0x28000000),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.goldTrim.withValues(alpha: 0.80),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _fanfareController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _QuestFanfarePainter(
                                progress: _fanfareController.value,
                                goldColor: theme.goldTrim,
                                accentColor: theme.sheetAccent,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: InkWell(
                            key: const Key('quest_banner_body'),
                            onTap: widget.onTapInspect,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                              child: Row(
                                children: <Widget>[
                                  AnimatedBuilder(
                                    animation: _fanfareController,
                                    builder: (context, child) {
                                      final t = _fanfareController.value;
                                      final pulse = t < 0.45
                                          ? 0.85 + 0.20 * math.sin((t / 0.45) * math.pi)
                                          : 1.0;
                                      return Transform.scale(
                                        scale: pulse,
                                        child: child,
                                      );
                                    },
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: theme.goldTrim.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: theme.goldTrim.withValues(alpha: 0.72),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Icon(
                                        widget.quest.icon,
                                        size: 20,
                                        color: theme.goldTrim,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          headerText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.goldTrim,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          widget.quest.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.sheetText,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'View',
                                    style: TextStyle(
                                      color: theme.sheetSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            key: const Key('quest_banner_dismiss'),
                            tooltip: 'Dismiss quest notice',
                            onPressed: widget.onDismiss,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: theme.sheetMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestFanfarePainter extends CustomPainter {
  const _QuestFanfarePainter({
    required this.progress,
    required this.goldColor,
    required this.accentColor,
  });

  final double progress;
  final Color goldColor;
  final Color accentColor;

  static const List<({double angle, double speed, double size, int tone})>
      _particles = <({double angle, double speed, double size, int tone})>[
    (angle: -2.6, speed: 34, size: 4.0, tone: 0),
    (angle: -2.0, speed: 44, size: 3.5, tone: 1),
    (angle: -1.4, speed: 50, size: 4.5, tone: 0),
    (angle: -0.9, speed: 56, size: 3.5, tone: 2),
    (angle: -0.45, speed: 64, size: 4.0, tone: 0),
    (angle: -0.15, speed: 70, size: 3.0, tone: 1),
    (angle: 0.25, speed: 58, size: 4.0, tone: 2),
    (angle: 0.65, speed: 46, size: 3.5, tone: 0),
    (angle: 1.25, speed: 36, size: 3.0, tone: 1),
    (angle: 2.35, speed: 30, size: 3.5, tone: 0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    // Gentle antique-gold shimmer band across the top hairline during first 55%
    if (progress < 0.55) {
      final sweepT = progress / 0.55;
      final bandX = size.width * sweepT;
      final bandAlpha = math.sin(sweepT * math.pi) * 0.22;
      final bandPaint = Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            goldColor.withValues(alpha: 0.0),
            goldColor.withValues(alpha: bandAlpha),
            goldColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(bandX - 48, 0, 96, size.height));
      canvas.drawRect(Offset.zero & size, bandPaint);
    }

    // Calm radial confetti diamonds/rectangles around the medal icon
    final origin = Offset(30, size.height * 0.5);
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1.0 - Curves.easeIn.transform(progress)).clamp(0.0, 1.0);
    if (fade <= 0.01) return;

    const palette = <Color>[
      Color(0xFFD0AA54),
      Color(0xFFB21E24),
      Color(0xFF1D5B47),
    ];

    for (var i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      final dist = p.speed * eased;
      final x = origin.dx + math.cos(p.angle) * dist;
      final y = origin.dy + math.sin(p.angle) * dist + eased * eased * 8.0;
      if (x < 0 || x > size.width || y < 0 || y > size.height) continue;

      final color = (p.tone == 0 ? goldColor : palette[p.tone % palette.length])
          .withValues(alpha: fade * 0.85);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.angle + progress * 2.2);
      if (i.isEven) {
        final half = p.size * 0.5;
        canvas.drawPath(
          Path()
            ..moveTo(0, -half)
            ..lineTo(half, 0)
            ..lineTo(0, half)
            ..lineTo(-half, 0)
            ..close(),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 1.2,
              height: p.size * 0.55,
            ),
            const Radius.circular(1),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_QuestFanfarePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.goldColor != goldColor;
}
