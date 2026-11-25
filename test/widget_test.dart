import 'package:cleardeck_solitaire/engine/engine.dart';
import 'package:cleardeck_solitaire/main.dart';
import 'package:cleardeck_solitaire/services/analytics_service.dart';
import 'package:cleardeck_solitaire/services/audio_service.dart';
import 'package:cleardeck_solitaire/services/monetization_service.dart';
import 'package:cleardeck_solitaire/services/persistence_service.dart';
import 'package:cleardeck_solitaire/state/game_controller.dart';
import 'package:cleardeck_solitaire/state/settings_controller.dart';
import 'package:cleardeck_solitaire/state/stats_controller.dart';
import 'package:cleardeck_solitaire/theme/deck_palette.dart';
import 'package:cleardeck_solitaire/ui/widgets/playing_card_widget.dart';
import 'package:cleardeck_solitaire/ui/widgets/settings_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<
    ({
      GameController game,
      SettingsController settings,
      StatsController stats,
      LightweightAudioService audio,
    })> _createBootedApp() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final persistence = SharedPrefsPersistenceService(prefs);
  final audio = LightweightAudioService();
  final analytics = DebugAnalyticsService();
  const monetization = BetaFreeMonetizationService();

  final settings = SettingsController(persistence: persistence, audio: audio);
  final stats = StatsController(persistence: persistence);
  final game = GameController(
    persistence: persistence,
    settings: settings,
    stats: stats,
    audio: audio,
    analytics: analytics,
    monetization: monetization,
  );

  await settings.initialize();
  await stats.initialize();
  await game.initialize();
  return (game: game, settings: settings, stats: stats, audio: audio);
}

void main() {
  testWidgets(
    'launches straight into playable board on Phone Portrait (390x844) and toggles Settings cleanly',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final deps = await _createBootedApp();
      addTearDown(() {
        deps.game.dispose();
        deps.settings.dispose();
        deps.stats.dispose();
      });

      await tester.pumpWidget(
        ClearDeckApp(
          gameController: deps.game,
          settingsController: deps.settings,
          statsController: deps.stats,
        ),
      );
      await tester.pumpAndSettle();

      // Zero onboarding wall; fixed 4-button labeled bar visible immediately.
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Hint'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Moves'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('top_moves_value'))).data,
        '0',
      );

      // Tap Settings -> verify Sheet & toggle 4-Color Deck, Left-Handed, Warm Night
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SettingsSheet),
          matching: find.text('Settings'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('4-Color Deck'));
      await tester.pumpAndSettle();
      expect(deps.settings.settings.fourColorDeck, isTrue);

      await tester.tap(find.text('Left-Handed Layout'));
      await tester.pumpAndSettle();
      expect(deps.settings.settings.leftHanded, isTrue);

      await tester.ensureVisible(find.text('Warm Night'));
      await tester.tap(find.text('Warm Night'));
      await tester.pumpAndSettle();
      expect(deps.settings.settings.tableTheme, TableThemeId.midnightMahogany);

      await tester.ensureVisible(find.text('Royal Navy'));
      await tester.tap(find.text('Royal Navy'));
      await tester.pumpAndSettle();
      expect(deps.settings.settings.cardBackStyle, CardBackStyle.royalNavy);

      await tester.tap(find.byTooltip('Close Settings'));
      await tester.pumpAndSettle();

      // Tap Hint and verify board still renders cleanly without overflow errors.
      await tester.tap(find.text('Hint'));
      await tester.pumpAndSettle();

      // Open and close Daily Challenge sheet cleanly at 390x844
      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();
      expect(find.text('Daily Challenge'), findsOneWidget);
      await tester.tap(find.byTooltip('Close Calendar'));
      await tester.pumpAndSettle();

      // Open and close Statistics sheet cleanly at 390x844
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(find.text('Statistics'), findsOneWidget);
      await tester.tap(find.byTooltip('Close Statistics'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  test('GameController smartRewind restores solvable checkpoint cleanly', () async {
    final deps = await _createBootedApp();
    addTearDown(() {
      deps.game.dispose();
      deps.settings.dispose();
      deps.stats.dispose();
    });

    await deps.game.tapStock();
    await deps.game.tapStock();
    expect(deps.game.state.undoHistory.length, 3);

    final rewound = await deps.game.smartRewind();
    expect(rewound, isTrue);
    expect(deps.game.state.undoHistory.length, lessThan(3));
  });

  testWidgets(
    'renders cleanly without overflow on Tablet Landscape (1194x834) and persists moves/audio lifecycle',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1194, 834));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final deps = await _createBootedApp();
      addTearDown(() {
        deps.game.dispose();
        deps.settings.dispose();
        deps.stats.dispose();
      });

      await tester.pumpWidget(
        ClearDeckApp(
          gameController: deps.game,
          settingsController: deps.settings,
          statsController: deps.stats,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Draw from stock and verify move persisted & lifecycle pauses audio cleanly.
      await deps.game.tapStock();
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('top_moves_value'))).data,
        '1',
      );

      deps.game.handleLifecycleChange(AppLifecycleState.paused);
      expect(deps.audio.isPaused, isTrue);

      deps.game.handleLifecycleChange(AppLifecycleState.resumed);
      expect(deps.audio.isPaused, isFalse);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'card flip midpoint renders without StackOverflowError or ErrorWidget and timer updates cleanly',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = InMemoryPersistenceService();
      final audio = LightweightAudioService();
      final analytics = DebugAnalyticsService();
      const monetization = BetaFreeMonetizationService();

      final initialBoard = BoardSnapshot(
        stock: const <PlayingCard>[
          PlayingCard(suit: Suit.diamonds, rank: 12, isFaceUp: false),
        ],
        waste: const <PlayingCard>[],
        foundations:
            List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
        tableau: <List<PlayingCard>>[
          const <PlayingCard>[
            PlayingCard(suit: Suit.hearts, rank: 7, isFaceUp: false),
            PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true),
          ],
          const <PlayingCard>[
            PlayingCard(suit: Suit.clubs, rank: 8, isFaceUp: true),
          ],
          const <PlayingCard>[],
          const <PlayingCard>[],
          const <PlayingCard>[],
          const <PlayingCard>[],
          const <PlayingCard>[],
        ],
      );

      await persistence.saveActiveGame(
        GameState(
          board: initialBoard,
          drawMode: DrawMode.draw1,
          dealType: DealType.winnable,
          dealSeed: 42,
          undoHistory: <BoardSnapshot>[initialBoard],
        ),
      );

      final settings = SettingsController(persistence: persistence, audio: audio);
      final stats = StatsController(persistence: persistence);
      final game = GameController(
        persistence: persistence,
        settings: settings,
        stats: stats,
        audio: audio,
        analytics: analytics,
        monetization: monetization,
      );
      addTearDown(() {
        game.dispose();
        settings.dispose();
        stats.dispose();
      });

      await settings.initialize();
      await settings.setShowTimer(true);
      await stats.initialize();
      await game.initialize();

      await tester.pumpWidget(
        ClearDeckApp(
          gameController: game,
          settingsController: settings,
          statsController: stats,
        ),
      );
      await tester.pumpAndSettle();

      // Tap A♠ so it flies to foundation and triggers the 3D flip of 7♥ below it.
      final aceCardFinder = find.descendant(
        of: find.byType(PlayingCardWidget),
        matching: find.text('A'),
      );
      expect(aceCardFinder, findsOneWidget);
      await tester.tap(aceCardFinder);
      await tester.pump();

      // Inspect across the full 260ms flip curve (including past t = 0.5 at 130ms).
      for (final stepMs in const <int>[40, 50, 40, 30, 50, 70, 70]) {
        await tester.pump(Duration(milliseconds: stepMs));
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
      }

      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('7'),
        ),
        findsOneWidget,
      );

      // Verify isolated ValueListenable timer updates cleanly without rebuild errors.
      await tester.pump(const Duration(seconds: 1));
      final timerWidget = tester.widget<Text>(
        find.byKey(const Key('top_timer_value')),
      );
      expect(timerWidget.data, isNotNull);
      expect(timerWidget.data, isNot('00:00'));
      expect(tester.takeException(), isNull);
    },
  );
}
