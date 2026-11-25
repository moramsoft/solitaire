import 'game_state.dart';
import 'move.dart';
import 'rules.dart';

/// Resolves single-tap gestures into the most natural, accurate Klondike move.
class TapResolver {
  const TapResolver._();

  /// Resolves a single tap on the stock pile.
  static SolitaireMove? resolveStockTap(
    BoardSnapshot board,
    DrawMode drawMode,
  ) {
    if (board.stock.isNotEmpty) {
      return const SolitaireMove(kind: MoveKind.drawStock);
    }
    if (board.waste.isNotEmpty) {
      return const SolitaireMove(kind: MoveKind.recycleStock);
    }
    return null;
  }

  /// Resolves a single tap on the top card of the waste pile.
  /// Prioritizes Foundation first, then non-empty Tableau build, then empty column.
  static SolitaireMove? resolveWasteTap(BoardSnapshot board) {
    if (board.waste.isEmpty) return null;
    final top = board.waste.last;

    final fIdx = SolitaireRules.findFoundationDestination(top, board.foundations);
    if (fIdx != null) {
      return SolitaireMove(kind: MoveKind.wasteToFoundation, toPileIndex: fIdx);
    }

    for (var to = 0; to < 7; to++) {
      if (board.tableau[to].isNotEmpty &&
          SolitaireRules.canPlaceOnTableau(top, board.tableau[to])) {
        return SolitaireMove(kind: MoveKind.wasteToTableau, toPileIndex: to);
      }
    }

    for (var to = 0; to < 7; to++) {
      if (board.tableau[to].isEmpty &&
          SolitaireRules.canPlaceOnTableau(top, board.tableau[to])) {
        return SolitaireMove(kind: MoveKind.wasteToTableau, toPileIndex: to);
      }
    }

    return null;
  }

  /// Resolves a single tap on [cardIndex] in tableau column [colIndex].
  static SolitaireMove? resolveTableauTap(
    BoardSnapshot board,
    int colIndex,
    int cardIndex,
  ) {
    if (colIndex < 0 || colIndex >= 7) return null;
    final col = board.tableau[colIndex];
    if (cardIndex < 0 || cardIndex >= col.length) return null;
    if (!col[cardIndex].isFaceUp) return null;

    final movingRun = col.sublist(cardIndex);
    if (!SolitaireRules.isValidTableauRun(movingRun)) return null;

    // Single top card: try foundation first!
    if (movingRun.length == 1) {
      final fIdx = SolitaireRules.findFoundationDestination(
        movingRun.first,
        board.foundations,
      );
      if (fIdx != null) {
        return SolitaireMove(
          kind: MoveKind.tableauToFoundation,
          fromPileIndex: colIndex,
          toPileIndex: fIdx,
        );
      }
    }

    // Prefer non-empty tableau destination before empty column.
    for (var to = 0; to < 7; to++) {
      if (to == colIndex) continue;
      if (board.tableau[to].isNotEmpty &&
          SolitaireRules.canPlaceOnTableau(movingRun.first, board.tableau[to])) {
        return SolitaireMove(
          kind: MoveKind.tableauToTableau,
          fromPileIndex: colIndex,
          toPileIndex: to,
          cardCount: movingRun.length,
        );
      }
    }

    // Empty column destination (skip pointless King empty-to-empty transfer).
    if (!(cardIndex == 0 && movingRun.first.rank == 13)) {
      for (var to = 0; to < 7; to++) {
        if (to == colIndex) continue;
        if (board.tableau[to].isEmpty &&
            SolitaireRules.canPlaceOnTableau(
              movingRun.first,
              board.tableau[to],
            )) {
          return SolitaireMove(
            kind: MoveKind.tableauToTableau,
            fromPileIndex: colIndex,
            toPileIndex: to,
            cardCount: movingRun.length,
          );
        }
      }
    }

    return null;
  }

  /// Resolves a tap on the top card of foundation [foundationIndex], moving it
  /// back to a legal tableau column if possible.
  static SolitaireMove? resolveFoundationTap(
    BoardSnapshot board,
    int foundationIndex,
  ) {
    if (foundationIndex < 0 || foundationIndex >= 4) return null;
    final pile = board.foundations[foundationIndex];
    if (pile.isEmpty) return null;
    final top = pile.last;

    for (var to = 0; to < 7; to++) {
      if (SolitaireRules.canPlaceOnTableau(top, board.tableau[to])) {
        return SolitaireMove(
          kind: MoveKind.foundationToTableau,
          fromPileIndex: foundationIndex,
          toPileIndex: to,
        );
      }
    }
    return null;
  }
}
