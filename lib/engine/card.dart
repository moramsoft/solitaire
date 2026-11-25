/// Suit of a standard 52-card playing deck.
enum Suit {
  spades,
  hearts,
  diamonds,
  clubs;

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;

  String get symbol {
    switch (this) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  String get shortCode {
    switch (this) {
      case Suit.spades:
        return 'S';
      case Suit.hearts:
        return 'H';
      case Suit.diamonds:
        return 'D';
      case Suit.clubs:
        return 'C';
    }
  }

  String get displayName {
    switch (this) {
      case Suit.spades:
        return 'Spades';
      case Suit.hearts:
        return 'Hearts';
      case Suit.diamonds:
        return 'Diamonds';
      case Suit.clubs:
        return 'Clubs';
    }
  }

  static Suit fromShortCode(String code) {
    switch (code) {
      case 'S':
        return Suit.spades;
      case 'H':
        return Suit.hearts;
      case 'D':
        return Suit.diamonds;
      case 'C':
        return Suit.clubs;
      default:
        return Suit.values.byName(code);
    }
  }
}

/// Immutable representation of a playing card.
class PlayingCard {
  const PlayingCard({
    required this.suit,
    required this.rank,
    this.isFaceUp = false,
  }) : assert(rank >= 1 && rank <= 13, 'Rank must be between 1 and 13.');

  final Suit suit;
  final int rank;
  final bool isFaceUp;

  String get rankLabel {
    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return '$rank';
    }
  }

  /// Compact key encoding suit, rank, and visibility.
  String get shortKey => '${suit.shortCode}$rank${isFaceUp ? 'u' : 'd'}';

  /// Compact key encoding suit and rank only.
  String get identityKey => '${suit.shortCode}$rank';

  PlayingCard copyWith({
    Suit? suit,
    int? rank,
    bool? isFaceUp,
  }) {
    return PlayingCard(
      suit: suit ?? this.suit,
      rank: rank ?? this.rank,
      isFaceUp: isFaceUp ?? this.isFaceUp,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      's': suit.shortCode,
      'r': rank,
      'u': isFaceUp,
    };
  }

  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(
      suit: Suit.fromShortCode(json['s'] as String),
      rank: (json['r'] as num).toInt(),
      isFaceUp: json['u'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayingCard &&
        other.suit == suit &&
        other.rank == rank &&
        other.isFaceUp == isFaceUp;
  }

  @override
  int get hashCode => Object.hash(suit, rank, isFaceUp);

  @override
  String toString() => '$rankLabel${suit.symbol}${isFaceUp ? '' : '(down)'}';
}
