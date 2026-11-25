import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../engine/card.dart';
import '../engine/move.dart';
import '../models/quest.dart';
import '../services/persistence_service.dart';

/// Tracks offline Klondike quest progress across 50 curated milestones and
/// manages the non-intrusive bottom completion ribbon queue.
class QuestController extends ChangeNotifier {
  QuestController({required this._persistence});

  final PersistenceService _persistence;

  final Map<String, QuestProgress> _progressMap = <String, QuestProgress>{};
  final List<QuestDefinition> _pendingBanners = <QuestDefinition>[];

  List<QuestDefinition> get catalog => QuestCatalog.all;

  QuestProgress progressFor(String id) =>
      _progressMap[id] ?? QuestProgress(questId: id, current: 0);

  int get completedCount =>
      QuestCatalog.all.where((q) => progressFor(q.id).isCompleted).length;

  int get totalCount => QuestCatalog.all.length;

  int completedCountInCategory(QuestCategory category) => QuestCatalog.all
      .where((q) => q.category == category && progressFor(q.id).isCompleted)
      .length;

  int totalCountInCategory(QuestCategory category) =>
      QuestCatalog.all.where((q) => q.category == category).length;

  QuestDefinition? get activeBannerQuest =>
      _pendingBanners.isEmpty ? null : _pendingBanners.first;

  int get pendingBannerCount => _pendingBanners.length;

  Future<void> initialize() async {
    final json = await _persistence.loadQuestsJson();
    if (json != null) {
      final rawProgress = json['progress'];
      if (rawProgress is Map<String, dynamic>) {
        for (final entry in rawProgress.entries) {
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            final def = QuestCatalog.findById(entry.key);
            if (def == null) continue;
            final decoded = QuestProgress.fromJson(value);
            _progressMap[entry.key] = QuestProgress(
              questId: entry.key,
              current: decoded.clampedProgress(def.target),
              isCompleted:
                  decoded.isCompleted || decoded.current >= def.target,
              completedAtIso: decoded.completedAtIso,
            );
          }
        }
      }
    }
    notifyListeners();
  }

  /// Evaluates a legal Klondike move against in-hand quests.
  Future<void> recordMove({
    required SolitaireMove move,
    required List<PlayingCard> movedCards,
    required bool revealedHiddenCard,
    required bool targetColumnWasEmpty,
  }) async {
    var changed = false;

    changed |= _advanceQuest('moves_25', delta: 1);

    if (move.kind == MoveKind.drawStock) {
      changed |= _advanceQuest('stock_draws_10', delta: 1);
    } else if (move.kind == MoveKind.recycleStock) {
      changed |= _advanceQuest('stock_recycler', delta: 1);
    }

    if (move.kind == MoveKind.wasteToTableau ||
        move.kind == MoveKind.wasteToFoundation) {
      changed |= _advanceQuest('waste_player', delta: 1);
    }

    if (move.kind == MoveKind.foundationToTableau) {
      changed |= _advanceQuest('tactical_pullback', delta: 1);
    }

    if (move.kind == MoveKind.wasteToFoundation ||
        move.kind == MoveKind.tableauToFoundation) {
      changed |= _advanceQuest('foundation_builder', delta: 1);
      changed |= _advanceQuest('foundation_52', delta: 1);
      changed |= _advanceQuest('foundation_200', delta: 1);
      changed |= _advanceQuest('foundation_500', delta: 1);

      if (movedCards.isNotEmpty) {
        final top = movedCards.first;
        if (top.rank == 1) {
          changed |= _advanceQuest('first_foundation', delta: 1);
          changed |= _advanceQuest('four_aces_placed', delta: 1);
          changed |= _advanceQuest('twenty_aces_placed', delta: 1);
        } else if (top.rank == 13) {
          switch (top.suit) {
            case Suit.spades:
              changed |= _advanceQuest('spades_suit_done', delta: 1);
            case Suit.hearts:
              changed |= _advanceQuest('hearts_suit_done', delta: 1);
            case Suit.diamonds:
              changed |= _advanceQuest('diamonds_suit_done', delta: 1);
            case Suit.clubs:
              changed |= _advanceQuest('clubs_suit_done', delta: 1);
          }
        }
      }
    }

    if (revealedHiddenCard) {
      changed |= _advanceQuest('reveal_hidden_5', delta: 1);
      changed |= _advanceQuest('reveal_hidden_30', delta: 1);
      changed |= _advanceQuest('reveal_hidden_100', delta: 1);
      changed |= _advanceQuest('reveal_hidden_250', delta: 1);
    }

    if (move.kind == MoveKind.tableauToTableau && move.cardCount >= 2) {
      changed |= _advanceQuest('stack_mover', delta: 1);
      changed |= _advanceQuest('stack_mover_25', delta: 1);
      if (move.cardCount >= 4) {
        changed |= _advanceQuest('long_stack_4', delta: 1);
      }
      if (move.cardCount >= 7) {
        changed |= _advanceQuest('grand_stack_7', delta: 1);
      }
    }

    if ((move.kind == MoveKind.tableauToTableau ||
            move.kind == MoveKind.wasteToTableau ||
            move.kind == MoveKind.foundationToTableau) &&
        targetColumnWasEmpty &&
        movedCards.isNotEmpty &&
        movedCards.first.rank == 13) {
      changed |= _advanceQuest('kings_seat', delta: 1);
      changed |= _advanceQuest('kings_seat_10', delta: 1);
      if (movedCards.length >= 3) {
        changed |= _advanceQuest('king_with_entourage', delta: 1);
      }
    }

    if (changed) {
      notifyListeners();
      await _save();
    }
  }

  /// Evaluates win-condition quests after a hand completes.
  Future<void> recordWin({
    required bool usedHintInHand,
    bool usedUndoInHand = false,
    required DrawMode drawMode,
    DealType dealType = DealType.winnable,
    required bool isDaily,
    required int currentStreak,
    int? movesCount,
    int? elapsedSeconds,
  }) async {
    var changed = false;

    changed |= _advanceQuest('first_victory', delta: 1);
    changed |= _advanceQuest('wins_5', delta: 1);
    changed |= _advanceQuest('wins_15', delta: 1);
    changed |= _advanceQuest('wins_30', delta: 1);
    changed |= _advanceQuest('wins_50', delta: 1);

    if (!usedHintInHand) {
      changed |= _advanceQuest('unaided_hand', delta: 1);
    }
    if (!usedUndoInHand) {
      changed |= _advanceQuest('no_undo_victory', delta: 1);
    }
    if (!usedHintInHand && !usedUndoInHand) {
      changed |= _advanceQuest('flawless_victory', delta: 1);
    }

    if (drawMode == DrawMode.draw3) {
      changed |= _advanceQuest('draw_three_victory', delta: 1);
      changed |= _advanceQuest('draw_three_wins_5', delta: 1);
    }

    if (dealType == DealType.random) {
      changed |= _advanceQuest('random_deal_victory', delta: 1);
    }

    if (isDaily) {
      changed |= _advanceQuest('daily_regular', delta: 1);
      changed |= _advanceQuest('daily_wins_5', delta: 1);
    }

    if (currentStreak > 0) {
      changed |= _advanceQuest('three_win_streak', setAtLeast: currentStreak);
      changed |= _advanceQuest('five_win_streak', setAtLeast: currentStreak);
    }

    if (movesCount != null && movesCount <= 120) {
      changed |= _advanceQuest('efficient_victory', delta: 1);
    }

    if (elapsedSeconds != null && elapsedSeconds <= 300) {
      changed |= _advanceQuest('brisk_victory', delta: 1);
    }

    if (changed) {
      notifyListeners();
      await _save();
    }
  }

  Future<void> recordUndo() => _recordSingleEvent('first_undo');

  Future<void> recordHintUsed() => _recordSingleEvent('first_hint');

  Future<void> recordAutoCompleteUsed() =>
      _recordSingleEvent('first_auto_complete');

  Future<void> recordTutorialCompleted() =>
      _recordSingleEvent('tutorial_graduate');

  Future<void> recordFaceStyleChanged() =>
      _recordSingleEvent('deck_connoisseur');

  Future<void> recordThemeOrBackChanged() =>
      _recordSingleEvent('table_decorator');

  Future<void> _recordSingleEvent(String questId) async {
    if (_advanceQuest(questId, delta: 1)) {
      notifyListeners();
      await _save();
    }
  }

  void dismissActiveBanner() {
    if (_pendingBanners.isEmpty) return;
    _pendingBanners.removeAt(0);
    notifyListeners();
  }

  void dismissBannerById(String questId) {
    final before = _pendingBanners.length;
    _pendingBanners.removeWhere((q) => q.id == questId);
    if (_pendingBanners.length != before) {
      notifyListeners();
    }
  }

  bool _advanceQuest(String id, {int delta = 0, int? setAtLeast}) {
    final def = QuestCatalog.findById(id);
    if (def == null) return false;

    final prev = progressFor(id);
    final rawNext = setAtLeast != null
        ? math.max(prev.current, setAtLeast)
        : prev.current + delta;
    final capped = rawNext.clamp(0, def.target);
    final nowCompleted = prev.isCompleted || capped >= def.target;

    if (capped == prev.current && nowCompleted == prev.isCompleted) {
      return false;
    }

    final newlyCompleted = !prev.isCompleted && nowCompleted;
    _progressMap[id] = QuestProgress(
      questId: id,
      current: capped,
      isCompleted: nowCompleted,
      completedAtIso: prev.completedAtIso ??
          (nowCompleted ? DateTime.now().toIso8601String() : null),
    );

    if (newlyCompleted && !_pendingBanners.any((q) => q.id == def.id)) {
      _pendingBanners.add(def);
    }
    return true;
  }

  Future<void> _save() async {
    await _persistence.saveQuestsJson(<String, dynamic>{
      'progress': <String, dynamic>{
        for (final entry in _progressMap.entries)
          entry.key: entry.value.toJson(),
      },
    });
  }
}
