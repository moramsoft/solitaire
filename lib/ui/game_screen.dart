import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import '../engine/engine.dart';
import '../state/game_controller.dart';
import '../state/quest_controller.dart';
import '../state/settings_controller.dart';
import '../state/stats_controller.dart';
import '../theme/app_theme.dart';
import '../theme/deck_palette.dart';
import 'strings.dart';
import 'tutorial_screen.dart';
import 'widgets/bottom_action_bar.dart';
import 'widgets/card_back_painter.dart';
import 'widgets/daily_sheet.dart';
import 'widgets/playing_card_widget.dart';
import 'widgets/quest_banner.dart';
import 'widgets/quests_sheet.dart';
import 'widgets/settings_sheet.dart';
import 'widgets/stats_sheet.dart';
import 'widgets/suit_painter.dart';
import 'widgets/table_background.dart';
import 'widgets/win_cascade_overlay.dart';

/// Deterministic helper calculating Y-offsets for each card in a tableau column
/// so flying card targets land to the exact pixel without vertical overflow.
({List<double> tops, double upStep, double downStep})
    _computeTableauLayoutOffsets({
  required List<PlayingCard> cards,
  required double cardHeight,
  required double maxColumnHeight,
  required CardScale cardScale,
}) {
  final isJumbo = cardScale == CardScale.jumbo;
  var downStep = (cardHeight * 0.16).clamp(9.0, 18.0);
  var upStep = (cardHeight * (isJumbo ? 0.42 : 0.37)).clamp(22.0, 56.0);

  if (cards.isEmpty) {
    return (tops: const <double>[], upStep: upStep, downStep: downStep);
  }

  var rawOffsets = 0.0;
  for (var i = 0; i < cards.length - 1; i++) {
    rawOffsets += cards[i].isFaceUp ? upStep : downStep;
  }
  final availableOffsets =
      (maxColumnHeight - cardHeight - 4.0).clamp(0.0, maxColumnHeight);
  if (rawOffsets > availableOffsets && rawOffsets > 0) {
    final scale = availableOffsets / rawOffsets;
    downStep *= scale;
    upStep *= scale;
  }

  final tops = <double>[0.0];
  for (var i = 0; i < cards.length - 1; i++) {
    tops.add(tops[i] + (cards[i].isFaceUp ? upStep : downStep));
  }
  return (tops: tops, upStep: upStep, downStep: downStep);
}

/// Computes the exact horizontal offset inside the combined Waste+Gap container
/// for a card at [indexFromBottom] in the visible Waste fan.
double _wasteCardLeftOffset({
  required int indexFromBottom,
  required int visibleCount,
  required double cardWidth,
  required double colGap,
  required bool leftHanded,
}) {
  assert(visibleCount >= 1);
  final fanStep = (cardWidth * 0.24).clamp(10.0, 26.0);
  if (!leftHanded) {
    return indexFromBottom * fanStep;
  }
  return (cardWidth + colGap) - indexFromBottom * fanStep;
}

class _BoardGeometry {
  const _BoardGeometry({
    required this.boardWidth,
    required this.cardWidth,
    required this.cardHeight,
    required this.colGap,
    required this.rowSpacing,
    required this.tableauMaxHeight,
  });

  final double boardWidth;
  final double cardWidth;
  final double cardHeight;
  final double colGap;
  final double rowSpacing;
  final double tableauMaxHeight;

  double get effectiveColGap =>
      ((boardWidth - cardWidth * 7) / 6).clamp(0.0, 200.0);

  static _BoardGeometry compute(
    BoxConstraints constraints, {
    required double shortestSide,
  }) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final isTabletLandscape =
        shortestSide >= 600 && width > height && width >= 700;
    final sidePadding = isTabletLandscape ? 24.0 : 4.0;
    final boardWidth = isTabletLandscape
        ? math.min(width - sidePadding * 2, 920.0)
        : (width - sidePadding * 2);
    final colGap = isTabletLandscape ? 12.0 : 2.5;
    final rawCardWidth = (boardWidth - colGap * 6) / 7;
    final maxCardHeightFromHeight = isTabletLandscape
        ? ((height - 20.0) * 0.24).clamp(52.0, 210.0)
        : ((height - 16.0) * 0.265).clamp(52.0, 210.0);
    final cardWidth = math
        .min(rawCardWidth, maxCardHeightFromHeight / 1.48)
        .clamp(36.0, 130.0);
    final cardHeight = cardWidth * 1.48;
    final rowSpacing = isTabletLandscape ? 16.0 : 12.0;
    // Top pad (12) + bottom pad (4) + cardHeight + rowSpacing
    final tableauMaxHeight =
        (height - 16.0 - cardHeight - rowSpacing).clamp(cardHeight, height);

    return _BoardGeometry(
      boardWidth: boardWidth,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      colGap: colGap,
      rowSpacing: rowSpacing,
      tableauMaxHeight: tableauMaxHeight,
    );
  }
}

/// Main responsive Klondike Solitaire screen designed for Phone Portrait
/// and Tablet Landscape comfort with tactile Heritage animations.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.gameController,
    required this.settingsController,
    required this.statsController,
    this.questController,
  });

  final GameController gameController;
  final SettingsController settingsController;
  final StatsController statsController;
  final QuestController? questController;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final GlobalKey _boardOverlayKey = GlobalKey();
  final GlobalKey _stockKey = GlobalKey();
  final GlobalKey _wasteKey = GlobalKey();
  final List<GlobalKey> _foundationKeys =
      List<GlobalKey>.generate(4, (_) => GlobalKey());
  final List<GlobalKey> _tableauColKeys =
      List<GlobalKey>.generate(7, (_) => GlobalKey());

  late final AnimationController _flightController;
  late final AnimationController _flipController;
  late final AnimationController _shimmerController;

  bool _deadEndModalOpen = false;
  bool _tutorialOfferModalOpen = false;
  final Set<DeckFaceStyle> _precachedFaceStyles = <DeckFaceStyle>{};
  int _handledVisualSeq = 0;
  late DeckFaceStyle _lastFaceStyle;
  late TableThemeId _lastTableTheme;
  late CardBackStyle _lastCardBackStyle;

  // Active card flight state
  List<PlayingCard> _flightCards = const <PlayingCard>[];
  Rect? _flightFromRect;
  Rect? _flightToRect;
  List<Rect> _flightToRects = const <Rect>[];
  double _flightFromUpStep = 24.0;
  double _flightToUpStep = 24.0;
  MoveKind? _flightDestKind;
  int? _flightDestPileIndex;

  // Active 3D tableau card flip state
  int? _flipColIndex;
  int? _flipCardIndex;

  // Active foundation shimmer state
  int? _shimmerFoundationIndex;

  // Active tableau drag origin for hiding child cards in the dragged run
  int? _draggingTableauCol;
  int? _draggingTableauStartIdx;

  // Remaining card count per foundation pile during WinCascadeOverlay finale
  List<int>? _winCascadeRemainingCounts;

  _BoardGeometry? _lastGeometry;

  @override
  void initState() {
    super.initState();
    _flightController = AnimationController(
      vsync: this,
      duration: ClearDeckTheme.flightDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _flightCards = const <PlayingCard>[];
            _flightFromRect = null;
            _flightToRect = null;
            _flightToRects = const <Rect>[];
            _flightDestKind = null;
            _flightDestPileIndex = null;
          });
        }
      });

    _flipController = AnimationController(
      vsync: this,
      duration: ClearDeckTheme.flipDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _flipColIndex = null;
            _flipCardIndex = null;
          });
        }
      });

    _shimmerController = AnimationController(
      vsync: this,
      duration: ClearDeckTheme.settleDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _shimmerFoundationIndex = null;
          });
        }
      });

    final initialSettings = widget.settingsController.settings;
    _lastFaceStyle = initialSettings.deckFaceStyle;
    _lastTableTheme = initialSettings.tableTheme;
    _lastCardBackStyle = initialSettings.cardBackStyle;
    widget.gameController.addListener(_onGameStateChanged);
    widget.settingsController.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final current = widget.settingsController.settings;
    _precacheFaceStyle(current.deckFaceStyle);
    if (current.deckFaceStyle != _lastFaceStyle) {
      _lastFaceStyle = current.deckFaceStyle;
      if (widget.questController != null) {
        unawaited(widget.questController!.recordFaceStyleChanged());
      }
    }
    if (current.tableTheme != _lastTableTheme ||
        current.cardBackStyle != _lastCardBackStyle) {
      _lastTableTheme = current.tableTheme;
      _lastCardBackStyle = current.cardBackStyle;
      if (widget.questController != null) {
        unawaited(widget.questController!.recordThemeOrBackChanged());
      }
    }
  }

  void _precacheFaceStyle(DeckFaceStyle style) {
    if (!_precachedFaceStyles.add(style)) return;
    for (final rank in const <int>[11, 12, 13]) {
      final path = CourtCrestWidget.assetPathFor(style, rank);
      if (path != null) {
        unawaited(
          precacheImage(AssetImage(path), context).catchError((_) {}),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheFaceStyle(widget.settingsController.settings.deckFaceStyle);
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameController != widget.gameController) {
      oldWidget.gameController.removeListener(_onGameStateChanged);
      widget.gameController.addListener(_onGameStateChanged);
    }
    if (oldWidget.settingsController != widget.settingsController) {
      oldWidget.settingsController.removeListener(_onSettingsChanged);
      widget.settingsController.addListener(_onSettingsChanged);
      final current = widget.settingsController.settings;
      _lastFaceStyle = current.deckFaceStyle;
      _lastTableTheme = current.tableTheme;
      _lastCardBackStyle = current.cardBackStyle;
      _precacheFaceStyle(current.deckFaceStyle);
    }
  }

  @override
  void dispose() {
    widget.gameController.removeListener(_onGameStateChanged);
    widget.settingsController.removeListener(_onSettingsChanged);
    _flightController.dispose();
    _flipController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _clearTableauDragState() {
    if (!mounted) return;
    if (_draggingTableauCol != null || _draggingTableauStartIdx != null) {
      setState(() {
        _draggingTableauCol = null;
        _draggingTableauStartIdx = null;
      });
    }
  }

  void _cancelActiveVisuals() {
    _flightController.stop();
    _flipController.stop();
    _shimmerController.stop();
    if (mounted &&
        (_flightCards.isNotEmpty ||
            _flipColIndex != null ||
            _shimmerFoundationIndex != null ||
            _draggingTableauCol != null ||
            _draggingTableauStartIdx != null ||
            _winCascadeRemainingCounts != null)) {
      setState(() {
        _flightCards = const <PlayingCard>[];
        _flightFromRect = null;
        _flightToRect = null;
        _flightToRects = const <Rect>[];
        _flightDestKind = null;
        _flightDestPileIndex = null;
        _flipColIndex = null;
        _flipCardIndex = null;
        _shimmerFoundationIndex = null;
        _draggingTableauCol = null;
        _draggingTableauStartIdx = null;
        _winCascadeRemainingCounts = null;
      });
    } else {
      _draggingTableauCol = null;
      _draggingTableauStartIdx = null;
      _winCascadeRemainingCounts = null;
    }
  }

  void _onGameStateChanged() {
    if (!mounted || !widget.gameController.isReady) return;

    if (!widget.gameController.state.isWon &&
        _winCascadeRemainingCounts != null) {
      setState(() {
        _winCascadeRemainingCounts = null;
      });
    }

    final visual = widget.gameController.lastVisualEvent;
    if (visual == null) {
      _cancelActiveVisuals();
    } else if (visual.sequenceId != _handledVisualSeq) {
      _handledVisualSeq = visual.sequenceId;
      _triggerVisualTransitions(visual);
    }

    if (widget.gameController.deadEndDialogVisible && !_deadEndModalOpen) {
      _deadEndModalOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDeadEndDialog();
      });
    } else if (widget.gameController.tutorialOfferVisible &&
        !_tutorialOfferModalOpen &&
        !_deadEndModalOpen) {
      _tutorialOfferModalOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showTutorialOfferDialog();
      });
    }
  }

  void _triggerVisualTransitions(MoveVisualEvent event) {
    final geo = _lastGeometry;
    final state = widget.gameController.state;
    final settings = widget.settingsController.settings;

    _draggingTableauCol = null;
    _draggingTableauStartIdx = null;

    if (event.isDragMove ||
        event.move.kind == MoveKind.recycleStock ||
        _flightController.isAnimating) {
      _flightController.stop();
      _flightCards = const <PlayingCard>[];
      _flightFromRect = null;
      _flightToRect = null;
      _flightToRects = const <Rect>[];
      _flightDestKind = null;
      _flightDestPileIndex = null;
    }

    // 1. 3D card flip on newly exposed tableau card
    if (event.revealedTableauCol != null && event.revealedCardIndex != null) {
      _flipColIndex = event.revealedTableauCol;
      _flipCardIndex = event.revealedCardIndex;
      _flipController.forward(from: 0.0);
    }

    // 2. Antique-gold shimmer when landing on foundation
    if (event.landedFoundationIndex != null) {
      _shimmerFoundationIndex = event.landedFoundationIndex;
      _shimmerController.forward(from: 0.0);
    }

    // 3. Smooth curved card flight (skip for recycleStock or manual finger drag)
    if (!event.isDragMove &&
        event.movedCards.isNotEmpty &&
        event.move.kind != MoveKind.recycleStock &&
        geo != null) {
      final preBoard = state.undoHistory.length >= 2
          ? state.undoHistory[state.undoHistory.length - 2]
          : state.board;

      final fromRect = _resolveMoveSourceRect(
        event.move,
        preBoard,
        state.drawMode,
        geo,
        settings.cardScale,
        settings.leftHanded,
      );

      if (event.move.kind == MoveKind.drawStock) {
        final toRects = _resolveDrawStockDestRects(
          postBoard: state.board,
          drawMode: state.drawMode,
          drawnCount: event.movedCards.length,
          geo: geo,
          leftHanded: settings.leftHanded,
        );
        if (fromRect != null && toRects.length == event.movedCards.length) {
          _flightCards = event.movedCards;
          _flightFromRect = fromRect;
          _flightToRect = toRects.last;
          _flightToRects = toRects;
          _flightFromUpStep = geo.cardHeight * 0.30;
          _flightToUpStep = geo.cardHeight * 0.30;
          _flightDestKind = event.move.kind;
          _flightDestPileIndex = event.move.toPileIndex;
          _flightController.duration = event.isAutoCompleting
              ? ClearDeckTheme.autoFlightDuration
              : ClearDeckTheme.flightDuration;
          _flightController.forward(from: 0.0);
        }
        return;
      }

      final toRect = _resolveMoveDestRect(
        event.move,
        state.board,
        event.movedCards.length,
        geo,
        settings.cardScale,
      );

      if (fromRect != null && toRect != null) {
        final fromUpStep = (event.move.kind == MoveKind.tableauToTableau &&
                event.move.fromPileIndex != null)
            ? _computeTableauLayoutOffsets(
                cards: preBoard.tableau[event.move.fromPileIndex!],
                cardHeight: geo.cardHeight,
                maxColumnHeight: geo.tableauMaxHeight,
                cardScale: settings.cardScale,
              ).upStep
            : (geo.cardHeight * 0.30);

        final toUpStep = ((event.move.kind == MoveKind.tableauToTableau ||
                    event.move.kind == MoveKind.wasteToTableau ||
                    event.move.kind == MoveKind.foundationToTableau) &&
                event.move.toPileIndex != null)
            ? _computeTableauLayoutOffsets(
                cards: state.board.tableau[event.move.toPileIndex!],
                cardHeight: geo.cardHeight,
                maxColumnHeight: geo.tableauMaxHeight,
                cardScale: settings.cardScale,
              ).upStep
            : fromUpStep;

        _flightCards = event.movedCards;
        _flightFromRect = fromRect;
        _flightToRect = toRect;
        _flightToRects = <Rect>[toRect];
        _flightFromUpStep = fromUpStep;
        _flightToUpStep = toUpStep;
        _flightDestKind = event.move.kind;
        _flightDestPileIndex = event.move.toPileIndex;
        _flightController.duration = event.isAutoCompleting
            ? ClearDeckTheme.autoFlightDuration
            : ClearDeckTheme.flightDuration;
        _flightController.forward(from: 0.0);
      }
    }
  }

  Rect? _localRectForKey(GlobalKey key, Size expectedSize) {
    final overlayObj = _boardOverlayKey.currentContext?.findRenderObject();
    final targetObj = key.currentContext?.findRenderObject();
    if (overlayObj is! RenderBox ||
        targetObj is! RenderBox ||
        !overlayObj.attached ||
        !targetObj.attached) {
      return null;
    }
    final topLeft = targetObj.localToGlobal(Offset.zero, ancestor: overlayObj);
    return topLeft & expectedSize;
  }

  Rect? _resolveMoveSourceRect(
    SolitaireMove move,
    BoardSnapshot preBoard,
    DrawMode drawMode,
    _BoardGeometry geo,
    CardScale scale,
    bool leftHanded,
  ) {
    final cardSize = Size(geo.cardWidth, geo.cardHeight);
    switch (move.kind) {
      case MoveKind.drawStock:
        return _localRectForKey(_stockKey, cardSize);
      case MoveKind.recycleStock:
        return null;
      case MoveKind.wasteToFoundation:
      case MoveKind.wasteToTableau:
        final slotSize =
            Size(geo.cardWidth * 2 + geo.effectiveColGap, geo.cardHeight);
        final wasteSlotRect = _localRectForKey(_wasteKey, slotSize);
        if (wasteSlotRect == null) return null;
        final visibleCount = drawMode == DrawMode.draw3
            ? math.min(3, preBoard.waste.length)
            : 1;
        final indexFromBottom = math.max(0, visibleCount - 1);
        final dx = _wasteCardLeftOffset(
          indexFromBottom: indexFromBottom,
          visibleCount: math.max(1, visibleCount),
          cardWidth: geo.cardWidth,
          colGap: geo.effectiveColGap,
          leftHanded: leftHanded,
        );
        return Rect.fromLTWH(
          wasteSlotRect.left + dx,
          wasteSlotRect.top,
          geo.cardWidth,
          geo.cardHeight,
        );
      case MoveKind.tableauToFoundation:
      case MoveKind.tableauToTableau:
        final fromCol = move.fromPileIndex;
        if (fromCol == null) return null;
        final colRect = _localRectForKey(_tableauColKeys[fromCol], cardSize);
        if (colRect == null) return null;
        final colCards = preBoard.tableau[fromCol];
        final count =
            move.kind == MoveKind.tableauToFoundation ? 1 : move.cardCount;
        final startIdx = (colCards.length - count).clamp(0, colCards.length);
        final layout = _computeTableauLayoutOffsets(
          cards: colCards,
          cardHeight: geo.cardHeight,
          maxColumnHeight: geo.tableauMaxHeight,
          cardScale: scale,
        );
        final dy = startIdx < layout.tops.length ? layout.tops[startIdx] : 0.0;
        return colRect.shift(Offset(0, dy));
      case MoveKind.foundationToTableau:
        final fromF = move.fromPileIndex;
        if (fromF == null) return null;
        return _localRectForKey(_foundationKeys[fromF], cardSize);
    }
  }

  List<Rect> _resolveDrawStockDestRects({
    required BoardSnapshot postBoard,
    required DrawMode drawMode,
    required int drawnCount,
    required _BoardGeometry geo,
    required bool leftHanded,
  }) {
    final slotSize =
        Size(geo.cardWidth * 2 + geo.effectiveColGap, geo.cardHeight);
    final wasteSlotRect = _localRectForKey(_wasteKey, slotSize);
    if (wasteSlotRect == null || postBoard.waste.isEmpty) {
      return const <Rect>[];
    }
    final totalWaste = postBoard.waste.length;
    final visibleTotal =
        drawMode == DrawMode.draw3 ? math.min(3, totalWaste) : 1;
    final fanStartIdx = totalWaste - visibleTotal;
    final arrivalStartIdx = (totalWaste - drawnCount).clamp(0, totalWaste);

    return List<Rect>.generate(drawnCount, (k) {
      final wasteIdx = arrivalStartIdx + k;
      final maxFanIndex = math.max(0, visibleTotal - 1);
      final indexFromBottom =
          (wasteIdx - fanStartIdx).clamp(0, maxFanIndex).toInt();
      final dx = _wasteCardLeftOffset(
        indexFromBottom: indexFromBottom,
        visibleCount: math.max(1, visibleTotal),
        cardWidth: geo.cardWidth,
        colGap: geo.effectiveColGap,
        leftHanded: leftHanded,
      );
      return Rect.fromLTWH(
        wasteSlotRect.left + dx,
        wasteSlotRect.top,
        geo.cardWidth,
        geo.cardHeight,
      );
    });
  }

  Rect? _resolveMoveDestRect(
    SolitaireMove move,
    BoardSnapshot postBoard,
    int movedCount,
    _BoardGeometry geo,
    CardScale scale,
  ) {
    final cardSize = Size(geo.cardWidth, geo.cardHeight);
    switch (move.kind) {
      case MoveKind.drawStock:
        return _localRectForKey(_wasteKey, cardSize);
      case MoveKind.recycleStock:
        return null;
      case MoveKind.wasteToFoundation:
      case MoveKind.tableauToFoundation:
        final toF = move.toPileIndex;
        if (toF == null) return null;
        return _localRectForKey(_foundationKeys[toF], cardSize);
      case MoveKind.wasteToTableau:
      case MoveKind.tableauToTableau:
      case MoveKind.foundationToTableau:
        final toCol = move.toPileIndex;
        if (toCol == null) return null;
        final colRect = _localRectForKey(_tableauColKeys[toCol], cardSize);
        if (colRect == null) return null;
        final colCards = postBoard.tableau[toCol];
        final landedIdx =
            (colCards.length - movedCount).clamp(0, colCards.length);
        final layout = _computeTableauLayoutOffsets(
          cards: colCards,
          cardHeight: geo.cardHeight,
          maxColumnHeight: geo.tableauMaxHeight,
          cardScale: scale,
        );
        final dy = landedIdx < layout.tops.length ? layout.tops[landedIdx] : 0.0;
        return colRect.shift(Offset(0, dy));
    }
  }

  Future<void> _showDeadEndDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.deadEndTitle),
        content: const Text(AppStrings.deadEndBody),
        actions: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(ctx).pop();
                  final ok = await widget.gameController.smartRewind();
                  if (!ok && mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Earlier moves in this random deal were also unsolvable. Try Replay or New Deal.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.fast_rewind_rounded, size: 18),
                label: const Text(AppStrings.smartRewindButton),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await widget.gameController.replaySameDeal();
                },
                child: const Text(AppStrings.replayDealButton),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await widget.gameController.startNewDeal();
                },
                child: const Text(AppStrings.newDealButton),
              ),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () {
                  widget.gameController.dismissDeadEndDialog();
                  Navigator.of(ctx).pop();
                },
                child: const Text(AppStrings.dismissButton),
              ),
            ],
          ),
        ],
      ),
    );
    _deadEndModalOpen = false;
    widget.gameController.dismissDeadEndDialog();
  }

  Future<void> _showTutorialOfferDialog() async {
    var handledChoice = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.tutorialOfferTitle),
        content: const Text(AppStrings.tutorialOfferBody),
        actions: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FilledButton.icon(
                key: const Key('tutorial_offer_accept'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () {
                  handledChoice = true;
                  Navigator.of(ctx).pop();
                  widget.gameController
                      .dismissTutorialOffer(rememberDismissal: false);
                  _openTutorialScreen();
                },
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text(AppStrings.startTutorialButton),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('tutorial_offer_decline'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () {
                  handledChoice = true;
                  Navigator.of(ctx).pop();
                  widget.gameController
                      .dismissTutorialOffer(rememberDismissal: true);
                },
                child: const Text(AppStrings.declineTutorialButton),
              ),
            ],
          ),
        ],
      ),
    );
    _tutorialOfferModalOpen = false;
    if (!handledChoice) {
      widget.gameController.dismissTutorialOffer(rememberDismissal: false);
    }
  }

  void _openQuestsSheet({String? highlightQuestId}) {
    final qc = widget.questController;
    if (qc == null) return;
    final theme = ClearDeckTheme.fromId(
      widget.settingsController.settings.tableTheme,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: QuestsSheet(
          theme: theme,
          questController: qc,
          highlightQuestId: highlightQuestId,
        ),
      ),
    );
  }

  void _openTutorialScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TutorialScreen(
          settingsController: widget.settingsController,
          audioService: widget.gameController.audio,
          onTutorialCompleted: widget.questController == null
              ? null
              : () => unawaited(
                    widget.questController!.recordTutorialCompleted(),
                  ),
        ),
      ),
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: SettingsSheet(
          settingsController: widget.settingsController,
          gameController: widget.gameController,
          onOpenDaily: _openDailySheet,
          onOpenStats: _openStatsSheet,
          onOpenQuests: widget.questController == null ? null : _openQuestsSheet,
          onOpenTutorial: _openTutorialScreen,
        ),
      ),
    );
  }

  void _openDailySheet() {
    final theme = ClearDeckTheme.fromId(
      widget.settingsController.settings.tableTheme,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: DailyChallengeSheet(
          theme: theme,
          statsController: widget.statsController,
          gameController: widget.gameController,
        ),
      ),
    );
  }

  void _openStatsSheet() {
    final theme = ClearDeckTheme.fromId(
      widget.settingsController.settings.tableTheme,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.72,
        child: StatsSheet(
          theme: theme,
          statsController: widget.statsController,
        ),
      ),
    );
  }

  void _openNewDealDialog() {
    final theme = ClearDeckTheme.fromId(
      widget.settingsController.settings.tableTheme,
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.sheetSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Text(
                  'Start a Deal',
                  style: TextStyle(
                    color: theme.sheetText,
                    fontFamily: 'Georgia',
                    fontFamilyFallback: const <String>[
                      'Times New Roman',
                      'Noto Serif',
                      'serif',
                    ],
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await widget.gameController.startNewDeal();
                  },
                  icon: const Icon(Icons.style_rounded, size: 18),
                  label: const Text(AppStrings.newDealButton),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await widget.gameController.replaySameDeal();
                  },
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text(AppStrings.replayDealButton),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openDailySheet();
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('Daily Challenge'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openTutorialScreen();
                  },
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text(AppStrings.howToPlayLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.gameController,
        widget.settingsController,
        widget.statsController,
        if (widget.questController != null) widget.questController!,
      ]),
      builder: (context, _) {
        final settings = widget.settingsController.settings;
        final theme = ClearDeckTheme.fromId(settings.tableTheme);
        final activeQuestBanner = widget.questController?.activeBannerQuest;

        if (!widget.gameController.isReady) {
          return Scaffold(
            backgroundColor: theme.tableBackground,
            body: TableBackground(
              theme: theme,
              child: Center(
                child: CircularProgressIndicator(color: theme.textOnTable),
              ),
            ),
          );
        }

        final state = widget.gameController.state;
        final hint = widget.gameController.activeHint;
        final ruleTip = widget.gameController.activeRuleTip;
        final stats = widget.statsController.stats;

        // Apply 14.0dp jitter tolerance so slight hand tremor never steals taps.
        final baseMedia = MediaQuery.of(context);
        final shortestSide = baseMedia.size.shortestSide;
        final overlayStyle = (theme.isDarkTable
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: MediaQuery(
            data: baseMedia.copyWith(
              textScaler: baseMedia.textScaler.clamp(
                minScaleFactor: 1.0,
                maxScaleFactor: 1.25,
              ),
              gestureSettings: const DeviceGestureSettings(touchSlop: 14.0),
            ),
            child: Scaffold(
              backgroundColor: theme.tableBackground,
              body: TableBackground(
                theme: theme,
                child: SafeArea(
                  child: Column(
                    children: <Widget>[
                      _TopStatusBar(
                        theme: theme,
                        state: state,
                        showTimer: settings.showTimer,
                        elapsedSecondsListenable:
                            widget.gameController.elapsedSecondsNotifier,
                        onOpenDaily: _openDailySheet,
                        onOpenStats: _openStatsSheet,
                      ),
                      if (hint != null &&
                          hint.move != null &&
                          !state.isWon)
                        _HintBannerStrip(
                          key: const Key('hint_banner'),
                          reason: hint.reason,
                          theme: theme,
                          onDismiss: widget.gameController.clearHint,
                        )
                      else if (ruleTip != null && !state.isWon)
                        _HintBannerStrip(
                          key: const Key('rule_tip_banner'),
                          reason: ruleTip,
                          theme: theme,
                          icon: Icons.info_outline_rounded,
                          onDismiss: widget.gameController.clearRuleTip,
                        ),
                      Expanded(
                        child: Stack(
                          key: _boardOverlayKey,
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            RepaintBoundary(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final geo = _BoardGeometry.compute(
                                    constraints,
                                    shortestSide: shortestSide,
                                  );
                                  _lastGeometry = geo;
                                  return _PlayableBoardArea(
                                    geometry: geo,
                                    containerHeight: constraints.maxHeight,
                                    state: state,
                                    settings: settings,
                                    theme: theme,
                                    hintMove: hint?.move,
                                    controller: widget.gameController,
                                    stockKey: _stockKey,
                                    wasteKey: _wasteKey,
                                    foundationKeys: _foundationKeys,
                                    tableauColKeys: _tableauColKeys,
                                    flightAnimation: _flightController,
                                    flightDestKind: _flightDestKind,
                                    flightDestPileIndex: _flightDestPileIndex,
                                    flightHideCount: _flightCards.length,
                                    flipController: _flipController,
                                    flipColIndex: _flipColIndex,
                                    flipCardIndex: _flipCardIndex,
                                    shimmerController: _shimmerController,
                                    shimmerFoundationIndex:
                                        _shimmerFoundationIndex,
                                    draggingTableauCol: _draggingTableauCol,
                                    draggingTableauStartIdx:
                                        _draggingTableauStartIdx,
                                    onTableauDragStarted: (col, idx) {
                                      setState(() {
                                        _draggingTableauCol = col;
                                        _draggingTableauStartIdx = idx;
                                      });
                                    },
                                    onTableauDragFinished:
                                        _clearTableauDragState,
                                    cascadeRemainingCounts: state.isWon
                                        ? _winCascadeRemainingCounts
                                        : null,
                                  );
                                },
                              ),
                            ),

                            // GPU-composited flying card stack overlay during tap / auto-complete
                            if (_flightCards.isNotEmpty &&
                                _flightFromRect != null &&
                                _flightToRect != null)
                              _CardFlightOverlay(
                                animation: _flightController,
                                cards: _flightCards,
                                fromRect: _flightFromRect!,
                                toRect: _flightToRect!,
                                toRects: _flightToRects,
                                fromUpStep: _flightFromUpStep,
                                toUpStep: _flightToUpStep,
                                destKind: _flightDestKind,
                                theme: theme,
                                fourColorDeck: settings.fourColorDeck,
                                cardScale: settings.cardScale,
                                deckFaceStyle: settings.deckFaceStyle,
                                cardBackStyle: settings.cardBackStyle,
                              ),

                            if (widget.gameController.canAutoComplete)
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 12,
                                child: Center(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: theme.goldTrim,
                                      foregroundColor: const Color(0xFF1A1612),
                                      minimumSize: const Size(208, 48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: widget
                                        .gameController.triggerAutoComplete,
                                    icon: const Icon(
                                      Icons.done_all_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      AppStrings.autoCompleteLabel,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Bouncing card waterfall + calm scorecard on Win
                            if (state.isWon) ...<Widget>[
                              Positioned.fill(
                                child: WinCascadeOverlay(
                                  cardWidth: _lastGeometry?.cardWidth ?? 56.0,
                                  cardHeight: _lastGeometry?.cardHeight ?? 80.0,
                                  theme: theme,
                                  fourColorDeck: settings.fourColorDeck,
                                  leftHanded: settings.leftHanded,
                                  deckFaceStyle: settings.deckFaceStyle,
                                  colGap:
                                      _lastGeometry?.effectiveColGap ?? 4.0,
                                  boardWidth: _lastGeometry?.boardWidth,
                                  topOffset: 12.0,
                                  foundations: state.board.foundations,
                                  onFoundationRemainingChanged: (counts) {
                                    if (!mounted ||
                                        !widget.gameController.state.isWon) {
                                      return;
                                    }
                                    setState(() {
                                      _winCascadeRemainingCounts = counts;
                                    });
                                  },
                                ),
                              ),
                              Positioned(
                                left: 20,
                                right: 20,
                                top: 12,
                                bottom: 16,
                                child: LayoutBuilder(
                                  builder: (context, winConstraints) {
                                    return Align(
                                      alignment: Alignment.bottomCenter,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: 440,
                                          maxHeight: winConstraints.maxHeight,
                                        ),
                                        child: SingleChildScrollView(
                                          child: _WinCelebrationCard(
                                            theme: theme,
                                            moves: state.movesCount,
                                            elapsedSeconds:
                                                state.elapsedSeconds,
                                            showTimer: settings.showTimer,
                                            currentStreak: stats.currentStreak,
                                            onOpenDaily: _openDailySheet,
                                            onPlayNext: () {
                                              setState(() {
                                                _winCascadeRemainingCounts =
                                                    null;
                                              });
                                              widget.gameController
                                                  .startNewDeal(
                                                countAbandonedStreak: false,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: ClearDeckTheme.motionCurve,
                        child: (activeQuestBanner != null && !state.isWon)
                            ? QuestBannerStrip(
                                quest: activeQuestBanner,
                                extraPendingCount: math.max(
                                  0,
                                  (widget.questController?.pendingBannerCount ??
                                          1) -
                                      1,
                                ),
                                theme: theme,
                                onTapInspect: () {
                                  final questId = activeQuestBanner.id;
                                  widget.questController
                                      ?.dismissBannerById(questId);
                                  _openQuestsSheet(highlightQuestId: questId);
                                },
                                onDismiss: () {
                                  widget.questController?.dismissActiveBanner();
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                      BottomActionBar(
                        theme: theme,
                        canUndo: state.canUndo && !state.isWon,
                        onUndo: widget.gameController.undo,
                        onHint: state.isWon
                            ? null
                            : widget.gameController.requestHint,
                        onNewDeal: _openNewDealDialog,
                        onOpenSettings: _openSettingsSheet,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HintBannerStrip extends StatelessWidget {
  const _HintBannerStrip({
    super.key,
    required this.reason,
    required this.theme,
    required this.onDismiss,
    this.icon = Icons.lightbulb_outline_rounded,
  });

  final String reason;
  final ClearDeckTheme theme;
  final VoidCallback onDismiss;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.barSurface,
      child: InkWell(
        onTap: onDismiss,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.chromeHairline,
                width: 1.0,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    icon,
                    size: 16,
                    color: theme.hintHighlight,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textOnTable,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: theme.mutedOnTable,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WinCelebrationCard extends StatelessWidget {
  const _WinCelebrationCard({
    required this.theme,
    required this.moves,
    required this.elapsedSeconds,
    required this.showTimer,
    required this.currentStreak,
    required this.onOpenDaily,
    required this.onPlayNext,
  });

  final ClearDeckTheme theme;
  final int moves;
  final int elapsedSeconds;
  final bool showTimer;
  final int currentStreak;
  final VoidCallback onOpenDaily;
  final VoidCallback onPlayNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.sheetCard,
      elevation: 6,
      shadowColor: const Color(0x28000000),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.sheetBorder, width: 1.0),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  AppStrings.winTitle,
                  textAlign: TextAlign.center,
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
                const SizedBox(height: 4),
                Text(
                  AppStrings.winSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.sheetMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ParlorRuleDivider(
              brassColor: theme.goldTrim,
              hairlineColor: theme.sheetBorder,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _WinMetric(
                  label: 'Moves',
                  value: '$moves',
                  theme: theme,
                ),
                if (showTimer)
                  _WinMetric(
                    label: 'Time',
                    value: StatsSheet.formatDuration(elapsedSeconds),
                    theme: theme,
                  ),
                _WinMetric(
                  label: 'Streak',
                  value: '$currentStreak',
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: onOpenDaily,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Daily Calendar', maxLines: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: onPlayNext,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(AppStrings.playNextDealButton, maxLines: 1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParlorRuleDivider extends StatelessWidget {
  const _ParlorRuleDivider({
    required this.brassColor,
    required this.hairlineColor,
  });

  final Color brassColor;
  final Color hairlineColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(height: 1, color: brassColor.withValues(alpha: 0.52)),
              const SizedBox(height: 2),
              Container(height: 1, color: hairlineColor),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 6,
              height: 6,
              color: brassColor,
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(height: 1, color: brassColor.withValues(alpha: 0.52)),
              const SizedBox(height: 2),
              Container(height: 1, color: hairlineColor),
            ],
          ),
        ),
      ],
    );
  }
}

class _WinMetric extends StatelessWidget {
  const _WinMetric({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ClearDeckTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: theme.sheetMuted,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: theme.sheetText,
            fontSize: 24,
            fontWeight: FontWeight.w500,
            fontFeatures: const <FontFeature>[
              FontFeature.tabularFigures(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar({
    required this.theme,
    required this.state,
    required this.showTimer,
    required this.elapsedSecondsListenable,
    required this.onOpenDaily,
    required this.onOpenStats,
  });

  final ClearDeckTheme theme;
  final GameState state;
  final bool showTimer;
  final ValueListenable<int> elapsedSecondsListenable;
  final VoidCallback onOpenDaily;
  final VoidCallback onOpenStats;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 380;
    final badgeText = state.dealType == DealType.daily
        ? 'Daily · ${state.drawMode.label}'
        : state.drawMode.label;

    return Container(
      decoration: BoxDecoration(
        color: theme.dockBackground,
        border: Border(
          bottom: BorderSide(
            color: theme.chromeHairline,
            width: 1.0,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: 8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          AppStrings.movesLabel,
                          style: TextStyle(
                            color: theme.mutedOnTable,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${state.movesCount}',
                          key: const Key('top_moves_value'),
                          style: TextStyle(
                            color: theme.textOnTable,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        if (showTimer) ...<Widget>[
                          SizedBox(width: compact ? 10 : 16),
                          ValueListenableBuilder<int>(
                            valueListenable: elapsedSecondsListenable,
                            builder: (context, seconds, _) {
                              return Text(
                                StatsSheet.formatDuration(seconds),
                                key: const Key('top_timer_value'),
                                style: TextStyle(
                                  color: theme.mutedOnTable,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                        SizedBox(width: compact ? 8 : 12),
                        Text(
                          badgeText,
                          style: TextStyle(
                            color: theme.mutedOnTable,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 6 : 8),
              _HeaderButton(
                icon: Icons.calendar_month_rounded,
                label: AppStrings.dailyLabel,
                theme: theme,
                compact: compact,
                onTap: onOpenDaily,
              ),
              SizedBox(width: compact ? 6 : 8),
              _HeaderButton(
                icon: Icons.bar_chart_rounded,
                label: AppStrings.statsLabel,
                theme: theme,
                compact: compact,
                onTap: onOpenStats,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.theme,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ClearDeckTheme theme;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.chromeButtonSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.chromeHairline,
              width: 1.0,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: compact ? 16 : 18, color: theme.mutedOnTable),
              SizedBox(width: compact ? 4 : 8),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: theme.textOnTable,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayableBoardArea extends StatelessWidget {
  const _PlayableBoardArea({
    required this.geometry,
    required this.containerHeight,
    required this.state,
    required this.settings,
    required this.theme,
    required this.hintMove,
    required this.controller,
    required this.stockKey,
    required this.wasteKey,
    required this.foundationKeys,
    required this.tableauColKeys,
    required this.flightAnimation,
    required this.flightDestKind,
    required this.flightDestPileIndex,
    required this.flightHideCount,
    required this.flipController,
    required this.flipColIndex,
    required this.flipCardIndex,
    required this.shimmerController,
    required this.shimmerFoundationIndex,
    required this.draggingTableauCol,
    required this.draggingTableauStartIdx,
    required this.onTableauDragStarted,
    required this.onTableauDragFinished,
    this.cascadeRemainingCounts,
  });

  final _BoardGeometry geometry;
  final double containerHeight;
  final GameState state;
  final AppSettings settings;
  final ClearDeckTheme theme;
  final SolitaireMove? hintMove;
  final GameController controller;
  final GlobalKey stockKey;
  final GlobalKey wasteKey;
  final List<GlobalKey> foundationKeys;
  final List<GlobalKey> tableauColKeys;
  final AnimationController flightAnimation;
  final MoveKind? flightDestKind;
  final int? flightDestPileIndex;
  final int flightHideCount;
  final AnimationController flipController;
  final int? flipColIndex;
  final int? flipCardIndex;
  final AnimationController shimmerController;
  final int? shimmerFoundationIndex;
  final int? draggingTableauCol;
  final int? draggingTableauStartIdx;
  final void Function(int colIndex, int cardIndex) onTableauDragStarted;
  final VoidCallback onTableauDragFinished;
  final List<int>? cascadeRemainingCounts;

  @override
  Widget build(BuildContext context) {
    final isFlying = flightAnimation.isAnimating;

    return Center(
      child: SizedBox(
        width: geometry.boardWidth,
        height: containerHeight,
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Column(
            children: <Widget>[
              _TopPilesRow(
                board: state.board,
                drawMode: state.drawMode,
                cardWidth: geometry.cardWidth,
                cardHeight: geometry.cardHeight,
                colGap: geometry.effectiveColGap,
                theme: theme,
                fourColorDeck: settings.fourColorDeck,
                cardScale: settings.cardScale,
                deckFaceStyle: settings.deckFaceStyle,
                cardBackStyle: settings.cardBackStyle,
                leftHanded: settings.leftHanded,
                hintMove: hintMove,
                controller: controller,
                stockKey: stockKey,
                wasteKey: wasteKey,
                foundationKeys: foundationKeys,
                hideWasteCount:
                    (isFlying && flightDestKind == MoveKind.drawStock)
                        ? flightHideCount
                        : 0,
                hiddenFoundationIndex: (isFlying &&
                        (flightDestKind == MoveKind.wasteToFoundation ||
                            flightDestKind == MoveKind.tableauToFoundation))
                    ? flightDestPileIndex
                    : null,
                shimmerController: shimmerController,
                shimmerFoundationIndex: shimmerFoundationIndex,
                cascadeRemainingCounts: cascadeRemainingCounts,
              ),
              SizedBox(height: geometry.rowSpacing),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, tableauConstraints) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List<Widget>.generate(7, (colIdx) {
                        final hideTopCount = (isFlying &&
                                (flightDestKind == MoveKind.wasteToTableau ||
                                    flightDestKind ==
                                        MoveKind.tableauToTableau ||
                                    flightDestKind ==
                                        MoveKind.foundationToTableau) &&
                                flightDestPileIndex == colIdx)
                            ? flightHideCount
                            : 0;
                        return RepaintBoundary(
                          child: _TableauColumnWidget(
                            key: tableauColKeys[colIdx],
                            colIndex: colIdx,
                            cards: state.board.tableau[colIdx],
                            cardWidth: geometry.cardWidth,
                            cardHeight: geometry.cardHeight,
                            maxColumnHeight: tableauConstraints.maxHeight,
                            theme: theme,
                            fourColorDeck: settings.fourColorDeck,
                            cardScale: settings.cardScale,
                            deckFaceStyle: settings.deckFaceStyle,
                            cardBackStyle: settings.cardBackStyle,
                            hintMove: hintMove,
                            controller: controller,
                            hideTopCount: hideTopCount,
                            flipController: flipController,
                            flipCardIndex:
                                flipColIndex == colIdx ? flipCardIndex : null,
                            draggingStartIdx: draggingTableauCol == colIdx
                                ? draggingTableauStartIdx
                                : null,
                            onDragStarted: (startIdx) =>
                                onTableauDragStarted(colIdx, startIdx),
                            onDragFinished: onTableauDragFinished,
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopPilesRow extends StatelessWidget {
  const _TopPilesRow({
    required this.board,
    required this.drawMode,
    required this.cardWidth,
    required this.cardHeight,
    required this.colGap,
    required this.theme,
    required this.fourColorDeck,
    required this.cardScale,
    required this.deckFaceStyle,
    required this.cardBackStyle,
    required this.leftHanded,
    required this.hintMove,
    required this.controller,
    required this.stockKey,
    required this.wasteKey,
    required this.foundationKeys,
    required this.hideWasteCount,
    required this.hiddenFoundationIndex,
    required this.shimmerController,
    required this.shimmerFoundationIndex,
    this.cascadeRemainingCounts,
  });

  final BoardSnapshot board;
  final DrawMode drawMode;
  final double cardWidth;
  final double cardHeight;
  final double colGap;
  final ClearDeckTheme theme;
  final bool fourColorDeck;
  final CardScale cardScale;
  final DeckFaceStyle deckFaceStyle;
  final CardBackStyle cardBackStyle;
  final bool leftHanded;
  final SolitaireMove? hintMove;
  final GameController controller;
  final GlobalKey stockKey;
  final GlobalKey wasteKey;
  final List<GlobalKey> foundationKeys;
  final int hideWasteCount;
  final int? hiddenFoundationIndex;
  final AnimationController shimmerController;
  final int? shimmerFoundationIndex;
  final List<int>? cascadeRemainingCounts;

  @override
  Widget build(BuildContext context) {
    final stockWidget = _buildStockWidget();
    final wasteSlotWidget = _buildWasteWidget();
    final foundationWidgets = List<Widget>.generate(4, _buildFoundationSlot);

    final rowChildren = leftHanded
        ? <Widget>[
            ...foundationWidgets,
            wasteSlotWidget,
            stockWidget,
          ]
        : <Widget>[
            stockWidget,
            wasteSlotWidget,
            ...foundationWidgets,
          ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: rowChildren,
    );
  }

  Widget _buildStockWidget() {
    final isHinted = hintMove?.kind == MoveKind.drawStock ||
        hintMove?.kind == MoveKind.recycleStock;
    final hasCards = board.stock.isNotEmpty;

    return GestureDetector(
      key: stockKey,
      behavior: HitTestBehavior.opaque,
      onTap: controller.tapStock,
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            EmptyPileSlot(
              width: cardWidth,
              height: cardHeight,
              theme: theme,
              icon: board.waste.isNotEmpty
                  ? Icons.refresh_rounded
                  : Icons.block_rounded,
              isHighlighted: !hasCards && isHinted,
            ),
            if (hasCards)
              DeckDepthStack(
                cardCount: board.stock.length,
                width: cardWidth,
                height: cardHeight,
                theme: theme,
                keyPrefix: 'stock',
                topCard: PlayingCardWidget(
                  card: board.stock.last,
                  width: cardWidth,
                  height: cardHeight,
                  theme: theme,
                  fourColorDeck: fourColorDeck,
                  cardScale: cardScale,
                  deckFaceStyle: deckFaceStyle,
                  cardBackStyle: cardBackStyle,
                  isHighlighted: isHinted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteWidget() {
    final isHinted = hintMove?.kind == MoveKind.wasteToFoundation ||
        hintMove?.kind == MoveKind.wasteToTableau;
    final slotWidth = cardWidth * 2 + colGap;
    final isFlightBlocking = hideWasteCount > 0;
    final preArrivalLen =
        (board.waste.length - hideWasteCount).clamp(0, board.waste.length);
    final preArrivalWaste = board.waste.sublist(0, preArrivalLen);
    final baseLeft = _wasteCardLeftOffset(
      indexFromBottom: 0,
      visibleCount: 1,
      cardWidth: cardWidth,
      colGap: colGap,
      leftHanded: leftHanded,
    );

    if (preArrivalWaste.isEmpty) {
      return SizedBox(
        key: wasteKey,
        width: slotWidth,
        height: cardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: baseLeft,
              top: 0,
              child: EmptyPileSlot(
                width: cardWidth,
                height: cardHeight,
                theme: theme,
              ),
            ),
          ],
        ),
      );
    }

    final visibleCount = drawMode == DrawMode.draw3
        ? math.min(3, preArrivalWaste.length)
        : 1;
    final visibleCards =
        preArrivalWaste.sublist(preArrivalWaste.length - visibleCount);

    Widget buildTopInteractiveCard() {
      final topCard = visibleCards.last;
      final cardFace = PlayingCardWidget(
        card: topCard,
        width: cardWidth,
        height: cardHeight,
        theme: theme,
        fourColorDeck: fourColorDeck,
        cardScale: cardScale,
        deckFaceStyle: deckFaceStyle,
        cardBackStyle: cardBackStyle,
        isHighlighted: !isFlightBlocking && isHinted,
      );

      final Widget restingTop = visibleCount == 1
          ? DeckDepthStack(
              cardCount: preArrivalWaste.length,
              width: cardWidth,
              height: cardHeight,
              theme: theme,
              keyPrefix: 'waste',
              topCard: cardFace,
            )
          : cardFace;

      if (isFlightBlocking) {
        return IgnorePointer(child: restingTop);
      }

      final Widget underCard = visibleCount >= 2
          ? const SizedBox.shrink()
          : (preArrivalWaste.length >= 2
              ? DeckDepthStack(
                  cardCount: preArrivalWaste.length - 1,
                  width: cardWidth,
                  height: cardHeight,
                  theme: theme,
                  keyPrefix: 'waste_under',
                  topCard: PlayingCardWidget(
                    card: preArrivalWaste[preArrivalWaste.length - 2],
                    width: cardWidth,
                    height: cardHeight,
                    theme: theme,
                    fourColorDeck: fourColorDeck,
                    cardScale: cardScale,
                    deckFaceStyle: deckFaceStyle,
                    cardBackStyle: cardBackStyle,
                  ),
                )
              : EmptyPileSlot(
                  width: cardWidth,
                  height: cardHeight,
                  theme: theme,
                ));

      final payload = CardDragPayload(
        sourceKind: MoveKind.wasteToTableau,
        fromPileIndex: 0,
        cards: <PlayingCard>[topCard],
      );

      Offset? dragStartOffset;
      return Builder(
        builder: (dragCtx) => Draggable<CardDragPayload>(
          data: payload,
          maxSimultaneousDrags: 1,
          onDragStarted: () {
            controller.clearPendingDragRejection();
            final box = dragCtx.findRenderObject();
            if (box is RenderBox && box.attached) {
              dragStartOffset = box.localToGlobal(Offset.zero);
            }
          },
          onDraggableCanceled: (_, releaseOffset) {
            controller.handleCanceledDrag(
              dragStartOffset: dragStartOffset,
              releaseOffset: releaseOffset,
              cardSize: Size(cardWidth, cardHeight),
            );
            dragStartOffset = null;
          },
          onDragCompleted: () {
            controller.clearPendingDragRejection();
            dragStartOffset = null;
          },
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.05,
              alignment: Alignment.topCenter,
              child: PlayingCardWidget(
                card: topCard,
                width: cardWidth,
                height: cardHeight,
                theme: theme,
                fourColorDeck: fourColorDeck,
                cardScale: cardScale,
                deckFaceStyle: deckFaceStyle,
                cardBackStyle: cardBackStyle,
                isElevated: true,
              ),
            ),
          ),
          childWhenDragging: underCard,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: controller.tapWaste,
            child: restingTop,
          ),
        ),
      );
    }

    return SizedBox(
      key: wasteKey,
      width: slotWidth,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: baseLeft,
            top: 0,
            child: EmptyPileSlot(
              width: cardWidth,
              height: cardHeight,
              theme: theme,
            ),
          ),
          for (var i = 0; i < visibleCards.length; i++)
            Positioned(
              left: _wasteCardLeftOffset(
                indexFromBottom: i,
                visibleCount: visibleCount,
                cardWidth: cardWidth,
                colGap: colGap,
                leftHanded: leftHanded,
              ),
              top: 0,
              child: i == visibleCards.length - 1
                  ? buildTopInteractiveCard()
                  : PlayingCardWidget(
                      card: visibleCards[i],
                      width: cardWidth,
                      height: cardHeight,
                      theme: theme,
                      fourColorDeck: fourColorDeck,
                      cardScale: cardScale,
                      deckFaceStyle: deckFaceStyle,
                      cardBackStyle: cardBackStyle,
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoundationSlot(int foundationIndex) {
    final fullPile = board.foundations[foundationIndex];
    final isFlightLandingHere = hiddenFoundationIndex == foundationIndex;
    var effectiveLen = (isFlightLandingHere && fullPile.isNotEmpty)
        ? fullPile.length - 1
        : fullPile.length;
    if (cascadeRemainingCounts != null &&
        foundationIndex < cascadeRemainingCounts!.length) {
      effectiveLen = math.min(
        effectiveLen,
        cascadeRemainingCounts![foundationIndex],
      );
    }
    final visiblePile = effectiveLen > 0
        ? fullPile.sublist(0, effectiveLen)
        : const <PlayingCard>[];

    final isHintTarget = (hintMove?.kind == MoveKind.wasteToFoundation ||
            hintMove?.kind == MoveKind.tableauToFoundation) &&
        hintMove?.toPileIndex == foundationIndex;

    return DragTarget<CardDragPayload>(
      key: foundationKeys[foundationIndex],
      onWillAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload.sourceKind == MoveKind.foundationToTableau) {
          return false;
        }
        final valid = payload.cards.length == 1 &&
            SolitaireRules.canPlaceOnFoundation(
              payload.cards.single,
              fullPile,
            );
        if (!valid) {
          final reason = SolitaireRules.explainFoundationRejection(
            payload.cards.first,
            fullPile,
            cardCount: payload.cards.length,
          );
          final box = foundationKeys[foundationIndex].currentContext?.findRenderObject();
          if (reason != null && box is RenderBox && box.attached) {
            controller.noteRejectedDragTarget(
              reason: reason,
              targetRect: box.localToGlobal(Offset.zero) & box.size,
            );
          }
          return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload.sourceKind == MoveKind.wasteToTableau) {
          controller.performMove(
            SolitaireMove(
              kind: MoveKind.wasteToFoundation,
              toPileIndex: foundationIndex,
            ),
            isDragMove: true,
          );
        } else if (payload.sourceKind == MoveKind.tableauToTableau) {
          controller.performMove(
            SolitaireMove(
              kind: MoveKind.tableauToFoundation,
              fromPileIndex: payload.fromPileIndex,
              toPileIndex: foundationIndex,
            ),
            isDragMove: true,
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final activeHighlight = isHintTarget || candidateData.isNotEmpty;
        final Widget baseSlot;

        if (visiblePile.isEmpty) {
          baseSlot = EmptyPileSlot(
            width: cardWidth,
            height: cardHeight,
            theme: theme,
            label: 'A',
            isHighlighted: activeHighlight,
            isFoundation: true,
          );
        } else {
          final topCard = visiblePile.last;
          final stackedFace = DeckDepthStack(
            cardCount: visiblePile.length,
            width: cardWidth,
            height: cardHeight,
            theme: theme,
            keyPrefix: 'foundation_$foundationIndex',
            topCard: PlayingCardWidget(
              card: topCard,
              width: cardWidth,
              height: cardHeight,
              theme: theme,
              fourColorDeck: fourColorDeck,
              cardScale: cardScale,
              deckFaceStyle: deckFaceStyle,
              cardBackStyle: cardBackStyle,
              isHighlighted: activeHighlight,
            ),
          );

          if (isFlightLandingHere) {
            baseSlot = IgnorePointer(child: stackedFace);
          } else {
            final payload = CardDragPayload(
              sourceKind: MoveKind.foundationToTableau,
              fromPileIndex: foundationIndex,
              cards: <PlayingCard>[topCard],
            );

            Offset? dragStartOffset;
            baseSlot = Builder(
              builder: (dragCtx) => Draggable<CardDragPayload>(
                data: payload,
                maxSimultaneousDrags: 1,
                onDragStarted: () {
                  controller.clearPendingDragRejection();
                  final box = dragCtx.findRenderObject();
                  if (box is RenderBox && box.attached) {
                    dragStartOffset = box.localToGlobal(Offset.zero);
                  }
                },
                onDraggableCanceled: (_, releaseOffset) {
                  controller.handleCanceledDrag(
                    dragStartOffset: dragStartOffset,
                    releaseOffset: releaseOffset,
                    cardSize: Size(cardWidth, cardHeight),
                  );
                  dragStartOffset = null;
                },
                onDragCompleted: () {
                  controller.clearPendingDragRejection();
                  dragStartOffset = null;
                },
                feedback: Material(
                  color: Colors.transparent,
                  child: Transform.scale(
                    scale: 1.05,
                    alignment: Alignment.topCenter,
                    child: PlayingCardWidget(
                      card: topCard,
                      width: cardWidth,
                      height: cardHeight,
                      theme: theme,
                      fourColorDeck: fourColorDeck,
                      cardScale: cardScale,
                      deckFaceStyle: deckFaceStyle,
                      cardBackStyle: cardBackStyle,
                      isElevated: true,
                    ),
                  ),
                ),
                childWhenDragging: visiblePile.length > 1
                    ? DeckDepthStack(
                        cardCount: visiblePile.length - 1,
                        width: cardWidth,
                        height: cardHeight,
                        theme: theme,
                        keyPrefix: 'foundation_${foundationIndex}_under',
                        topCard: PlayingCardWidget(
                          card: visiblePile[visiblePile.length - 2],
                          width: cardWidth,
                          height: cardHeight,
                          theme: theme,
                          fourColorDeck: fourColorDeck,
                          cardScale: cardScale,
                          deckFaceStyle: deckFaceStyle,
                          cardBackStyle: cardBackStyle,
                        ),
                      )
                    : EmptyPileSlot(
                        width: cardWidth,
                        height: cardHeight,
                        theme: theme,
                        label: 'A',
                        isFoundation: true,
                      ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => controller.tapFoundation(foundationIndex),
                  child: stackedFace,
                ),
              ),
            );
          }
        }

        if (shimmerFoundationIndex != foundationIndex ||
            !shimmerController.isAnimating) {
          return baseSlot;
        }

        return AnimatedBuilder(
          animation: shimmerController,
          builder: (context, child) {
            final t =
                ClearDeckTheme.motionCurve.transform(shimmerController.value);
            final radius = (cardWidth * 0.11).clamp(6.0, 12.0);
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                child!,
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color:
                              theme.goldTrim.withValues(alpha: (1.0 - t) * 0.85),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: baseSlot,
        );
      },
    );
  }
}

class _TableauColumnWidget extends StatelessWidget {
  const _TableauColumnWidget({
    super.key,
    required this.colIndex,
    required this.cards,
    required this.cardWidth,
    required this.cardHeight,
    required this.maxColumnHeight,
    required this.theme,
    required this.fourColorDeck,
    required this.cardScale,
    required this.deckFaceStyle,
    required this.cardBackStyle,
    required this.hintMove,
    required this.controller,
    required this.hideTopCount,
    required this.flipController,
    required this.flipCardIndex,
    required this.draggingStartIdx,
    required this.onDragStarted,
    required this.onDragFinished,
  });

  final int colIndex;
  final List<PlayingCard> cards;
  final double cardWidth;
  final double cardHeight;
  final double maxColumnHeight;
  final ClearDeckTheme theme;
  final bool fourColorDeck;
  final CardScale cardScale;
  final DeckFaceStyle deckFaceStyle;
  final CardBackStyle cardBackStyle;
  final SolitaireMove? hintMove;
  final GameController controller;
  final int hideTopCount;
  final AnimationController flipController;
  final int? flipCardIndex;
  final int? draggingStartIdx;
  final void Function(int startIdx) onDragStarted;
  final VoidCallback onDragFinished;

  @override
  Widget build(BuildContext context) {
    final isHintTarget = (hintMove?.kind == MoveKind.wasteToTableau ||
            hintMove?.kind == MoveKind.tableauToTableau ||
            hintMove?.kind == MoveKind.foundationToTableau) &&
        hintMove?.toPileIndex == colIndex;

    final hintSourceSplitIndex =
        (hintMove?.kind == MoveKind.tableauToTableau ||
                    hintMove?.kind == MoveKind.tableauToFoundation) &&
                hintMove?.fromPileIndex == colIndex
            ? (cards.length - (hintMove?.cardCount ?? 1))
            : null;

    return DragTarget<CardDragPayload>(
      onWillAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload.sourceKind == MoveKind.tableauToTableau &&
            payload.fromPileIndex == colIndex) {
          return false;
        }
        final valid =
            SolitaireRules.canPlaceOnTableau(payload.cards.first, cards);
        if (!valid) {
          final reason = SolitaireRules.explainTableauRejection(
            payload.cards.first,
            cards,
          );
          final box = context.findRenderObject();
          if (reason != null && box is RenderBox && box.attached) {
            controller.noteRejectedDragTarget(
              reason: reason,
              targetRect: box.localToGlobal(Offset.zero) & box.size,
            );
          }
          return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload.sourceKind == MoveKind.wasteToTableau) {
          controller.performMove(
            SolitaireMove(
              kind: MoveKind.wasteToTableau,
              toPileIndex: colIndex,
            ),
            isDragMove: true,
          );
        } else if (payload.sourceKind == MoveKind.foundationToTableau) {
          controller.performMove(
            SolitaireMove(
              kind: MoveKind.foundationToTableau,
              fromPileIndex: payload.fromPileIndex,
              toPileIndex: colIndex,
            ),
            isDragMove: true,
          );
        } else if (payload.sourceKind == MoveKind.tableauToTableau) {
          controller.performMove(
            SolitaireMove(
              kind: MoveKind.tableauToTableau,
              fromPileIndex: payload.fromPileIndex,
              toPileIndex: colIndex,
              cardCount: payload.cards.length,
            ),
            isDragMove: true,
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final dropHighlight = isHintTarget || candidateData.isNotEmpty;
        final visibleCount = (cards.length - hideTopCount).clamp(0, cards.length);
        final isFlightBlocking = hideTopCount > 0;

        if (visibleCount == 0) {
          return IgnorePointer(
            ignoring: isFlightBlocking,
            child: SizedBox(
              width: cardWidth,
              height: maxColumnHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: EmptyPileSlot(
                  width: cardWidth,
                  height: cardHeight,
                  theme: theme,
                  label: 'K',
                  isHighlighted: dropHighlight,
                ),
              ),
            ),
          );
        }

        final layout = _computeTableauLayoutOffsets(
          cards: cards,
          cardHeight: cardHeight,
          maxColumnHeight: maxColumnHeight,
          cardScale: cardScale,
        );
        final tops = layout.tops;
        final upStep = layout.upStep;

        return IgnorePointer(
          ignoring: isFlightBlocking,
          child: SizedBox(
            width: cardWidth,
            height: maxColumnHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: 0,
                  top: 0,
                  child: EmptyPileSlot(
                    width: cardWidth,
                    height: cardHeight,
                    theme: theme,
                    label: 'K',
                    isHighlighted: dropHighlight,
                  ),
                ),
                ...List<Widget>.generate(visibleCount, (idx) {
                  final card = cards[idx];
                  final isLastVisible = idx == visibleCount - 1;
                  final highlightThisCard = (dropHighlight && isLastVisible) ||
                      (hintSourceSplitIndex != null &&
                          idx >= hintSourceSplitIndex &&
                          idx < visibleCount);

                  final Widget faceCardWidget = PlayingCardWidget(
                    card: card,
                    width: cardWidth,
                    height: cardHeight,
                    theme: theme,
                    fourColorDeck: fourColorDeck,
                    cardScale: cardScale,
                    deckFaceStyle: deckFaceStyle,
                    cardBackStyle: cardBackStyle,
                    isHighlighted: highlightThisCard,
                  );

                  final Widget displayCardWidget =
                      (flipCardIndex == idx && flipController.isAnimating)
                          ? _CardFlipWidget(
                              animation: flipController,
                              width: cardWidth,
                              height: cardHeight,
                              front: RepaintBoundary(child: faceCardWidget),
                              back: RepaintBoundary(
                                child: CardBackPatternWidget(
                                  style: cardBackStyle,
                                  width: cardWidth,
                                  height: cardHeight,
                                  paperColor: theme.cardFace,
                                  borderColor: theme.cardBorder,
                                ),
                              ),
                            )
                          : faceCardWidget;

                  if (!card.isFaceUp) {
                    return Positioned(
                      left: 0,
                      top: tops[idx],
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => controller.recordInvalidMoveAttempt(
                          reason:
                              'Face-down cards flip automatically once the cards on top are cleared.',
                        ),
                        child: displayCardWidget,
                      ),
                    );
                  }

                  final isHiddenByParentDrag =
                      draggingStartIdx != null && idx > draggingStartIdx!;
                  if (isHiddenByParentDrag) {
                    return Positioned(
                      left: 0,
                      top: tops[idx],
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.0,
                          child: displayCardWidget,
                        ),
                      ),
                    );
                  }

                  final subRun = cards.sublist(idx, visibleCount);
                  if (!SolitaireRules.isValidTableauRun(subRun)) {
                    return Positioned(
                      left: 0,
                      top: tops[idx],
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => controller.recordInvalidMoveAttempt(
                          reason:
                              'Move the top card first — stacked cards move together only in alternating colors.',
                        ),
                        child: displayCardWidget,
                      ),
                    );
                  }

                  final payload = CardDragPayload(
                    sourceKind: MoveKind.tableauToTableau,
                    fromPileIndex: colIndex,
                    cards: subRun,
                  );

                  Offset? dragStartOffset;
                  return Positioned(
                    left: 0,
                    top: tops[idx],
                    child: Builder(
                      builder: (dragCtx) => Draggable<CardDragPayload>(
                        data: payload,
                        maxSimultaneousDrags: 1,
                        onDragStarted: () {
                          controller.clearPendingDragRejection();
                          final box = dragCtx.findRenderObject();
                          if (box is RenderBox && box.attached) {
                            dragStartOffset = box.localToGlobal(Offset.zero);
                          }
                          onDragStarted(idx);
                        },
                        onDragEnd: (_) => onDragFinished(),
                        onDraggableCanceled: (_, releaseOffset) {
                          controller.handleCanceledDrag(
                            dragStartOffset: dragStartOffset,
                            releaseOffset: releaseOffset,
                            cardSize: Size(cardWidth, cardHeight),
                          );
                          dragStartOffset = null;
                          onDragFinished();
                        },
                        onDragCompleted: () {
                          controller.clearPendingDragRejection();
                          dragStartOffset = null;
                          onDragFinished();
                        },
                      feedback: Material(
                        color: Colors.transparent,
                        child: Transform.scale(
                          scale: 1.04,
                          alignment: Alignment.topCenter,
                          child: RepaintBoundary(
                            child: _buildStackedDragPreview(
                              subRun,
                              upStep,
                            ),
                          ),
                        ),
                      ),
                      childWhenDragging: SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => controller.tapTableauCard(colIndex, idx),
                        child: displayCardWidget,
                      ),
                    ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStackedDragPreview(
    List<PlayingCard> subRun,
    double upStep,
  ) {
    final totalHeight = cardHeight + (subRun.length - 1) * upStep;
    return SizedBox(
      width: cardWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List<Widget>.generate(subRun.length, (i) {
          return Positioned(
            left: 0,
            top: i * upStep,
            child: PlayingCardWidget(
              card: subRun[i],
              width: cardWidth,
              height: cardHeight,
              theme: theme,
              fourColorDeck: fourColorDeck,
              cardScale: cardScale,
              deckFaceStyle: deckFaceStyle,
              cardBackStyle: cardBackStyle,
              isElevated: true,
            ),
          );
        }),
      ),
    );
  }
}

/// Pure GPU-composited 3D Y-axis card flip keeping pre-built [front] and
/// [back] cached textures completely separate so closures never self-recurse.
class _CardFlipWidget extends StatelessWidget {
  const _CardFlipWidget({
    required this.animation,
    required this.width,
    required this.height,
    required this.front,
    required this.back,
  });

  final Animation<double> animation;
  final double width;
  final double height;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = ClearDeckTheme.flipCurve.transform(animation.value);
          final showBack = t < 0.5;
          final rawAngle = showBack ? t * math.pi : (t - 1.0) * math.pi;
          final angle = showBack
              ? rawAngle.clamp(0.0, math.pi * 0.495)
              : rawAngle.clamp(-math.pi * 0.495, 0.0);
          final liftScale = 1.0 + 0.04 * math.sin(math.pi * t);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: Transform.scale(
              scale: liftScale,
              child: showBack ? back : front,
            ),
          );
        },
      ),
    );
  }
}

/// GPU-composited card flight overlay transforming pre-built [RepaintBoundary]
/// cards with `Transform.translate`, `Transform.scale`, and step interpolation
/// (zero relayouts per tick).
class _CardFlightOverlay extends StatelessWidget {
  const _CardFlightOverlay({
    required this.animation,
    required this.cards,
    required this.fromRect,
    required this.toRect,
    required this.toRects,
    required this.fromUpStep,
    required this.toUpStep,
    required this.destKind,
    required this.theme,
    required this.fourColorDeck,
    required this.cardScale,
    this.deckFaceStyle = DeckFaceStyle.americanHeritage,
    required this.cardBackStyle,
  });

  final Animation<double> animation;
  final List<PlayingCard> cards;
  final Rect fromRect;
  final Rect toRect;
  final List<Rect> toRects;
  final double fromUpStep;
  final double toUpStep;
  final MoveKind? destKind;
  final ClearDeckTheme theme;
  final bool fourColorDeck;
  final CardScale cardScale;
  final DeckFaceStyle deckFaceStyle;
  final CardBackStyle cardBackStyle;

  @override
  Widget build(BuildContext context) {
    final w = fromRect.width;
    final h = fromRect.height;

    if (destKind == MoveKind.drawStock) {
      final backChild = RepaintBoundary(
        child: SizedBox(
          width: w,
          height: h,
          child: CardBackPatternWidget(
            style: cardBackStyle,
            width: w,
            height: h,
            paperColor: theme.cardFace,
            borderColor: theme.cardBorder,
          ),
        ),
      );
      final frontChildren = List<Widget>.generate(
        cards.length,
        (i) => RepaintBoundary(
          child: SizedBox(
            width: w,
            height: h,
            child: PlayingCardWidget(
              card: cards[i],
              width: w,
              height: h,
              theme: theme,
              fourColorDeck: fourColorDeck,
              cardScale: cardScale,
              deckFaceStyle: deckFaceStyle,
              cardBackStyle: cardBackStyle,
              isElevated: true,
            ),
          ),
        ),
      );

      final count = cards.length;
      final staggerSpan = count > 1 ? 1.0 - 0.08 * (count - 1) : 1.0;

      return Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final raw = animation.value;
              return Stack(
                clipBehavior: Clip.none,
                children: List<Widget>.generate(count, (k) {
                  final targetRect = k < toRects.length ? toRects[k] : toRect;
                  final localRaw = count > 1
                      ? ((raw - 0.08 * k) / staggerSpan).clamp(0.0, 1.0)
                      : raw;
                  final t = ClearDeckTheme.motionCurve.transform(localRaw);
                  final flipT = ClearDeckTheme.flipCurve.transform(localRaw);
                  final arcLift = -14.0 * math.sin(math.pi * t);
                  final liftScale = 1.0 + 0.07 * math.sin(math.pi * t);
                  final dx =
                      fromRect.left + (targetRect.left - fromRect.left) * t;
                  final dy = fromRect.top +
                      (targetRect.top - fromRect.top) * t +
                      arcLift;

                  final showBack = flipT < 0.5;
                  final rawAngle =
                      showBack ? flipT * math.pi : (flipT - 1.0) * math.pi;
                  final angle = showBack
                      ? rawAngle.clamp(0.0, math.pi * 0.495)
                      : rawAngle.clamp(-math.pi * 0.495, 0.0);

                  return Positioned(
                    left: 0,
                    top: 0,
                    child: Transform.translate(
                      offset: Offset(dx, dy),
                      child: Transform.scale(
                        scale: liftScale,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateY(angle),
                          child: showBack ? backChild : frontChildren[k],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      );
    }

    if (cards.length == 1) {
      final cachedSingle = RepaintBoundary(
        child: SizedBox(
          width: w,
          height: h,
          child: PlayingCardWidget(
            card: cards.single,
            width: w,
            height: h,
            theme: theme,
            fourColorDeck: fourColorDeck,
            cardScale: cardScale,
            deckFaceStyle: deckFaceStyle,
            cardBackStyle: cardBackStyle,
            isElevated: true,
          ),
        ),
      );

      return AnimatedBuilder(
        animation: animation,
        child: cachedSingle,
        builder: (context, child) {
          final t = ClearDeckTheme.motionCurve.transform(animation.value);
          final arcLift = -14.0 * math.sin(math.pi * t);
          final liftScale = 1.0 + 0.07 * math.sin(math.pi * t);
          final dx = fromRect.left + (toRect.left - fromRect.left) * t;
          final dy = fromRect.top + (toRect.top - fromRect.top) * t + arcLift;

          return Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.scale(
                  scale: liftScale,
                  child: child,
                ),
              ),
            ),
          );
        },
      );
    }

    final cachedCards = List<Widget>.generate(
      cards.length,
      (i) => RepaintBoundary(
        child: PlayingCardWidget(
          card: cards[i],
          width: w,
          height: h,
          theme: theme,
          fourColorDeck: fourColorDeck,
          cardScale: cardScale,
          deckFaceStyle: deckFaceStyle,
          cardBackStyle: cardBackStyle,
          isElevated: true,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = ClearDeckTheme.motionCurve.transform(animation.value);
        final arcLift = -14.0 * math.sin(math.pi * t);
        final liftScale = 1.0 + 0.07 * math.sin(math.pi * t);
        final currentStep = fromUpStep + (toUpStep - fromUpStep) * t;
        final dx = fromRect.left + (toRect.left - fromRect.left) * t;
        final dy = fromRect.top + (toRect.top - fromRect.top) * t + arcLift;

        return Positioned(
          left: 0,
          top: 0,
          child: IgnorePointer(
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.scale(
                scale: liftScale,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: w,
                  height: h + (cachedCards.length - 1) * currentStep,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: List<Widget>.generate(
                      cachedCards.length,
                      (i) => Transform.translate(
                        offset: Offset(0, i * currentStep),
                        child: cachedCards[i],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
