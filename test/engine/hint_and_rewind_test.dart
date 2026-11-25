import 'package:cleardeck_solitaire/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HintEngine, Smart Rewind & TapResolver', () {
    test('prioritizes safe Ace foundation and hidden card reveal moves', () {
      final board = BoardSnapshot(
        stock: const <PlayingCard>[],
        waste: const <PlayingCard>[
          PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true),
        ],
        foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
        tableau: <List<PlayingCard>>[
          <PlayingCard>[
            const PlayingCard(suit: Suit.clubs, rank: 9, isFaceUp: false),
            const PlayingCard(suit: Suit.hearts, rank: 5, isFaceUp: true),
          ],
          <PlayingCard>[
            const PlayingCard(suit: Suit.spades, rank: 6, isFaceUp: true),
          ],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
        ],
      );

      final hint1 = HintEngine.findSmartHint(board, DrawMode.draw1);
      expect(hint1.isDeadEnd, isFalse);
      expect(hint1.move?.kind, MoveKind.wasteToFoundation);

      final afterAce = SolitaireRules.applyMove(board, hint1.move!, DrawMode.draw1);
      final hint2 = HintEngine.findSmartHint(afterAce, DrawMode.draw1);
      expect(hint2.isDeadEnd, isFalse);
      expect(hint2.move?.kind, MoveKind.tableauToTableau);
      expect(hint2.move?.fromPileIndex, 0);
      expect(hint2.move?.toPileIndex, 1);
    });

    test('anti-loop regression: NEVER hints moving Queen onto King when card below Queen is already face-up', () {
      final board = BoardSnapshot(
        stock: const <PlayingCard>[],
        waste: const <PlayingCard>[],
        foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
        tableau: <List<PlayingCard>>[
          <PlayingCard>[
            const PlayingCard(suit: Suit.spades, rank: 13, isFaceUp: true),
            const PlayingCard(suit: Suit.hearts, rank: 12, isFaceUp: true),
          ],
          <PlayingCard>[
            const PlayingCard(suit: Suit.clubs, rank: 13, isFaceUp: true),
          ],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
        ],
      );

      final hint = HintEngine.findSmartHint(board, DrawMode.draw1);
      expect(hint.move, isNull);
      expect(hint.isDeadEnd, isTrue);
    });

    test('anti-loop regression: NEVER hints moving King from empty column base to empty column', () {
      final board = BoardSnapshot(
        stock: const <PlayingCard>[],
        waste: const <PlayingCard>[],
        foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
        tableau: <List<PlayingCard>>[
          <PlayingCard>[
            const PlayingCard(suit: Suit.spades, rank: 13, isFaceUp: true),
          ],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
        ],
      );

      final hint = HintEngine.findSmartHint(board, DrawMode.draw1);
      expect(hint.move, isNull);
      expect(hint.isDeadEnd, isTrue);
    });

    test('detects dead-end when stock cycle has zero playable cards', () {
      final board = BoardSnapshot(
        stock: const <PlayingCard>[
          PlayingCard(suit: Suit.spades, rank: 9),
          PlayingCard(suit: Suit.hearts, rank: 8),
        ],
        waste: const <PlayingCard>[],
        foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
        tableau: <List<PlayingCard>>[
          <PlayingCard>[
            const PlayingCard(suit: Suit.clubs, rank: 4, isFaceUp: true),
          ],
          <PlayingCard>[
            const PlayingCard(suit: Suit.diamonds, rank: 4, isFaceUp: true),
          ],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
        ],
      );

      final hint = HintEngine.findSmartHint(board, DrawMode.draw1);
      expect(hint.move, isNull);
      expect(hint.isDeadEnd, isTrue);
    });

    test('TapResolver picks foundation first for single top card and avoids empty King loops', () {
      final board = BoardSnapshot(
        stock: const <PlayingCard>[],
        waste: const <PlayingCard>[],
        foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
        tableau: <List<PlayingCard>>[
          <PlayingCard>[
            const PlayingCard(suit: Suit.diamonds, rank: 1, isFaceUp: true),
          ],
          <PlayingCard>[
            const PlayingCard(suit: Suit.spades, rank: 13, isFaceUp: true),
          ],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
        ],
      );

      final aceMove = TapResolver.resolveTableauTap(board, 0, 0);
      expect(aceMove?.kind, MoveKind.tableauToFoundation);
      expect(aceMove?.toPileIndex, 0);

      // King already on empty column should not tap-jump to another empty column
      final kingMove = TapResolver.resolveTableauTap(board, 1, 0);
      expect(kingMove, isNull);
    });

    test('KlondikeSolver.isSolvableQuick distinguishes solvable checkpoint from dead-end', () {
      final deal = DealGenerator.generateWinnableDeal(
        baseSeed: 777,
        drawMode: DrawMode.draw1,
      );
      expect(KlondikeSolver.isSolvableQuick(deal.board, DrawMode.draw1), isTrue);

      final deadBoard = BoardSnapshot(
        stock: const <PlayingCard>[],
        waste: const <PlayingCard>[],
        foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
        tableau: <List<PlayingCard>>[
          <PlayingCard>[
            const PlayingCard(suit: Suit.clubs, rank: 2, isFaceUp: true),
          ],
          <PlayingCard>[
            const PlayingCard(suit: Suit.diamonds, rank: 2, isFaceUp: true),
          ],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
        ],
      );
      expect(KlondikeSolver.isSolvableQuick(deadBoard, DrawMode.draw1), isFalse);
    });
  });
}
