import 'package:cleardeck_solitaire/engine/engine.dart';
import 'package:cleardeck_solitaire/main.dart';
import 'package:cleardeck_solitaire/services/analytics_service.dart';
import 'package:cleardeck_solitaire/services/audio_service.dart';
import 'package:cleardeck_solitaire/services/monetization_service.dart';
import 'package:cleardeck_solitaire/services/persistence_service.dart';
import 'package:cleardeck_solitaire/state/game_controller.dart';
import 'package:cleardeck_solitaire/state/settings_controller.dart';
import 'package:cleardeck_solitaire/state/stats_controller.dart';
import 'package:cleardeck_solitaire/theme/app_theme.dart';
import 'package:cleardeck_solitaire/theme/deck_palette.dart';
import 'package:cleardeck_solitaire/ui/widgets/card_back_painter.dart';
import 'package:cleardeck_solitaire/ui/widgets/playing_card_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<
    ({
      GameController game,
      SettingsController settings,
      StatsController stats,
      LightweightAudioService audio,
    })> _pumpBoard(
  WidgetTester tester, {
  required BoardSnapshot board,
  DrawMode drawMode = DrawMode.draw1,
  AppSettings settings = const AppSettings(),
  Size surfaceSize = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final persistence = InMemoryPersistenceService();
  await persistence.saveSettingsJson(
    settings.copyWith(drawMode: drawMode).toJson(),
  );
  await persistence.saveActiveGame(
    GameState(
      board: board,
      drawMode: drawMode,
      dealType: DealType.winnable,
      dealSeed: 42,
      undoHistory: <BoardSnapshot>[board],
    ),
  );

  final audio = LightweightAudioService();
  final analytics = DebugAnalyticsService();
  const monetization = BetaFreeMonetizationService();

  final settingsController = SettingsController(
    persistence: persistence,
    audio: audio,
  );
  final statsController = StatsController(persistence: persistence);
  final gameController = GameController(
    persistence: persistence,
    settings: settingsController,
    stats: statsController,
    audio: audio,
    analytics: analytics,
    monetization: monetization,
  );

  addTearDown(() {
    gameController.dispose();
    settingsController.dispose();
    statsController.dispose();
  });

  await settingsController.initialize();
  await statsController.initialize();
  await gameController.initialize();

  await tester.pumpWidget(
    ClearDeckApp(
      gameController: gameController,
      settingsController: settingsController,
      statsController: statsController,
    ),
  );
  await tester.pumpAndSettle();

  return (
    game: gameController,
    settings: settingsController,
    stats: statsController,
    audio: audio,
  );
}

List<PlayingCard> _makeCards(
  int count, {
  bool isFaceUp = false,
  int startIndex = 0,
}) {
  return List<PlayingCard>.generate(count, (i) {
    final idx = startIndex + i;
    return PlayingCard(
      suit: Suit.values[idx % 4],
      rank: (idx % 13) + 1,
      isFaceUp: isFaceUp,
    );
  });
}

List<PlayingCard> _makeSuitRun(Suit suit, int count) {
  return List<PlayingCard>.generate(
    count,
    (i) => PlayingCard(suit: suit, rank: i + 1, isFaceUp: true),
  );
}

BoardSnapshot _emptyBoard({
  List<PlayingCard> stock = const <PlayingCard>[],
  List<PlayingCard> waste = const <PlayingCard>[],
  List<List<PlayingCard>>? foundations,
  List<List<PlayingCard>>? tableau,
}) {
  return BoardSnapshot(
    stock: stock,
    waste: waste,
    foundations:
        foundations ?? List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
    tableau:
        tableau ?? List<List<PlayingCard>>.generate(7, (_) => <PlayingCard>[]),
  );
}

Finder _cardFinder(PlayingCard card, {bool? isElevated}) {
  return find.byWidgetPredicate((w) {
    if (w is! PlayingCardWidget) return false;
    if (w.card != card) return false;
    if (isElevated != null && w.isElevated != isElevated) return false;
    return true;
  });
}

Finder _tableauColumnDragTarget(int colIndex) {
  final kSlot =
      find.byWidgetPredicate((w) => w is EmptyPileSlot && w.label == 'K').at(
            colIndex,
          );
  return find.ancestor(
    of: kSlot,
    matching: find.byType(DragTarget<CardDragPayload>),
  );
}

void _expectDepthLayers(String prefix, int expectedCount) {
  for (var i = 0; i < 3; i++) {
    final matcher = i < expectedCount ? findsOneWidget : findsNothing;
    expect(
      find.byKey(Key('${prefix}_depth_$i')),
      matcher,
      reason: 'Expected $expectedCount depth layers for $prefix (layer $i)',
    );
  }
}

bool _hasZeroOpacityAncestorWithin(
  WidgetTester tester, {
  required Finder target,
  required Finder scope,
}) {
  final scopeElement = tester.element(scope);
  final targetElement = tester.element(target);
  var found = false;
  targetElement.visitAncestorElements((ancestor) {
    if (ancestor == scopeElement) return false;
    final widget = ancestor.widget;
    if (widget is Opacity && widget.opacity == 0.0) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

void main() {
  testWidgets(
    'V1: DeckDepthStack renders exact layer keys for Stock/Waste/Foundations and updates dynamically on Stock draws',
    (WidgetTester tester) async {
      expect(DeckDepthStack.visibleLayersForCount(0), 0);
      expect(DeckDepthStack.visibleLayersForCount(1), 0);
      expect(DeckDepthStack.visibleLayersForCount(2), 1);
      expect(DeckDepthStack.visibleLayersForCount(5), 1);
      expect(DeckDepthStack.visibleLayersForCount(6), 2);
      expect(DeckDepthStack.visibleLayersForCount(13), 2);
      expect(DeckDepthStack.visibleLayersForCount(14), 3);

      final board = _emptyBoard(
        stock: _makeCards(14, isFaceUp: false, startIndex: 0),
        waste: const <PlayingCard>[
          PlayingCard(suit: Suit.clubs, rank: 10, isFaceUp: true),
        ],
        foundations: <List<PlayingCard>>[
          _makeSuitRun(Suit.spades, 1),
          _makeSuitRun(Suit.hearts, 2),
          _makeSuitRun(Suit.diamonds, 6),
          _makeSuitRun(Suit.clubs, 13),
        ],
      );

      final deps = await _pumpBoard(tester, board: board);

      // Initial counts:
      // Stock=14 -> 3 layers, Waste=1 -> 0 layers,
      // F0=1 -> 0 layers, F1=2 -> 1 layer, F2=6 -> 2 layers, F3=13 -> 2 layers.
      _expectDepthLayers('stock', 3);
      _expectDepthLayers('waste', 0);
      _expectDepthLayers('foundation_0', 0);
      _expectDepthLayers('foundation_1', 1);
      _expectDepthLayers('foundation_2', 2);
      _expectDepthLayers('foundation_3', 2);

      final stockFinder = find.byWidgetPredicate(
        (w) => w is DeckDepthStack && w.keyPrefix == 'stock',
      );

      // Draw 1: Stock 14 -> 13 (2 layers), Waste 1 -> 2 (1 layer).
      await tester.tap(stockFinder);
      await tester.pumpAndSettle();
      expect(deps.game.state.board.stock.length, 13);
      expect(deps.game.state.board.waste.length, 2);
      _expectDepthLayers('stock', 2);
      _expectDepthLayers('waste', 1);

      // Draw 4 more: Stock 13 -> 9 (2 layers), Waste 2 -> 6 (2 layers).
      for (var i = 0; i < 4; i++) {
        await tester.tap(stockFinder);
        await tester.pumpAndSettle();
      }
      expect(deps.game.state.board.stock.length, 9);
      expect(deps.game.state.board.waste.length, 6);
      _expectDepthLayers('stock', 2);
      _expectDepthLayers('waste', 2);

      // Draw 4 more: Stock 9 -> 5 (1 layer), Waste 6 -> 10 (2 layers).
      for (var i = 0; i < 4; i++) {
        await tester.tap(stockFinder);
        await tester.pumpAndSettle();
      }
      expect(deps.game.state.board.stock.length, 5);
      expect(deps.game.state.board.waste.length, 10);
      _expectDepthLayers('stock', 1);
      _expectDepthLayers('waste', 2);

      // Draw 4 more: Stock 5 -> 1 (0 layers), Waste 10 -> 14 (3 layers).
      for (var i = 0; i < 4; i++) {
        await tester.tap(stockFinder);
        await tester.pumpAndSettle();
      }
      expect(deps.game.state.board.stock.length, 1);
      expect(deps.game.state.board.waste.length, 14);
      _expectDepthLayers('stock', 0);
      _expectDepthLayers('waste', 3);

      // Draw final card: Stock 1 -> 0 (0 layers), Waste 14 -> 15 (3 layers).
      await tester.tap(stockFinder);
      await tester.pumpAndSettle();
      expect(deps.game.state.board.stock.length, 0);
      expect(deps.game.state.board.waste.length, 15);
      _expectDepthLayers('stock', 0);
      _expectDepthLayers('waste', 3);

      expect(tester.takeException(), isNull);
    },
  );

  group('V2: Draw-1 Waste drag reveals card underneath or EmptyPileSlot', () {
    testWidgets(
      'dragging top Waste card with waste.length >= 2 displays waste[len - 2] cleanly underneath',
      (WidgetTester tester) async {
        const bottomCard = PlayingCard(
          suit: Suit.diamonds,
          rank: 7,
          isFaceUp: true,
        );
        const underCard = PlayingCard(
          suit: Suit.clubs,
          rank: 9,
          isFaceUp: true,
        );
        const topCard = PlayingCard(
          suit: Suit.hearts,
          rank: 4,
          isFaceUp: true,
        );

        final board = _emptyBoard(
          waste: const <PlayingCard>[bottomCard, underCard, topCard],
        );
        await _pumpBoard(tester, board: board, drawMode: DrawMode.draw1);

        final wasteDraggable = find.byWidgetPredicate(
          (w) =>
              w is Draggable<CardDragPayload> &&
              w.data?.sourceKind == MoveKind.wasteToTableau,
        );
        expect(wasteDraggable, findsOneWidget);

        final topCardFinder = _cardFinder(topCard, isElevated: false);
        expect(topCardFinder, findsOneWidget);

        final gesture = await tester.startGesture(
          tester.getCenter(topCardFinder),
        );
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump(const Duration(milliseconds: 50));

        // Elevated drag feedback shows the top card.
        expect(_cardFinder(topCard, isElevated: true), findsOneWidget);

        // Beneath the dragged top card, waste[len - 2] (9♣) is rendered in waste_under!
        final wasteUnderStack = find.byWidgetPredicate(
          (w) => w is DeckDepthStack && w.keyPrefix == 'waste_under',
        );
        expect(wasteUnderStack, findsOneWidget);
        expect(
          find.descendant(
            of: wasteUnderStack,
            matching: _cardFinder(underCard, isElevated: false),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('waste_under_depth_0')), findsOneWidget);
        expect(
          find.descendant(
            of: wasteDraggable,
            matching: _cardFinder(topCard),
          ),
          findsNothing,
        );

        await gesture.up();
        await tester.pumpAndSettle();

        expect(_cardFinder(topCard, isElevated: false), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'dragging top Waste card with waste.length == 1 exposes EmptyPileSlot underneath',
      (WidgetTester tester) async {
        const onlyCard = PlayingCard(
          suit: Suit.hearts,
          rank: 4,
          isFaceUp: true,
        );

        final board = _emptyBoard(waste: const <PlayingCard>[onlyCard]);
        await _pumpBoard(tester, board: board, drawMode: DrawMode.draw1);

        final wasteDraggable = find.byWidgetPredicate(
          (w) =>
              w is Draggable<CardDragPayload> &&
              w.data?.sourceKind == MoveKind.wasteToTableau,
        );
        final topCardFinder = _cardFinder(onlyCard, isElevated: false);
        expect(topCardFinder, findsOneWidget);

        final gesture = await tester.startGesture(
          tester.getCenter(topCardFinder),
        );
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump(const Duration(milliseconds: 50));

        expect(_cardFinder(onlyCard, isElevated: true), findsOneWidget);
        expect(
          find.descendant(
            of: wasteDraggable,
            matching: find.byType(EmptyPileSlot),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: wasteDraggable,
            matching: find.byType(PlayingCardWidget),
          ),
          findsNothing,
        );

        await gesture.up();
        await tester.pumpAndSettle();

        expect(_cardFinder(onlyCard, isElevated: false), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('V3: Draw-3 outer 10dp Waste edge tap & Stock draw flight', () {
    for (final leftHanded in const <bool>[false, true]) {
      testWidgets(
        'Draw-3 (${leftHanded ? 'Left-Handed' : 'Right-Handed'}): Stock draws 3 cards cleanly (0..250ms) and outermost 10dp edge tap on 3rd card plays cleanly',
        (WidgetTester tester) async {
          const card1 = PlayingCard(suit: Suit.clubs, rank: 7, isFaceUp: false);
          const card2 =
              PlayingCard(suit: Suit.hearts, rank: 5, isFaceUp: false);
          const card3 =
              PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: false);

          final board = _emptyBoard(
            stock: const <PlayingCard>[
              PlayingCard(suit: Suit.clubs, rank: 13, isFaceUp: false),
              PlayingCard(suit: Suit.diamonds, rank: 12, isFaceUp: false),
              PlayingCard(suit: Suit.spades, rank: 11, isFaceUp: false),
              card3, // 3rd drawn -> top playable waste card
              card2, // 2nd drawn
              card1, // 1st drawn (stock.last)
            ],
          );

          final deps = await _pumpBoard(
            tester,
            board: board,
            drawMode: DrawMode.draw3,
            settings: AppSettings(
              drawMode: DrawMode.draw3,
              leftHanded: leftHanded,
            ),
          );

          final stockFinder = find.byWidgetPredicate(
            (w) => w is DeckDepthStack && w.keyPrefix == 'stock',
          );
          await tester.tap(stockFinder);
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(ErrorWidget), findsNothing);

          // Step across 0..250ms Stock Draw-3 flight/flip curve.
          for (final stepMs in const <int>[40, 40, 40, 50, 40, 40]) {
            await tester.pump(Duration(milliseconds: stepMs));
            expect(tester.takeException(), isNull);
            expect(find.byType(ErrorWidget), findsNothing);
          }

          await tester.pumpAndSettle();
          expect(deps.game.state.movesCount, 1);
          expect(
            tester.widget<Text>(find.byKey(const Key('top_moves_value'))).data,
            '1',
          );

          final c1Finder = _cardFinder(card1.copyWith(isFaceUp: true));
          final c2Finder = _cardFinder(card2.copyWith(isFaceUp: true));
          final c3Finder = _cardFinder(card3.copyWith(isFaceUp: true));
          expect(c1Finder, findsOneWidget);
          expect(c2Finder, findsOneWidget);
          expect(c3Finder, findsOneWidget);

          final r1 = tester.getRect(c1Finder);
          final r2 = tester.getRect(c2Finder);
          final r3 = tester.getRect(c3Finder);
          if (!leftHanded) {
            expect(r1.left, lessThan(r2.left));
            expect(r2.left, lessThan(r3.left));
          } else {
            expect(r1.left, greaterThan(r2.left));
            expect(r2.left, greaterThan(r3.left));
          }

          // Tap the outermost 10dp edge of the 3rd fanned Waste card.
          final outerEdgeTap = !leftHanded
              ? Offset(r3.right - 4.0, r3.center.dy)
              : Offset(r3.left + 4.0, r3.center.dy);
          await tester.tapAt(outerEdgeTap);
          await tester.pumpAndSettle();

          expect(deps.game.state.movesCount, 2);
          expect(
            tester.widget<Text>(find.byKey(const Key('top_moves_value'))).data,
            '2',
          );
          expect(deps.game.state.board.waste.length, 2);
          expect(deps.game.state.board.foundations[0].single.rank, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('V4: Multi-card tableau drag hides child cards cleanly', () {
    testWidgets(
      '(a) idx == 0 [K♠, Q♥, J♣]: feedback lifts all 3, children hidden with Opacity(0.0), EmptyPileSlot(K) unobscured, cancel restores, legal drop commits',
      (WidgetTester tester) async {
        const king = PlayingCard(suit: Suit.spades, rank: 13, isFaceUp: true);
        const queen = PlayingCard(suit: Suit.hearts, rank: 12, isFaceUp: true);
        const jack = PlayingCard(suit: Suit.clubs, rank: 11, isFaceUp: true);
        const blocker =
            PlayingCard(suit: Suit.diamonds, rank: 2, isFaceUp: true);

        final board = _emptyBoard(
          tableau: <List<PlayingCard>>[
            const <PlayingCard>[king, queen, jack],
            const <PlayingCard>[blocker],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
          ],
        );

        final deps = await _pumpBoard(tester, board: board);
        final col0Target = _tableauColumnDragTarget(0);

        final kingRect = tester.getRect(_cardFinder(king, isElevated: false));
        // Exposed top strip of K♠ above Q♥.
        final startPos = Offset(kingRect.center.dx, kingRect.top + 10.0);

        final gesture = await tester.startGesture(startPos);
        await gesture.moveBy(const Offset(40, 20));
        await tester.pump(const Duration(milliseconds: 50));

        // Drag feedback lifts all 3 cards cleanly.
        expect(_cardFinder(king, isElevated: true), findsOneWidget);
        expect(_cardFinder(queen, isElevated: true), findsOneWidget);
        expect(_cardFinder(jack, isElevated: true), findsOneWidget);

        // Source column has zero visible cards: K♠ replaced by SizedBox, Q♥ & J♣ wrapped in Opacity(0.0).
        expect(
          find.descendant(
            of: col0Target,
            matching: _cardFinder(king, isElevated: false),
          ),
          findsNothing,
        );
        final col0Queen = find.descendant(
          of: col0Target,
          matching: _cardFinder(queen, isElevated: false),
        );
        final col0Jack = find.descendant(
          of: col0Target,
          matching: _cardFinder(jack, isElevated: false),
        );
        expect(col0Queen, findsOneWidget);
        expect(col0Jack, findsOneWidget);
        expect(
          _hasZeroOpacityAncestorWithin(
            tester,
            target: col0Queen,
            scope: col0Target,
          ),
          isTrue,
        );
        expect(
          _hasZeroOpacityAncestorWithin(
            tester,
            target: col0Jack,
            scope: col0Target,
          ),
          isTrue,
        );

        // EmptyPileSlot('K') on col 0 is unobscured (no visible PlayingCardWidget in col 0).
        expect(
          find.descendant(
            of: col0Target,
            matching: find.byWidgetPredicate(
              (w) => w is EmptyPileSlot && w.label == 'K',
            ),
          ),
          findsOneWidget,
        );

        // Release over non-accepting blocker col 1 -> cancels & restores visibility cleanly.
        await gesture.up();
        await tester.pumpAndSettle();

        expect(deps.game.state.movesCount, 0);
        expect(_cardFinder(king, isElevated: true), findsNothing);
        expect(
          _hasZeroOpacityAncestorWithin(
            tester,
            target: find.descendant(
              of: col0Target,
              matching: _cardFinder(queen, isElevated: false),
            ),
            scope: col0Target,
          ),
          isFalse,
        );
        expect(
          _hasZeroOpacityAncestorWithin(
            tester,
            target: find.descendant(
              of: col0Target,
              matching: _cardFinder(jack, isElevated: false),
            ),
            scope: col0Target,
          ),
          isFalse,
        );

        // Drag onto legal empty col 2 and commit cleanly.
        final col2Slot = find
            .byWidgetPredicate((w) => w is EmptyPileSlot && w.label == 'K')
            .at(2);
        final col2Center = tester.getCenter(col2Slot);

        final drag2 = await tester.startGesture(startPos);
        await drag2.moveBy(const Offset(40, 20));
        await tester.pump(const Duration(milliseconds: 50));
        await drag2.moveTo(col2Center);
        await tester.pump();
        await drag2.up();
        await tester.pumpAndSettle();

        expect(deps.game.state.movesCount, 1);
        expect(deps.game.state.board.tableau[0], isEmpty);
        expect(
          deps.game.state.board.tableau[2],
          const <PlayingCard>[king, queen, jack],
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '(b) mid-column [9♦, 8♠, 7♥, 6♣]: dragging 8♠ leaves 9♦ visible, hides 7♥ & 6♣ with Opacity(0.0), cancel restores, legal drop onto 9♥ commits',
      (WidgetTester tester) async {
        const nineDiamonds =
            PlayingCard(suit: Suit.diamonds, rank: 9, isFaceUp: true);
        const eight = PlayingCard(suit: Suit.spades, rank: 8, isFaceUp: true);
        const seven = PlayingCard(suit: Suit.hearts, rank: 7, isFaceUp: true);
        const six = PlayingCard(suit: Suit.clubs, rank: 6, isFaceUp: true);
        const blocker = PlayingCard(suit: Suit.clubs, rank: 2, isFaceUp: true);
        const targetNine =
            PlayingCard(suit: Suit.hearts, rank: 9, isFaceUp: true);

        final board = _emptyBoard(
          tableau: <List<PlayingCard>>[
            const <PlayingCard>[nineDiamonds, eight, seven, six],
            const <PlayingCard>[blocker],
            const <PlayingCard>[targetNine],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
          ],
        );

        final deps = await _pumpBoard(tester, board: board);
        final col0Target = _tableauColumnDragTarget(0);

        final eightRect = tester.getRect(_cardFinder(eight, isElevated: false));
        final startPos = Offset(eightRect.center.dx, eightRect.top + 10.0);

        final gesture = await tester.startGesture(startPos);
        await gesture.moveBy(const Offset(40, 20));
        await tester.pump(const Duration(milliseconds: 50));

        // Feedback lifts all 3 cards [8♠, 7♥, 6♣].
        expect(_cardFinder(eight, isElevated: true), findsOneWidget);
        expect(_cardFinder(seven, isElevated: true), findsOneWidget);
        expect(_cardFinder(six, isElevated: true), findsOneWidget);
        expect(_cardFinder(nineDiamonds, isElevated: true), findsNothing);

        // Parent 9♦ stays cleanly visible; 8♠ is replaced; 7♥ & 6♣ have Opacity(0.0).
        final col0Nine = find.descendant(
          of: col0Target,
          matching: _cardFinder(nineDiamonds, isElevated: false),
        );
        final col0Seven = find.descendant(
          of: col0Target,
          matching: _cardFinder(seven, isElevated: false),
        );
        final col0Six = find.descendant(
          of: col0Target,
          matching: _cardFinder(six, isElevated: false),
        );
        expect(col0Nine, findsOneWidget);
        expect(
          _hasZeroOpacityAncestorWithin(
            tester,
            target: col0Nine,
            scope: col0Target,
          ),
          isFalse,
        );
        expect(
          find.descendant(
            of: col0Target,
            matching: _cardFinder(eight, isElevated: false),
          ),
          findsNothing,
        );
        expect(col0Seven, findsOneWidget);
        expect(col0Six, findsOneWidget);
        expect(
          _hasZeroOpacityAncestorWithin(
            tester,
            target: col0Seven,
            scope: col0Target,
          ),
          isTrue,
        );
        expect(
          _hasZeroOpacityAncestorWithin(
            tester,
            target: col0Six,
            scope: col0Target,
          ),
          isTrue,
        );

        // Cancel over blocker col 1 -> restores visibility cleanly.
        await gesture.up();
        await tester.pumpAndSettle();

        expect(deps.game.state.movesCount, 0);
        expect(
          _hasZeroOpacityAncestorWithin(
            tester,
            target: find.descendant(
              of: col0Target,
              matching: _cardFinder(seven, isElevated: false),
            ),
            scope: col0Target,
          ),
          isFalse,
        );
        expect(
          _hasZeroOpacityAncestorWithin(
            tester,
            target: find.descendant(
              of: col0Target,
              matching: _cardFinder(six, isElevated: false),
            ),
            scope: col0Target,
          ),
          isFalse,
        );

        // Drag onto legal 9♥ on col 2 and commit cleanly.
        final targetCenter = tester.getCenter(
          _cardFinder(targetNine, isElevated: false),
        );
        final drag2 = await tester.startGesture(startPos);
        await drag2.moveBy(const Offset(40, 20));
        await tester.pump(const Duration(milliseconds: 50));
        await drag2.moveTo(targetCenter);
        await tester.pump();
        await drag2.up();
        await tester.pumpAndSettle();

        expect(deps.game.state.movesCount, 1);
        expect(
          deps.game.state.board.tableau[0],
          const <PlayingCard>[nineDiamonds],
        );
        expect(
          deps.game.state.board.tableau[2],
          const <PlayingCard>[targetNine, eight, seven, six],
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets(
    'V5: Hint highlights all 3 cards of hinted 3-card run and tap-to-move flies cleanly across 0..250ms',
    (WidgetTester tester) async {
      const hiddenFive =
          PlayingCard(suit: Suit.diamonds, rank: 5, isFaceUp: false);
      const eight = PlayingCard(suit: Suit.spades, rank: 8, isFaceUp: true);
      const seven = PlayingCard(suit: Suit.hearts, rank: 7, isFaceUp: true);
      const six = PlayingCard(suit: Suit.clubs, rank: 6, isFaceUp: true);
      const targetNine =
          PlayingCard(suit: Suit.diamonds, rank: 9, isFaceUp: true);

      final board = _emptyBoard(
        tableau: <List<PlayingCard>>[
          const <PlayingCard>[hiddenFive, eight, seven, six],
          const <PlayingCard>[targetNine],
          const <PlayingCard>[],
          const <PlayingCard>[],
          const <PlayingCard>[],
          const <PlayingCard>[],
          const <PlayingCard>[],
        ],
      );

      final deps = await _pumpBoard(tester, board: board);

      // Tap Hint -> best move is moving [8♠, 7♥, 6♣] to 9♦ to uncover 5♦.
      await tester.tap(find.text('Hint'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<PlayingCardWidget>(_cardFinder(eight)).isHighlighted,
        isTrue,
      );
      expect(
        tester.widget<PlayingCardWidget>(_cardFinder(seven)).isHighlighted,
        isTrue,
      );
      expect(
        tester.widget<PlayingCardWidget>(_cardFinder(six)).isHighlighted,
        isTrue,
      );
      expect(
        tester.widget<PlayingCardWidget>(_cardFinder(hiddenFive)).isHighlighted,
        isFalse,
      );

      // Tap exposed top strip of 8♠ -> 3-card stack flies across 0..250ms.
      final eightRect = tester.getRect(_cardFinder(eight));
      await tester.tapAt(Offset(eightRect.center.dx, eightRect.top + 10.0));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);

      var checkedMidFlight = false;
      for (final stepMs in const <int>[30, 30, 30, 40, 40, 40, 40]) {
        await tester.pump(Duration(milliseconds: stepMs));
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        if (!checkedMidFlight) {
          // Verify all 3 cards fly in the elevated overlay.
          if (tester
                  .widgetList<PlayingCardWidget>(
                    find.byWidgetPredicate(
                      (w) => w is PlayingCardWidget && w.isElevated,
                    ),
                  )
                  .length ==
              3) {
            checkedMidFlight = true;
          }
        }
      }
      expect(checkedMidFlight, isTrue);

      await tester.pumpAndSettle();
      expect(deps.game.state.movesCount, 1);
      expect(
        deps.game.state.board.tableau[0],
        <PlayingCard>[hiddenFive.copyWith(isFaceUp: true)],
      );
      expect(
        deps.game.state.board.tableau[1],
        const <PlayingCard>[targetNine, eight, seven, six],
      );
      expect(tester.takeException(), isNull);
    },
  );

  group('V6: Tableau 3D flip and Draw-3 Stock flip frame sweep', () {
    const timestamps = <int>[0, 40, 90, 130, 170, 220, 280, 350];

    testWidgets(
      'tableau 3D flip across 0, 40, 90, 130, 170, 220, 280, 350ms produces 0 exceptions and 0 ErrorWidgets',
      (WidgetTester tester) async {
        const hiddenSeven =
            PlayingCard(suit: Suit.hearts, rank: 7, isFaceUp: false);
        const aceSpades =
            PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true);

        final board = _emptyBoard(
          tableau: <List<PlayingCard>>[
            const <PlayingCard>[hiddenSeven, aceSpades],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
          ],
        );

        await _pumpBoard(tester, board: board);

        await tester.tap(_cardFinder(aceSpades));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);

        var prevMs = 0;
        for (final t in timestamps.skip(1)) {
          await tester.pump(Duration(milliseconds: t - prevMs));
          prevMs = t;
          expect(tester.takeException(), isNull);
          expect(find.byType(ErrorWidget), findsNothing);
        }

        await tester.pumpAndSettle();
        expect(
          _cardFinder(hiddenSeven.copyWith(isFaceUp: true)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Draw-3 Stock draw flip across 0, 40, 90, 130, 170, 220, 280, 350ms produces 0 exceptions and 0 ErrorWidgets',
      (WidgetTester tester) async {
        final board = _emptyBoard(
          stock: _makeCards(6, isFaceUp: false, startIndex: 0),
        );

        final deps = await _pumpBoard(
          tester,
          board: board,
          drawMode: DrawMode.draw3,
          settings: const AppSettings(drawMode: DrawMode.draw3),
        );

        final stockFinder = find.byWidgetPredicate(
          (w) => w is DeckDepthStack && w.keyPrefix == 'stock',
        );
        await tester.tap(stockFinder);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);

        var prevMs = 0;
        for (final t in timestamps.skip(1)) {
          await tester.pump(Duration(milliseconds: t - prevMs));
          prevMs = t;
          expect(tester.takeException(), isNull);
          expect(find.byType(ErrorWidget), findsNothing);
        }

        await tester.pumpAndSettle();
        expect(deps.game.state.board.waste.length, 3);
        expect(deps.game.state.board.stock.length, 3);
      },
    );

    testWidgets(
      'Warm Night (midnightMahogany): transient Tableau reveal flip (40ms) and Stock draw flight (40ms) preserve #E7DDCC paperColor and cardBorder on every CardBackPatternWidget',
      (WidgetTester tester) async {
        const hiddenSeven =
            PlayingCard(suit: Suit.hearts, rank: 7, isFaceUp: false);
        const aceSpades =
            PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true);

        final board = _emptyBoard(
          stock: _makeCards(6, isFaceUp: false, startIndex: 0),
          tableau: <List<PlayingCard>>[
            const <PlayingCard>[hiddenSeven, aceSpades],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
            const <PlayingCard>[],
          ],
        );

        await _pumpBoard(
          tester,
          board: board,
          drawMode: DrawMode.draw3,
          settings: const AppSettings(
            drawMode: DrawMode.draw3,
            tableTheme: TableThemeId.midnightMahogany,
          ),
        );

        // 1. Tableau reveal flip at 40ms (showBack == true on flipping card).
        await tester.tap(_cardFinder(aceSpades));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);

        final tableauFlipBacks = tester
            .widgetList<CardBackPatternWidget>(
              find.byType(CardBackPatternWidget),
            )
            .toList();
        expect(tableauFlipBacks.length, greaterThanOrEqualTo(2));
        for (final back in tableauFlipBacks) {
          expect(
            back.paperColor,
            ClearDeckTheme.midnightMahogany.cardFace,
          );
          expect(
            back.borderColor,
            ClearDeckTheme.midnightMahogany.cardBorder,
          );
        }

        await tester.pumpAndSettle();
        expect(
          _cardFinder(hiddenSeven.copyWith(isFaceUp: true)),
          findsOneWidget,
        );

        // 2. Draw-3 Stock draw flight at 40ms (showBack == true on flying cards).
        final stockFinder = find.byWidgetPredicate(
          (w) => w is DeckDepthStack && w.keyPrefix == 'stock',
        );
        await tester.tap(stockFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);

        final stockFlightBacks = tester
            .widgetList<CardBackPatternWidget>(
              find.byType(CardBackPatternWidget),
            )
            .toList();
        expect(stockFlightBacks.length, greaterThanOrEqualTo(2));
        for (final back in stockFlightBacks) {
          expect(
            back.paperColor,
            ClearDeckTheme.midnightMahogany.cardFace,
          );
          expect(
            back.borderColor,
            ClearDeckTheme.midnightMahogany.cardBorder,
          );
        }

        await tester.pumpAndSettle();
      },
    );
  });

  group(
    'V7: Full visual matrix (4 themes x leftHanded x Draw3 x Jumbo x 4-color x Phone/Tablet)',
    () {
      final matrixBoard = _emptyBoard(
        stock: _makeCards(6, isFaceUp: false, startIndex: 0),
        waste: const <PlayingCard>[
          PlayingCard(suit: Suit.clubs, rank: 4, isFaceUp: true),
          PlayingCard(suit: Suit.diamonds, rank: 7, isFaceUp: true),
          PlayingCard(suit: Suit.hearts, rank: 10, isFaceUp: true),
        ],
        foundations: <List<PlayingCard>>[
          _makeSuitRun(Suit.spades, 2),
          _makeSuitRun(Suit.hearts, 1),
          const <PlayingCard>[],
          const <PlayingCard>[],
        ],
        tableau: <List<PlayingCard>>[
          const <PlayingCard>[
            PlayingCard(suit: Suit.clubs, rank: 3, isFaceUp: false),
            PlayingCard(suit: Suit.spades, rank: 13, isFaceUp: true),
            PlayingCard(suit: Suit.hearts, rank: 12, isFaceUp: true),
            PlayingCard(suit: Suit.clubs, rank: 11, isFaceUp: true),
            PlayingCard(suit: Suit.diamonds, rank: 10, isFaceUp: true),
            PlayingCard(suit: Suit.spades, rank: 9, isFaceUp: true),
          ],
          const <PlayingCard>[
            PlayingCard(suit: Suit.diamonds, rank: 6, isFaceUp: false),
            PlayingCard(suit: Suit.hearts, rank: 1, isFaceUp: true),
          ],
          const <PlayingCard>[],
          const <PlayingCard>[
            PlayingCard(suit: Suit.spades, rank: 5, isFaceUp: false),
            PlayingCard(suit: Suit.clubs, rank: 8, isFaceUp: true),
          ],
          const <PlayingCard>[
            PlayingCard(suit: Suit.hearts, rank: 2, isFaceUp: false),
            PlayingCard(suit: Suit.diamonds, rank: 4, isFaceUp: true),
          ],
          const <PlayingCard>[
            PlayingCard(suit: Suit.spades, rank: 7, isFaceUp: true),
          ],
          const <PlayingCard>[
            PlayingCard(suit: Suit.clubs, rank: 12, isFaceUp: true),
          ],
        ],
      );

      const sizes = <({String label, Size size})>[
        (label: '390x844', size: Size(390, 844)),
        (label: '1194x834', size: Size(1194, 834)),
      ];

      for (final themeId in TableThemeId.values) {
        for (final leftHanded in const <bool>[false, true]) {
          for (final viewport in sizes) {
            testWidgets(
              '${themeId.name} | leftHanded=$leftHanded | ${viewport.label}',
              (WidgetTester tester) async {
                await _pumpBoard(
                  tester,
                  board: matrixBoard,
                  drawMode: DrawMode.draw3,
                  surfaceSize: viewport.size,
                  settings: AppSettings(
                    tableTheme: themeId,
                    leftHanded: leftHanded,
                    drawMode: DrawMode.draw3,
                    cardScale: CardScale.jumbo,
                    fourColorDeck: true,
                    showTimer: true,
                  ),
                );

                expect(tester.takeException(), isNull);
                expect(find.byType(ErrorWidget), findsNothing);

                final cardBacks = tester.widgetList<CardBackPatternWidget>(
                  find.byType(CardBackPatternWidget),
                );
                expect(cardBacks, isNotEmpty);

                if (themeId == TableThemeId.midnightMahogany) {
                  for (final back in cardBacks) {
                    expect(
                      back.paperColor,
                      ClearDeckTheme.midnightMahogany.cardFace,
                    );
                    expect(
                      back.borderColor,
                      ClearDeckTheme.midnightMahogany.cardBorder,
                    );
                  }
                }
              },
            );
          }
        }
      }
    },
  );
}
