import 'package:material_ui/material_ui.dart';

/// Grouping categories displayed inside the Quests sheet.
enum QuestCategory {
  gettingStarted,
  tableCraft,
  foundations,
  milestones,
  parlorLife;

  String get displayName {
    switch (this) {
      case QuestCategory.gettingStarted:
        return 'Getting started';
      case QuestCategory.tableCraft:
        return 'Table craft';
      case QuestCategory.foundations:
        return 'Foundations';
      case QuestCategory.milestones:
        return 'Wins & streaks';
      case QuestCategory.parlorLife:
        return 'Modes & parlor';
    }
  }
}

/// Immutable catalog entry describing an offline Klondike quest.
class QuestDefinition {
  const QuestDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.category,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final int target;
  final QuestCategory category;
  final IconData icon;
}

/// Persisted progress state for a single quest.
class QuestProgress {
  const QuestProgress({
    required this.questId,
    this.current = 0,
    this.isCompleted = false,
    this.completedAtIso,
  });

  final String questId;
  final int current;
  final bool isCompleted;
  final String? completedAtIso;

  int clampedProgress(int target) => current.clamp(0, target);

  double fraction(int target) {
    if (target <= 0) return 1.0;
    return (clampedProgress(target) / target).clamp(0.0, 1.0);
  }

  QuestProgress copyWith({
    int? current,
    bool? isCompleted,
    String? completedAtIso,
  }) {
    return QuestProgress(
      questId: questId,
      current: current ?? this.current,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAtIso: completedAtIso ?? this.completedAtIso,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'questId': questId,
      'current': current,
      'isCompleted': isCompleted,
      if (completedAtIso != null) 'completedAtIso': completedAtIso,
    };
  }

  factory QuestProgress.fromJson(Map<String, dynamic> json) {
    return QuestProgress(
      questId: json['questId'] as String? ?? '',
      current: (json['current'] as num?)?.toInt() ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAtIso: json['completedAtIso'] as String?,
    );
  }
}

/// Curated 50-quest catalog of dignified card-room milestones and parlor challenges.
class QuestCatalog {
  const QuestCatalog._();

  static const List<QuestDefinition> all = <QuestDefinition>[
    // ── Getting started (10) ────────────────────────────────────────────────
    QuestDefinition(
      id: 'first_foundation',
      title: 'First Ace Placed',
      description: 'Move your first Ace onto a foundation slot',
      target: 1,
      category: QuestCategory.gettingStarted,
      icon: Icons.workspace_premium_rounded,
    ),
    QuestDefinition(
      id: 'waste_player',
      title: 'From the Waste',
      description: 'Play 3 cards from the Waste pile',
      target: 3,
      category: QuestCategory.gettingStarted,
      icon: Icons.move_down_rounded,
    ),
    QuestDefinition(
      id: 'reveal_hidden_5',
      title: 'Card Revealer',
      description: 'Flip 5 hidden table cards face-up',
      target: 5,
      category: QuestCategory.gettingStarted,
      icon: Icons.flip_rounded,
    ),
    QuestDefinition(
      id: 'stock_draws_10',
      title: 'Deck Explorer',
      description: 'Draw from the Stock deck 10 times',
      target: 10,
      category: QuestCategory.gettingStarted,
      icon: Icons.touch_app_rounded,
    ),
    QuestDefinition(
      id: 'moves_25',
      title: 'Opening Rhythm',
      description: 'Make 25 valid moves across your hands',
      target: 25,
      category: QuestCategory.gettingStarted,
      icon: Icons.timeline_rounded,
    ),
    QuestDefinition(
      id: 'stock_recycler',
      title: 'Full Pass',
      description: 'Recycle the Waste pile back into the Stock',
      target: 1,
      category: QuestCategory.gettingStarted,
      icon: Icons.refresh_rounded,
    ),
    QuestDefinition(
      id: 'first_undo',
      title: 'Second Look',
      description: 'Use Undo to reconsider a move',
      target: 1,
      category: QuestCategory.gettingStarted,
      icon: Icons.undo_rounded,
    ),
    QuestDefinition(
      id: 'first_hint',
      title: 'Gentle Nudge',
      description: 'Request a Smart Hint during a hand',
      target: 1,
      category: QuestCategory.gettingStarted,
      icon: Icons.lightbulb_outline_rounded,
    ),
    QuestDefinition(
      id: 'tutorial_graduate',
      title: 'Rules Mastered',
      description: 'Complete the interactive How to Play guide',
      target: 1,
      category: QuestCategory.gettingStarted,
      icon: Icons.menu_book_rounded,
    ),
    QuestDefinition(
      id: 'first_auto_complete',
      title: 'Clean Sweep',
      description: 'Finish a hand using Auto-Complete',
      target: 1,
      category: QuestCategory.gettingStarted,
      icon: Icons.done_all_rounded,
    ),

    // ── Table craft (10) ────────────────────────────────────────────────────
    QuestDefinition(
      id: 'stack_mover',
      title: 'Stack Mover',
      description: 'Move a sequence of 2 or more cards together',
      target: 1,
      category: QuestCategory.tableCraft,
      icon: Icons.layers_rounded,
    ),
    QuestDefinition(
      id: 'stack_mover_25',
      title: 'Column Architect',
      description: 'Move multi-card sequences 25 times',
      target: 25,
      category: QuestCategory.tableCraft,
      icon: Icons.view_stream_rounded,
    ),
    QuestDefinition(
      id: 'long_stack_4',
      title: 'Four-Card Parade',
      description: 'Move a sequence of 4 or more cards at once',
      target: 1,
      category: QuestCategory.tableCraft,
      icon: Icons.format_line_spacing_rounded,
    ),
    QuestDefinition(
      id: 'grand_stack_7',
      title: 'Seven-Card Ribbon',
      description: 'Move a sequence of 7 or more cards at once',
      target: 1,
      category: QuestCategory.tableCraft,
      icon: Icons.view_week_rounded,
    ),
    QuestDefinition(
      id: 'kings_seat',
      title: 'King’s Seat',
      description: 'Place a King into an empty table column',
      target: 1,
      category: QuestCategory.tableCraft,
      icon: Icons.military_tech_rounded,
    ),
    QuestDefinition(
      id: 'kings_seat_10',
      title: 'Royal Court',
      description: 'Place 10 Kings into empty table columns',
      target: 10,
      category: QuestCategory.tableCraft,
      icon: Icons.account_balance_rounded,
    ),
    QuestDefinition(
      id: 'king_with_entourage',
      title: 'Royal Escort',
      description: 'Move a King carrying 2 or more cards into an empty column',
      target: 1,
      category: QuestCategory.tableCraft,
      icon: Icons.shield_rounded,
    ),
    QuestDefinition(
      id: 'reveal_hidden_30',
      title: 'Keen Eye',
      description: 'Flip 30 hidden table cards face-up',
      target: 30,
      category: QuestCategory.tableCraft,
      icon: Icons.visibility_rounded,
    ),
    QuestDefinition(
      id: 'reveal_hidden_100',
      title: 'Card Sleuth',
      description: 'Flip 100 hidden table cards face-up',
      target: 100,
      category: QuestCategory.tableCraft,
      icon: Icons.search_rounded,
    ),
    QuestDefinition(
      id: 'reveal_hidden_250',
      title: 'Master Excavator',
      description: 'Flip 250 hidden table cards face-up',
      target: 250,
      category: QuestCategory.tableCraft,
      icon: Icons.auto_fix_high_rounded,
    ),

    // ── Foundations (10) ────────────────────────────────────────────────────
    QuestDefinition(
      id: 'four_aces_placed',
      title: 'Four Aces',
      description: 'Place 4 Aces onto foundation slots',
      target: 4,
      category: QuestCategory.foundations,
      icon: Icons.looks_4_rounded,
    ),
    QuestDefinition(
      id: 'twenty_aces_placed',
      title: 'Ace Collector',
      description: 'Place 20 Aces onto foundation slots',
      target: 20,
      category: QuestCategory.foundations,
      icon: Icons.stars_rounded,
    ),
    QuestDefinition(
      id: 'foundation_builder',
      title: 'Suit Collector',
      description: 'Place 13 cards onto the foundations',
      target: 13,
      category: QuestCategory.foundations,
      icon: Icons.style_rounded,
    ),
    QuestDefinition(
      id: 'foundation_52',
      title: 'Full Deck Home',
      description: 'Place 52 cards onto the foundations',
      target: 52,
      category: QuestCategory.foundations,
      icon: Icons.collections_bookmark_rounded,
    ),
    QuestDefinition(
      id: 'foundation_200',
      title: 'Foundation Regular',
      description: 'Place 200 cards onto the foundations',
      target: 200,
      category: QuestCategory.foundations,
      icon: Icons.inventory_2_rounded,
    ),
    QuestDefinition(
      id: 'foundation_500',
      title: 'Grand Archivist',
      description: 'Place 500 cards onto the foundations',
      target: 500,
      category: QuestCategory.foundations,
      icon: Icons.library_books_rounded,
    ),
    QuestDefinition(
      id: 'spades_suit_done',
      title: 'Crown of Spades',
      description: 'Complete a Spades foundation up to the King',
      target: 1,
      category: QuestCategory.foundations,
      icon: Icons.grade_rounded,
    ),
    QuestDefinition(
      id: 'hearts_suit_done',
      title: 'Crown of Hearts',
      description: 'Complete a Hearts foundation up to the King',
      target: 1,
      category: QuestCategory.foundations,
      icon: Icons.favorite_rounded,
    ),
    QuestDefinition(
      id: 'diamonds_suit_done',
      title: 'Crown of Diamonds',
      description: 'Complete a Diamonds foundation up to the King',
      target: 1,
      category: QuestCategory.foundations,
      icon: Icons.diamond_rounded,
    ),
    QuestDefinition(
      id: 'clubs_suit_done',
      title: 'Crown of Clubs',
      description: 'Complete a Clubs foundation up to the King',
      target: 1,
      category: QuestCategory.foundations,
      icon: Icons.park_rounded,
    ),

    // ── Wins & streaks (10) ─────────────────────────────────────────────────
    QuestDefinition(
      id: 'first_victory',
      title: 'First Hand Won',
      description: 'Complete your first full Klondike hand',
      target: 1,
      category: QuestCategory.milestones,
      icon: Icons.emoji_events_rounded,
    ),
    QuestDefinition(
      id: 'wins_5',
      title: 'Card Room Regular',
      description: 'Complete 5 full Klondike hands',
      target: 5,
      category: QuestCategory.milestones,
      icon: Icons.looks_5_rounded,
    ),
    QuestDefinition(
      id: 'wins_15',
      title: 'Seasoned Player',
      description: 'Complete 15 full Klondike hands',
      target: 15,
      category: QuestCategory.milestones,
      icon: Icons.military_tech_outlined,
    ),
    QuestDefinition(
      id: 'wins_30',
      title: 'Parlor Veteran',
      description: 'Complete 30 full Klondike hands',
      target: 30,
      category: QuestCategory.milestones,
      icon: Icons.workspace_premium_outlined,
    ),
    QuestDefinition(
      id: 'wins_50',
      title: 'Golden Jubilee',
      description: 'Complete 50 full Klondike hands',
      target: 50,
      category: QuestCategory.milestones,
      icon: Icons.celebration_rounded,
    ),
    QuestDefinition(
      id: 'unaided_hand',
      title: 'Unaided Victory',
      description: 'Complete a hand without requesting a hint',
      target: 1,
      category: QuestCategory.milestones,
      icon: Icons.verified_rounded,
    ),
    QuestDefinition(
      id: 'no_undo_victory',
      title: 'Steady Hand',
      description: 'Complete a hand without using Undo',
      target: 1,
      category: QuestCategory.milestones,
      icon: Icons.check_circle_outline_rounded,
    ),
    QuestDefinition(
      id: 'flawless_victory',
      title: 'Pure Classic',
      description: 'Win a hand using neither Hint nor Undo',
      target: 1,
      category: QuestCategory.milestones,
      icon: Icons.diamond_outlined,
    ),
    QuestDefinition(
      id: 'three_win_streak',
      title: 'Three in a Row',
      description: 'Reach a 3-hand winning streak',
      target: 3,
      category: QuestCategory.milestones,
      icon: Icons.auto_awesome_rounded,
    ),
    QuestDefinition(
      id: 'five_win_streak',
      title: 'Five-Hand Run',
      description: 'Reach a 5-hand winning streak',
      target: 5,
      category: QuestCategory.milestones,
      icon: Icons.bolt_rounded,
    ),

    // ── Modes & parlor (10) ─────────────────────────────────────────────────
    QuestDefinition(
      id: 'draw_three_victory',
      title: 'Draw 3 Classic',
      description: 'Complete a hand in Draw 3 mode',
      target: 1,
      category: QuestCategory.parlorLife,
      icon: Icons.filter_3_rounded,
    ),
    QuestDefinition(
      id: 'draw_three_wins_5',
      title: 'Three-Card Strategist',
      description: 'Win 5 hands in Draw 3 mode',
      target: 5,
      category: QuestCategory.parlorLife,
      icon: Icons.view_carousel_rounded,
    ),
    QuestDefinition(
      id: 'random_deal_victory',
      title: 'Wild Shuffle',
      description: 'Complete a Classic Random deal',
      target: 1,
      category: QuestCategory.parlorLife,
      icon: Icons.shuffle_rounded,
    ),
    QuestDefinition(
      id: 'daily_regular',
      title: 'Daily Challenge',
      description: 'Complete any Daily Challenge deal',
      target: 1,
      category: QuestCategory.parlorLife,
      icon: Icons.calendar_month_rounded,
    ),
    QuestDefinition(
      id: 'daily_wins_5',
      title: 'Weekly Habit',
      description: 'Complete 5 Daily Challenge hands',
      target: 5,
      category: QuestCategory.parlorLife,
      icon: Icons.event_available_rounded,
    ),
    QuestDefinition(
      id: 'efficient_victory',
      title: 'Economical Play',
      description: 'Win a hand in 120 moves or fewer',
      target: 1,
      category: QuestCategory.parlorLife,
      icon: Icons.speed_rounded,
    ),
    QuestDefinition(
      id: 'brisk_victory',
      title: 'Brisk Morning Hand',
      description: 'Complete a hand in 5 minutes or less',
      target: 1,
      category: QuestCategory.parlorLife,
      icon: Icons.timer_outlined,
    ),
    QuestDefinition(
      id: 'deck_connoisseur',
      title: 'Fresh Deck',
      description: 'Try a new Card Face style in Settings',
      target: 1,
      category: QuestCategory.parlorLife,
      icon: Icons.palette_outlined,
    ),
    QuestDefinition(
      id: 'table_decorator',
      title: 'Table Setting',
      description: 'Customize your Table Theme or Card Back',
      target: 1,
      category: QuestCategory.parlorLife,
      icon: Icons.weekend_outlined,
    ),
    QuestDefinition(
      id: 'tactical_pullback',
      title: 'Strategic Retreat',
      description: 'Bring a card back from a Foundation to the table',
      target: 1,
      category: QuestCategory.parlorLife,
      icon: Icons.reply_rounded,
    ),
  ];

  static QuestDefinition? findById(String id) {
    for (final q in all) {
      if (q.id == id) return q;
    }
    return null;
  }
}
