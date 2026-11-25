/// Number of cards drawn from stock per tap.
enum DrawMode {
  draw1,
  draw3;

  int get drawCount => this == DrawMode.draw1 ? 1 : 3;

  String get label => this == DrawMode.draw1 ? 'Draw 1' : 'Draw 3';
}

/// Strategy used to create the current deal.
enum DealType {
  winnable,
  random,
  daily;

  String get label {
    switch (this) {
      case DealType.winnable:
        return 'Winnable';
      case DealType.random:
        return 'Classic Random';
      case DealType.daily:
        return 'Daily Challenge';
    }
  }
}

/// Kind of legal Klondike move.
enum MoveKind {
  drawStock,
  recycleStock,
  wasteToFoundation,
  wasteToTableau,
  tableauToFoundation,
  tableauToTableau,
  foundationToTableau,
}

/// Immutable descriptor for a single Klondike move.
class SolitaireMove {
  const SolitaireMove({
    required this.kind,
    this.fromPileIndex,
    this.toPileIndex,
    this.cardCount = 1,
    this.priority = 0,
  });

  final MoveKind kind;
  final int? fromPileIndex;
  final int? toPileIndex;
  final int cardCount;
  final int priority;

  SolitaireMove withPriority(int newPriority) {
    return SolitaireMove(
      kind: kind,
      fromPileIndex: fromPileIndex,
      toPileIndex: toPileIndex,
      cardCount: cardCount,
      priority: newPriority,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SolitaireMove &&
        other.kind == kind &&
        other.fromPileIndex == fromPileIndex &&
        other.toPileIndex == toPileIndex &&
        other.cardCount == cardCount;
  }

  @override
  int get hashCode =>
      Object.hash(kind, fromPileIndex, toPileIndex, cardCount);

  @override
  String toString() =>
      'SolitaireMove($kind, from=$fromPileIndex, to=$toPileIndex, count=$cardCount)';
}
