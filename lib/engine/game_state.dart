import 'card.dart';
import 'move.dart';

/// Immutable snapshot of all Klondike card piles.
class BoardSnapshot {
  BoardSnapshot({
    required List<PlayingCard> stock,
    required List<PlayingCard> waste,
    required List<List<PlayingCard>> foundations,
    required List<List<PlayingCard>> tableau,
  })  : assert(foundations.length == 4, 'Foundations must have 4 piles.'),
        assert(tableau.length == 7, 'Tableau must have 7 columns.'),
        stock = List<PlayingCard>.unmodifiable(stock),
        waste = List<PlayingCard>.unmodifiable(waste),
        foundations = List<List<PlayingCard>>.unmodifiable(
          foundations.map((f) => List<PlayingCard>.unmodifiable(f)),
        ),
        tableau = List<List<PlayingCard>>.unmodifiable(
          tableau.map((c) => List<PlayingCard>.unmodifiable(c)),
        );

  final List<PlayingCard> stock;
  final List<PlayingCard> waste;
  final List<List<PlayingCard>> foundations;
  final List<List<PlayingCard>> tableau;

  /// Creates mutable deep copies of all lists for fast rule application.
  ({
    List<PlayingCard> stock,
    List<PlayingCard> waste,
    List<List<PlayingCard>> foundations,
    List<List<PlayingCard>> tableau,
  }) cloneMutable() {
    return (
      stock: List<PlayingCard>.of(stock),
      waste: List<PlayingCard>.of(waste),
      foundations: foundations.map((f) => List<PlayingCard>.of(f)).toList(),
      tableau: tableau.map((c) => List<PlayingCard>.of(c)).toList(),
    );
  }

  /// Total cards currently placed in foundations.
  int get foundationCardCount {
    var total = 0;
    for (final pile in foundations) {
      total += pile.length;
    }
    return total;
  }

  /// Number of hidden (face-down) cards still in the tableau.
  int get tableauFaceDownCount {
    var total = 0;
    for (final col in tableau) {
      for (final card in col) {
        if (!card.isFaceUp) total++;
      }
    }
    return total;
  }

  /// Canonical board signature used by the solver to prune duplicate states.
  /// Empty and suit-assigned foundation slots are sorted canonically so
  /// placing an Ace in slot 0 vs slot 1 hashes identically.
  String canonicalKey() {
    final buf = StringBuffer();
    for (var i = 0; i < stock.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(stock[i].identityKey);
    }
    buf.write('|');
    for (var i = 0; i < waste.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(waste[i].identityKey);
    }
    buf.write('|');
    final fKeys = foundations.map((f) {
      if (f.isEmpty) return '_';
      return '${f.last.suit.shortCode}${f.length}';
    }).toList()
      ..sort();
    buf.write(fKeys.join(','));
    buf.write('|');
    for (var c = 0; c < 7; c++) {
      if (c > 0) buf.write(';');
      final col = tableau[c];
      for (var r = 0; r < col.length; r++) {
        if (r > 0) buf.write(',');
        buf.write(col[r].shortKey);
      }
    }
    return buf.toString();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stock': stock.map((c) => c.toJson()).toList(),
      'waste': waste.map((c) => c.toJson()).toList(),
      'foundations': foundations
          .map((pile) => pile.map((c) => c.toJson()).toList())
          .toList(),
      'tableau':
          tableau.map((col) => col.map((c) => c.toJson()).toList()).toList(),
    };
  }

  factory BoardSnapshot.fromJson(Map<String, dynamic> json) {
    List<PlayingCard> decodePile(dynamic raw) {
      return (raw as List<dynamic>)
          .map((item) => PlayingCard.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return BoardSnapshot(
      stock: decodePile(json['stock']),
      waste: decodePile(json['waste']),
      foundations: (json['foundations'] as List<dynamic>)
          .map(decodePile)
          .toList(),
      tableau: (json['tableau'] as List<dynamic>).map(decodePile).toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BoardSnapshot) return false;
    if (!_listEquals(stock, other.stock) || !_listEquals(waste, other.waste)) {
      return false;
    }
    for (var i = 0; i < 4; i++) {
      if (!_listEquals(foundations[i], other.foundations[i])) return false;
    }
    for (var i = 0; i < 7; i++) {
      if (!_listEquals(tableau[i], other.tableau[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(stock),
        Object.hashAll(waste),
        Object.hashAll(foundations.map(Object.hashAll)),
        Object.hashAll(tableau.map(Object.hashAll)),
      );
}

/// Complete active game session state persisted after every move.
class GameState {
  GameState({
    required this.board,
    required this.drawMode,
    required this.dealType,
    required this.dealSeed,
    this.dailyDateKey,
    this.movesCount = 0,
    this.elapsedSeconds = 0,
    this.hasStarted = false,
    this.isWon = false,
    List<BoardSnapshot>? undoHistory,
    this.lastKnownSolvableHistoryIndex,
  }) : undoHistory = List<BoardSnapshot>.unmodifiable(
          undoHistory ?? <BoardSnapshot>[board],
        );

  final BoardSnapshot board;
  final DrawMode drawMode;
  final DealType dealType;
  final int dealSeed;
  final String? dailyDateKey;
  final int movesCount;
  final int elapsedSeconds;
  final bool hasStarted;
  final bool isWon;
  final List<BoardSnapshot> undoHistory;
  final int? lastKnownSolvableHistoryIndex;

  bool get canUndo => undoHistory.length > 1;

  GameState copyWith({
    BoardSnapshot? board,
    DrawMode? drawMode,
    DealType? dealType,
    int? dealSeed,
    String? dailyDateKey,
    bool clearDailyDateKey = false,
    int? movesCount,
    int? elapsedSeconds,
    bool? hasStarted,
    bool? isWon,
    List<BoardSnapshot>? undoHistory,
    int? lastKnownSolvableHistoryIndex,
    bool clearLastKnownSolvableHistoryIndex = false,
  }) {
    return GameState(
      board: board ?? this.board,
      drawMode: drawMode ?? this.drawMode,
      dealType: dealType ?? this.dealType,
      dealSeed: dealSeed ?? this.dealSeed,
      dailyDateKey:
          clearDailyDateKey ? null : (dailyDateKey ?? this.dailyDateKey),
      movesCount: movesCount ?? this.movesCount,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      hasStarted: hasStarted ?? this.hasStarted,
      isWon: isWon ?? this.isWon,
      undoHistory: undoHistory ?? this.undoHistory,
      lastKnownSolvableHistoryIndex: clearLastKnownSolvableHistoryIndex
          ? null
          : (lastKnownSolvableHistoryIndex ??
              this.lastKnownSolvableHistoryIndex),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'board': board.toJson(),
      'drawMode': drawMode.name,
      'dealType': dealType.name,
      'dealSeed': dealSeed,
      'dailyDateKey': dailyDateKey,
      'movesCount': movesCount,
      'elapsedSeconds': elapsedSeconds,
      'hasStarted': hasStarted,
      'isWon': isWon,
      'undoHistory': undoHistory.map((b) => b.toJson()).toList(),
      'lastKnownSolvableHistoryIndex': lastKnownSolvableHistoryIndex,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      board: BoardSnapshot.fromJson(json['board'] as Map<String, dynamic>),
      drawMode: DrawMode.values.byName(json['drawMode'] as String),
      dealType: DealType.values.byName(json['dealType'] as String),
      dealSeed: (json['dealSeed'] as num).toInt(),
      dailyDateKey: json['dailyDateKey'] as String?,
      movesCount: (json['movesCount'] as num?)?.toInt() ?? 0,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      hasStarted: json['hasStarted'] as bool? ?? false,
      isWon: json['isWon'] as bool? ?? false,
      undoHistory: (json['undoHistory'] as List<dynamic>)
          .map((item) => BoardSnapshot.fromJson(item as Map<String, dynamic>))
          .toList(),
      lastKnownSolvableHistoryIndex:
          (json['lastKnownSolvableHistoryIndex'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameState &&
        other.board == board &&
        other.drawMode == drawMode &&
        other.dealType == dealType &&
        other.dealSeed == dealSeed &&
        other.dailyDateKey == dailyDateKey &&
        other.movesCount == movesCount &&
        other.elapsedSeconds == elapsedSeconds &&
        other.hasStarted == hasStarted &&
        other.isWon == isWon &&
        _listEquals(other.undoHistory, undoHistory) &&
        other.lastKnownSolvableHistoryIndex == lastKnownSolvableHistoryIndex;
  }

  @override
  int get hashCode => Object.hash(
        board,
        drawMode,
        dealType,
        dealSeed,
        dailyDateKey,
        movesCount,
        elapsedSeconds,
        hasStarted,
        isWon,
        Object.hashAll(undoHistory),
        lastKnownSolvableHistoryIndex,
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
