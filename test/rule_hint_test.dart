import 'package:cleardeck_solitaire/engine/engine.dart';
import 'package:cleardeck_solitaire/services/analytics_service.dart';
import 'package:cleardeck_solitaire/services/audio_service.dart';
import 'package:cleardeck_solitaire/services/monetization_service.dart';
import 'package:cleardeck_solitaire/services/persistence_service.dart';
import 'package:cleardeck_solitaire/state/game_controller.dart';
import 'package:cleardeck_solitaire/state/quest_controller.dart';
import 'package:cleardeck_solitaire/state/settings_controller.dart';
import 'package:cleardeck_solitaire/state/stats_controller.dart';
import 'package:cleardeck_solitaire/ui/game_screen.dart';
import 'package:cleardeck_solitaire/ui/widgets/playing_card_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _RecordingAnalyticsService implements AnalyticsService {
  final List<String> events = <String>[];

  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {
    events.add(name);
  }
}

Future<
    ({
      GameController game,
      SettingsController settings,
      _RecordingAnalyticsService analytics,
    })> _pumpBoard(
  WidgetTester tester, {
  required BoardSnapshot board,
  bool tutorialCompleted = true,
  bool tutorialPromptDismissed = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final persistence = InMemoryPersistenceService();
  await persistence.saveActiveGame(
    GameState(
      board: board,
      drawMode: DrawMode.draw1,
      dealType: DealType.winnable,
      dealSeed: 77,
      undoHistory: <BoardSnapshot>[board],
    ),
  );

  final audio = LightweightAudioService();
  final analytics = _RecordingAnalyticsService();
  const monetization = BetaFreeMonetizationService();

  final settings = SettingsController(persistence: persistence, audio: audio);
  await settings.initialize();
  if (tutorialCompleted) {
    await settings.setTutorialCompleted(true);
  }
  if (tutorialPromptDismissed) {
    await settings.setTutorialPromptDismissed(true);
  }
  addTearDown(settings.dispose);

  final stats = StatsController(persistence: persistence);
  await stats.initialize();
  addTearDown(stats.dispose);

  final quests = QuestController(persistence: persistence);
  await quests.initialize();
  addTearDown(quests.dispose);

  final game = GameController(
    persistence: persistence,
    settings: settings,
    stats: stats,
    audio: audio,
    analytics: analytics,
    monetization: monetization,
    quests: quests,
  );
  await game.initialize();
  addTearDown(game.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(
        gameController: game,
        settingsController: settings,
        statsController: stats,
        questController: quests,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (game: game, settings: settings, analytics: analytics);
}

void main() {
  group('SolitaireRules rejection explanations', () {
    test('explainFoundationRejection reports suit, Ace, rank, and multi-card', () {
      const twoHearts = PlayingCard(suit: Suit.hearts, rank: 2, isFaceUp: true);
      const aceSpades = PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true);
      const fourSpades = PlayingCard(suit: Suit.spades, rank: 4, isFaceUp: true);
      const twoSpades = PlayingCard(suit: Suit.spades, rank: 2, isFaceUp: true);

      expect(
        SolitaireRules.explainFoundationRejection(twoHearts, const [aceSpades]),
        allOf(contains('same suit'), contains('A♠')),
      );
      expect(
        SolitaireRules.explainFoundationRejection(twoSpades, const []),
        contains('Ace (A)'),
      );
      expect(
        SolitaireRules.explainFoundationRejection(fourSpades, const [aceSpades]),
        contains('2♠'),
      );
      expect(
        SolitaireRules.explainFoundationRejection(
          twoSpades,
          const [aceSpades],
          cardCount: 2,
        ),
        contains('one card at a time'),
      );
      expect(
        SolitaireRules.explainFoundationRejection(twoSpades, const [aceSpades]),
        isNull,
      );
    });

    test('explainTableauRejection reports alternating colors, rank, and King rule', () {
      const eightHearts = PlayingCard(suit: Suit.hearts, rank: 8, isFaceUp: true);
      const sevenSpades = PlayingCard(suit: Suit.spades, rank: 7, isFaceUp: true);
      const nineDiamonds =
          PlayingCard(suit: Suit.diamonds, rank: 9, isFaceUp: true);

      expect(
        SolitaireRules.explainTableauRejection(eightHearts, const [nineDiamonds]),
        contains('alternate colors'),
      );
      expect(
        SolitaireRules.explainTableauRejection(sevenSpades, const [nineDiamonds]),
        contains('place 8 on 9♦'),
      );
      expect(
        SolitaireRules.explainTableauRejection(eightHearts, const []),
        contains('King (K)'),
      );
    });
  });

  group('Repeated-mistake contextual hint & rule tip', () {
    testWidgets(
      'shows foundation suit explanation only after 3rd consecutive invalid drag of 2♥ onto A♠ and dismisses on tap',
      (tester) async {
        final board = BoardSnapshot(
          stock: const <PlayingCard>[],
          waste: const <PlayingCard>[],
          foundations: <List<PlayingCard>>[
            const <PlayingCard>[
              PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true),
            ],
            <PlayingCard>[],
            <PlayingCard>[],
            <PlayingCard>[],
          ],
          tableau: <List<PlayingCard>>[
            const <PlayingCard>[
              PlayingCard(suit: Suit.hearts, rank: 2, isFaceUp: true),
            ],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
          ],
        );

        await _pumpBoard(tester, board: board, tutorialCompleted: true);

        final card2H = find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('2'),
        );
        final aceSpadesSlot = find
            .descendant(
              of: find.byType(PlayingCardWidget),
              matching: find.text('A'),
            )
            .first;
        final delta =
            tester.getCenter(aceSpadesSlot) - tester.getCenter(card2H);
        expect(delta.distance, greaterThan(20.0));

        for (var i = 0; i < 2; i++) {
          await tester.drag(card2H, delta);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('rule_tip_banner')), findsNothing);
          expect(find.byKey(const Key('hint_banner')), findsNothing);
        }

        await tester.drag(card2H, delta);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rule_tip_banner')), findsOneWidget);
        expect(find.textContaining('same suit'), findsOneWidget);
        expect(find.textContaining('A♠'), findsOneWidget);

        await tester.tap(find.byKey(const Key('rule_tip_banner')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rule_tip_banner')), findsNothing);
      },
    );

    testWidgets(
      'making a valid move resets the mistake streak so a single later mistake does not show a banner',
      (tester) async {
        final board = BoardSnapshot(
          stock: const <PlayingCard>[],
          waste: const <PlayingCard>[],
          foundations: <List<PlayingCard>>[
            const <PlayingCard>[
              PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true),
            ],
            <PlayingCard>[],
            <PlayingCard>[],
            <PlayingCard>[],
          ],
          tableau: <List<PlayingCard>>[
            const <PlayingCard>[
              PlayingCard(suit: Suit.hearts, rank: 2, isFaceUp: true),
            ],
            const <PlayingCard>[
              PlayingCard(suit: Suit.hearts, rank: 1, isFaceUp: true),
            ],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
          ],
        );

        await _pumpBoard(tester, board: board, tutorialCompleted: true);

        final card2H = find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('2'),
        );
        final aceSpadesSlot = find
            .descendant(
              of: find.byType(PlayingCardWidget),
              matching: find.text('A'),
            )
            .first;
        final delta =
            tester.getCenter(aceSpadesSlot) - tester.getCenter(card2H);

        // Two invalid drags -> streak = 2 (below threshold of 3)
        await tester.drag(card2H, delta);
        await tester.pumpAndSettle();
        await tester.drag(card2H, delta);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rule_tip_banner')), findsNothing);

        // Valid move: tap A♥ onto empty foundation 1 -> resets streak to 0
        final cardAH = find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('A'),
        );
        await tester.tap(cardAH.last);
        await tester.pumpAndSettle();

        // One more invalid drag -> streak = 1, still no banner
        await tester.drag(card2H, delta);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rule_tip_banner')), findsNothing);
      },
    );

    testWidgets(
      '3rd consecutive unmovable tap triggers gentle auto-hint without logging manual hint penalty',
      (tester) async {
        final board = BoardSnapshot(
          stock: const <PlayingCard>[],
          waste: const <PlayingCard>[],
          foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
          tableau: <List<PlayingCard>>[
            const <PlayingCard>[
              PlayingCard(suit: Suit.hearts, rank: 10, isFaceUp: true),
            ],
            const <PlayingCard>[
              PlayingCard(suit: Suit.clubs, rank: 1, isFaceUp: true),
            ],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
          ],
        );

        final deps = await _pumpBoard(
          tester,
          board: board,
          tutorialCompleted: false,
          tutorialPromptDismissed: true,
        );

        final card10H = find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('10'),
        );

        await tester.tap(card10H);
        await tester.pumpAndSettle();
        await tester.tap(card10H);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('hint_banner')), findsNothing);

        await tester.tap(card10H);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('hint_banner')), findsOneWidget);
        expect(
          deps.analytics.events,
          contains('repeated_mistake_auto_hint'),
        );
        expect(deps.analytics.events, isNot(contains('hint_requested')));
      },
    );
  });
}
