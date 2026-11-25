import 'dart:collection';

import 'game_state.dart';
import 'move.dart';
import 'rules.dart';

/// Result returned by [KlondikeSolver].
class SolverResult {
  const SolverResult({
    required this.solvable,
    required this.solution,
    required this.nodesExplored,
  });

  final bool solvable;
  final List<SolitaireMove> solution;
  final int nodesExplored;
}

class _SolverNode {
  const _SolverNode({
    required this.board,
    required this.moves,
    required this.score,
    required this.depth,
  });

  final BoardSnapshot board;
  final List<SolitaireMove> moves;
  final int score;
  final int depth;
}

/// Fast bounded Best-First Klondike solver used to verify winnable deals
/// and locate solvable checkpoints for Smart Rewind.
class KlondikeSolver {
  const KlondikeSolver._();

  /// Attempts to solve [start] within [maxNodes] explored states.
  static SolverResult solve(
    BoardSnapshot start,
    DrawMode drawMode, {
    int maxNodes = 2500,
  }) {
    final visited = HashSet<String>();
    final queue = _MaxPriorityQueue<_SolverNode>(
      (a, b) => a.score.compareTo(b.score),
    );

    final initialReduced = _autoAdvanceSafeMoves(start, const <SolitaireMove>[]);
    if (SolitaireRules.isWon(initialReduced.board)) {
      return SolverResult(
        solvable: true,
        solution: initialReduced.moves,
        nodesExplored: 1,
      );
    }
    if (SolitaireRules.canAutoComplete(initialReduced.board)) {
      final finished = _tryFinishAutoComplete(
        initialReduced.board,
        initialReduced.moves,
        drawMode,
      );
      if (finished != null) {
        return SolverResult(
          solvable: true,
          solution: finished,
          nodesExplored: 1,
        );
      }
    }

    visited.add(initialReduced.board.canonicalKey());
    queue.add(
      _SolverNode(
        board: initialReduced.board,
        moves: initialReduced.moves,
        score: _heuristic(initialReduced.board, initialReduced.moves.length),
        depth: 0,
      ),
    );

    var explored = 0;
    while (queue.isNotEmpty && explored < maxNodes) {
      final current = queue.removeMax();
      explored++;

      final candidateMoves = _prunedMoves(current.board, drawMode);
      for (final move in candidateMoves) {
        final rawNext =
            SolitaireRules.applyMove(current.board, move, drawMode);
        final reduced = _autoAdvanceSafeMoves(
          rawNext,
          <SolitaireMove>[...current.moves, move],
        );

        if (SolitaireRules.isWon(reduced.board)) {
          return SolverResult(
            solvable: true,
            solution: reduced.moves,
            nodesExplored: explored,
          );
        }

        if (SolitaireRules.canAutoComplete(reduced.board)) {
          final finished = _tryFinishAutoComplete(
            reduced.board,
            reduced.moves,
            drawMode,
          );
          if (finished != null) {
            return SolverResult(
              solvable: true,
              solution: finished,
              nodesExplored: explored,
            );
          }
        }

        final key = reduced.board.canonicalKey();
        if (!visited.add(key)) continue;

        final nextDepth = current.depth + 1;
        queue.add(
          _SolverNode(
            board: reduced.board,
            moves: reduced.moves,
            score: _heuristic(reduced.board, nextDepth),
            depth: nextDepth,
          ),
        );
      }
    }

    return SolverResult(
      solvable: false,
      solution: const <SolitaireMove>[],
      nodesExplored: explored,
    );
  }

  /// Quick bounded solvability check for Dead-End & Smart Rewind checkpoints.
  static bool isSolvableQuick(
    BoardSnapshot board,
    DrawMode drawMode, {
    int maxNodes = 1200,
  }) {
    return solve(board, drawMode, maxNodes: maxNodes).solvable;
  }

  static ({BoardSnapshot board, List<SolitaireMove> moves})
      _autoAdvanceSafeMoves(
    BoardSnapshot start,
    List<SolitaireMove> existingMoves,
  ) {
    var board = start;
    final moves = List<SolitaireMove>.of(existingMoves);

    while (true) {
      var moved = false;

      if (board.waste.isNotEmpty) {
        final card = board.waste.last;
        if (SolitaireRules.isSafeFoundationMove(card, board.foundations)) {
          final fIdx = SolitaireRules.findFoundationDestination(
            card,
            board.foundations,
          );
          if (fIdx != null) {
            final move = SolitaireMove(
              kind: MoveKind.wasteToFoundation,
              toPileIndex: fIdx,
            );
            board = SolitaireRules.applyMove(board, move, DrawMode.draw1);
            moves.add(move);
            moved = true;
          }
        }
      }

      if (moved) continue;

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
            final move = SolitaireMove(
              kind: MoveKind.tableauToFoundation,
              fromPileIndex: c,
              toPileIndex: fIdx,
            );
            board = SolitaireRules.applyMove(board, move, DrawMode.draw1);
            moves.add(move);
            moved = true;
            break;
          }
        }
      }

      if (!moved) break;
    }

    return (board: board, moves: moves);
  }

  static List<SolitaireMove>? _tryFinishAutoComplete(
    BoardSnapshot start,
    List<SolitaireMove> existingMoves,
    DrawMode drawMode,
  ) {
    var board = start;
    final moves = List<SolitaireMove>.of(existingMoves);
    while (!SolitaireRules.isWon(board)) {
      final move = SolitaireRules.nextAutoCompleteMove(board);
      if (move == null) return null;
      board = SolitaireRules.applyMove(board, move, drawMode);
      moves.add(move);
    }
    return moves;
  }

  static int _heuristic(BoardSnapshot board, int depth) {
    var faceUpCards = 0;
    var emptyCols = 0;
    for (final col in board.tableau) {
      if (col.isEmpty) {
        emptyCols++;
      } else {
        for (final card in col) {
          if (card.isFaceUp) faceUpCards++;
        }
      }
    }
    return board.foundationCardCount * 30 -
        board.tableauFaceDownCount * 28 +
        faceUpCards * 2 +
        emptyCols * 8 -
        depth;
  }

  static List<SolitaireMove> _prunedMoves(
    BoardSnapshot board,
    DrawMode drawMode,
  ) {
    final moves = <SolitaireMove>[];
    final hasExposedKing = _hasMovableKing(board);

    // 1. Tableau -> Foundation (unsafe ones; safe ones already auto-advanced)
    for (var c = 0; c < 7; c++) {
      final col = board.tableau[c];
      if (col.isEmpty || !col.last.isFaceUp) continue;
      final fIdx =
          SolitaireRules.findFoundationDestination(col.last, board.foundations);
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

    // 2. Waste -> Foundation
    if (board.waste.isNotEmpty) {
      final wasteTop = board.waste.last;
      final fIdx = SolitaireRules.findFoundationDestination(
        wasteTop,
        board.foundations,
      );
      if (fIdx != null) {
        moves.add(
          SolitaireMove(
            kind: MoveKind.wasteToFoundation,
            toPileIndex: fIdx,
          ),
        );
      }
    }

    // 3. Constructive Tableau -> Tableau moves
    var emptyTargetUsed = false;
    for (var from = 0; from < 7; from++) {
      final col = board.tableau[from];
      if (col.isEmpty) continue;

      final firstFaceUpIdx = col.indexWhere((c) => c.isFaceUp);
      if (firstFaceUpIdx == -1) continue;

      for (var split = firstFaceUpIdx; split < col.length; split++) {
        final movingRun = col.sublist(split);
        final movingBottom = movingRun.first;
        final uncoversFaceDown = split > 0 && !col[split - 1].isFaceUp;
        final emptiesColumn = split == 0;
        final cardBelowIsFaceUp = split > 0 && col[split - 1].isFaceUp;
        final exposesFoundationCard = cardBelowIsFaceUp &&
            SolitaireRules.findFoundationDestination(
                  col[split - 1],
                  board.foundations,
                ) !=
                null;

        // Prune useless shuffling of already face-up runs unless it unblocks a
        // foundation card or frees a needed King slot.
        if (cardBelowIsFaceUp && !exposesFoundationCard) continue;
        if (emptiesColumn && movingBottom.rank == 13) continue;
        if (emptiesColumn && !hasExposedKing) continue;
        if (!uncoversFaceDown && !emptiesColumn && !exposesFoundationCard) {
          continue;
        }

        for (var to = 0; to < 7; to++) {
          if (from == to) continue;
          final targetCol = board.tableau[to];
          if (targetCol.isEmpty) {
            if (emptyTargetUsed) continue;
            if (SolitaireRules.canPlaceOnTableau(movingBottom, targetCol)) {
              emptyTargetUsed = true;
              moves.add(
                SolitaireMove(
                  kind: MoveKind.tableauToTableau,
                  fromPileIndex: from,
                  toPileIndex: to,
                  cardCount: movingRun.length,
                ),
              );
            }
          } else if (SolitaireRules.canPlaceOnTableau(
            movingBottom,
            targetCol,
          )) {
            moves.add(
              SolitaireMove(
                kind: MoveKind.tableauToTableau,
                fromPileIndex: from,
                toPileIndex: to,
                cardCount: movingRun.length,
              ),
            );
          }
        }
      }
    }

    // 4. Waste -> Tableau
    if (board.waste.isNotEmpty) {
      final wasteTop = board.waste.last;
      var wasteEmptyUsed = false;
      for (var to = 0; to < 7; to++) {
        final targetCol = board.tableau[to];
        if (targetCol.isEmpty) {
          if (wasteEmptyUsed) continue;
          if (SolitaireRules.canPlaceOnTableau(wasteTop, targetCol)) {
            wasteEmptyUsed = true;
            moves.add(
              SolitaireMove(kind: MoveKind.wasteToTableau, toPileIndex: to),
            );
          }
        } else if (SolitaireRules.canPlaceOnTableau(wasteTop, targetCol)) {
          moves.add(
            SolitaireMove(kind: MoveKind.wasteToTableau, toPileIndex: to),
          );
        }
      }
    }

    // 5. Stock draw / recycle
    if (board.stock.isNotEmpty) {
      moves.add(const SolitaireMove(kind: MoveKind.drawStock));
    } else if (board.waste.isNotEmpty) {
      moves.add(const SolitaireMove(kind: MoveKind.recycleStock));
    }

    return moves;
  }

  static bool _hasMovableKing(BoardSnapshot board) {
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
}

class _MaxPriorityQueue<T> {
  _MaxPriorityQueue(this._compare);

  final int Function(T a, T b) _compare;
  final List<T> _heap = <T>[];

  bool get isNotEmpty => _heap.isNotEmpty;

  void add(T element) {
    _heap.add(element);
    _siftUp(_heap.length - 1);
  }

  T removeMax() {
    final top = _heap.first;
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      _siftDown(0);
    }
    return top;
  }

  void _siftUp(int index) {
    var i = index;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_compare(_heap[i], _heap[parent]) <= 0) break;
      final tmp = _heap[i];
      _heap[i] = _heap[parent];
      _heap[parent] = tmp;
      i = parent;
    }
  }

  void _siftDown(int index) {
    var i = index;
    final length = _heap.length;
    while (true) {
      final left = (i << 1) + 1;
      final right = left + 1;
      var largest = i;
      if (left < length && _compare(_heap[left], _heap[largest]) > 0) {
        largest = left;
      }
      if (right < length && _compare(_heap[right], _heap[largest]) > 0) {
        largest = right;
      }
      if (largest == i) break;
      final tmp = _heap[i];
      _heap[i] = _heap[largest];
      _heap[largest] = tmp;
      i = largest;
    }
  }
}
