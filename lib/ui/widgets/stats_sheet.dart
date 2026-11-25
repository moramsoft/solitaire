import 'package:material_ui/material_ui.dart';

import '../../state/stats_controller.dart';
import '../../theme/app_theme.dart';
import '../strings.dart';

/// Personal Klondike statistics scorecard sheet.
class StatsSheet extends StatelessWidget {
  const StatsSheet({
    super.key,
    required this.theme,
    required this.statsController,
  });

  final ClearDeckTheme theme;
  final StatsController statsController;

  static String formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: statsController,
      builder: (context, _) {
        final st = statsController.stats;
        final winRatio = (st.winRatePercent / 100.0).clamp(0.0, 1.0);

        return Container(
          decoration: BoxDecoration(
            color: theme.sheetSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                  child: Column(
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.sheetMuted.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              AppStrings.statsTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.sheetText,
                                fontFamily: 'Georgia',
                                fontFamilyFallback: const <String>[
                                  'Times New Roman',
                                  'Noto Serif',
                                  'serif',
                                ],
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close Statistics',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: theme.sheetSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Win rate summary card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.sheetCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.sheetBorder,
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          '${st.winRatePercent.toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            color: theme.sheetText,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w500,
                                            height: 1.0,
                                            fontFeatures: const <FontFeature>[
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Win rate',
                                          style: TextStyle(
                                            color: theme.sheetMuted,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${st.gamesWon} won · ${st.gamesPlayed} played',
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: theme.sheetSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        fontFeatures: const <FontFeature>[
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: winRatio,
                                  minHeight: 6,
                                  backgroundColor: theme.sheetRaised,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.sheetAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Card-room ledger
                        Container(
                          decoration: BoxDecoration(
                            color: theme.sheetCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.sheetBorder,
                              width: 1.0,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: <Widget>[
                              _LedgerRow(
                                label: 'Current streak',
                                value: '${st.currentStreak}',
                                theme: theme,
                              ),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.sheetBorder,
                              ),
                              _LedgerRow(
                                label: 'Best streak',
                                value: '${st.bestStreak}',
                                theme: theme,
                              ),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.sheetBorder,
                              ),
                              _LedgerRow(
                                label: 'Daily stamps',
                                value:
                                    '${statsController.completedDailyDates.length}',
                                theme: theme,
                              ),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.sheetBorder,
                              ),
                              _LedgerRow(
                                label: 'Best moves',
                                value: st.bestMoves == null
                                    ? '—'
                                    : '${st.bestMoves}',
                                theme: theme,
                              ),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.sheetBorder,
                              ),
                              _LedgerRow(
                                label: 'Best time',
                                value: st.bestTimeSeconds == null
                                    ? '—'
                                    : formatDuration(st.bestTimeSeconds!),
                                theme: theme,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title:
                                    const Text('Reset Personal Statistics?'),
                                content: const Text(
                                  'Your games played, win rate, and streak counts will be set back to zero.',
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Reset'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await statsController.resetStats();
                            }
                          },
                          child: const Text(AppStrings.resetStatsButton),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ClearDeckTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: theme.sheetSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: theme.sheetText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
