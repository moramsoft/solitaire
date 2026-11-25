import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// Matte parlor felt table surface with subtle single-hue overhead lamp falloff.
class TableBackground extends StatelessWidget {
  const TableBackground({
    super.key,
    required this.theme,
    required this.child,
  });

  final ClearDeckTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.2),
                radius: 1.15,
                colors: <Color>[
                  theme.tableCenterGlow,
                  theme.tableBackground,
                  theme.tableEdgeVignette,
                ],
                stops: const <double>[0.0, 0.56, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }
}
