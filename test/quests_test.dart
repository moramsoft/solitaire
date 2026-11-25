import 'package:cleardeck_solitaire/engine/engine.dart';
import 'package:cleardeck_solitaire/main.dart';
import 'package:cleardeck_solitaire/models/quest.dart';
import 'package:cleardeck_solitaire/services/analytics_service.dart';
import 'package:cleardeck_solitaire/services/audio_service.dart';
import 'package:cleardeck_solitaire/services/monetization_service.dart';
import 'package:cleardeck_solitaire/services/persistence_service.dart';
import 'package:cleardeck_solitaire/state/game_controller.dart';
import 'package:cleardeck_solitaire/state/quest_controller.dart';
import 'package:cleardeck_solitaire/state/settings_controller.dart';
import 'package:cleardeck_solitaire/state/stats_controller.dart';
import 'package:cleardeck_solitaire/theme/deck_palette.dart';
import 'package:cleardeck_solitaire/ui/widgets/playing_card_widget.dart';
import 'package:cleardeck_solitaire/ui/widgets/quest_banner.dart';
import 'package:cleardeck_solitaire/ui/widgets/quests_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('QuestCatalog defines 50 unique quests with 10 per category', () {
    expect(QuestCatalog.all.length, 50);
    expect(QuestCatalog.all.map((q) => q.id).toSet().length, 50);
    for (final category in QuestCategory.values) {
      expect(
        QuestCatalog.all.where((q) => q.category == category).length,
        10,
        reason: 'Category ${category.name} should have 10 quests',
      );
    }
  });

  test('QuestController tracks all 50 quests, queues FIFO banners, and persists', () async {
    final persistence = InMemoryPersistenceService();
    final qc = QuestController(persistence: persistence);
    await qc.initialize();

    expect(qc.totalCount, 50);
    expect(qc.completedCount, 0);
    expect(qc.activeBannerQuest, isNull);

    // 1. Place first Ace -> completes first_foundation and opens progress on Aces/Foundations/Hidden
    await qc.recordMove(
      move: const SolitaireMove(
        kind: MoveKind.tableauToFoundation,
        fromPileIndex: 0,
        toPileIndex: 0,
      ),
      movedCards: const <PlayingCard>[
        PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true),
      ],
      revealedHiddenCard: true,
      targetColumnWasEmpty: false,
    );

    expect(qc.progressFor('first_foundation').isCompleted, isTrue);
    expect(qc.progressFor('foundation_builder').current, 1);
    expect(qc.progressFor('reveal_hidden_5').current, 1);
    expect(qc.activeBannerQuest?.id, 'first_foundation');

    // 2. Move a 2-card King stack onto empty column -> completes stack_mover & kings_seat
    await qc.recordMove(
      move: const SolitaireMove(
        kind: MoveKind.tableauToTableau,
        fromPileIndex: 1,
        toPileIndex: 2,
        cardCount: 2,
      ),
      movedCards: const <PlayingCard>[
        PlayingCard(suit: Suit.diamonds, rank: 13, isFaceUp: true),
        PlayingCard(suit: Suit.clubs, rank: 12, isFaceUp: true),
      ],
      revealedHiddenCard: false,
      targetColumnWasEmpty: true,
    );

    expect(qc.progressFor('stack_mover').isCompleted, isTrue);
    expect(qc.progressFor('kings_seat').isCompleted, isTrue);
    expect(qc.pendingBannerCount, 3);

    // Dismiss initial banners in FIFO order
    expect(qc.activeBannerQuest?.id, 'first_foundation');
    qc.dismissActiveBanner();
    expect(qc.activeBannerQuest?.id, 'stack_mover');
    qc.dismissActiveBanner();
    expect(qc.activeBannerQuest?.id, 'kings_seat');
    qc.dismissActiveBanner();
    expect(qc.activeBannerQuest, isNull);

    // Stock draw x10 + recycle + Waste x3 + Foundation pullback
    for (var i = 0; i < 10; i++) {
      await qc.recordMove(
        move: const SolitaireMove(kind: MoveKind.drawStock),
        movedCards: const <PlayingCard>[
          PlayingCard(suit: Suit.clubs, rank: 5, isFaceUp: true),
        ],
        revealedHiddenCard: false,
        targetColumnWasEmpty: false,
      );
    }
    await qc.recordMove(
      move: const SolitaireMove(kind: MoveKind.recycleStock),
      movedCards: const <PlayingCard>[],
      revealedHiddenCard: false,
      targetColumnWasEmpty: false,
    );
    for (var i = 0; i < 3; i++) {
      await qc.recordMove(
        move: const SolitaireMove(
          kind: MoveKind.wasteToTableau,
          toPileIndex: 0,
        ),
        movedCards: const <PlayingCard>[
          PlayingCard(suit: Suit.hearts, rank: 4, isFaceUp: true),
        ],
        revealedHiddenCard: false,
        targetColumnWasEmpty: false,
      );
    }
    await qc.recordMove(
      move: const SolitaireMove(
        kind: MoveKind.foundationToTableau,
        fromPileIndex: 0,
        toPileIndex: 1,
      ),
      movedCards: const <PlayingCard>[
        PlayingCard(suit: Suit.spades, rank: 9, isFaceUp: true),
      ],
      revealedHiddenCard: false,
      targetColumnWasEmpty: false,
    );

    // Multi-card stacks (25x, plus 4-card & 7-card) and Kings (10x + entourage)
    await qc.recordMove(
      move: const SolitaireMove(
        kind: MoveKind.tableauToTableau,
        fromPileIndex: 0,
        toPileIndex: 1,
        cardCount: 7,
      ),
      movedCards: List<PlayingCard>.generate(
        7,
        (i) => PlayingCard(suit: Suit.spades, rank: 13 - i, isFaceUp: true),
      ),
      revealedHiddenCard: false,
      targetColumnWasEmpty: true,
    );
    for (var i = 0; i < 24; i++) {
      await qc.recordMove(
        move: const SolitaireMove(
          kind: MoveKind.tableauToTableau,
          fromPileIndex: 0,
          toPileIndex: 1,
          cardCount: 2,
        ),
        movedCards: const <PlayingCard>[
          PlayingCard(suit: Suit.clubs, rank: 13, isFaceUp: true),
          PlayingCard(suit: Suit.hearts, rank: 12, isFaceUp: true),
        ],
        revealedHiddenCard: false,
        targetColumnWasEmpty: i < 9,
      );
    }

    // 250 hidden card flips (1 already done above -> 249 more)
    for (var i = 0; i < 249; i++) {
      await qc.recordMove(
        move: const SolitaireMove(
          kind: MoveKind.tableauToTableau,
          fromPileIndex: 0,
          toPileIndex: 1,
          cardCount: 1,
        ),
        movedCards: const <PlayingCard>[
          PlayingCard(suit: Suit.hearts, rank: 5, isFaceUp: true),
        ],
        revealedHiddenCard: true,
        targetColumnWasEmpty: false,
      );
    }

    // 4 Suit Kings to foundation
    for (final suit in Suit.values) {
      await qc.recordMove(
        move: const SolitaireMove(
          kind: MoveKind.tableauToFoundation,
          fromPileIndex: 0,
          toPileIndex: 0,
        ),
        movedCards: <PlayingCard>[
          PlayingCard(suit: suit, rank: 13, isFaceUp: true),
        ],
        revealedHiddenCard: false,
        targetColumnWasEmpty: false,
      );
    }

    // 19 more Aces (total 20) + enough foundation placements to hit 500
    for (var i = 0; i < 19; i++) {
      await qc.recordMove(
        move: const SolitaireMove(
          kind: MoveKind.tableauToFoundation,
          fromPileIndex: 0,
          toPileIndex: 0,
        ),
        movedCards: const <PlayingCard>[
          PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true),
        ],
        revealedHiddenCard: false,
        targetColumnWasEmpty: false,
      );
    }
    for (var i = 0; i < 476; i++) {
      await qc.recordMove(
        move: const SolitaireMove(
          kind: MoveKind.tableauToFoundation,
          fromPileIndex: 0,
          toPileIndex: 0,
        ),
        movedCards: const <PlayingCard>[
          PlayingCard(suit: Suit.hearts, rank: 2, isFaceUp: true),
        ],
        revealedHiddenCard: false,
        targetColumnWasEmpty: false,
      );
    }

    // Parlor/feature quests
    await qc.recordUndo();
    await qc.recordHintUsed();
    await qc.recordAutoCompleteUsed();
    await qc.recordTutorialCompleted();
    await qc.recordFaceStyleChanged();
    await qc.recordThemeOrBackChanged();

    // Win quests (1st covering flawless, draw3, random, daily, 5-streak, <=120 moves, <=300s)
    await qc.recordWin(
      usedHintInHand: false,
      usedUndoInHand: false,
      drawMode: DrawMode.draw3,
      dealType: DealType.random,
      isDaily: true,
      currentStreak: 5,
      movesCount: 95,
      elapsedSeconds: 180,
    );
    // 49 more wins (covering 5x draw3, 5x daily, 50 total wins)
    for (var i = 0; i < 49; i++) {
      await qc.recordWin(
        usedHintInHand: true,
        usedUndoInHand: true,
        drawMode: DrawMode.draw3,
        dealType: DealType.winnable,
        isDaily: i < 4,
        currentStreak: 1,
        movesCount: 150,
        elapsedSeconds: 400,
      );
    }

    expect(qc.completedCount, 50);
    for (final cat in QuestCategory.values) {
      expect(qc.completedCountInCategory(cat), 10);
    }

    // Persistence round-trip into a brand new controller
    final qc2 = QuestController(persistence: persistence);
    await qc2.initialize();
    expect(qc2.completedCount, 50);
    for (final q in QuestCatalog.all) {
      expect(qc2.progressFor(q.id).isCompleted, isTrue, reason: q.id);
    }

    qc.dispose();
    qc2.dispose();
  });

  testWidgets(
    'Completing quest shows bottom strip, opens QuestsSheet focused cleanly, and filters 50 quests without overflow on 390x844 and 360x780',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = InMemoryPersistenceService();
      final initialBoard = BoardSnapshot(
        stock: const <PlayingCard>[],
        waste: const <PlayingCard>[],
        foundations:
            List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
        tableau: <List<PlayingCard>>[
          const <PlayingCard>[
            PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true),
          ],
          const <PlayingCard>[
            PlayingCard(suit: Suit.clubs, rank: 7, isFaceUp: true),
          ],
          const <PlayingCard>[
            PlayingCard(suit: Suit.hearts, rank: 6, isFaceUp: true),
            PlayingCard(suit: Suit.clubs, rank: 5, isFaceUp: true),
          ],
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
          dealSeed: 7,
          undoHistory: <BoardSnapshot>[initialBoard],
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

      // Tap Ace of Spades to move to Foundation -> completes First Ace Placed
      await tester.tap(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('A'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuestBannerStrip), findsOneWidget);
      expect(find.text('First Ace Placed'), findsOneWidget);

      // Verify bottom strip sits cleanly ABOVE BottomActionBar without overlapping it
      final bannerRect = tester.getRect(find.byType(QuestBannerStrip));
      final undoRect = tester.getRect(find.text('Undo'));
      expect(bannerRect.bottom, lessThanOrEqualTo(undoRect.top + 8.0));

      // Dismiss explicitly via the X button
      await tester.tap(find.byKey(const Key('quest_banner_dismiss')));
      await tester.pumpAndSettle();
      expect(find.byType(QuestBannerStrip), findsNothing);
      expect(find.byType(QuestsSheet), findsNothing);

      // Now trigger Stack Mover by tapping 6♥ stack onto 7♣
      await tester.tap(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.text('6'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuestBannerStrip), findsOneWidget);
      expect(find.text('Stack Mover'), findsOneWidget);

      // Tap banner body to open QuestsSheet (auto-focused on Table craft)
      await tester.tap(find.byKey(const Key('quest_banner_body')));
      await tester.pumpAndSettle();

      expect(find.byType(QuestsSheet), findsOneWidget);
      expect(find.text('2 of 50 complete'), findsOneWidget);
      expect(find.text('Stack Mover'), findsOneWidget);
      expect(find.byType(QuestBannerStrip), findsNothing);

      // Test switching category filter pills
      final foundationsChip = find.byKey(const Key('quest_filter_foundations'));
      await tester.ensureVisible(foundationsChip);
      await tester.tap(foundationsChip);
      await tester.pumpAndSettle();
      expect(find.text('Suit Collector'), findsOneWidget);

      final allChip = find.byKey(const Key('quest_filter_all'));
      await tester.ensureVisible(allChip);
      await tester.tap(allChip);
      await tester.pumpAndSettle();
      expect(find.text('First Ace Placed'), findsOneWidget);

      // Also verify compact 360x780 viewport renders cleanly without overflow
      await tester.binding.setSurfaceSize(const Size(360, 780));
      await tester.pumpAndSettle();

      // Switch DeckFaceStyle in SettingsController and verify parlor quest tracks cleanly
      await settings.setDeckFaceStyle(DeckFaceStyle.artDecoParlor);
      await tester.pumpAndSettle();
      expect(quests.progressFor('deck_connoisseur').isCompleted, isTrue);

      expect(tester.takeException(), isNull);
    },
  );
}
