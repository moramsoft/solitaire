import 'package:cleardeck_solitaire/engine/engine.dart';
import 'package:cleardeck_solitaire/theme/app_theme.dart';
import 'package:cleardeck_solitaire/theme/deck_palette.dart';
import 'package:cleardeck_solitaire/ui/widgets/win_cascade_overlay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('WinCascadeOverlay foundation depletion', () {
    testWidgets(
      'drains minimal custom foundations one pile at a time and stops cleanly at [0, 0, 0, 0]',
      (tester) async {
        final foundations = <List<PlayingCard>>[
          const <PlayingCard>[
            PlayingCard(suit: Suit.hearts, rank: 13, isFaceUp: true),
          ],
          const <PlayingCard>[
            PlayingCard(suit: Suit.clubs, rank: 13, isFaceUp: true),
          ],
          const <PlayingCard>[
            PlayingCard(suit: Suit.diamonds, rank: 13, isFaceUp: true),
          ],
          const <PlayingCard>[
            PlayingCard(suit: Suit.spades, rank: 13, isFaceUp: true),
          ],
        ];
        final snapshots = <List<int>>[];

        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(
                child: WinCascadeOverlay(
                  cardWidth: 50,
                  cardHeight: 74,
                  theme: ClearDeckTheme.fromId(TableThemeId.heritageGreen),
                  fourColorDeck: false,
                  leftHanded: false,
                  deckFaceStyle: DeckFaceStyle.americanHeritage,
                  foundations: foundations,
                  onFoundationRemainingChanged: (counts) {
                    snapshots.add(counts);
                  },
                ),
              ),
            ),
          ),
        );

        // Advance simulation frames (dt is clamped to 50ms per tick).
        for (var i = 0; i < 400; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (snapshots.isNotEmpty &&
              snapshots.last.every((count) => count == 0)) {
            break;
          }
        }

        expect(snapshots, equals(const <List<int>>[
          <int>[0, 1, 1, 1],
          <int>[0, 0, 1, 1],
          <int>[0, 0, 0, 1],
          <int>[0, 0, 0, 0],
        ]));

        // Wait further after completion to ensure ticker stops and no extra events fire.
        final countAtCompletion = snapshots.length;
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(snapshots.length, countAtCompletion);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'drains full 52-card foundations down to [0, 0, 0, 0] without mutating caller lists or resetting to K',
      (tester) async {
        List<PlayingCard> buildSuitPile(Suit suit) => List<PlayingCard>.generate(
              13,
              (i) => PlayingCard(suit: suit, rank: i + 1, isFaceUp: true),
            );

        final foundations = <List<PlayingCard>>[
          buildSuitPile(Suit.clubs),
          buildSuitPile(Suit.hearts),
          buildSuitPile(Suit.spades),
          buildSuitPile(Suit.diamonds),
        ];
        final snapshots = <List<int>>[];

        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(
                child: WinCascadeOverlay(
                  cardWidth: 50,
                  cardHeight: 74,
                  theme: ClearDeckTheme.fromId(TableThemeId.heritageGreen),
                  fourColorDeck: false,
                  leftHanded: false,
                  foundations: foundations,
                  onFoundationRemainingChanged: snapshots.add,
                ),
              ),
            ),
          ),
        );

        for (var i = 0; i < 3600; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (snapshots.length == 52) break;
        }

        expect(snapshots.length, 52);
        expect(snapshots.first, equals(const <int>[12, 13, 13, 13]));
        expect(snapshots[3], equals(const <int>[12, 12, 12, 12]));
        expect(snapshots.last, equals(const <int>[0, 0, 0, 0]));
        // Ensure original caller foundation lists were never mutated.
        expect(foundations.every((pile) => pile.length == 13), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
