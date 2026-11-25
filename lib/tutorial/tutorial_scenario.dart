import '../engine/engine.dart';

/// Rule-matching expectation for the user's current interactive tutorial step.
class TutorialMoveExpectation {
  const TutorialMoveExpectation({
    required this.kind,
    this.fromPileIndex,
    this.toPileIndex,
    this.cardCount,
  });

  final MoveKind kind;
  final int? fromPileIndex;
  final int? toPileIndex;
  final int? cardCount;

  bool matches(SolitaireMove actual) {
    if (actual.kind != kind) return false;
    if (fromPileIndex != null && actual.fromPileIndex != fromPileIndex) {
      return false;
    }
    if (toPileIndex != null && actual.toPileIndex != toPileIndex) {
      return false;
    }
    if (cardCount != null && actual.cardCount != cardCount) {
      return false;
    }
    return true;
  }
}

/// A single guided interactive action inside a [TutorialLesson].
class TutorialSubStep {
  const TutorialSubStep({
    required this.prompt,
    required this.expectedMove,
    required this.highlightHintMove,
  });

  final String prompt;
  final TutorialMoveExpectation expectedMove;
  final SolitaireMove highlightHintMove;
}

/// Self-contained curated Klondike board scenario teaching one core rule.
class TutorialLesson {
  const TutorialLesson({
    required this.index,
    required this.title,
    required this.ruleSummary,
    required this.completionMessage,
    required this.initialBoard,
    required this.subSteps,
    this.triggersWinCelebration = false,
  });

  final int index;
  final String title;
  final String ruleSummary;
  final String completionMessage;
  final BoardSnapshot initialBoard;
  final List<TutorialSubStep> subSteps;
  final bool triggersWinCelebration;
}

/// Curated 6-lesson hands-on Klondike tutorial progression.
class TutorialCurriculum {
  const TutorialCurriculum._();

  static List<TutorialLesson> buildLessons() {
    return <TutorialLesson>[
      _lessonAlternatingColumns(),
      _lessonDrawFromStock(),
      _lessonMoveStackedRun(),
      _lessonKingInEmptySlot(),
      _lessonBuildFoundationFromAce(),
      _lessonFinalWinningMove(),
    ];
  }

  /// Resolves the live hint highlight for [subStep] against [board] so dynamic
  /// foundation destinations (like placing 2♠ onto wherever A♠ landed) always
  /// highlight the exact destination slot.
  static SolitaireMove resolveHighlightMove(
    TutorialSubStep subStep,
    BoardSnapshot board,
  ) {
    final base = subStep.highlightHintMove;
    if (base.kind == MoveKind.tableauToFoundation &&
        base.fromPileIndex != null) {
      final col = board.tableau[base.fromPileIndex!];
      if (col.isNotEmpty) {
        final destF = SolitaireRules.findFoundationDestination(
          col.last,
          board.foundations,
        );
        if (destF != null) {
          return SolitaireMove(
            kind: MoveKind.tableauToFoundation,
            fromPileIndex: base.fromPileIndex,
            toPileIndex: destF,
          );
        }
      }
    } else if (base.kind == MoveKind.wasteToFoundation &&
        board.waste.isNotEmpty) {
      final destF = SolitaireRules.findFoundationDestination(
        board.waste.last,
        board.foundations,
      );
      if (destF != null) {
        return SolitaireMove(
          kind: MoveKind.wasteToFoundation,
          toPileIndex: destF,
        );
      }
    }
    return base;
  }

  /// Returns respectful plain-English feedback explaining why an attempted move
  /// breaks Klondike rules or diverges from the guided lesson.
  static String diagnoseWrongAttempt({
    required TutorialLesson lesson,
    required TutorialSubStep subStep,
    PlayingCard? attemptedCard,
    List<PlayingCard>? targetTableauCol,
    List<PlayingCard>? targetFoundation,
  }) {
    if (attemptedCard == null) {
      return subStep.prompt;
    }

    if (!attemptedCard.isFaceUp) {
      return 'Face-down cards cannot be moved until the cards above them are cleared.';
    }

    if (targetFoundation != null) {
      if (targetFoundation.isEmpty && attemptedCard.rank != 1) {
        return 'Empty foundation slots only accept an Ace first (A → 2 → 3).';
      }
      if (targetFoundation.isNotEmpty) {
        final top = targetFoundation.last;
        if (top.suit != attemptedCard.suit) {
          return 'Foundations build in a matching suit (${top.suit.displayName} stays on ${top.suit.displayName}).';
        }
        if (attemptedCard.rank != top.rank + 1) {
          return 'Foundations build upward one rank at a time (next card needed is rank ${top.rank + 1}).';
        }
      }
    }

    if (targetTableauCol != null) {
      if (targetTableauCol.isEmpty && attemptedCard.rank != 13) {
        return 'Only a King (K) — or a stack led by a King — can move into an empty table slot.';
      }
      if (targetTableauCol.isNotEmpty && targetTableauCol.last.isFaceUp) {
        final targetTop = targetTableauCol.last;
        if (attemptedCard.suit.isRed == targetTop.suit.isRed) {
          return 'Table columns must alternate colors — place Red on Black, or Black on Red.';
        }
        if (attemptedCard.rank != targetTop.rank - 1) {
          return 'Cards on the table count downward by 1 rank (only rank ${targetTop.rank - 1} goes on ${targetTop.rankLabel}).';
        }
      }
    }

    return subStep.prompt;
  }

  static TutorialLesson _lessonAlternatingColumns() {
    final board = BoardSnapshot(
      stock: const <PlayingCard>[],
      waste: const <PlayingCard>[],
      foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
      tableau: <List<PlayingCard>>[
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.spades, rank: 7, isFaceUp: true),
        ],
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.diamonds, rank: 9, isFaceUp: true),
        ],
        const <PlayingCard>[
          PlayingCard(suit: Suit.hearts, rank: 6, isFaceUp: true),
        ],
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.clubs, rank: 4, isFaceUp: true),
        ],
      ],
    );

    return TutorialLesson(
      index: 0,
      title: 'Building alternating columns',
      ruleSummary:
          'On the seven table columns, cards stack downward by one rank and must alternate colors — Red on Black, or Black on Red.',
      completionMessage:
          'Nicely done — 6♥ rests cleanly on 7♠ because 6 is one below 7 and Red alternates with Black.',
      initialBoard: board,
      subSteps: const <TutorialSubStep>[
        TutorialSubStep(
          prompt: 'Tap or drag the Red 6♥ onto the Black 7♠.',
          expectedMove: TutorialMoveExpectation(
            kind: MoveKind.tableauToTableau,
            fromPileIndex: 4,
            toPileIndex: 1,
            cardCount: 1,
          ),
          highlightHintMove: SolitaireMove(
            kind: MoveKind.tableauToTableau,
            fromPileIndex: 4,
            toPileIndex: 1,
            cardCount: 1,
          ),
        ),
      ],
    );
  }

  static TutorialLesson _lessonDrawFromStock() {
    final board = BoardSnapshot(
      stock: const <PlayingCard>[
        PlayingCard(suit: Suit.diamonds, rank: 9, isFaceUp: false),
        PlayingCard(suit: Suit.clubs, rank: 12, isFaceUp: false),
        PlayingCard(suit: Suit.spades, rank: 3, isFaceUp: false),
        PlayingCard(suit: Suit.clubs, rank: 5, isFaceUp: false),
      ],
      waste: const <PlayingCard>[],
      foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
      tableau: <List<PlayingCard>>[
        const <PlayingCard>[],
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.spades, rank: 7, isFaceUp: true),
          PlayingCard(suit: Suit.hearts, rank: 6, isFaceUp: true),
        ],
        const <PlayingCard>[],
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.diamonds, rank: 10, isFaceUp: true),
        ],
        const <PlayingCard>[],
      ],
    );

    return TutorialLesson(
      index: 1,
      title: 'Drawing from the stock deck',
      ruleSummary:
          'When no direct table move is open, tap the face-down Stock pile in the top corner to turn over fresh cards to play.',
      completionMessage:
          'Good eye — you uncovered 5♣ from the Stock deck and played it right onto 6♥.',
      initialBoard: board,
      subSteps: const <TutorialSubStep>[
        TutorialSubStep(
          prompt: 'Step 1: Tap the face-down Stock pile to turn over a card.',
          expectedMove: TutorialMoveExpectation(kind: MoveKind.drawStock),
          highlightHintMove: SolitaireMove(kind: MoveKind.drawStock),
        ),
        TutorialSubStep(
          prompt: 'Step 2: Move the revealed Black 5♣ onto the Red 6♥.',
          expectedMove: TutorialMoveExpectation(
            kind: MoveKind.wasteToTableau,
            toPileIndex: 2,
          ),
          highlightHintMove: SolitaireMove(
            kind: MoveKind.wasteToTableau,
            toPileIndex: 2,
          ),
        ),
      ],
    );
  }

  static TutorialLesson _lessonMoveStackedRun() {
    final board = BoardSnapshot(
      stock: const <PlayingCard>[],
      waste: const <PlayingCard>[],
      foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
      tableau: <List<PlayingCard>>[
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.clubs, rank: 9, isFaceUp: false),
          PlayingCard(suit: Suit.hearts, rank: 6, isFaceUp: true),
          PlayingCard(suit: Suit.clubs, rank: 5, isFaceUp: true),
          PlayingCard(suit: Suit.diamonds, rank: 4, isFaceUp: true),
        ],
        const <PlayingCard>[],
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.diamonds, rank: 8, isFaceUp: true),
          PlayingCard(suit: Suit.spades, rank: 7, isFaceUp: true),
        ],
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.hearts, rank: 10, isFaceUp: true),
        ],
      ],
    );

    return TutorialLesson(
      index: 2,
      title: 'Moving stacked sequences together',
      ruleSummary:
          'An ordered face-up run moves together as one stack. Lifting a stack off a face-down card turns that hidden card face-up automatically.',
      completionMessage:
          'Well played — all three cards moved as one stack onto 7♠, revealing the hidden 9♣ underneath.',
      initialBoard: board,
      subSteps: const <TutorialSubStep>[
        TutorialSubStep(
          prompt: 'Tap or drag from 6♥ to move [6♥ · 5♣ · 4♦] together onto 7♠.',
          expectedMove: TutorialMoveExpectation(
            kind: MoveKind.tableauToTableau,
            fromPileIndex: 1,
            toPileIndex: 4,
            cardCount: 3,
          ),
          highlightHintMove: SolitaireMove(
            kind: MoveKind.tableauToTableau,
            fromPileIndex: 1,
            toPileIndex: 4,
            cardCount: 3,
          ),
        ),
      ],
    );
  }

  static TutorialLesson _lessonKingInEmptySlot() {
    final board = BoardSnapshot(
      stock: const <PlayingCard>[],
      waste: const <PlayingCard>[],
      foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
      tableau: <List<PlayingCard>>[
        const <PlayingCard>[
          PlayingCard(suit: Suit.hearts, rank: 9, isFaceUp: true),
        ],
        const <PlayingCard>[],
        const <PlayingCard>[],
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.clubs, rank: 11, isFaceUp: false),
          PlayingCard(suit: Suit.diamonds, rank: 13, isFaceUp: true),
          PlayingCard(suit: Suit.spades, rank: 12, isFaceUp: true),
        ],
        const <PlayingCard>[],
        const <PlayingCard>[],
      ],
    );

    return TutorialLesson(
      index: 3,
      title: 'Filling empty spaces with a King',
      ruleSummary:
          'Empty columns show a K slot because only a King — or a face-up stack led by a King — may fill an empty column.',
      completionMessage:
          'Exact rule — moving the King stack opened the space while flipping J♣ face-up.',
      initialBoard: board,
      subSteps: const <TutorialSubStep>[
        TutorialSubStep(
          prompt: 'Move K♦ (with Q♠ attached) into the empty K column slot.',
          expectedMove: TutorialMoveExpectation(
            kind: MoveKind.tableauToTableau,
            fromPileIndex: 4,
            cardCount: 2,
          ),
          highlightHintMove: SolitaireMove(
            kind: MoveKind.tableauToTableau,
            fromPileIndex: 4,
            toPileIndex: 2,
            cardCount: 2,
          ),
        ),
      ],
    );
  }

  static TutorialLesson _lessonBuildFoundationFromAce() {
    final board = BoardSnapshot(
      stock: const <PlayingCard>[],
      waste: const <PlayingCard>[],
      foundations: List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]),
      tableau: <List<PlayingCard>>[
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.diamonds, rank: 4, isFaceUp: false),
          PlayingCard(suit: Suit.spades, rank: 1, isFaceUp: true),
        ],
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.spades, rank: 2, isFaceUp: true),
        ],
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.hearts, rank: 3, isFaceUp: true),
        ],
        const <PlayingCard>[],
      ],
    );

    return TutorialLesson(
      index: 4,
      title: 'Building Foundations from Ace up',
      ruleSummary:
          'The four A slots at the top are your Foundations. Each starts with an Ace and builds upward in the exact same suit (A → 2 → 3 → … → K).',
      completionMessage:
          'Clear progress — Aces begin each Foundation and matching suits stack upward to King.',
      initialBoard: board,
      subSteps: const <TutorialSubStep>[
        TutorialSubStep(
          prompt: 'Step 1: Move A♠ up to any empty A Foundation slot.',
          expectedMove: TutorialMoveExpectation(
            kind: MoveKind.tableauToFoundation,
            fromPileIndex: 1,
          ),
          highlightHintMove: SolitaireMove(
            kind: MoveKind.tableauToFoundation,
            fromPileIndex: 1,
            toPileIndex: 0,
          ),
        ),
        TutorialSubStep(
          prompt: 'Step 2: Now place 2♠ on top of A♠ in that same Foundation.',
          expectedMove: TutorialMoveExpectation(
            kind: MoveKind.tableauToFoundation,
            fromPileIndex: 3,
          ),
          highlightHintMove: SolitaireMove(
            kind: MoveKind.tableauToFoundation,
            fromPileIndex: 3,
            toPileIndex: 0,
          ),
        ),
      ],
    );
  }

  static TutorialLesson _lessonFinalWinningMove() {
    List<PlayingCard> fullSuit(Suit suit, {int upTo = 13}) {
      return List<PlayingCard>.generate(
        upTo,
        (i) => PlayingCard(suit: suit, rank: i + 1, isFaceUp: true),
      );
    }

    final board = BoardSnapshot(
      stock: const <PlayingCard>[],
      waste: const <PlayingCard>[],
      foundations: <List<PlayingCard>>[
        fullSuit(Suit.spades, upTo: 13),
        fullSuit(Suit.diamonds, upTo: 13),
        fullSuit(Suit.clubs, upTo: 13),
        fullSuit(Suit.hearts, upTo: 12),
      ],
      tableau: <List<PlayingCard>>[
        const <PlayingCard>[],
        const <PlayingCard>[],
        const <PlayingCard>[],
        const <PlayingCard>[
          PlayingCard(suit: Suit.hearts, rank: 13, isFaceUp: true),
        ],
        const <PlayingCard>[],
        const <PlayingCard>[],
        const <PlayingCard>[],
      ],
    );

    return TutorialLesson(
      index: 5,
      title: 'Finishing the final hand',
      ruleSummary:
          'Once all 52 cards reach the four Foundations up to their Kings, the hand is complete. Play the final card below to see how a victory finishes.',
      completionMessage:
          'Hand complete — you now know every core rule of Klondike Solitaire.',
      initialBoard: board,
      triggersWinCelebration: true,
      subSteps: const <TutorialSubStep>[
        TutorialSubStep(
          prompt: 'Place the final King of Hearts (K♥) onto Q♥ at the top.',
          expectedMove: TutorialMoveExpectation(
            kind: MoveKind.tableauToFoundation,
            fromPileIndex: 3,
            toPileIndex: 3,
          ),
          highlightHintMove: SolitaireMove(
            kind: MoveKind.tableauToFoundation,
            fromPileIndex: 3,
            toPileIndex: 3,
          ),
        ),
      ],
    );
  }
}
