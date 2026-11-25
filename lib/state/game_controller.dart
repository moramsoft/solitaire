import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../engine/engine.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/monetization_service.dart';
import '../services/persistence_service.dart';
import 'quest_controller.dart';
import 'settings_controller.dart';
import 'stats_controller.dart';

/// Visual transition payload emitted after a move so the UI can animate
/// card flight, 3D tableau flips, and foundation gold shimmers smoothly.
class MoveVisualEvent {
  const MoveVisualEvent({
    required this.sequenceId,
    required this.move,
    required this.movedCards,
    required this.isDragMove,
    required this.isAutoCompleting,
    this.revealedTableauCol,
    this.revealedCardIndex,
    this.landedFoundationIndex,
  });

  final int sequenceId;
  final SolitaireMove move;
  final List<PlayingCard> movedCards;
  final bool isDragMove;
  final bool isAutoCompleting;
  final int? revealedTableauCol;
  final int? revealedCardIndex;
  final int? landedFoundationIndex;
}

/// Orchestrates active Klondike gameplay, move persistence, hints,
/// Smart Rewind, Auto-Complete, and lifecycle hooks.
class GameController extends ChangeNotifier {
  GameController({
    required this._persistence,
    required this._settings,
    required this._stats,
    required this._audio,
    required this._analytics,
    required this._monetization,
    this.quests,
  });

  final PersistenceService _persistence;
  final SettingsController _settings;
  final StatsController _stats;
  final AudioService _audio;
  final AnalyticsService _analytics;
  final MonetizationService _monetization;
  final QuestController? quests;

  final math.Random _seedRng = math.Random();

  GameState? _state;
  HintResult? _activeHint;
  String? _activeRuleTip;
  String? _pendingDragRejectionReason;
  Rect? _pendingDragRejectionRect;
  MoveVisualEvent? _lastVisualEvent;
  int _visualSeq = 0;
  bool _deadEndDialogVisible = false;
  bool _isAutoCompleting = false;
  bool _isLifecyclePaused = false;
  int _consecutiveStockCycles = 0;
  bool _usedHintThisHand = false;
  bool _usedUndoThisHand = false;
  int _invalidMoveAttempts = 0;
  bool _tutorialOfferVisible = false;

  Timer? _clockTimer;
  Timer? _autoCompleteTimer;
  Timer? _saveDebounceTimer;
  bool _hasPendingSave = false;

  /// Isolated elapsed-time publisher so 1-second timer ticks only rebuild the
  /// timer label instead of all 52 cards on the board.
  final ValueNotifier<int> elapsedSecondsNotifier = ValueNotifier<int>(0);

  GameState get state => _state!;
  bool get isReady => _state != null;
  HintResult? get activeHint => _activeHint;
  String? get activeRuleTip => _activeRuleTip;
  MoveVisualEvent? get lastVisualEvent => _lastVisualEvent;
  bool get deadEndDialogVisible => _deadEndDialogVisible;
  bool get isAutoCompleting => _isAutoCompleting;
  int get invalidMoveAttempts => _invalidMoveAttempts;
  bool get tutorialOfferVisible => _tutorialOfferVisible;
  AudioService get audio => _audio;

  bool get canAutoComplete =>
      _state != null &&
      !_state!.isWon &&
      !_isAutoCompleting &&
      SolitaireRules.canAutoComplete(_state!.board);

  void _resetMistakeTracking() {
    _invalidMoveAttempts = 0;
    _activeRuleTip = null;
    clearPendingDragRejection();
  }

  void clearRuleTip() {
    if (_activeRuleTip == null) return;
    _activeRuleTip = null;
    notifyListeners();
  }

  void noteRejectedDragTarget({
    required String reason,
    required Rect targetRect,
  }) {
    _pendingDragRejectionReason = reason;
    _pendingDragRejectionRect = targetRect;
  }

  void clearPendingDragRejection() {
    _pendingDragRejectionReason = null;
    _pendingDragRejectionRect = null;
  }

  String? consumeRejectedDragReason(Rect releaseRect) {
    final reason = _pendingDragRejectionReason;
    final targetRect = _pendingDragRejectionRect;
    clearPendingDragRejection();
    if (reason == null || targetRect == null) return null;
    return targetRect.overlaps(releaseRect) ? reason : null;
  }

  void handleCanceledDrag({
    required Offset? dragStartOffset,
    required Offset releaseOffset,
    required Size cardSize,
  }) {
    if (dragStartOffset != null &&
        (releaseOffset - dragStartOffset).distance >= 20.0) {
      final releaseRect = Rect.fromLTWH(
        releaseOffset.dx,
        releaseOffset.dy,
        cardSize.width,
        cardSize.height,
      ).inflate(12.0);
      final reason = consumeRejectedDragReason(releaseRect);
      recordInvalidMoveAttempt(reason: reason);
    } else {
      clearPendingDragRejection();
    }
  }

  void _syncElapsedNotifier() {
    final seconds = _state?.elapsedSeconds ?? 0;
    if (elapsedSecondsNotifier.value != seconds) {
      elapsedSecondsNotifier.value = seconds;
    }
  }

  void _scheduleDebouncedSave() {
    _hasPendingSave = true;
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 280), () {
      unawaited(_flushPendingSave());
    });
  }

  Future<void> _flushPendingSave({bool force = false}) async {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;
    final current = _state;
    if (current == null) {
      _hasPendingSave = false;
      return;
    }
    if (!force && !_hasPendingSave) return;
    _hasPendingSave = false;
    await _persistence.saveActiveGame(current);
  }

  Future<void> initialize() async {
    final saved = await _persistence.loadActiveGame();
    if (saved != null && !saved.isWon) {
      _state = saved;
      _syncElapsedNotifier();
      _ensureClockRunningIfNeeded();
      notifyListeners();
      return;
    }

    await startNewDeal(countAbandonedStreak: false);
  }

  /// Starts a fresh deal using current settings.
  Future<void> startNewDeal({
    DrawMode? overrideDrawMode,
    DealType? overrideDealType,
    bool countAbandonedStreak = true,
  }) async {
    _cancelAutoComplete();
    _saveDebounceTimer?.cancel();
    _hasPendingSave = false;
    _activeHint = null;
    _lastVisualEvent = null;
    _deadEndDialogVisible = false;
    _consecutiveStockCycles = 0;
    _usedHintThisHand = false;
    _usedUndoThisHand = false;
    _resetMistakeTracking();
    _tutorialOfferVisible = false;

    if (countAbandonedStreak &&
        _state != null &&
        _state!.hasStarted &&
        !_state!.isWon) {
      await _stats.recordAbandonedGame();
    }

    final drawMode = overrideDrawMode ?? _settings.settings.drawMode;
    final rawDealType = overrideDealType ?? _settings.settings.preferredDealType;
    final dealType =
        rawDealType == DealType.daily ? DealType.winnable : rawDealType;
    final baseSeed = _seedRng.nextInt(1 << 30);

    late final BoardSnapshot board;
    late final int seed;
    late final int? solvableIdx;

    if (dealType == DealType.winnable) {
      final generated = DealGenerator.generateWinnableDeal(
        baseSeed: baseSeed,
        drawMode: drawMode,
      );
      board = generated.board;
      seed = generated.resolvedSeed;
      solvableIdx = generated.verifiedWinnable ? 0 : null;
    } else {
      board = DealGenerator.generateRandomDeal(baseSeed);
      seed = baseSeed;
      solvableIdx = null;
    }

    _state = GameState(
      board: board,
      drawMode: drawMode,
      dealType: dealType,
      dealSeed: seed,
      undoHistory: <BoardSnapshot>[board],
      lastKnownSolvableHistoryIndex: solvableIdx,
    );

    _syncElapsedNotifier();
    _ensureClockRunningIfNeeded();
    notifyListeners();
    await _flushPendingSave(force: true);
    _analytics.logEvent('deal_started', <String, Object?>{
      'draw_mode': drawMode.name,
      'deal_type': dealType.name,
    });
  }

  /// Starts a deterministic offline Daily Challenge for [date].
  Future<void> startDailyDeal(DateTime date) async {
    _cancelAutoComplete();
    _saveDebounceTimer?.cancel();
    _hasPendingSave = false;
    _activeHint = null;
    _lastVisualEvent = null;
    _deadEndDialogVisible = false;
    _consecutiveStockCycles = 0;
    _usedHintThisHand = false;
    _usedUndoThisHand = false;
    _resetMistakeTracking();
    _tutorialOfferVisible = false;

    if (_state != null && _state!.hasStarted && !_state!.isWon) {
      await _stats.recordAbandonedGame();
    }

    final drawMode = _settings.settings.drawMode;
    final generated = DealGenerator.generateDailyDeal(date, drawMode);
    final dateKey = DealGenerator.formatDateKey(date);

    _state = GameState(
      board: generated.board,
      drawMode: drawMode,
      dealType: DealType.daily,
      dealSeed: generated.resolvedSeed,
      dailyDateKey: dateKey,
      undoHistory: <BoardSnapshot>[generated.board],
      lastKnownSolvableHistoryIndex: generated.verifiedWinnable ? 0 : null,
    );

    _syncElapsedNotifier();
    _ensureClockRunningIfNeeded();
    notifyListeners();
    await _flushPendingSave(force: true);
    _analytics.logEvent('daily_deal_started', <String, Object?>{
      'date': dateKey,
      'draw_mode': drawMode.name,
    });
  }

  /// Restarts the exact same seed/layout from move 0.
  Future<void> replaySameDeal() async {
    final current = _state;
    if (current == null) return;
    _cancelAutoComplete();
    _saveDebounceTimer?.cancel();
    _hasPendingSave = false;
    _activeHint = null;
    _lastVisualEvent = null;
    _deadEndDialogVisible = false;
    _consecutiveStockCycles = 0;
    _usedHintThisHand = false;
    _usedUndoThisHand = false;
    _resetMistakeTracking();
    _tutorialOfferVisible = false;

    final freshBoard = DealGenerator.generateRandomDeal(current.dealSeed);
    _state = GameState(
      board: freshBoard,
      drawMode: current.drawMode,
      dealType: current.dealType,
      dealSeed: current.dealSeed,
      dailyDateKey: current.dailyDateKey,
      undoHistory: <BoardSnapshot>[freshBoard],
      lastKnownSolvableHistoryIndex:
          (current.dealType == DealType.winnable ||
                  current.dealType == DealType.daily)
              ? 0
              : null,
    );

    _syncElapsedNotifier();
    _ensureClockRunningIfNeeded();
    notifyListeners();
    await _flushPendingSave(force: true);
  }

  Future<void> tapStock() async {
    if (_state == null || _state!.isWon || _isAutoCompleting) return;
    final move = TapResolver.resolveStockTap(_state!.board, _state!.drawMode);
    if (move == null) return;
    await performMove(move);
  }

  Future<bool> tapWaste() async {
    if (_state == null || _state!.isWon || _isAutoCompleting) return false;
    final move = TapResolver.resolveWasteTap(_state!.board);
    if (move == null) {
      if (_state!.board.waste.isNotEmpty) {
        recordInvalidMoveAttempt();
      }
      return false;
    }
    await performMove(move);
    return true;
  }

  Future<bool> tapTableauCard(int colIndex, int cardIndex) async {
    if (_state == null || _state!.isWon || _isAutoCompleting) return false;
    final move = TapResolver.resolveTableauTap(
      _state!.board,
      colIndex,
      cardIndex,
    );
    if (move == null) {
      if (colIndex >= 0 &&
          colIndex < 7 &&
          cardIndex >= 0 &&
          cardIndex < _state!.board.tableau[colIndex].length) {
        final tappedCard = _state!.board.tableau[colIndex][cardIndex];
        recordInvalidMoveAttempt(
          reason: tappedCard.isFaceUp
              ? null
              : 'Face-down cards flip automatically once the cards on top are cleared.',
        );
      }
      return false;
    }
    await performMove(move);
    return true;
  }

  Future<bool> tapFoundation(int foundationIndex) async {
    if (_state == null || _state!.isWon || _isAutoCompleting) return false;
    final move = TapResolver.resolveFoundationTap(
      _state!.board,
      foundationIndex,
    );
    if (move == null) {
      if (foundationIndex >= 0 &&
          foundationIndex < 4 &&
          _state!.board.foundations[foundationIndex].isNotEmpty) {
        recordInvalidMoveAttempt();
      }
      return false;
    }
    await performMove(move);
    return true;
  }

  /// Tracks consecutive illegal move attempts. After 3 mistakes, offers the
  /// Guided Tutorial to new players or displays a calm contextual hint/rule tip.
  void recordInvalidMoveAttempt({String? reason}) {
    if (_state == null ||
        _state!.isWon ||
        _isAutoCompleting ||
        _tutorialOfferVisible) {
      return;
    }
    _invalidMoveAttempts++;
    if (_invalidMoveAttempts < 3) return;
    _invalidMoveAttempts = 0;

    final settings = _settings.settings;
    final eligibleForTutorialOffer = !settings.tutorialCompleted &&
        !settings.tutorialPromptDismissed &&
        _stats.stats.gamesWon == 0;
    if (eligibleForTutorialOffer) {
      _activeRuleTip = null;
      _tutorialOfferVisible = true;
      _analytics.logEvent('tutorial_offer_triggered');
      notifyListeners();
      return;
    }

    if (reason != null && reason.isNotEmpty) {
      _activeHint = null;
      _activeRuleTip = reason;
      _analytics.logEvent('repeated_mistake_rule_tip');
      notifyListeners();
      return;
    }

    final suggestion = HintEngine.findSmartHint(
      _state!.board,
      _state!.drawMode,
      consecutiveStockCycles: _consecutiveStockCycles,
    );
    if (!suggestion.isDeadEnd && suggestion.move != null) {
      _activeRuleTip = null;
      _activeHint = suggestion;
      _analytics.logEvent('repeated_mistake_auto_hint', <String, Object?>{
        'kind': suggestion.move!.kind.name,
      });
    } else {
      _activeHint = null;
      _activeRuleTip =
          'No legal move for that card — draw from the deck or try Undo.';
    }
    notifyListeners();
  }

  void dismissTutorialOffer({required bool rememberDismissal}) {
    _resetMistakeTracking();
    if (rememberDismissal) {
      unawaited(_settings.setTutorialPromptDismissed(true));
    }
    if (!_tutorialOfferVisible) return;
    _tutorialOfferVisible = false;
    notifyListeners();
  }

  Future<bool> performMove(
    SolitaireMove move, {
    bool isDragMove = false,
  }) async {
    final current = _state;
    if (current == null || current.isWon) return false;

    late final BoardSnapshot nextBoard;
    try {
      nextBoard = SolitaireRules.applyMove(
        current.board,
        move,
        current.drawMode,
      );
    } catch (_) {
      return false;
    }

    final movedCards = _extractMovingCards(
      current.board,
      move,
      current.drawMode,
    );
    int? revealedCol;
    int? revealedIdx;
    if (move.kind == MoveKind.tableauToFoundation ||
        move.kind == MoveKind.tableauToTableau) {
      final fromIdx = move.fromPileIndex!;
      final fromCol = current.board.tableau[fromIdx];
      final count = move.kind == MoveKind.tableauToFoundation ? 1 : move.cardCount;
      final remaining = fromCol.length - count;
      if (remaining > 0 && !fromCol[remaining - 1].isFaceUp) {
        revealedCol = fromIdx;
        revealedIdx = remaining - 1;
      }
    }

    final wasStarted = current.hasStarted;
    final targetColumnWasEmpty =
        (move.kind == MoveKind.tableauToTableau ||
                move.kind == MoveKind.wasteToTableau ||
                move.kind == MoveKind.foundationToTableau) &&
            move.toPileIndex != null &&
            current.board.tableau[move.toPileIndex!].isEmpty;

    if (move.kind == MoveKind.recycleStock) {
      _consecutiveStockCycles++;
    } else if (move.kind != MoveKind.drawStock) {
      _consecutiveStockCycles = 0;
    }

    final won = SolitaireRules.isWon(nextBoard);
    final nextHistory = <BoardSnapshot>[...current.undoHistory, nextBoard];
    final landedFoundationIndex = (move.kind == MoveKind.wasteToFoundation ||
            move.kind == MoveKind.tableauToFoundation)
        ? move.toPileIndex
        : null;

    _visualSeq++;
    _lastVisualEvent = MoveVisualEvent(
      sequenceId: _visualSeq,
      move: move,
      movedCards: movedCards,
      isDragMove: isDragMove,
      isAutoCompleting: _isAutoCompleting,
      revealedTableauCol: revealedCol,
      revealedCardIndex: revealedIdx,
      landedFoundationIndex: landedFoundationIndex,
    );

    _activeHint = null;
    _resetMistakeTracking();
    _deadEndDialogVisible = false;
    _state = current.copyWith(
      board: nextBoard,
      movesCount: current.movesCount + 1,
      hasStarted: true,
      isWon: won,
      undoHistory: nextHistory,
    );
    _syncElapsedNotifier();

    if (landedFoundationIndex != null) {
      _audio.playFoundationPlace();
    } else if (move.kind == MoveKind.drawStock ||
        move.kind == MoveKind.recycleStock ||
        revealedCol != null) {
      _audio.playCardFlip();
    } else {
      _audio.playCardMove();
    }

    _ensureClockRunningIfNeeded();
    notifyListeners();

    if (!won && !_isAutoCompleting) {
      _scheduleDebouncedSave();
    }

    if (!wasStarted) {
      unawaited(_stats.recordGameStarted());
    }

    if (quests != null) {
      unawaited(
        quests!.recordMove(
          move: move,
          movedCards: movedCards,
          revealedHiddenCard: revealedCol != null,
          targetColumnWasEmpty: targetColumnWasEmpty,
        ),
      );
    }

    if (won) {
      await _handleWin();
    }
    return true;
  }

  List<PlayingCard> _extractMovingCards(
    BoardSnapshot board,
    SolitaireMove move,
    DrawMode drawMode,
  ) {
    switch (move.kind) {
      case MoveKind.drawStock:
        if (board.stock.isEmpty) return const <PlayingCard>[];
        final count = math.min(drawMode.drawCount, board.stock.length);
        return List<PlayingCard>.unmodifiable(
          List<PlayingCard>.generate(
            count,
            (i) => board.stock[board.stock.length - 1 - i].copyWith(
              isFaceUp: true,
            ),
          ),
        );
      case MoveKind.recycleStock:
        return const <PlayingCard>[];
      case MoveKind.wasteToFoundation:
      case MoveKind.wasteToTableau:
        if (board.waste.isEmpty) return const <PlayingCard>[];
        return <PlayingCard>[board.waste.last];
      case MoveKind.tableauToFoundation:
        final col = board.tableau[move.fromPileIndex!];
        if (col.isEmpty) return const <PlayingCard>[];
        return <PlayingCard>[col.last];
      case MoveKind.tableauToTableau:
        final col = board.tableau[move.fromPileIndex!];
        if (col.length < move.cardCount) return const <PlayingCard>[];
        return List<PlayingCard>.unmodifiable(
          col.sublist(col.length - move.cardCount),
        );
      case MoveKind.foundationToTableau:
        final pile = board.foundations[move.fromPileIndex!];
        if (pile.isEmpty) return const <PlayingCard>[];
        return <PlayingCard>[pile.last];
    }
  }

  Future<void> undo() async {
    final current = _state;
    if (current == null ||
        !current.canUndo ||
        current.isWon ||
        _isAutoCompleting) {
      return;
    }

    _activeHint = null;
    _resetMistakeTracking();
    _lastVisualEvent = null;
    _deadEndDialogVisible = false;
    _usedUndoThisHand = true;
    final nextHistory = current.undoHistory.sublist(
      0,
      current.undoHistory.length - 1,
    );
    _state = current.copyWith(
      board: nextHistory.last,
      movesCount: current.movesCount + 1,
      undoHistory: nextHistory,
    );

    _audio.playCardMove();
    notifyListeners();
    _scheduleDebouncedSave();
    if (quests != null) {
      unawaited(quests!.recordUndo());
    }
  }

  void requestHint() {
    final current = _state;
    if (current == null || current.isWon || _isAutoCompleting) return;

    final result = HintEngine.findSmartHint(
      current.board,
      current.drawMode,
      consecutiveStockCycles: _consecutiveStockCycles,
    );

    if (result.isDeadEnd || result.move == null) {
      _activeHint = null;
      _deadEndDialogVisible = true;
      _analytics.logEvent('dead_end_detected', <String, Object?>{
        'moves': current.movesCount,
      });
    } else {
      _usedHintThisHand = true;
      _resetMistakeTracking();
      _activeHint = result;
      _deadEndDialogVisible = false;
      _analytics.logEvent('hint_requested', <String, Object?>{
        'kind': result.move!.kind.name,
      });
      if (quests != null) {
        unawaited(quests!.recordHintUsed());
      }
    }
    notifyListeners();
  }

  void dismissDeadEndDialog() {
    if (!_deadEndDialogVisible) return;
    _deadEndDialogVisible = false;
    notifyListeners();
  }

  void clearHint() {
    if (_activeHint == null) return;
    _activeHint = null;
    notifyListeners();
  }

  /// Walks backward through move history to find the latest proven solvable
  /// checkpoint so the player doesn't have to hammer Undo repeatedly.
  Future<bool> smartRewind() async {
    final current = _state;
    if (current == null || current.undoHistory.length <= 1) {
      return false;
    }

    _activeHint = null;
    _resetMistakeTracking();
    _lastVisualEvent = null;
    _deadEndDialogVisible = false;

    int? targetIndex;
    for (var i = current.undoHistory.length - 2; i >= 0; i--) {
      if (KlondikeSolver.isSolvableQuick(
        current.undoHistory[i],
        current.drawMode,
        maxNodes: 900,
      )) {
        targetIndex = i;
        break;
      }
    }

    targetIndex ??= current.lastKnownSolvableHistoryIndex;
    if (targetIndex == null || targetIndex >= current.undoHistory.length) {
      return false;
    }

    final rewoundHistory = current.undoHistory.sublist(0, targetIndex + 1);
    _state = current.copyWith(
      board: rewoundHistory.last,
      undoHistory: rewoundHistory,
      lastKnownSolvableHistoryIndex: targetIndex,
    );
    _consecutiveStockCycles = 0;
    _usedUndoThisHand = true;

    _audio.playCardFlip();
    notifyListeners();
    await _flushPendingSave(force: true);
    _analytics.logEvent('smart_rewind_used', <String, Object?>{
      'restored_index': targetIndex,
    });
    return true;
  }

  void triggerAutoComplete() {
    if (!canAutoComplete) return;
    _isAutoCompleting = true;
    _activeHint = null;
    _resetMistakeTracking();
    _deadEndDialogVisible = false;
    notifyListeners();
    if (quests != null) {
      unawaited(quests!.recordAutoCompleteUsed());
    }

    _autoCompleteTimer?.cancel();
    _autoCompleteTimer = Timer.periodic(const Duration(milliseconds: 115), (
      timer,
    ) async {
      final current = _state;
      if (current == null || current.isWon) {
        timer.cancel();
        _isAutoCompleting = false;
        notifyListeners();
        unawaited(_flushPendingSave());
        return;
      }
      final nextMove = SolitaireRules.nextAutoCompleteMove(current.board);
      if (nextMove == null) {
        timer.cancel();
        _isAutoCompleting = false;
        notifyListeners();
        unawaited(_flushPendingSave(force: true));
        return;
      }
      await performMove(nextMove);
    });
  }

  void handleLifecycleChange(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _isLifecyclePaused = true;
        _clockTimer?.cancel();
        _clockTimer = null;
        _audio.pauseAll();
        unawaited(_flushPendingSave(force: true));
      case AppLifecycleState.resumed:
        _isLifecyclePaused = false;
        _audio.resumeIfEnabled();
        _ensureClockRunningIfNeeded();
    }
  }

  Future<void> _handleWin() async {
    _cancelAutoComplete();
    _clockTimer?.cancel();
    _clockTimer = null;
    final current = _state!;
    _audio.playWin();
    await _flushPendingSave(force: true);
    await _stats.recordWin(
      moves: current.movesCount,
      elapsedSeconds: current.elapsedSeconds,
      dailyDateKey: current.dailyDateKey,
    );
    if (quests != null) {
      await quests!.recordWin(
        usedHintInHand: _usedHintThisHand,
        usedUndoInHand: _usedUndoThisHand,
        drawMode: current.drawMode,
        dealType: current.dealType,
        isDaily: current.dealType == DealType.daily,
        currentStreak: _stats.stats.currentStreak,
        movesCount: current.movesCount,
        elapsedSeconds: current.elapsedSeconds,
      );
    }
    await _monetization.onGameCompleted();
    _analytics.logEvent('game_won', <String, Object?>{
      'moves': current.movesCount,
      'seconds': current.elapsedSeconds,
      'deal_type': current.dealType.name,
      'draw_mode': current.drawMode.name,
    });
  }

  void _ensureClockRunningIfNeeded() {
    final current = _state;
    if (current == null ||
        !current.hasStarted ||
        current.isWon ||
        _isLifecyclePaused) {
      _clockTimer?.cancel();
      _clockTimer = null;
      return;
    }

    if (_clockTimer != null && _clockTimer!.isActive) return;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final active = _state;
      if (active == null || !active.hasStarted || active.isWon) return;
      final nextSeconds = active.elapsedSeconds + 1;
      _state = active.copyWith(elapsedSeconds: nextSeconds);
      elapsedSecondsNotifier.value = nextSeconds;
      // Persist elapsed clock periodically even without moves.
      if (nextSeconds % 5 == 0) {
        _scheduleDebouncedSave();
      }
    });
  }

  void _cancelAutoComplete() {
    _autoCompleteTimer?.cancel();
    _autoCompleteTimer = null;
    _isAutoCompleting = false;
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _autoCompleteTimer?.cancel();
    _saveDebounceTimer?.cancel();
    elapsedSecondsNotifier.dispose();
    super.dispose();
  }
}
