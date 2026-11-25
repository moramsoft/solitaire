import 'dart:convert';

import 'package:cleardeck_solitaire/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameState persistence serialization', () {
    test('GameState round-trips through JSON cleanly with undoHistory and daily fields', () {
      final deal = DealGenerator.generateDailyDeal(
        DateTime(2026, 11, 23),
        DrawMode.draw3,
      );
      final movedBoard = SolitaireRules.applyMove(
        deal.board,
        const SolitaireMove(kind: MoveKind.drawStock),
        DrawMode.draw3,
      );

      final original = GameState(
        board: movedBoard,
        drawMode: DrawMode.draw3,
        dealType: DealType.daily,
        dealSeed: deal.resolvedSeed,
        dailyDateKey: '2026-11-23',
        movesCount: 1,
        elapsedSeconds: 47,
        hasStarted: true,
        isWon: false,
        undoHistory: <BoardSnapshot>[deal.board, movedBoard],
        lastKnownSolvableHistoryIndex: 0,
      );

      final encoded = jsonEncode(original.toJson());
      final decoded = GameState.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded, equals(original));
      expect(decoded.undoHistory.length, 2);
      expect(decoded.dailyDateKey, '2026-11-23');
      expect(decoded.lastKnownSolvableHistoryIndex, 0);
    });
  });
}
