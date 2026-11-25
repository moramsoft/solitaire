import 'package:material_ui/material_ui.dart';

import '../../engine/card.dart';
import '../../engine/move.dart';
import '../../state/game_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/deck_palette.dart';
import '../strings.dart';
import 'playing_card_widget.dart';
import 'suit_painter.dart';

/// Respectful 1-tap Settings & Visual Comfort modal sheet.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.settingsController,
    required this.gameController,
    required this.onOpenDaily,
    required this.onOpenStats,
    this.onOpenQuests,
    this.onOpenTutorial,
  });

  final SettingsController settingsController;
  final GameController gameController;
  final VoidCallback onOpenDaily;
  final VoidCallback onOpenStats;
  final VoidCallback? onOpenQuests;
  final VoidCallback? onOpenTutorial;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        settingsController,
        gameController,
      ]),
      builder: (context, _) {
        final s = settingsController.settings;
        final theme = ClearDeckTheme.fromId(s.tableTheme);
        final activeState = gameController.state;
        final rulesDifferFromActive = activeState.drawMode != s.drawMode ||
            (activeState.dealType != DealType.daily &&
                activeState.dealType != s.preferredDealType);

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
                              AppStrings.settingsTitle,
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
                            tooltip: 'Close Settings',
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
                        _SectionHeader(
                          title: AppStrings.appearanceSection,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),

                        _SettingsGroupCard(
                          theme: theme,
                          children: <Widget>[
                            _SwitchSettingRow(
                              title: AppStrings.fourColorLabel,
                              subtitle: AppStrings.fourColorHint,
                              value: s.fourColorDeck,
                              theme: theme,
                              leading: _FourSuitBadge(
                                fourColor: s.fourColorDeck,
                                theme: theme,
                              ),
                              onChanged: (v) =>
                                  settingsController.setFourColorDeck(v),
                            ),
                            _SegmentedSettingRow<CardScale>(
                              label: AppStrings.cardSizeLabel,
                              theme: theme,
                              selected: s.cardScale,
                              options: const <({
                                CardScale value,
                                String label,
                              })>[
                                (value: CardScale.large, label: 'Large'),
                                (value: CardScale.jumbo, label: 'Jumbo'),
                              ],
                              onSelect: (v) =>
                                  settingsController.setCardScale(v),
                            ),
                            _SwitchSettingRow(
                              title: AppStrings.leftHandedLabel,
                              subtitle: AppStrings.leftHandedHint,
                              value: s.leftHanded,
                              theme: theme,
                              onChanged: (v) =>
                                  settingsController.setLeftHanded(v),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Text(
                          AppStrings.tableThemeLabel,
                          style: TextStyle(
                            color: theme.sheetText,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.5,
                          children: TableThemeId.values.map((id) {
                            final swatchTheme = ClearDeckTheme.fromId(id);
                            final selected = s.tableTheme == id;
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  settingsController.setTableTheme(id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment.center,
                                    radius: 1.0,
                                    colors: <Color>[
                                      swatchTheme.tableCenterGlow,
                                      swatchTheme.tableEdgeVignette,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? theme.sheetAccent
                                        : (swatchTheme.isDarkTable
                                            ? swatchTheme.slotBorder
                                            : theme.sheetBorder),
                                    width: selected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    if (selected) ...<Widget>[
                                      Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: swatchTheme.textOnTable,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          id.displayName,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: swatchTheme.textOnTable,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),
                        Text(
                          AppStrings.cardFaceStyleLabel,
                          style: TextStyle(
                            color: theme.sheetText,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: DeckFaceStyle.values.map((style) {
                              final selected = s.deckFaceStyle == style;
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: style == DeckFaceStyle.values.last
                                      ? 0
                                      : 8,
                                ),
                                child: InkWell(
                                  key: Key('deck_face_${style.name}'),
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => settingsController
                                      .setDeckFaceStyle(style),
                                  child: Container(
                                    width: 92,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: selected
                                          ? theme.sheetCard
                                          : theme.sheetCard.withValues(alpha: 0.45),
                                      border: Border.all(
                                        color: selected
                                            ? theme.sheetAccent
                                            : theme.sheetBorder,
                                        width: selected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        PlayingCardWidget(
                                          card: const PlayingCard(
                                            suit: Suit.hearts,
                                            rank: 13,
                                            isFaceUp: true,
                                          ),
                                          width: 54,
                                          height: 80,
                                          theme: theme,
                                          fourColorDeck: s.fourColorDeck,
                                          cardScale: s.cardScale,
                                          deckFaceStyle: style,
                                          cardBackStyle: s.cardBackStyle,
                                        ),
                                        const SizedBox(height: 6),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            style.displayName,
                                            maxLines: 1,
                                            style: TextStyle(
                                              color: selected
                                                  ? theme.sheetText
                                                  : theme.sheetSecondary,
                                              fontSize: 12,
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Text(
                          AppStrings.cardBackStyleLabel,
                          style: TextStyle(
                            color: theme.sheetText,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.72,
                          children: CardBackStyle.values.map((style) {
                            final selected = s.cardBackStyle == style;
                            return InkWell(
                              key: Key('card_back_${style.name}'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  settingsController.setCardBackStyle(style),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: selected
                                      ? theme.sheetCard
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: selected
                                        ? theme.sheetAccent
                                        : theme.sheetBorder,
                                    width: selected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    PlayingCardWidget(
                                      card: const PlayingCard(
                                        suit: Suit.spades,
                                        rank: 1,
                                        isFaceUp: false,
                                      ),
                                      width: 40,
                                      height: 56,
                                      theme: theme,
                                      fourColorDeck: s.fourColorDeck,
                                      cardScale: s.cardScale,
                                      deckFaceStyle: s.deckFaceStyle,
                                      cardBackStyle: style,
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        style.displayName,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: selected
                                              ? theme.sheetText
                                              : theme.sheetSecondary,
                                          fontSize: 11.5,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),
                        _SectionHeader(
                          title: AppStrings.gameplaySection,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),

                        _SettingsGroupCard(
                          theme: theme,
                          children: <Widget>[
                            _SegmentedSettingRow<DrawMode>(
                              label: AppStrings.drawModeLabel,
                              theme: theme,
                              selected: s.drawMode,
                              options: const <({
                                DrawMode value,
                                String label,
                              })>[
                                (value: DrawMode.draw1, label: 'Draw 1'),
                                (value: DrawMode.draw3, label: 'Draw 3'),
                              ],
                              onSelect: (mode) async {
                                await settingsController.setDrawMode(mode);
                                if (!gameController.state.hasStarted) {
                                  await gameController.startNewDeal(
                                    overrideDrawMode: mode,
                                    countAbandonedStreak: false,
                                  );
                                }
                              },
                            ),
                            _SegmentedSettingRow<DealType>(
                              label: AppStrings.dealModeLabel,
                              theme: theme,
                              selected: s.preferredDealType == DealType.random
                                  ? DealType.random
                                  : DealType.winnable,
                              options: const <({
                                DealType value,
                                String label,
                              })>[
                                (value: DealType.winnable, label: 'Winnable'),
                                (
                                  value: DealType.random,
                                  label: 'Classic Random',
                                ),
                              ],
                              onSelect: (type) async {
                                await settingsController
                                    .setPreferredDealType(type);
                                if (!gameController.state.hasStarted) {
                                  await gameController.startNewDeal(
                                    overrideDealType: type,
                                    countAbandonedStreak: false,
                                  );
                                }
                              },
                            ),
                            if (rulesDifferFromActive)
                              Container(
                                color: theme.sheetRaised,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        AppStrings.applyRuleChangeNote,
                                        style: TextStyle(
                                          color: theme.sheetSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 40),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final nav = Navigator.of(context);
                                        await gameController.startNewDeal();
                                        nav.pop();
                                      },
                                      child: const Text('Start Now'),
                                    ),
                                  ],
                                ),
                              ),
                            _SwitchSettingRow(
                              title: AppStrings.showTimerLabel,
                              subtitle: AppStrings.showTimerHint,
                              value: s.showTimer,
                              theme: theme,
                              onChanged: (v) =>
                                  settingsController.setShowTimer(v),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        _SectionHeader(
                          title: AppStrings.audioSection,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        _SettingsGroupCard(
                          theme: theme,
                          children: <Widget>[
                            _VolumeSliderRow(
                              label: AppStrings.sfxVolumeLabel,
                              value: s.sfxVolume,
                              theme: theme,
                              icon: Icons.touch_app_rounded,
                              onChanged: (v) =>
                                  settingsController.setSfxVolume(v),
                            ),
                            _VolumeSliderRow(
                              label: AppStrings.bgmVolumeLabel,
                              value: s.bgmVolume,
                              theme: theme,
                              icon: Icons.music_note_rounded,
                              onChanged: (v) =>
                                  settingsController.setBgmVolume(v),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        _SectionHeader(
                          title: AppStrings.progressSection,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onOpenDaily();
                                },
                                icon: const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 18,
                                ),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Daily Calendar', maxLines: 1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onOpenStats();
                                },
                                icon: const Icon(
                                  Icons.bar_chart_rounded,
                                  size: 18,
                                ),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Statistics', maxLines: 1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (onOpenQuests != null || onOpenTutorial != null) ...<Widget>[
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              if (onOpenQuests != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      onOpenQuests!();
                                    },
                                    icon: const Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 18,
                                    ),
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(AppStrings.questsLabel, maxLines: 1),
                                    ),
                                  ),
                                ),
                              if (onOpenQuests != null && onOpenTutorial != null)
                                const SizedBox(width: 12),
                              if (onOpenTutorial != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      onOpenTutorial!();
                                    },
                                    icon: const Icon(
                                      Icons.menu_book_rounded,
                                      size: 18,
                                    ),
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        AppStrings.howToPlayLabel,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            AppStrings.betaBadge,
                            style: TextStyle(
                              color: theme.sheetMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ClearDeckTheme theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: theme.sheetMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({
    required this.theme,
    required this.children,
  });

  final ClearDeckTheme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.sheetCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.sheetBorder, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, thickness: 1, color: theme.sheetBorder),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SwitchSettingRow extends StatelessWidget {
  const _SwitchSettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.theme,
    required this.onChanged,
    this.leading,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ClearDeckTheme theme;
  final ValueChanged<bool> onChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.sheetText,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FourSuitBadge extends StatelessWidget {
  const _FourSuitBadge({
    required this.fourColor,
    required this.theme,
  });

  final bool fourColor;
  final ClearDeckTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.sheetRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.sheetBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < Suit.values.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 4),
            SuitIcon(
              suit: Suit.values[i],
              size: 14,
              color: DeckPalette.suitColor(
                Suit.values[i],
                fourColor: fourColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentedSettingRow<T> extends StatelessWidget {
  const _SegmentedSettingRow({
    required this.label,
    required this.theme,
    required this.selected,
    required this.options,
    required this.onSelect,
  });

  final String label;
  final ClearDeckTheme theme;
  final T selected;
  final List<({T value, String label})> options;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: theme.sheetText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.sheetRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: options.map((opt) {
                final isSelected = opt.value == selected;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: opt == options.last ? 0 : 4,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => onSelect(opt.value),
                      child: AnimatedContainer(
                        duration: ClearDeckTheme.feedbackDuration,
                        curve: ClearDeckTheme.motionCurve,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.sheetAccent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              opt.label,
                              maxLines: 1,
                              style: TextStyle(
                                color: isSelected
                                    ? theme.sheetAccentText
                                    : theme.sheetSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeSliderRow extends StatelessWidget {
  const _VolumeSliderRow({
    required this.label,
    required this.value,
    required this.theme,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ClearDeckTheme theme;
  final IconData icon;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 20,
            child: Icon(icon, color: theme.sheetSecondary, size: 18),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.sheetText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Slider(
              value: value,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${(value * 100).round()}%',
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
          ),
        ],
      ),
    );
  }
}
