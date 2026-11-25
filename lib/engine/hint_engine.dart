import 'dart:collection';

import 'game_state.dart';
import 'move.dart';
import 'rules.dart';

/// Result returned by [HintEngine.findSmartHint].
class HintResult {
  const HintResult({
    required this.move,
    required this.isDeadEnd,
    required this.reason,
  });

  final SolitaireMove? move;
  final bool isDeadEnd;
  final String reason;
}

/// Loop-free hint engine & Stock-cycle Dead-End detector.
/// Eliminates frustrating junk hints (e.g., moving a Queen onto a King when no
/// hidden card or foundation card is exposed, or empty-King shuffling).
class HintEngine {
  const HintEngine._();

  static HintResult findSmartHint(
    BoardSnapshot board,
    DrawMode drawMode, {
    int consecutiveStockCycles = 0,
  }) {
    if (SolitaireRules.isWon(board)) {
      return const HintResult(
        move: null,
        isDeadEnd: false,
        reason: 'Board is already won',
      );
    }

    // 1. Safe Foundation move (Ace / 2 / safe rank from Tableau or Waste)
    for (var c = 0; c < 7; c++) {
      final col = board.tableau[c];
      if (col.isEmpty || !col.last.isFaceUp) continue;
      final card = col.last;
      if (SolitaireRules.isSafeFoundationMove(card, board.foundations)) {
        final fIdx = SolitaireRules.findFoundationDestination(
          card,
          board.foundations,
        );
        if (fIdx != null) {
          return HintResult(
            move: SolitaireMove(
              kind: MoveKind.tableauToFoundation,
              fromPileIndex: c,
              toPileIndex: fIdx,
              priority: 100,
            ),
            isDeadEnd: false,
            reason: 'Move ${card.rankLabel}${card.suit.symbol} to foundation',
          );
        }
      }
    }

    if (board.waste.isNotEmpty) {
      final card = board.waste.last;
      if (SolitaireRules.isSafeFoundationMove(card, board.foundations)) {
        final fIdx = SolitaireRules.findFoundationDestination(
          card,
          board.foundations,
        );
        if (fIdx != null) {
          return HintResult(
            move: SolitaireMove(
              kind: MoveKind.wasteToFoundation,
              toPileIndex: fIdx,
              priority: 95,
            ),
            isDeadEnd: false,
            reason: 'Move ${card.rankLabel}${card.suit.symbol} to foundation',
          );
        }
      }
    }

    // 2. Tableau -> Tableau move that uncovers a face-down card (non-King or King)
    final hasWaitingKing = _hasWaitingKingForEmptyColumn(board);
    SolitaireMove? uncoverNonKingMove;
    SolitaireMove? uncoverKingMove;
    SolitaireMove? exposeFoundationMove;
    SolitaireMove? vacateForKingMove;

    for (var from = 0; from < 7; from++) {
      final col = board.tableau[from];
      if (col.isEmpty) continue;

      for (var split = 0; split < col.length; split++) {
        if (!col[split].isFaceUp) continue;
        final subRun = col.sublist(split);
        if (!SolitaireRules.isValidTableauRun(subRun)) continue;

        final movingBottom = subRun.first;
        final uncoversFaceDown = split > 0 && !col[split - 1].isFaceUp;
        final emptiesColumn = split == 0;
        final cardBelowIsFaceUp = split > 0 && col[split - 1].isFaceUp;
        final exposesFoundation = cardBelowIsFaceUp &&
            SolitaireRules.findFoundationDestination(
                  col[split - 1],
                  board.foundations,
                ) !=
                null;

        // Anti-junk rule #1: Never move a King from an empty column base to another empty column.
        if (emptiesColumn && movingBottom.rank == 13) continue;

        // Anti-junk rule #2: Never suggest moving a face-up sub-stack when the card
        // directly underneath it is already face-up UNLESS it immediately exposes
        // a card playable to a foundation.
        if (cardBelowIsFaceUp && !exposesFoundation) continue;

        for (var to = 0; to < 7; to++) {
          if (from == to) continue;
          final targetCol = board.tableau[to];
          if (!SolitaireRules.canPlaceOnTableau(movingBottom, targetCol)) {
            continue;
          }

          final candidate = SolitaireMove(
            kind: MoveKind.tableauToTableau,
            fromPileIndex: from,
            toPileIndex: to,
            cardCount: subRun.length,
          );

          if (uncoversFaceDown) {
            if (movingBottom.rank == 13 && targetCol.isEmpty) {
              uncoverKingMove ??= candidate.withPriority(85);
            } else {
              uncoverNonKingMove ??= candidate.withPriority(90);
            }
          } else if (exposesFoundation) {
            exposeFoundationMove ??= candidate.withPriority(82);
          } else if (emptiesColumn && targetCol.isNotEmpty && hasWaitingKing) {
            vacateForKingMove ??= candidate.withPriority(78);
          }
        }
      }
    }

    if (uncoverNonKingMove != null) {
      return HintResult(
        move: uncoverNonKingMove,
        isDeadEnd: false,
        reason: 'Reveal a hidden tableau card',
      );
    }
    if (uncoverKingMove != null) {
      return HintResult(
        move: uncoverKingMove,
        isDeadEnd: false,
        reason: 'Move King to empty column to reveal a hidden card',
      );
    }
    if (exposeFoundationMove != null) {
      return HintResult(
        move: exposeFoundationMove,
        isDeadEnd: false,
        reason: 'Free a card for the foundation',
      );
    }
    if (vacateForKingMove != null) {
      return HintResult(
        move: vacateForKingMove,
        isDeadEnd: false,
        reason: 'Clear an empty column for a waiting King',
      );
    }

    // 3. Remaining legal Foundation moves (higher rank)
    if (board.waste.isNotEmpty) {
      final card = board.waste.last;
      final fIdx = SolitaireRules.findFoundationDestination(
        card,
        board.foundations,
      );
      if (fIdx != null) {
        return HintResult(
          move: SolitaireMove(
            kind: MoveKind.wasteToFoundation,
            toPileIndex: fIdx,
            priority: 75,
          ),
          isDeadEnd: false,
          reason: 'Move ${card.rankLabel}${card.suit.symbol} to foundation',
        );
      }
    }

    for (var c = 0; c < 7; c++) {
      final col = board.tableau[c];
      if (col.isEmpty || !col.last.isFaceUp) continue;
      final card = col.last;
      final fIdx = SolitaireRules.findFoundationDestination(
        card,
        board.foundations,
      );
      if (fIdx != null) {
        return HintResult(
          move: SolitaireMove(
            kind: MoveKind.tableauToFoundation,
            fromPileIndex: c,
            toPileIndex: fIdx,
            priority: 74,
          ),
          isDeadEnd: false,
          reason: 'Move ${card.rankLabel}${card.suit.symbol} to foundation',
        );
      }
    }

    // 4. Waste -> Tableau
    if (board.waste.isNotEmpty) {
      final wasteTop = board.waste.last;
      for (var to = 0; to < 7; to++) {
        if (SolitaireRules.canPlaceOnTableau(wasteTop, board.tableau[to])) {
          return HintResult(
            move: SolitaireMove(
              kind: MoveKind.wasteToTableau,
              toPileIndex: to,
              priority: 65,
            ),
            isDeadEnd: false,
            reason:
                'Move ${wasteTop.rankLabel}${wasteTop.suit.symbol} from waste',
          );
        }
      }
    }

    // 5. Constructive Stock Draw / Recycle lookahead across full stock cycle
    if (consecutiveStockCycles < 2 &&
        (board.stock.isNotEmpty || board.waste.isNotEmpty)) {
      if (_hasPlayableCardInStockCycle(board, drawMode)) {
        if (board.stock.isNotEmpty) {
          return const HintResult(
            move: SolitaireMove(kind: MoveKind.drawStock, priority: 40),
            isDeadEnd: false,
            reason: 'Draw from stock to reach a playable card',
          );
        } else {
          return const HintResult(
            move: SolitaireMove(kind: MoveKind.recycleStock, priority: 35),
            isDeadEnd: false,
            reason: 'Recycle waste back to stock to reach a playable card',
          );
        }
      }
    }

    return const HintResult(
      move: null,
      isDeadEnd: true,
      reason: 'No constructive moves remain',
    );
  }

  static bool _hasWaitingKingForEmptyColumn(BoardSnapshot board) {
    if (board.waste.isNotEmpty && board.waste.last.rank == 13) return true;
    for (final col in board.tableau) {
      for (var i = 1; i < col.length; i++) {
        if (col[i].isFaceUp && col[i].rank == 13 && !col[i - 1].isFaceUp) {
          return true;
        }
      }
    }
    return false;
  }

  /// Simulates drawing/recycling the stock without mutating foundations or
  /// tableau to determine if ANY reachable waste top card can be legally played.
  static bool _hasPlayableCardInStockCycle(
    BoardSnapshot start,
    DrawMode drawMode,
  ) {
    var current = start;
    final seenStockWaste = HashSet<String>();
    final maxSteps = start.stock.length + start.waste.length + 4;

    for (var step = 0; step < maxSteps; step++) {
      final cycleKey =
          '${current.stock.map((c) => c.identityKey).join(',')}|'
          '${current.waste.map((c) => c.identityKey).join(',')}';
      if (!seenStockWaste.add(cycleKey)) {
        return false;
      }

      if (current.stock.isNotEmpty) {
        current = SolitaireRules.applyMove(
          current,
          const SolitaireMove(kind: MoveKind.drawStock),
          drawMode,
        );
      } else if (current.waste.isNotEmpty) {
        current = SolitaireRules.applyMove(
          current,
          const SolitaireMove(kind: MoveKind.recycleStock),
          drawMode,
        );
      } else {
        return false;
      }

      if (current.waste.isNotEmpty) {
        final top = current.waste.last;
        if (SolitaireRules.findFoundationDestination(
              top,
              current.foundations,
            ) !=
            null) {
          return true;
        }
        for (var to = 0; to < 7; to++) {
          if (SolitaireRules.canPlaceOnTableau(top, current.tableau[to])) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
