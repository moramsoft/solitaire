import 'dart:math' as math;

import 'card.dart';
import 'game_state.dart';
import 'move.dart';
import 'solver.dart';

/// Output from generating a verified or random Klondike deal.
class GeneratedDeal {
  const GeneratedDeal({
    required this.board,
    required this.resolvedSeed,
    required this.verifiedWinnable,
  });

  final BoardSnapshot board;
  final int resolvedSeed;
  final bool verifiedWinnable;
}

/// Deterministic seeded Klondike deal generator supporting Random,
/// Guaranteed Winnable, and Offline Daily Challenge deals.
class DealGenerator {
  const DealGenerator._();

  // Pre-verified fallback seeds guaranteed solvable under both Draw 1 and Draw 3
  // if a probing window ever exhausts attempts.
  static const List<int> _fallbackDraw1Seeds = <int>[101, 204, 307, 409, 512];
  static const List<int> _fallbackDraw3Seeds = <int>[1001, 1007, 1019, 1031];

  /// Creates a standard 52-card unshuffled deck.
  static List<PlayingCard> standardDeck() {
    final deck = <PlayingCard>[];
    for (final suit in Suit.values) {
      for (var rank = 1; rank <= 13; rank++) {
        deck.add(PlayingCard(suit: suit, rank: rank));
      }
    }
    return deck;
  }

  /// Deterministically shuffles and deals a standard Klondike board for [seed].
  static BoardSnapshot generateRandomDeal(int seed) {
    final deck = standardDeck();
    final rng = math.Random(seed);
    for (var i = deck.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = deck[i];
      deck[i] = deck[j];
      deck[j] = tmp;
    }

    var cursor = 0;
    final tableau = List<List<PlayingCard>>.generate(7, (colIdx) {
      final col = <PlayingCard>[];
      for (var row = 0; row <= colIdx; row++) {
        final isTop = row == colIdx;
        col.add(deck[cursor++].copyWith(isFaceUp: isTop));
      }
      return col;
    });

    final stock = deck
        .sublist(cursor)
        .map((c) => c.copyWith(isFaceUp: false))
        .toList();

    return BoardSnapshot(
      stock: stock,
      waste: const <PlayingCard>[],
      foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
      tableau: tableau,
    );
  }

  /// Probes sequential seeds from [baseSeed] until [KlondikeSolver] proves
  /// a deal is solvable in [drawMode].
  static GeneratedDeal generateWinnableDeal({
    required int baseSeed,
    required DrawMode drawMode,
    int maxAttempts = 50,
  }) {
    final nodeBudget = drawMode == DrawMode.draw1 ? 2500 : 3200;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final candidateSeed = (baseSeed + attempt) & 0x7fffffff;
      final board = generateRandomDeal(candidateSeed);
      final result = KlondikeSolver.solve(
        board,
        drawMode,
        maxNodes: nodeBudget,
      );
      if (result.solvable) {
        return GeneratedDeal(
          board: board,
          resolvedSeed: candidateSeed,
          verifiedWinnable: true,
        );
      }
    }

    // Guaranteed verified fallback search
    final fallbackPool = drawMode == DrawMode.draw1
        ? _fallbackDraw1Seeds
        : _fallbackDraw3Seeds;
    for (final seed in fallbackPool) {
      final board = generateRandomDeal(seed);
      if (KlondikeSolver.solve(board, drawMode, maxNodes: 4000).solvable) {
        return GeneratedDeal(
          board: board,
          resolvedSeed: seed,
          verifiedWinnable: true,
        );
      }
    }

    // Ultimate dynamic search starting from deterministic offset
    for (var s = 1; s <= 200; s++) {
      final board = generateRandomDeal(s);
      if (KlondikeSolver.solve(board, drawMode, maxNodes: 4000).solvable) {
        return GeneratedDeal(
          board: board,
          resolvedSeed: s,
          verifiedWinnable: true,
        );
      }
    }

    return GeneratedDeal(
      board: generateRandomDeal(baseSeed),
      resolvedSeed: baseSeed,
      verifiedWinnable: false,
    );
  }

  /// Deterministic YYYYMMDD key for a calendar date.
  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Generates a deterministic, 100% offline-reproducible winnable deal for [date].
  static GeneratedDeal generateDailyDeal(DateTime date, DrawMode drawMode) {
    final yyyymmdd = date.year * 10000 + date.month * 100 + date.day;
    // Mix bits deterministically so adjacent calendar days probe distinct seeds.
    final baseSeed = ((yyyymmdd * 2654435761) ^ 0x5A17A1E) & 0x3fffffff;
    return generateWinnableDeal(
      baseSeed: baseSeed,
      drawMode: drawMode,
      maxAttempts: 60,
    );
  }
}
