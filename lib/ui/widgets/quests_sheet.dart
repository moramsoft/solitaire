import 'package:material_ui/material_ui.dart';

import '../../models/quest.dart';
import '../../state/quest_controller.dart';
import '../../theme/app_theme.dart';

/// Dignified parlor modal displaying all 50 active and completed Klondike
/// quests with category filters for effortless navigation.
class QuestsSheet extends StatefulWidget {
  const QuestsSheet({
    super.key,
    required this.theme,
    required this.questController,
    this.highlightQuestId,
  });

  final ClearDeckTheme theme;
  final QuestController questController;
  final String? highlightQuestId;

  @override
  State<QuestsSheet> createState() => _QuestsSheetState();
}

class _QuestsSheetState extends State<QuestsSheet> {
  QuestCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    final highlightId = widget.highlightQuestId;
    if (highlightId != null) {
      _selectedCategory = QuestCatalog.findById(highlightId)?.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final questController = widget.questController;

    return ListenableBuilder(
      listenable: questController,
      builder: (context, _) {
        final completed = questController.completedCount;
        final total = questController.totalCount;
        final overallFraction = total > 0 ? (completed / total) : 0.0;
        final visibleCategories = _selectedCategory == null
            ? QuestCategory.values
            : <QuestCategory>[_selectedCategory!];

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
                              'Quests',
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
                            tooltip: 'Close Quests',
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.sheetCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.sheetBorder, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Parlor milestones',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.sheetSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '$completed of $total complete',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: theme.sheetText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: overallFraction,
                            minHeight: 6,
                            backgroundColor: theme.sheetRaised,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.goldTrim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: <Widget>[
                        _CategoryFilterPill(
                          key: const Key('quest_filter_all'),
                          label: 'All ($total)',
                          selected: _selectedCategory == null,
                          theme: theme,
                          onTap: () => setState(() => _selectedCategory = null),
                        ),
                        const SizedBox(width: 8),
                        for (final category in QuestCategory.values) ...<Widget>[
                          _CategoryFilterPill(
                            key: Key('quest_filter_${category.name}'),
                            label: category.displayName,
                            selected: _selectedCategory == category,
                            theme: theme,
                            onTap: () =>
                                setState(() => _selectedCategory = category),
                          ),
                          if (category != QuestCategory.values.last)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: <Widget>[
                      for (final category in visibleCategories) ...<Widget>[
                        _CategorySectionHeader(
                          title: category.displayName,
                          completed:
                              questController.completedCountInCategory(category),
                          total: questController.totalCountInCategory(category),
                          theme: theme,
                        ),
                        for (final quest in questController.catalog.where(
                          (q) => q.category == category,
                        ))
                          _QuestCardTile(
                            quest: quest,
                            progress: questController.progressFor(quest.id),
                            theme: theme,
                            isHighlighted: quest.id == widget.highlightQuestId,
                          ),
                      ],
                    ],
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

class _CategoryFilterPill extends StatelessWidget {
  const _CategoryFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ClearDeckTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? theme.sheetAccent : theme.sheetCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? theme.sheetAccent : theme.sheetBorder,
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: selected ? theme.sheetAccentText : theme.sheetSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySectionHeader extends StatelessWidget {
  const _CategorySectionHeader({
    required this.title,
    required this.completed,
    required this.total,
    required this.theme,
  });

  final String title;
  final int completed;
  final int total;
  final ClearDeckTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.sheetMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$completed / $total',
            style: TextStyle(
              color: theme.sheetMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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

class _QuestCardTile extends StatelessWidget {
  const _QuestCardTile({
    required this.quest,
    required this.progress,
    required this.theme,
    required this.isHighlighted,
  });

  final QuestDefinition quest;
  final QuestProgress progress;
  final ClearDeckTheme theme;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final completed = progress.isCompleted;
    final current = progress.clampedProgress(quest.target);
    final fraction = progress.fraction(quest.target);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.sheetCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isHighlighted || completed)
              ? theme.goldTrim.withValues(alpha: isHighlighted ? 0.95 : 0.60)
              : theme.sheetBorder,
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: completed
                  ? theme.goldTrim.withValues(alpha: 0.16)
                  : theme.sheetRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: completed
                    ? theme.goldTrim.withValues(alpha: 0.72)
                    : theme.sheetBorder,
                width: 1.0,
              ),
            ),
            child: Icon(
              completed ? Icons.check_rounded : quest.icon,
              size: 20,
              color: completed ? theme.goldTrim : theme.sheetSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        quest.title,
                        style: TextStyle(
                          color: theme.sheetText,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (completed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.goldTrim.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Complete',
                          style: TextStyle(
                            color: theme.goldTrim,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Text(
                        '$current / ${quest.target}',
                        style: TextStyle(
                          color: theme.sheetSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  quest.description,
                  style: TextStyle(
                    color: theme.sheetSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (!completed && quest.target > 1) ...<Widget>[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 4,
                      backgroundColor: theme.sheetRaised,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.sheetAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
