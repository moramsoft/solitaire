import 'dart:math' as math;

import 'card.dart';
import 'game_state.dart';
import 'move.dart';

/// Pure Klondike Solitaire rule validation and move transition logic.
class SolitaireRules {
  const SolitaireRules._();

  /// Returns true if [card] can legally be placed atop [foundation].
  static bool canPlaceOnFoundation(
    PlayingCard card,
    List<PlayingCard> foundation,
  ) {
    if (foundation.isEmpty) {
      return card.rank == 1;
    }
    final top = foundation.last;
    return top.suit == card.suit && card.rank == top.rank + 1;
  }

  static String _rankLabel(int rank) => switch (rank) {
        1 => 'A',
        11 => 'J',
        12 => 'Q',
        13 => 'K',
        _ => '$rank',
      };

  /// Explains why [card] (or a multi-card stack) cannot be placed onto
  /// [foundation], or returns null when the move is legal.
  static String? explainFoundationRejection(
    PlayingCard card,
    List<PlayingCard> foundation, {
    int cardCount = 1,
  }) {
    if (cardCount > 1) {
      return 'Top foundation slots accept one card at a time.';
    }
    if (foundation.isEmpty) {
      if (card.rank == 1) return null;
      return 'Start empty top slots with an Ace (A), then build up in the same suit.';
    }
    final top = foundation.last;
    if (top.suit != card.suit) {
      return 'Top foundation slots build in the same suit — only ${top.suit.symbol} goes on ${top.rankLabel}${top.suit.symbol} (A → K).';
    }
    if (card.rank != top.rank + 1) {
      if (top.rank >= 13) {
        return 'That ${top.suit.displayName} foundation is already complete up to K.';
      }
      return 'Top foundation slots build upward by 1 — next on ${top.rankLabel}${top.suit.symbol} is ${_rankLabel(top.rank + 1)}${top.suit.symbol}.';
    }
    return null;
  }

  /// Explains why [bottomMovingCard] cannot be placed onto [targetColumn], or
  /// returns null when the move is legal.
  static String? explainTableauRejection(
    PlayingCard bottomMovingCard,
    List<PlayingCard> targetColumn,
  ) {
    if (targetColumn.isEmpty) {
      if (bottomMovingCard.rank == 13) return null;
      return 'Only a King (K) — or a stack led by a King — can start an empty column.';
    }
    final targetTop = targetColumn.last;
    if (!targetTop.isFaceUp) {
      return 'Face-down cards flip automatically once the cards on top are cleared.';
    }
    if (bottomMovingCard.suit.isRed == targetTop.suit.isRed) {
      return 'Table columns alternate colors — place Red on Black, or Black on Red.';
    }
    if (bottomMovingCard.rank != targetTop.rank - 1) {
      if (targetTop.rank <= 1) {
        return 'Nothing can stack below an Ace on the table — move the Ace to a top slot.';
      }
      return 'Table columns count downward by 1 — place ${_rankLabel(targetTop.rank - 1)} on ${targetTop.rankLabel}${targetTop.suit.symbol}.';
    }
    return null;
  }

  /// Returns true if a run whose bottom card is [bottomMovingCard] can legally
  /// be placed on [targetColumn].
  static bool canPlaceOnTableau(
    PlayingCard bottomMovingCard,
    List<PlayingCard> targetColumn,
  ) {
    if (targetColumn.isEmpty) {
      return bottomMovingCard.rank == 13;
    }
    final targetTop = targetColumn.last;
    if (!targetTop.isFaceUp) return false;
    return bottomMovingCard.suit.isRed != targetTop.suit.isRed &&
        bottomMovingCard.rank == targetTop.rank - 1;
  }

  /// Validates that [cards] is a non-empty face-up descending run of
  /// strictly alternating colors.
  static bool isValidTableauRun(List<PlayingCard> cards) {
    if (cards.isEmpty) return false;
    for (var i = 0; i < cards.length; i++) {
      if (!cards[i].isFaceUp) return false;
      if (i > 0) {
        final prev = cards[i - 1];
        final curr = cards[i];
        if (prev.suit.isRed == curr.suit.isRed || prev.rank != curr.rank + 1) {
          return false;
        }
      }
    }
    return true;
  }

  /// Applies [move] to [board] and returns the resulting [BoardSnapshot].
  /// Throws [StateError] or [RangeError] if the move is illegal.
  static BoardSnapshot applyMove(
    BoardSnapshot board,
    SolitaireMove move,
    DrawMode drawMode,
  ) {
    final next = board.cloneMutable();

    switch (move.kind) {
      case MoveKind.drawStock:
        if (next.stock.isEmpty) {
          throw StateError('Cannot draw from an empty stock pile.');
        }
        final count = math.min(drawMode.drawCount, next.stock.length);
        for (var i = 0; i < count; i++) {
          final drawn = next.stock.removeLast().copyWith(isFaceUp: true);
          next.waste.add(drawn);
        }
      case MoveKind.recycleStock:
        if (next.stock.isNotEmpty || next.waste.isEmpty) {
          throw StateError(
            'Stock can only be recycled when stock is empty and waste is not empty.',
          );
        }
        while (next.waste.isNotEmpty) {
          next.stock.add(next.waste.removeLast().copyWith(isFaceUp: false));
        }
      case MoveKind.wasteToFoundation:
        final toIdx = move.toPileIndex!;
        if (next.waste.isEmpty) {
          throw StateError('Waste is empty.');
        }
        final card = next.waste.last;
        if (!canPlaceOnFoundation(card, next.foundations[toIdx])) {
          throw StateError('Illegal waste-to-foundation move.');
        }
        next.waste.removeLast();
        next.foundations[toIdx].add(card.copyWith(isFaceUp: true));
      case MoveKind.wasteToTableau:
        final toIdx = move.toPileIndex!;
        if (next.waste.isEmpty) {
          throw StateError('Waste is empty.');
        }
        final card = next.waste.last;
        if (!canPlaceOnTableau(card, next.tableau[toIdx])) {
          throw StateError('Illegal waste-to-tableau move.');
        }
        next.waste.removeLast();
        next.tableau[toIdx].add(card.copyWith(isFaceUp: true));
      case MoveKind.tableauToFoundation:
        final fromIdx = move.fromPileIndex!;
        final toIdx = move.toPileIndex!;
        final sourceCol = next.tableau[fromIdx];
        if (sourceCol.isEmpty) {
          throw StateError('Source tableau column is empty.');
        }
        final card = sourceCol.last;
        if (!card.isFaceUp ||
            !canPlaceOnFoundation(card, next.foundations[toIdx])) {
          throw StateError('Illegal tableau-to-foundation move.');
        }
        sourceCol.removeLast();
        _flipExposedTop(sourceCol);
        next.foundations[toIdx].add(card.copyWith(isFaceUp: true));
      case MoveKind.tableauToTableau:
        final fromIdx = move.fromPileIndex!;
        final toIdx = move.toPileIndex!;
        if (fromIdx == toIdx) {
          throw StateError('Cannot move cards to the same column.');
        }
        final sourceCol = next.tableau[fromIdx];
        if (move.cardCount <= 0 || move.cardCount > sourceCol.length) {
          throw StateError('Invalid cardCount ${move.cardCount}.');
        }
        final splitIdx = sourceCol.length - move.cardCount;
        final movingRun = sourceCol.sublist(splitIdx);
        if (!isValidTableauRun(movingRun) ||
            !canPlaceOnTableau(movingRun.first, next.tableau[toIdx])) {
          throw StateError('Illegal tableau-to-tableau move.');
        }
        sourceCol.removeRange(splitIdx, sourceCol.length);
        _flipExposedTop(sourceCol);
        next.tableau[toIdx].addAll(movingRun);
      case MoveKind.foundationToTableau:
        final fromIdx = move.fromPileIndex!;
        final toIdx = move.toPileIndex!;
        final sourceFoundation = next.foundations[fromIdx];
        if (sourceFoundation.isEmpty) {
          throw StateError('Source foundation is empty.');
        }
        final card = sourceFoundation.last;
        if (!canPlaceOnTableau(card, next.tableau[toIdx])) {
          throw StateError('Illegal foundation-to-tableau move.');
        }
        sourceFoundation.removeLast();
        next.tableau[toIdx].add(card.copyWith(isFaceUp: true));
    }

    return BoardSnapshot(
      stock: next.stock,
      waste: next.waste,
      foundations: next.foundations,
      tableau: next.tableau,
    );
  }

  static void _flipExposedTop(List<PlayingCard> column) {
    if (column.isNotEmpty && !column.last.isFaceUp) {
      column[column.length - 1] = column.last.copyWith(isFaceUp: true);
    }
  }

  /// Returns true when all 52 cards are stacked in the 4 foundations.
  static bool isWon(BoardSnapshot board) {
    return board.foundations.every((pile) => pile.length == 13);
  }

  /// Returns true when stock & waste are empty, every tableau card is face-up,
  /// and at least one foundation auto-move exists.
  static bool canAutoComplete(BoardSnapshot board) {
    if (board.stock.isNotEmpty || board.waste.isNotEmpty || isWon(board)) {
      return false;
    }
    if (!board.tableau.every((col) => col.every((card) => card.isFaceUp))) {
      return false;
    }
    return nextAutoCompleteMove(board) != null;
  }

  /// Returns the lowest-rank tableau top card move to a foundation during
  /// Auto-Complete, or null if no foundation move exists.
  static SolitaireMove? nextAutoCompleteMove(BoardSnapshot board) {
    SolitaireMove? bestMove;
    var lowestRank = 99;

    for (var colIdx = 0; colIdx < 7; colIdx++) {
      final col = board.tableau[colIdx];
      if (col.isEmpty) continue;
      final top = col.last;
      final fIdx = findFoundationDestination(top, board.foundations);
      if (fIdx != null && top.rank < lowestRank) {
        lowestRank = top.rank;
        bestMove = SolitaireMove(
          kind: MoveKind.tableauToFoundation,
          fromPileIndex: colIdx,
          toPileIndex: fIdx,
        );
      }
    }
    return bestMove;
  }

  /// Returns the preferred legal foundation pile index for [card], preferring
  /// an existing matching-suit foundation before an empty slot for Aces.
  static int? findFoundationDestination(
    PlayingCard card,
    List<List<PlayingCard>> foundations,
  ) {
    if (!card.isFaceUp) return null;
    if (card.rank == 1) {
      for (var i = 0; i < 4; i++) {
        if (foundations[i].isEmpty) return i;
      }
      return null;
    }
    for (var i = 0; i < 4; i++) {
      if (canPlaceOnFoundation(card, foundations[i])) return i;
    }
    return null;
  }

  /// Returns true if moving [card] to a foundation is strictly "safe"
  /// (cannot block descending tableau builds of opposite colors).
  static bool isSafeFoundationMove(
    PlayingCard card,
    List<List<PlayingCard>> foundations,
  ) {
    if (card.rank <= 2) return true;
    final neededOppositeRank = card.rank - 1;
    var minRedRank = 13;
    var minBlackRank = 13;
    var redSuitsSeen = 0;
    var blackSuitsSeen = 0;

    for (final f in foundations) {
      if (f.isEmpty) continue;
      final top = f.last;
      if (top.suit.isRed) {
        redSuitsSeen++;
        if (top.rank < minRedRank) minRedRank = top.rank;
      } else {
        blackSuitsSeen++;
        if (top.rank < minBlackRank) minBlackRank = top.rank;
      }
    }

    if (redSuitsSeen < 2) minRedRank = 0;
    if (blackSuitsSeen < 2) minBlackRank = 0;

    if (card.suit.isRed) {
      return minBlackRank >= neededOppositeRank;
    } else {
      return minRedRank >= neededOppositeRank;
    }
  }

  /// Enumerates all legal Klondike moves from [board].
  static List<SolitaireMove> allLegalMoves(
    BoardSnapshot board,
    DrawMode drawMode,
  ) {
    final moves = <SolitaireMove>[];

    // 1. Waste -> Foundation
    if (board.waste.isNotEmpty) {
      final wasteTop = board.waste.last;
      final fIdx = findFoundationDestination(wasteTop, board.foundations);
      if (fIdx != null) {
        moves.add(
          SolitaireMove(
            kind: MoveKind.wasteToFoundation,
            toPileIndex: fIdx,
          ),
        );
      }
    }

    // 2. Tableau -> Foundation
    for (var c = 0; c < 7; c++) {
      final col = board.tableau[c];
      if (col.isEmpty || !col.last.isFaceUp) continue;
      final fIdx = findFoundationDestination(col.last, board.foundations);
      if (fIdx != null) {
        moves.add(
          SolitaireMove(
            kind: MoveKind.tableauToFoundation,
            fromPileIndex: c,
            toPileIndex: fIdx,
          ),
        );
      }
    }

    // 3. Waste -> Tableau
    if (board.waste.isNotEmpty) {
      final wasteTop = board.waste.last;
      for (var to = 0; to < 7; to++) {
        if (canPlaceOnTableau(wasteTop, board.tableau[to])) {
          moves.add(
            SolitaireMove(
              kind: MoveKind.wasteToTableau,
              toPileIndex: to,
            ),
          );
        }
      }
    }

    // 4. Tableau -> Tableau (every valid face-up sub-run)
    for (var from = 0; from < 7; from++) {
      final col = board.tableau[from];
      if (col.isEmpty) continue;
      for (var split = 0; split < col.length; split++) {
        if (!col[split].isFaceUp) continue;
        final subRun = col.sublist(split);
        if (!isValidTableauRun(subRun)) continue;
        for (var to = 0; to < 7; to++) {
          if (from == to) continue;
          if (canPlaceOnTableau(subRun.first, board.tableau[to])) {
            moves.add(
              SolitaireMove(
                kind: MoveKind.tableauToTableau,
                fromPileIndex: from,
                toPileIndex: to,
                cardCount: subRun.length,
              ),
            );
          }
        }
      }
    }

    // 5. Foundation -> Tableau
    for (var f = 0; f < 4; f++) {
      final pile = board.foundations[f];
      if (pile.isEmpty) continue;
      final top = pile.last;
      for (var to = 0; to < 7; to++) {
        if (canPlaceOnTableau(top, board.tableau[to])) {
          moves.add(
            SolitaireMove(
              kind: MoveKind.foundationToTableau,
              fromPileIndex: f,
              toPileIndex: to,
            ),
          );
        }
      }
    }

    // 6. Stock draw / recycle
    if (board.stock.isNotEmpty) {
      moves.add(const SolitaireMove(kind: MoveKind.drawStock));
    } else if (board.waste.isNotEmpty) {
      moves.add(const SolitaireMove(kind: MoveKind.recycleStock));
    }

    return moves;
  }
}
