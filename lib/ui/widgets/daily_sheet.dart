import 'package:material_ui/material_ui.dart';

import '../../engine/deal_generator.dart';
import '../../state/game_controller.dart';
import '../../state/stats_controller.dart';
import '../../theme/app_theme.dart';
import '../strings.dart';

/// 100% offline monthly Daily Challenge calendar modal.
class DailyChallengeSheet extends StatefulWidget {
  const DailyChallengeSheet({
    super.key,
    required this.theme,
    required this.statsController,
    required this.gameController,
  });

  final ClearDeckTheme theme;
  final StatsController statsController;
  final GameController gameController;

  @override
  State<DailyChallengeSheet> createState() => _DailyChallengeSheetState();
}

class _DailyChallengeSheetState extends State<DailyChallengeSheet> {
  late DateTime _visibleMonth;

  static const List<String> _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdays = <String>[
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final firstWeekdayOffset =
        DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday % 7;

    final completed = widget.statsController.completedDailyDates;
    var monthCompletedCount = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final key = DealGenerator.formatDateKey(
        DateTime(_visibleMonth.year, _visibleMonth.month, day),
      );
      if (completed.contains(key)) monthCompletedCount++;
    }

    final isCurrentMonth =
        _visibleMonth.year == today.year && _visibleMonth.month == today.month;

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          AppStrings.dailyTitle,
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
                        tooltip: 'Close Calendar',
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
                    Text(
                      AppStrings.dailySubtitle,
                      style: TextStyle(
                        color: theme.sheetMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Open linen calendar scorecard
                    Container(
                      decoration: BoxDecoration(
                        color: theme.sheetCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.sheetBorder,
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'Previous Month',
                                onPressed: () {
                                  setState(() {
                                    _visibleMonth = DateTime(
                                      _visibleMonth.year,
                                      _visibleMonth.month - 1,
                                    );
                                  });
                                },
                                icon: Icon(
                                  Icons.chevron_left_rounded,
                                  size: 20,
                                  color: theme.sheetSecondary,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: <Widget>[
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: theme.sheetText,
                                          fontFamily: 'Georgia',
                                          fontFamilyFallback: const <String>[
                                            'Times New Roman',
                                            'Noto Serif',
                                            'serif',
                                          ],
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$monthCompletedCount of $daysInMonth completed',
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: theme.sheetMuted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          fontFeatures: const <FontFeature>[
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Next Month',
                                onPressed: isCurrentMonth
                                    ? null
                                    : () {
                                        setState(() {
                                          _visibleMonth = DateTime(
                                            _visibleMonth.year,
                                            _visibleMonth.month + 1,
                                          );
                                        });
                                      },
                                icon: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: isCurrentMonth
                                      ? theme.sheetMuted.withValues(alpha: 0.30)
                                      : theme.sheetSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: _weekdays
                                .map(
                                  (day) => Expanded(
                                    child: Center(
                                      child: Text(
                                        day,
                                        style: TextStyle(
                                          color: theme.sheetMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: firstWeekdayOffset + daysInMonth,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                            ),
                            itemBuilder: (context, idx) {
                              if (idx < firstWeekdayOffset) {
                                return const SizedBox.shrink();
                              }
                              final day = idx - firstWeekdayOffset + 1;
                              final date = DateTime(
                                _visibleMonth.year,
                                _visibleMonth.month,
                                day,
                              );
                              final isFuture = date.isAfter(today);
                              final isToday = date == today;
                              final dateKey = DealGenerator.formatDateKey(date);
                              final isDone = completed.contains(dateKey);

                              return Material(
                                color: isDone
                                    ? theme.stampFill
                                    : isToday
                                        ? theme.sheetRaised
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: isFuture
                                      ? null
                                      : () async {
                                          final nav = Navigator.of(context);
                                          await widget.gameController
                                              .startDailyDeal(date);
                                          nav.pop();
                                        },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: isToday && !isDone
                                          ? Border.all(
                                              color: theme.sheetAccent,
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                    padding: isDone
                                        ? const EdgeInsets.all(2)
                                        : EdgeInsets.zero,
                                    child: Container(
                                      decoration: isDone
                                          ? BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: theme.goldTrim
                                                    .withValues(alpha: 0.65),
                                                width: 0.9,
                                              ),
                                            )
                                          : null,
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Text(
                                                '$day',
                                                style: TextStyle(
                                                  color: isDone
                                                      ? theme.stampText
                                                      : isFuture
                                                          ? theme.sheetMuted
                                                              .withValues(
                                                              alpha: 0.32,
                                                            )
                                                          : theme.sheetText,
                                                  fontSize: isDone ? 14 : 15,
                                                  fontWeight: isDone || isToday
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  fontFeatures: const <FontFeature>[
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                              if (isDone)
                                                Icon(
                                                  Icons.check_rounded,
                                                  size: 10,
                                                  color: theme.goldTrim,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await widget.gameController.startDailyDeal(today);
                        nav.pop();
                      },
                      icon: const Icon(Icons.today_rounded, size: 18),
                      label: const Text("Play Today's Challenge"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
