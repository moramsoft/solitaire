import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import '../strings.dart';

/// Fixed 4-button quiet parlor dock (`Undo`, `Hint`, `New`, `Settings`).
/// Guaranteed ≥56dp touch targets, ≥12dp spacing, and zero bottom ads.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.theme,
    required this.canUndo,
    required this.onUndo,
    this.onHint,
    required this.onNewDeal,
    required this.onOpenSettings,
  });

  final ClearDeckTheme theme;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback? onHint;
  final VoidCallback onNewDeal;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.dockBackground,
        border: Border(
          top: BorderSide(
            color: theme.chromeHairline,
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _ActionButton(
                  icon: Icons.undo_rounded,
                  label: AppStrings.undoLabel,
                  theme: theme,
                  enabled: canUndo,
                  onTap: onUndo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.lightbulb_outline_rounded,
                  label: AppStrings.hintLabel,
                  theme: theme,
                  enabled: onHint != null,
                  onTap: onHint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.refresh_rounded,
                  label: AppStrings.newDealLabel,
                  theme: theme,
                  enabled: true,
                  onTap: onNewDeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.tune_rounded,
                  label: AppStrings.settingsLabel,
                  theme: theme,
                  enabled: true,
                  onTap: onOpenSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.theme,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ClearDeckTheme theme;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabledFg = theme.mutedOnTable.withValues(alpha: 0.34);
    final iconColor =
        enabled ? theme.textOnTable.withValues(alpha: 0.90) : disabledFg;
    final labelColor =
        enabled ? theme.textOnTable.withValues(alpha: 0.88) : disabledFg;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        splashColor: theme.chromeButtonSurface,
        highlightColor: theme.chromeButtonSurface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
