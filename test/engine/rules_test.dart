import 'package:cleardeck_solitaire/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SolitaireRules', () {
    test('validates foundation placement rules from Ace to King by suit', () {
      const aceSpades =
          PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true);
      const twoSpades =
          PlayingCard(suit: Suit.spades, rank: 2, isFaceUp: true);
      const twoHearts =
          PlayingCard(suit: Suit.hearts, rank: 2, isFaceUp: true);

      expect(SolitaireRules.canPlaceOnFoundation(aceSpades, <PlayingCard>[]), isTrue);
      expect(SolitaireRules.canPlaceOnFoundation(twoSpades, <PlayingCard>[]), isFalse);
      expect(
        SolitaireRules.canPlaceOnFoundation(twoSpades, <PlayingCard>[aceSpades]),
        isTrue,
      );
      expect(
        SolitaireRules.canPlaceOnFoundation(twoHearts, <PlayingCard>[aceSpades]),
        isFalse,
      );
    });

    test('validates tableau placement rules (King on empty, alternating descending)', () {
      const kingClubs = PlayingCard(suit: Suit.clubs, rank: 13, isFaceUp: true);
      const queenHearts =
          PlayingCard(suit: Suit.hearts, rank: 12, isFaceUp: true);
      const queenSpades =
          PlayingCard(suit: Suit.spades, rank: 12, isFaceUp: true);
      const jackSpades =
          PlayingCard(suit: Suit.spades, rank: 11, isFaceUp: true);

      expect(SolitaireRules.canPlaceOnTableau(kingClubs, <PlayingCard>[]), isTrue);
      expect(SolitaireRules.canPlaceOnTableau(queenHearts, <PlayingCard>[]), isFalse);
      expect(
        SolitaireRules.canPlaceOnTableau(queenHearts, <PlayingCard>[kingClubs]),
        isTrue,
      );
      expect(
        SolitaireRules.canPlaceOnTableau(queenSpades, <PlayingCard>[kingClubs]),
        isFalse,
      );
      expect(
        SolitaireRules.isValidTableauRun(
          <PlayingCard>[kingClubs, queenHearts, jackSpades],
        ),
        isTrue,
      );
      expect(
        SolitaireRules.isValidTableauRun(
          <PlayingCard>[kingClubs, queenSpades],
        ),
        isFalse,
      );
    });

    test('draw-1 and draw-3 draw and recycle preserve original card order', () {
      final stock = <PlayingCard>[
        const PlayingCard(suit: Suit.clubs, rank: 1),
        const PlayingCard(suit: Suit.diamonds, rank: 2),
        const PlayingCard(suit: Suit.hearts, rank: 3),
        const PlayingCard(suit: Suit.spades, rank: 4),
      ];
      final initial = BoardSnapshot(
        stock: stock,
        waste: const <PlayingCard>[],
        foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
        tableau: List<List<PlayingCard>>.generate(7, (_) => <PlayingCard>[]),
      );

      // Draw 3: draws Spades 4, Hearts 3, Diamonds 2 -> waste.last == Diamonds 2
      final afterDraw3 = SolitaireRules.applyMove(
        initial,
        const SolitaireMove(kind: MoveKind.drawStock),
        DrawMode.draw3,
      );
      expect(afterDraw3.stock.length, 1);
      expect(afterDraw3.waste.length, 3);
      expect(afterDraw3.waste.last, const PlayingCard(suit: Suit.diamonds, rank: 2, isFaceUp: true));

      // Draw remaining 1
      final afterLastDraw = SolitaireRules.applyMove(
        afterDraw3,
        const SolitaireMove(kind: MoveKind.drawStock),
        DrawMode.draw3,
      );
      expect(afterLastDraw.stock, isEmpty);
      expect(afterLastDraw.waste.last, const PlayingCard(suit: Suit.clubs, rank: 1, isFaceUp: true));

      // Recycle back to stock: first drawn card (Spades 4) must be on top (.last) again.
      final recycled = SolitaireRules.applyMove(
        afterLastDraw,
        const SolitaireMove(kind: MoveKind.recycleStock),
        DrawMode.draw3,
      );
      expect(recycled.waste, isEmpty);
      expect(recycled.stock.length, 4);
      expect(recycled.stock.every((c) => !c.isFaceUp), isTrue);
      expect(recycled.stock.last, const PlayingCard(suit: Suit.spades, rank: 4));
    });

    test('automatically flips newly exposed face-down tableau card', () {
      final board = BoardSnapshot(
        stock: const <PlayingCard>[],
        waste: const <PlayingCard>[],
        foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
        tableau: <List<PlayingCard>>[
          <PlayingCard>[
            const PlayingCard(suit: Suit.hearts, rank: 5, isFaceUp: false),
            const PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true),
          ],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
        ],
      );

      final next = SolitaireRules.applyMove(
        board,
        const SolitaireMove(
          kind: MoveKind.tableauToFoundation,
          fromPileIndex: 0,
          toPileIndex: 0,
        ),
        DrawMode.draw1,
      );

      expect(next.foundations[0].length, 1);
      expect(next.tableau[0].length, 1);
      expect(next.tableau[0].single.isFaceUp, isTrue);
      expect(next.tableau[0].single.rank, 5);
    });

    test('detects win, canAutoComplete, and picks lowest rank nextAutoCompleteMove', () {
      final fullFoundations = Suit.values
          .map(
            (s) => List<PlayingCard>.generate(
              13,
              (i) => PlayingCard(suit: s, rank: i + 1, isFaceUp: true),
            ),
          )
          .toList();
      final wonBoard = BoardSnapshot(
        stock: const <PlayingCard>[],
        waste: const <PlayingCard>[],
        foundations: fullFoundations,
        tableau: List<List<PlayingCard>>.generate(7, (_) => <PlayingCard>[]),
      );
      expect(SolitaireRules.isWon(wonBoard), isTrue);
      expect(SolitaireRules.canAutoComplete(wonBoard), isFalse);

      // Almost-won board ready for auto-complete
      final almostFoundations = Suit.values
          .map(
            (s) => List<PlayingCard>.generate(
              12,
              (i) => PlayingCard(suit: s, rank: i + 1, isFaceUp: true),
            ),
          )
          .toList();
      // Remove Q of Hearts so rank 12 (Hearts) vs rank 13 (Spades) tests lowest-rank pick
      almostFoundations[1].removeLast();
      final readyBoard = BoardSnapshot(
        stock: const <PlayingCard>[],
        waste: const <PlayingCard>[],
        foundations: almostFoundations,
        tableau: <List<PlayingCard>>[
          <PlayingCard>[
            const PlayingCard(suit: Suit.spades, rank: 13, isFaceUp: true),
          ],
          <PlayingCard>[
            const PlayingCard(suit: Suit.hearts, rank: 12, isFaceUp: true),
          ],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
          <PlayingCard>[],
        ],
      );

      expect(SolitaireRules.canAutoComplete(readyBoard), isTrue);
      final autoMove = SolitaireRules.nextAutoCompleteMove(readyBoard);
      expect(autoMove, isNotNull);
      expect(autoMove!.fromPileIndex, 1); // Queen (12) before King (13)
      expect(autoMove.toPileIndex, 1);
    });
  });
}
