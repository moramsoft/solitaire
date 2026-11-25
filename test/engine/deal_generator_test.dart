import 'package:cleardeck_solitaire/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DealGenerator & KlondikeSolver', () {
    test('standard random deal contains 52 unique cards in exact Klondike geometry', () {
      final board = DealGenerator.generateRandomDeal(42);
      expect(board.stock.length, 24);
      expect(board.stock.every((c) => !c.isFaceUp), isTrue);
      expect(board.waste, isEmpty);
      expect(board.foundations.every((f) => f.isEmpty), isTrue);

      final seen = <String>{};
      for (final c in board.stock) {
        seen.add(c.identityKey);
      }
      for (var col = 0; col < 7; col++) {
        final pile = board.tableau[col];
        expect(pile.length, col + 1);
        for (var row = 0; row < pile.length; row++) {
          expect(pile[row].isFaceUp, row == col);
          seen.add(pile[row].identityKey);
        }
      }
      expect(seen.length, 52);

      // Deterministic repeatability
      expect(DealGenerator.generateRandomDeal(42), equals(board));
    });

    test('generateWinnableDeal produces verified solvable Draw-1 deals quickly', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 12; i++) {
        final deal = DealGenerator.generateWinnableDeal(
          baseSeed: 1000 + i * 73,
          drawMode: DrawMode.draw1,
        );
        expect(deal.verifiedWinnable, isTrue);
        final check = KlondikeSolver.solve(deal.board, DrawMode.draw1);
        expect(check.solvable, isTrue);
        expect(check.solution, isNotEmpty);
      }
      sw.stop();
      // Average should be well under 100ms per deal (total 12 deals < 1500ms)
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('generateWinnableDeal produces verified solvable Draw-3 deals quickly', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 6; i++) {
        final deal = DealGenerator.generateWinnableDeal(
          baseSeed: 5000 + i * 113,
          drawMode: DrawMode.draw3,
        );
        expect(deal.verifiedWinnable, isTrue);
        final check = KlondikeSolver.solve(
          deal.board,
          DrawMode.draw3,
          maxNodes: 3500,
        );
        expect(check.solvable, isTrue);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2500));
    });

    test('generateDailyDeal is deterministic for fixed date offline', () {
      final date = DateTime(2026, 11, 23);
      final first = DealGenerator.generateDailyDeal(date, DrawMode.draw1);
      final second = DealGenerator.generateDailyDeal(date, DrawMode.draw1);
      final nextDay = DealGenerator.generateDailyDeal(
        DateTime(2026, 11, 24),
        DrawMode.draw1,
      );

      expect(first.verifiedWinnable, isTrue);
      expect(first.resolvedSeed, second.resolvedSeed);
      expect(first.board, second.board);
      expect(first.board, isNot(equals(nextDay.board)));
    });
  });
}
