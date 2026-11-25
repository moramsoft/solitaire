import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import '../engine/engine.dart';
import '../services/audio_service.dart';
import '../state/settings_controller.dart';
import '../theme/app_theme.dart';
import '../theme/deck_palette.dart';
import '../tutorial/tutorial_scenario.dart';
import 'widgets/card_back_painter.dart';
import 'widgets/playing_card_widget.dart';
import 'widgets/table_background.dart';
import 'widgets/win_cascade_overlay.dart';

/// Sandboxed interactive 6-lesson Klondike guide supporting real tap & drag
/// card moves across curated setups without altering the active game or stats.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
    required this.settingsController,
    required this.audioService,
    this.onTutorialCompleted,
  });

  final SettingsController settingsController;
  final AudioService audioService;
  final VoidCallback? onTutorialCompleted;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with SingleTickerProviderStateMixin {
  late final List<TutorialLesson> _lessons = TutorialCurriculum.buildLessons();
  late final AnimationController _flipController;

  int _lessonIndex = 0;
  int _subStepIndex = 0;
  late BoardSnapshot _board;
  bool _lessonCompleted = false;
  String? _feedbackMessage;
  bool _isErrorFeedback = false;

  int? _flipColIndex;
  int? _flipCardIndex;
  int? _draggingColIndex;
  int? _draggingStartIdx;
  List<int>? _winCascadeRemainingCounts;
  bool _notifiedCompletion = false;

  double _lastCardWidth = 56.0;
  double _lastCardHeight = 80.0;
  double _lastColGap = 4.0;
  double _lastBoardWidth = 374.0;

  @override
  void initState() {
    super.initState();
    _board = _lessons.first.initialBoard;
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
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  TutorialLesson get _currentLesson => _lessons[_lessonIndex];

  TutorialSubStep get _currentSubStep {
    final steps = _currentLesson.subSteps;
    final idx = _subStepIndex.clamp(0, steps.length - 1);
    return steps[idx];
  }

  void _selectLesson(int index) {
    final clamped = index.clamp(0, _lessons.length - 1);
    _flipController.stop();
    setState(() {
      _lessonIndex = clamped;
      _subStepIndex = 0;
      _board = _lessons[clamped].initialBoard;
      _lessonCompleted = false;
      _feedbackMessage = null;
      _isErrorFeedback = false;
      _flipColIndex = null;
      _flipCardIndex = null;
      _draggingColIndex = null;
      _draggingStartIdx = null;
      _winCascadeRemainingCounts = null;
    });
  }

  void _notifyCompletedOnce() {
    if (_notifiedCompletion) return;
    _notifiedCompletion = true;
    widget.onTutorialCompleted?.call();
  }

  void _finishTutorial() {
    unawaited(widget.settingsController.setTutorialCompleted(true));
    _notifyCompletedOnce();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _advanceOrFinish() {
    if (_lessonIndex + 1 < _lessons.length) {
      _selectLesson(_lessonIndex + 1);
    } else {
      _finishTutorial();
    }
  }

  void _clearDragState() {
    if (!mounted) return;
    if (_draggingColIndex != null || _draggingStartIdx != null) {
      setState(() {
        _draggingColIndex = null;
        _draggingStartIdx = null;
      });
    }
  }

  void _showWrongFeedback({
    PlayingCard? attemptedCard,
    List<PlayingCard>? targetTableauCol,
    List<PlayingCard>? targetFoundation,
  }) {
    final msg = TutorialCurriculum.diagnoseWrongAttempt(
      lesson: _currentLesson,
      subStep: _currentSubStep,
      attemptedCard: attemptedCard,
      targetTableauCol: targetTableauCol,
      targetFoundation: targetFoundation,
    );
    setState(() {
      _feedbackMessage = msg;
      _isErrorFeedback = true;
    });
  }

  bool _attemptMove(SolitaireMove move) {
    if (_lessonCompleted) return false;

    final expected = _currentSubStep.expectedMove;
    if (!expected.matches(move)) {
      _showWrongFeedback();
      return false;
    }

    late final BoardSnapshot nextBoard;
    try {
      nextBoard = SolitaireRules.applyMove(_board, move, DrawMode.draw1);
    } catch (_) {
      _showWrongFeedback();
      return false;
    }

    int? revealedCol;
    int? revealedIdx;
    if (move.kind == MoveKind.tableauToFoundation ||
        move.kind == MoveKind.tableauToTableau) {
      final fromIdx = move.fromPileIndex!;
      final fromCol = _board.tableau[fromIdx];
      final count = move.kind == MoveKind.tableauToFoundation ? 1 : move.cardCount;
      final remaining = fromCol.length - count;
      if (remaining > 0 && !fromCol[remaining - 1].isFaceUp) {
        revealedCol = fromIdx;
        revealedIdx = remaining - 1;
      }
    }

    if (move.kind == MoveKind.wasteToFoundation ||
        move.kind == MoveKind.tableauToFoundation) {
      widget.audioService.playFoundationPlace();
    } else if (move.kind == MoveKind.drawStock || revealedCol != null) {
      widget.audioService.playCardFlip();
    } else {
      widget.audioService.playCardMove();
    }

    final isFinalSubStep = _subStepIndex + 1 >= _currentLesson.subSteps.length;
    final wonNow = isFinalSubStep && _currentLesson.triggersWinCelebration;
    if (wonNow) {
      widget.audioService.playWin();
      unawaited(widget.settingsController.setTutorialCompleted(true));
      _notifyCompletedOnce();
    }

    setState(() {
      _board = nextBoard;
      _feedbackMessage = null;
      _isErrorFeedback = false;
      _draggingColIndex = null;
      _draggingStartIdx = null;
      if (revealedCol != null && revealedIdx != null) {
        _flipColIndex = revealedCol;
        _flipCardIndex = revealedIdx;
        _flipController.forward(from: 0.0);
      }
      if (isFinalSubStep) {
        _lessonCompleted = true;
      } else {
        _subStepIndex++;
      }
    });
    return true;
  }

  void _handleStockTap() {
    if (_lessonCompleted || _board.stock.isEmpty) return;
    _attemptMove(const SolitaireMove(kind: MoveKind.drawStock));
  }

  void _handleWasteTap() {
    if (_lessonCompleted || _board.waste.isEmpty) return;
    final hint = TutorialCurriculum.resolveHighlightMove(
      _currentSubStep,
      _board,
    );
    if (hint.kind == MoveKind.wasteToTableau && hint.toPileIndex != null) {
      final candidate = SolitaireMove(
        kind: MoveKind.wasteToTableau,
        toPileIndex: hint.toPileIndex,
      );
      if (SolitaireRules.canPlaceOnTableau(
        _board.waste.last,
        _board.tableau[hint.toPileIndex!],
      )) {
        _attemptMove(candidate);
        return;
      }
    }
    final resolved = TapResolver.resolveWasteTap(_board);
    if (resolved != null && _currentSubStep.expectedMove.matches(resolved)) {
      _attemptMove(resolved);
    } else {
      _showWrongFeedback(attemptedCard: _board.waste.last);
    }
  }

  void _handleTableauTap(int colIdx, int cardIdx) {
    if (_lessonCompleted) return;
    final col = _board.tableau[colIdx];
    if (cardIdx < 0 || cardIdx >= col.length) return;
    final tapped = col[cardIdx];
    if (!tapped.isFaceUp) {
      _showWrongFeedback(attemptedCard: tapped);
      return;
    }

    final subRun = col.sublist(cardIdx);
    if (!SolitaireRules.isValidTableauRun(subRun)) {
      _showWrongFeedback(attemptedCard: tapped);
      return;
    }

    final expected = _currentSubStep.expectedMove;
    final hint = TutorialCurriculum.resolveHighlightMove(
      _currentSubStep,
      _board,
    );

    if (expected.kind == MoveKind.tableauToFoundation &&
        cardIdx == col.length - 1) {
      final destF = SolitaireRules.findFoundationDestination(
        tapped,
        _board.foundations,
      );
      if (destF != null) {
        _attemptMove(
          SolitaireMove(
            kind: MoveKind.tableauToFoundation,
            fromPileIndex: colIdx,
            toPileIndex: destF,
          ),
        );
        return;
      }
    }

    if (expected.kind == MoveKind.tableauToTableau &&
        hint.toPileIndex != null &&
        hint.toPileIndex != colIdx &&
        SolitaireRules.canPlaceOnTableau(
          subRun.first,
          _board.tableau[hint.toPileIndex!],
        )) {
      final move = SolitaireMove(
        kind: MoveKind.tableauToTableau,
        fromPileIndex: colIdx,
        toPileIndex: hint.toPileIndex,
        cardCount: subRun.length,
      );
      if (expected.matches(move)) {
        _attemptMove(move);
        return;
      }
    }

    final fallback = TapResolver.resolveTableauTap(_board, colIdx, cardIdx);
    if (fallback != null && expected.matches(fallback)) {
      _attemptMove(fallback);
      return;
    }

    _showWrongFeedback(attemptedCard: tapped);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, _) {
        final settings = widget.settingsController.settings;
        final theme = ClearDeckTheme.fromId(settings.tableTheme);
        final lesson = _currentLesson;
        final activeHint = _lessonCompleted
            ? null
            : TutorialCurriculum.resolveHighlightMove(
                _currentSubStep,
                _board,
              );

        final baseMedia = MediaQuery.of(context);
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
                  _buildTopBar(theme),
                  _buildCoachingCard(theme, lesson),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return _buildBoardArea(
                              constraints: constraints,
                              theme: theme,
                              settings: settings,
                              hintMove: activeHint,
                            );
                          },
                        ),
                        if (_lessonCompleted && lesson.triggersWinCelebration)
                          Positioned.fill(
                            child: WinCascadeOverlay(
                              cardWidth: _lastCardWidth,
                              cardHeight: _lastCardHeight,
                              theme: theme,
                              fourColorDeck: settings.fourColorDeck,
                              leftHanded: settings.leftHanded,
                              deckFaceStyle: settings.deckFaceStyle,
                              colGap: _lastColGap,
                              boardWidth: _lastBoardWidth,
                              topOffset: 10.0,
                              foundations: _board.foundations,
                              onFoundationRemainingChanged: (counts) {
                                if (!mounted || !_lessonCompleted) return;
                                setState(() {
                                  _winCascadeRemainingCounts = counts;
                                });
                              },
                            ),
                          ),
                        if (_lessonCompleted && lesson.triggersWinCelebration)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 16,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 420),
                                child: Material(
                                  color: theme.sheetCard,
                                  elevation: 6,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.goldTrim,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          'You Are Ready to Play',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: theme.sheetText,
                                            fontFamily: 'Georgia',
                                            fontSize: 22,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Every core Klondike rule is ready at your fingertips.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: theme.sheetSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton(
                                            key: const Key(
                                              'tutorial_finish_button',
                                            ),
                                            style: FilledButton.styleFrom(
                                              minimumSize: const Size(0, 48),
                                            ),
                                            onPressed: _finishTutorial,
                                            child: const Text('Start Playing'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildBottomControls(theme),
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

  Widget _buildTopBar(ClearDeckTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.dockBackground,
        border: Border(
          bottom: BorderSide(color: theme.chromeHairline, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Row(
            children: <Widget>[
              Icon(Icons.menu_book_rounded, size: 18, color: theme.goldTrim),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'How to Play',
                      maxLines: 1,
                      style: TextStyle(
                        color: theme.textOnTable,
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Step ${_lessonIndex + 1} of ${_lessons.length}',
                key: const Key('tutorial_step_indicator'),
                maxLines: 1,
                style: TextStyle(
                  color: theme.mutedOnTable,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const Key('tutorial_exit_button'),
                tooltip: 'Close Tutorial',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: theme.textOnTable,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoachingCard(ClearDeckTheme theme, TutorialLesson lesson) {
    final subStep = _currentSubStep;
    final bannerText = _lessonCompleted
        ? lesson.completionMessage
        : (_feedbackMessage ?? subStep.prompt);
    final IconData bannerIcon;
    final Color bannerColor;

    if (_lessonCompleted) {
      bannerIcon = Icons.check_circle_rounded;
      bannerColor = const Color(0xFF1F6E4A);
    } else if (_isErrorFeedback) {
      bannerIcon = Icons.info_outline_rounded;
      bannerColor = const Color(0xFFB21E24);
    } else {
      bannerIcon = Icons.touch_app_rounded;
      bannerColor = theme.goldTrim;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.sheetCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.goldTrim.withValues(alpha: 0.72),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        lesson.title,
                        key: const Key('tutorial_lesson_title'),
                        style: TextStyle(
                          color: theme.sheetText,
                          fontFamily: 'Georgia',
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _lessonCompleted
                            ? theme.goldTrim.withValues(alpha: 0.18)
                            : theme.sheetRaised,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _lessonCompleted ? 'Complete' : 'Rule ${_lessonIndex + 1}',
                        style: TextStyle(
                          color: _lessonCompleted
                              ? theme.goldTrim
                              : theme.sheetSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  lesson.ruleSummary,
                  style: TextStyle(
                    color: theme.sheetSecondary,
                    fontSize: 13.5,
                    height: 1.38,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: bannerColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: bannerColor.withValues(alpha: 0.40),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(bannerIcon, size: 18, color: bannerColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bannerText,
                          key: const Key('tutorial_action_prompt'),
                          style: TextStyle(
                            color: theme.sheetText,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardArea({
    required BoxConstraints constraints,
    required ClearDeckTheme theme,
    required AppSettings settings,
    required SolitaireMove? hintMove,
  }) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final isTabletLandscape =
        shortestSide >= 600 && width > height && width >= 700;
    final sidePadding = isTabletLandscape ? 24.0 : 4.0;
    final boardWidth = isTabletLandscape
        ? math.min(width - sidePadding * 2, 920.0)
        : (width - sidePadding * 2);
    final rawGap = isTabletLandscape ? 12.0 : 2.5;
    final rawCardWidth = (boardWidth - rawGap * 6) / 7;
    final maxCardHeightFromHeight = isTabletLandscape
        ? ((height - 16.0) * 0.24).clamp(50.0, 180.0)
        : ((height - 16.0) * 0.265).clamp(50.0, 180.0);
    final cardWidth = math
        .min(rawCardWidth, maxCardHeightFromHeight / 1.48)
        .clamp(36.0, 124.0);
    final cardHeight = cardWidth * 1.48;
    final colGap = ((boardWidth - cardWidth * 7) / 6).clamp(0.0, 200.0);
    final rowSpacing = isTabletLandscape ? 14.0 : 10.0;

    _lastCardWidth = cardWidth;
    _lastCardHeight = cardHeight;
    _lastColGap = colGap;
    _lastBoardWidth = boardWidth;

    return Center(
      child: SizedBox(
        width: boardWidth,
        height: height,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Column(
            children: <Widget>[
              _buildTopRow(
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                colGap: colGap,
                theme: theme,
                settings: settings,
                hintMove: hintMove,
              ),
              SizedBox(height: rowSpacing),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, tableauConstraints) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List<Widget>.generate(7, (colIdx) {
                        return _buildTableauColumn(
                          colIdx: colIdx,
                          cards: _board.tableau[colIdx],
                          cardWidth: cardWidth,
                          cardHeight: cardHeight,
                          maxColumnHeight: tableauConstraints.maxHeight,
                          theme: theme,
                          settings: settings,
                          hintMove: hintMove,
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

  Widget _buildTopRow({
    required double cardWidth,
    required double cardHeight,
    required double colGap,
    required ClearDeckTheme theme,
    required AppSettings settings,
    required SolitaireMove? hintMove,
  }) {
    final stockWidget = _buildStock(
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      theme: theme,
      settings: settings,
      isHighlighted: hintMove?.kind == MoveKind.drawStock,
    );
    final wasteWidget = _buildWaste(
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      colGap: colGap,
      theme: theme,
      settings: settings,
      isHighlighted: hintMove?.kind == MoveKind.wasteToTableau ||
          hintMove?.kind == MoveKind.wasteToFoundation,
    );
    final foundations = List<Widget>.generate(4, (fIdx) {
      return _buildFoundation(
        fIdx: fIdx,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        theme: theme,
        settings: settings,
        isHighlighted: (hintMove?.kind == MoveKind.tableauToFoundation ||
                hintMove?.kind == MoveKind.wasteToFoundation) &&
            hintMove?.toPileIndex == fIdx,
      );
    });

    final children = settings.leftHanded
        ? <Widget>[...foundations, wasteWidget, stockWidget]
        : <Widget>[stockWidget, wasteWidget, ...foundations];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: children,
    );
  }

  Widget _buildStock({
    required double cardWidth,
    required double cardHeight,
    required ClearDeckTheme theme,
    required AppSettings settings,
    required bool isHighlighted,
  }) {
    final hasCards = _board.stock.isNotEmpty;
    return GestureDetector(
      key: const Key('tutorial_stock'),
      behavior: HitTestBehavior.opaque,
      onTap: _handleStockTap,
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
              icon: _board.waste.isNotEmpty
                  ? Icons.refresh_rounded
                  : Icons.block_rounded,
              isHighlighted: !hasCards && isHighlighted,
            ),
            if (hasCards)
              DeckDepthStack(
                cardCount: _board.stock.length,
                width: cardWidth,
                height: cardHeight,
                theme: theme,
                topCard: PlayingCardWidget(
                  card: _board.stock.last,
                  width: cardWidth,
                  height: cardHeight,
                  theme: theme,
                  fourColorDeck: settings.fourColorDeck,
                  cardScale: settings.cardScale,
                  deckFaceStyle: settings.deckFaceStyle,
                  cardBackStyle: settings.cardBackStyle,
                  isHighlighted: isHighlighted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaste({
    required double cardWidth,
    required double cardHeight,
    required double colGap,
    required ClearDeckTheme theme,
    required AppSettings settings,
    required bool isHighlighted,
  }) {
    final slotWidth = cardWidth * 2 + colGap;
    final leftOffset = settings.leftHanded ? (cardWidth + colGap) : 0.0;

    if (_board.waste.isEmpty) {
      return SizedBox(
        key: const Key('tutorial_waste'),
        width: slotWidth,
        height: cardHeight,
        child: Stack(
          children: <Widget>[
            Positioned(
              left: leftOffset,
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

    final topCard = _board.waste.last;
    final payload = CardDragPayload(
      sourceKind: MoveKind.wasteToTableau,
      fromPileIndex: 0,
      cards: <PlayingCard>[topCard],
    );

    final face = DeckDepthStack(
      cardCount: _board.waste.length,
      width: cardWidth,
      height: cardHeight,
      theme: theme,
      topCard: PlayingCardWidget(
        card: topCard,
        width: cardWidth,
        height: cardHeight,
        theme: theme,
        fourColorDeck: settings.fourColorDeck,
        cardScale: settings.cardScale,
        deckFaceStyle: settings.deckFaceStyle,
        cardBackStyle: settings.cardBackStyle,
        isHighlighted: isHighlighted,
      ),
    );

    return SizedBox(
      key: const Key('tutorial_waste'),
      width: slotWidth,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: leftOffset,
            top: 0,
            child: EmptyPileSlot(
              width: cardWidth,
              height: cardHeight,
              theme: theme,
            ),
          ),
          Positioned(
            left: leftOffset,
            top: 0,
            child: Draggable<CardDragPayload>(
              data: payload,
              maxSimultaneousDrags: _lessonCompleted ? 0 : 1,
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
                    fourColorDeck: settings.fourColorDeck,
                    cardScale: settings.cardScale,
                    deckFaceStyle: settings.deckFaceStyle,
                    cardBackStyle: settings.cardBackStyle,
                    isElevated: true,
                  ),
                ),
              ),
              childWhenDragging: EmptyPileSlot(
                width: cardWidth,
                height: cardHeight,
                theme: theme,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleWasteTap,
                child: face,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundation({
    required int fIdx,
    required double cardWidth,
    required double cardHeight,
    required ClearDeckTheme theme,
    required AppSettings settings,
    required bool isHighlighted,
  }) {
    final pile = _board.foundations[fIdx];
    return DragTarget<CardDragPayload>(
      key: Key('tutorial_foundation_$fIdx'),
      onWillAcceptWithDetails: (details) {
        if (_lessonCompleted) return false;
        final payload = details.data;
        if (payload.cards.length != 1) return false;
        final canPlace =
            SolitaireRules.canPlaceOnFoundation(payload.cards.single, pile);
        if (!canPlace) {
          _showWrongFeedback(
            attemptedCard: payload.cards.single,
            targetFoundation: pile,
          );
          return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload.sourceKind == MoveKind.wasteToTableau) {
          _attemptMove(
            SolitaireMove(kind: MoveKind.wasteToFoundation, toPileIndex: fIdx),
          );
        } else if (payload.sourceKind == MoveKind.tableauToTableau) {
          _attemptMove(
            SolitaireMove(
              kind: MoveKind.tableauToFoundation,
              fromPileIndex: payload.fromPileIndex,
              toPileIndex: fIdx,
            ),
          );
        }
      },
      builder: (context, candidateData, _) {
        final highlight = isHighlighted || candidateData.isNotEmpty;
        final isCascading = _lessonCompleted &&
            _currentLesson.triggersWinCelebration &&
            _winCascadeRemainingCounts != null &&
            fIdx < _winCascadeRemainingCounts!.length;
        final visibleLen = isCascading
            ? math.min(pile.length, _winCascadeRemainingCounts![fIdx])
            : pile.length;
        final visiblePile = visibleLen > 0
            ? pile.sublist(0, visibleLen)
            : const <PlayingCard>[];

        if (visiblePile.isEmpty) {
          return EmptyPileSlot(
            width: cardWidth,
            height: cardHeight,
            theme: theme,
            label: 'A',
            isHighlighted: highlight,
            isFoundation: true,
          );
        }
        return DeckDepthStack(
          cardCount: visiblePile.length,
          width: cardWidth,
          height: cardHeight,
          theme: theme,
          topCard: PlayingCardWidget(
            card: visiblePile.last,
            width: cardWidth,
            height: cardHeight,
            theme: theme,
            fourColorDeck: settings.fourColorDeck,
            cardScale: settings.cardScale,
            deckFaceStyle: settings.deckFaceStyle,
            cardBackStyle: settings.cardBackStyle,
            isHighlighted: highlight,
          ),
        );
      },
    );
  }

  Widget _buildTableauColumn({
    required int colIdx,
    required List<PlayingCard> cards,
    required double cardWidth,
    required double cardHeight,
    required double maxColumnHeight,
    required ClearDeckTheme theme,
    required AppSettings settings,
    required SolitaireMove? hintMove,
  }) {
    final isHintTarget = (hintMove?.kind == MoveKind.wasteToTableau ||
            hintMove?.kind == MoveKind.tableauToTableau) &&
        hintMove?.toPileIndex == colIdx;
    final hintSourceSplitIndex =
        (hintMove?.kind == MoveKind.tableauToTableau ||
                    hintMove?.kind == MoveKind.tableauToFoundation) &&
                hintMove?.fromPileIndex == colIdx
            ? (cards.length - (hintMove?.cardCount ?? 1))
            : null;

    return DragTarget<CardDragPayload>(
      key: Key('tutorial_tableau_$colIdx'),
      onWillAcceptWithDetails: (details) {
        if (_lessonCompleted) return false;
        final payload = details.data;
        if (payload.sourceKind == MoveKind.tableauToTableau &&
            payload.fromPileIndex == colIdx) {
          return false;
        }
        final canPlace =
            SolitaireRules.canPlaceOnTableau(payload.cards.first, cards);
        if (!canPlace) {
          _showWrongFeedback(
            attemptedCard: payload.cards.first,
            targetTableauCol: cards,
          );
          return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload.sourceKind == MoveKind.wasteToTableau) {
          _attemptMove(
            SolitaireMove(kind: MoveKind.wasteToTableau, toPileIndex: colIdx),
          );
        } else if (payload.sourceKind == MoveKind.tableauToTableau) {
          _attemptMove(
            SolitaireMove(
              kind: MoveKind.tableauToTableau,
              fromPileIndex: payload.fromPileIndex,
              toPileIndex: colIdx,
              cardCount: payload.cards.length,
            ),
          );
        }
      },
      builder: (context, candidateData, _) {
        final dropHighlight = isHintTarget || candidateData.isNotEmpty;
        if (cards.isEmpty) {
          return SizedBox(
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
          );
        }

        final isJumbo = settings.cardScale == CardScale.jumbo;
        var downStep = (cardHeight * 0.16).clamp(9.0, 18.0);
        var upStep = (cardHeight * (isJumbo ? 0.42 : 0.37)).clamp(22.0, 54.0);
        var rawTotal = 0.0;
        for (var i = 0; i < cards.length - 1; i++) {
          rawTotal += cards[i].isFaceUp ? upStep : downStep;
        }
        final avail = (maxColumnHeight - cardHeight - 4.0)
            .clamp(0.0, maxColumnHeight);
        if (rawTotal > avail && rawTotal > 0) {
          final scale = avail / rawTotal;
          downStep *= scale;
          upStep *= scale;
        }
        final tops = <double>[0.0];
        for (var i = 0; i < cards.length - 1; i++) {
          tops.add(tops[i] + (cards[i].isFaceUp ? upStep : downStep));
        }

        final colDraggingStart =
            _draggingColIndex == colIdx ? _draggingStartIdx : null;

        return SizedBox(
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
              for (var idx = 0; idx < cards.length; idx++)
                _buildTableauCard(
                  colIdx: colIdx,
                  idx: idx,
                  cards: cards,
                  top: tops[idx],
                  upStep: upStep,
                  cardWidth: cardWidth,
                  cardHeight: cardHeight,
                  theme: theme,
                  settings: settings,
                  highlightThisCard: (dropHighlight && idx == cards.length - 1) ||
                      (hintSourceSplitIndex != null &&
                          idx >= hintSourceSplitIndex),
                  isHiddenByParentDrag:
                      colDraggingStart != null && idx > colDraggingStart,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableauCard({
    required int colIdx,
    required int idx,
    required List<PlayingCard> cards,
    required double top,
    required double upStep,
    required double cardWidth,
    required double cardHeight,
    required ClearDeckTheme theme,
    required AppSettings settings,
    required bool highlightThisCard,
    required bool isHiddenByParentDrag,
  }) {
    final card = cards[idx];
    final face = PlayingCardWidget(
      card: card,
      width: cardWidth,
      height: cardHeight,
      theme: theme,
      fourColorDeck: settings.fourColorDeck,
      cardScale: settings.cardScale,
      deckFaceStyle: settings.deckFaceStyle,
      cardBackStyle: settings.cardBackStyle,
      isHighlighted: highlightThisCard,
    );

    final isFlippingHere =
        _flipColIndex == colIdx && _flipCardIndex == idx && _flipController.isAnimating;

    final displayWidget = isFlippingHere
        ? _TutorialFlipCard(
            animation: _flipController,
            width: cardWidth,
            height: cardHeight,
            front: RepaintBoundary(child: face),
            back: RepaintBoundary(
              child: CardBackPatternWidget(
                style: settings.cardBackStyle,
                width: cardWidth,
                height: cardHeight,
                paperColor: theme.cardFace,
                borderColor: theme.cardBorder,
              ),
            ),
          )
        : face;

    if (!card.isFaceUp) {
      return Positioned(
        left: 0,
        top: top,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTableauTap(colIdx, idx),
          child: displayWidget,
        ),
      );
    }

    if (isHiddenByParentDrag) {
      return Positioned(
        left: 0,
        top: top,
        child: IgnorePointer(
          child: Opacity(opacity: 0.0, child: displayWidget),
        ),
      );
    }

    final subRun = cards.sublist(idx);
    if (!SolitaireRules.isValidTableauRun(subRun)) {
      return Positioned(left: 0, top: top, child: displayWidget);
    }

    final payload = CardDragPayload(
      sourceKind: MoveKind.tableauToTableau,
      fromPileIndex: colIdx,
      cards: subRun,
    );

    return Positioned(
      left: 0,
      top: top,
      child: Draggable<CardDragPayload>(
        data: payload,
        maxSimultaneousDrags: _lessonCompleted ? 0 : 1,
        onDragStarted: () {
          setState(() {
            _draggingColIndex = colIdx;
            _draggingStartIdx = idx;
          });
        },
        onDragEnd: (_) => _clearDragState(),
        onDraggableCanceled: (_, _) => _clearDragState(),
        onDragCompleted: _clearDragState,
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(
            scale: 1.04,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: cardWidth,
              height: cardHeight + (subRun.length - 1) * upStep,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  for (var i = 0; i < subRun.length; i++)
                    Positioned(
                      left: 0,
                      top: i * upStep,
                      child: PlayingCardWidget(
                        card: subRun[i],
                        width: cardWidth,
                        height: cardHeight,
                        theme: theme,
                        fourColorDeck: settings.fourColorDeck,
                        cardScale: settings.cardScale,
                        deckFaceStyle: settings.deckFaceStyle,
                        cardBackStyle: settings.cardBackStyle,
                        isElevated: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        childWhenDragging: SizedBox(width: cardWidth, height: cardHeight),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTableauTap(colIdx, idx),
          child: displayWidget,
        ),
      ),
    );
  }

  Widget _buildBottomControls(ClearDeckTheme theme) {
    final isLast = _lessonIndex + 1 >= _lessons.length;

    return Container(
      decoration: BoxDecoration(
        color: theme.dockBackground,
        border: Border(
          top: BorderSide(color: theme.chromeHairline, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Row(
            children: <Widget>[
              OutlinedButton.icon(
                key: const Key('tutorial_back_button'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: theme.chromeButtonSurface,
                  foregroundColor: theme.textOnTable,
                  disabledForegroundColor:
                      theme.mutedOnTable.withValues(alpha: 0.42),
                  side: BorderSide(color: theme.chromeHairline),
                  minimumSize: const Size(76, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: _lessonIndex > 0
                    ? () => _selectLesson(_lessonIndex - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Back'),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(_lessons.length, (i) {
                        final active = i == _lessonIndex;
                        return GestureDetector(
                          onTap: () => _selectLesson(i),
                          child: Container(
                            width: active ? 16 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            decoration: BoxDecoration(
                              color: active
                                  ? theme.goldTrim
                                  : theme.mutedOnTable.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              if (_lessonCompleted)
                FilledButton.icon(
                  key: const Key('tutorial_next_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.goldTrim,
                    foregroundColor: const Color(0xFF1A1612),
                    minimumSize: const Size(104, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: _advanceOrFinish,
                  icon: Icon(
                    isLast ? Icons.check_rounded : Icons.chevron_right_rounded,
                    size: 18,
                  ),
                  label: Text(isLast ? 'Finish' : 'Next Step'),
                )
              else
                OutlinedButton(
                  key: const Key('tutorial_skip_button'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: theme.chromeButtonSurface,
                    foregroundColor: theme.textOnTable,
                    side: BorderSide(color: theme.chromeHairline),
                    minimumSize: const Size(76, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: _advanceOrFinish,
                  child: Text(isLast ? 'Finish' : 'Skip'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialFlipCard extends StatelessWidget {
  const _TutorialFlipCard({
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
