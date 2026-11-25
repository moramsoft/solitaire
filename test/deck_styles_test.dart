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
import 'package:cleardeck_solitaire/theme/app_theme.dart';
import 'package:cleardeck_solitaire/theme/deck_palette.dart';
import 'package:cleardeck_solitaire/ui/widgets/playing_card_widget.dart';
import 'package:cleardeck_solitaire/ui/widgets/suit_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('AppSettings serializes and restores all 5 DeckFaceStyles, 8 CardBackStyles, and tutorial flags', () {
    // Legacy JSON without new keys falls back safely
    final legacy = AppSettings.fromJson(<String, dynamic>{
      'drawMode': 'draw3',
      'cardBackStyle': 'royalNavy',
    });
    expect(legacy.drawMode, DrawMode.draw3);
    expect(legacy.deckFaceStyle, DeckFaceStyle.americanHeritage);
    expect(legacy.cardBackStyle, CardBackStyle.royalNavy);
    expect(legacy.tutorialCompleted, isFalse);
    expect(legacy.tutorialPromptDismissed, isFalse);

    for (final face in DeckFaceStyle.values) {
      for (final back in CardBackStyle.values) {
        final original = AppSettings(
          deckFaceStyle: face,
          cardBackStyle: back,
          tutorialCompleted: true,
          tutorialPromptDismissed: true,
        );
        final decoded = AppSettings.fromJson(original.toJson());
        expect(decoded.deckFaceStyle, face);
        expect(decoded.cardBackStyle, back);
        expect(decoded.tutorialCompleted, isTrue);
        expect(decoded.tutorialPromptDismissed, isTrue);
      }
    }
  });

  testWidgets(
    'PlayingCardWidget renders all 5 DeckFaceStyles and 8 CardBackStyles cleanly across themes without overflow',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final theme in <ClearDeckTheme>[
        ClearDeckTheme.heritageGreen,
        ClearDeckTheme.midnightMahogany,
      ]) {
        for (final faceStyle in DeckFaceStyle.values) {
          final cards = <PlayingCard>[
            const PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true),
            const PlayingCard(suit: Suit.hearts, rank: 7, isFaceUp: true),
            const PlayingCard(suit: Suit.diamonds, rank: 11, isFaceUp: true),
            const PlayingCard(suit: Suit.clubs, rank: 12, isFaceUp: true),
            const PlayingCard(suit: Suit.hearts, rank: 13, isFaceUp: true),
            const PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: false),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final card in cards)
                      PlayingCardWidget(
                        card: card,
                        width: 56,
                        height: 80,
                        theme: theme,
                        fourColorDeck: true,
                        cardScale: CardScale.large,
                        deckFaceStyle: faceStyle,
                        cardBackStyle: CardBackStyle.artDecoSunburst,
                      ),
                    for (final backStyle in CardBackStyle.values)
                      PlayingCardWidget(
                        card: const PlayingCard(
                          suit: Suit.spades,
                          rank: 1,
                          isFaceUp: false,
                        ),
                        width: 48,
                        height: 68,
                        theme: theme,
                        fourColorDeck: false,
                        cardScale: CardScale.large,
                        deckFaceStyle: faceStyle,
                        cardBackStyle: backStyle,
                      ),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      }

      // Royal Emblem uses pure vector crest (null asset path)
      expect(CourtCrestWidget.assetPathFor(DeckFaceStyle.royalEmblem, 13), isNull);
      expect(
        CourtCrestWidget.assetPathFor(DeckFaceStyle.botanicalGarden, 12),
        'assets/images/court_botanical_queen.png',
      );
      expect(
        CourtCrestWidget.assetPathFor(DeckFaceStyle.artDecoParlor, 11),
        'assets/images/court_artdeco_jack.png',
      );
      expect(
        CourtCrestWidget.assetPathFor(DeckFaceStyle.maritimeClub, 13),
        'assets/images/court_maritime_king.png',
      );
    },
  );

  testWidgets(
    'SettingsSheet switches all new DeckFaceStyles & CardBackStyles cleanly at compact 360x780 width',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = InMemoryPersistenceService();
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

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      for (final face in <DeckFaceStyle>[
        DeckFaceStyle.botanicalGarden,
        DeckFaceStyle.artDecoParlor,
        DeckFaceStyle.maritimeClub,
        DeckFaceStyle.royalEmblem,
      ]) {
        final finder = find.byKey(Key('deck_face_${face.name}'));
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(settings.settings.deckFaceStyle, face);
      }

      for (final back in <CardBackStyle>[
        CardBackStyle.artDecoSunburst,
        CardBackStyle.coastalCompass,
        CardBackStyle.plumDamask,
        CardBackStyle.sageTrellis,
      ]) {
        final finder = find.byKey(Key('card_back_${back.name}'));
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(settings.settings.cardBackStyle, back);
      }

      expect(tester.takeException(), isNull);
    },
  );
}
