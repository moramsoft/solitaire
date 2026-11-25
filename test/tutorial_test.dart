import 'package:cleardeck_solitaire/engine/engine.dart';
import 'package:cleardeck_solitaire/main.dart';
import 'package:cleardeck_solitaire/services/analytics_service.dart';
import 'package:cleardeck_solitaire/services/audio_service.dart';
import 'package:cleardeck_solitaire/services/monetization_service.dart';
import 'package:cleardeck_solitaire/services/persistence_service.dart';
import 'package:cleardeck_solitaire/state/game_controller.dart';
import 'package:cleardeck_solitaire/state/quest_controller.dart';
import 'package:cleardeck_solitaire/state/settings_controller.dart';
import 'package:cleardeck_solitaire/state/stats_controller.dart';
import 'package:cleardeck_solitaire/tutorial/tutorial_scenario.dart';
import 'package:cleardeck_solitaire/ui/strings.dart';
import 'package:cleardeck_solitaire/ui/tutorial_screen.dart';
import 'package:cleardeck_solitaire/ui/widgets/playing_card_widget.dart';
import 'package:cleardeck_solitaire/ui/widgets/win_cascade_overlay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<
    ({
      GameController game,
      SettingsController settings,
      StatsController stats,
      QuestController quests,
    })> _pumpRealBoard(
  WidgetTester tester, {
  required BoardSnapshot board,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final persistence = InMemoryPersistenceService();
  await persistence.saveActiveGame(
    GameState(
      board: board,
      drawMode: DrawMode.draw1,
      dealType: DealType.winnable,
      dealSeed: 99,
      undoHistory: <BoardSnapshot>[board],
    ),
  );

  final audio = LightweightAudioService();
  final analytics = DebugAnalyticsService();
  const monetization = BetaFreeMonetizationService();

  final settings = SettingsController(persistence: persistence, audio: audio);
  final stats = StatsController(persistence: persistence);
  final quests = QuestController(persistence: persistence);
  final game = GameController(
    persistence: persistence,
    settings: settings,
    stats: stats,
    audio: audio,
    analytics: analytics,
    monetization: monetization,
    quests: quests,
  );
  addTearDown(() {
    game.dispose();
    quests.dispose();
    settings.dispose();
    stats.dispose();
  });

  await settings.initialize();
  await stats.initialize();
  await quests.initialize();
  await game.initialize();

  await tester.pumpWidget(
    ClearDeckApp(
      gameController: game,
      settingsController: settings,
      statsController: stats,
      questController: quests,
    ),
  );
  await tester.pumpAndSettle();

  return (game: game, settings: settings, stats: stats, quests: quests);
}

void main() {
  test('All 6 TutorialCurriculum lessons have valid unique cards and legal expected moves', () {
    final lessons = TutorialCurriculum.buildLessons();
    expect(lessons.length, 6);

    for (final lesson in lessons) {
      final seen = <String>{};
      final initial = lesson.initialBoard;
      for (final c in <PlayingCard>[
        ...initial.stock,
        ...initial.waste,
        for (final f in initial.foundations) ...f,
        for (final col in initial.tableau) ...col,
      ]) {
        expect(seen.add(c.identityKey), isTrue, reason: 'Duplicate ${c.identityKey}');
      }

      var board = initial;
      for (final step in lesson.subSteps) {
        final resolved = TutorialCurriculum.resolveHighlightMove(step, board);
        expect(step.expectedMove.matches(resolved), isTrue);
        board = SolitaireRules.applyMove(board, resolved, DrawMode.draw1);
      }

      if (lesson.triggersWinCelebration) {
        expect(SolitaireRules.isWon(board), isTrue);
      }
    }
  });

  testWidgets(
    '3 invalid taps OR 3 rejected drags offer Tutorial dialog, decline persists, accept preserves game state',
    (WidgetTester tester) async {
      // Unplayable cards so taps fail and drags to neighbor column fail
      final board = BoardSnapshot(
        stock: const <PlayingCard>[],
        waste: const <PlayingCard>[],
        foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
        tableau: <List<PlayingCard>>[
          const <PlayingCard>[
            PlayingCard(suit: Suit.spades, rank: 8, isFaceUp: true),
          ],
          const <PlayingCard>[
            PlayingCard(suit: Suit.hearts, rank: 10, isFaceUp: true),
          ],
          const <PlayingCard>[],
          const <PlayingCard>[],
          const <PlayingCard>[],
          const <PlayingCard>[],
          const <PlayingCard>[],
        ],
      );

      final deps = await _pumpRealBoard(tester, board: board);

      final card8S = find.descendant(
        of: find.byType(PlayingCardWidget),
        matching: find.text('8'),
      );
      final card10H = find.descendant(
        of: find.byType(PlayingCardWidget),
        matching: find.text('10'),
      );

      // Perform 3 rejected drags >= 20dp (drag 8♠ right onto 10♥ — illegal!)
      final offsetDelta = tester.getCenter(card10H) - tester.getCenter(card8S);
      expect(offsetDelta.distance, greaterThan(20.0));

      for (var i = 0; i < 2; i++) {
        await tester.drag(card8S, offsetDelta);
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.tutorialOfferTitle), findsNothing);
      }

      await tester.drag(card8S, offsetDelta);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.tutorialOfferTitle), findsOneWidget);

      // Accept -> enters TutorialScreen without altering active game or stats
      await tester.tap(find.byKey(const Key('tutorial_offer_accept')));
      await tester.pumpAndSettle();

      expect(find.byType(TutorialScreen), findsOneWidget);
      expect(deps.game.state.board, board);
      expect(deps.stats.stats.gamesPlayed, 0);

      // Exit back to real board
      await tester.tap(find.byKey(const Key('tutorial_exit_button')));
      await tester.pumpAndSettle();
      expect(find.byType(TutorialScreen), findsNothing);

      // Now 3 invalid taps -> prompts again -> Decline -> never prompts again
      for (var i = 0; i < 3; i++) {
        await tester.tap(card8S);
        await tester.pumpAndSettle();
      }
      expect(find.text(AppStrings.tutorialOfferTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('tutorial_offer_decline')));
      await tester.pumpAndSettle();
      expect(deps.settings.settings.tutorialPromptDismissed, isTrue);

      for (var i = 0; i < 4; i++) {
        await tester.tap(card8S);
        await tester.pumpAndSettle();
      }
      expect(find.text(AppStrings.tutorialOfferTitle), findsNothing);
    },
  );

  testWidgets(
    'TutorialScreen walks through all 6 curated interactive lessons including Stock, Stack, King, Ace Foundation, and final win celebration',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = InMemoryPersistenceService();
      final audio = LightweightAudioService();
      final settings = SettingsController(persistence: persistence, audio: audio);
      await settings.initialize();
      addTearDown(settings.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TutorialScreen(
                          settingsController: settings,
                          audioService: audio,
                        ),
                      ),
                    );
                  },
                  child: const Text('Launch'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      // Lesson 1: Alternating Columns (wrong tap 4♣ shows guidance, then 6♥ -> 7♠)
      expect(find.text('Step 1 of 6'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('4'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tutorial_next_button')), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('6'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tutorial_next_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tutorial_next_button')));
      await tester.pumpAndSettle();

      // Lesson 2: Draw from Stock -> place 5♣ onto 6♥
      expect(find.text('Step 2 of 6'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tutorial_stock')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('5'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tutorial_next_button')));
      await tester.pumpAndSettle();

      // Lesson 3: Move 3-card stack [6♥, 5♣, 4♦] onto 7♠, uncovering 9♣ with 3D flip
      expect(find.text('Step 3 of 6'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('6'),
        ),
      );
      await tester.pumpAndSettle();
      // Uncovered 9♣ is now face-up!
      expect(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('9'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('tutorial_next_button')));
      await tester.pumpAndSettle();

      // Lesson 4: Move King stack [K♦, Q♠] into empty K slot, uncovering J♣
      expect(find.text('Step 4 of 6'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('K'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('J'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('tutorial_next_button')));
      await tester.pumpAndSettle();

      // Lesson 5: Build Foundation A♠ then 2♠
      expect(find.text('Step 5 of 6'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('A'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('2'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tutorial_next_button')));
      await tester.pumpAndSettle();

      // Lesson 6: Final move K♥ -> Q♥ Foundation triggers WinCascadeOverlay!
      expect(find.text('Step 6 of 6'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('tutorial_tableau_3')),
          matching: find.byType(PlayingCardWidget),
        ),
      );
      await tester.pump();
      // Step 50ms ticks past initial 150ms cooldown so foundation 0 pops K♠ -> Q♠.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(WinCascadeOverlay), findsOneWidget);
      expect(find.byKey(const Key('tutorial_finish_button')), findsOneWidget);
      expect(settings.settings.tutorialCompleted, isTrue);
      expect(
        find.descendant(
          of: find.byKey(const Key('tutorial_foundation_0')),
          matching: find.text('Q'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('tutorial_foundation_0')),
          matching: find.text('K'),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('tutorial_finish_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TutorialScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
