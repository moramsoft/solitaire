import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../services/persistence_service.dart';

/// Immutable personal statistics summary.
class PlayerStats {
  const PlayerStats({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.bestMoves,
    this.bestTimeSeconds,
  });

  final int gamesPlayed;
  final int gamesWon;
  final int currentStreak;
  final int bestStreak;
  final int? bestMoves;
  final int? bestTimeSeconds;

  double get winRatePercent {
    if (gamesPlayed <= 0) return 0;
    return (gamesWon / gamesPlayed) * 100.0;
  }

  PlayerStats copyWith({
    int? gamesPlayed,
    int? gamesWon,
    int? currentStreak,
    int? bestStreak,
    int? bestMoves,
    int? bestTimeSeconds,
  }) {
    return PlayerStats(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      bestMoves: bestMoves ?? this.bestMoves,
      bestTimeSeconds: bestTimeSeconds ?? this.bestTimeSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'bestMoves': bestMoves,
      'bestTimeSeconds': bestTimeSeconds,
    };
  }

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
      gamesWon: (json['gamesWon'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
      bestMoves: (json['bestMoves'] as num?)?.toInt(),
      bestTimeSeconds: (json['bestTimeSeconds'] as num?)?.toInt(),
    );
  }
}

/// Manages personal Klondike stats and offline daily calendar completions.
class StatsController extends ChangeNotifier {
  StatsController({required this._persistence});

  final PersistenceService _persistence;

  PlayerStats _stats = const PlayerStats();
  Set<String> _completedDailyDates = <String>{};

  PlayerStats get stats => _stats;
  Set<String> get completedDailyDates =>
      Set<String>.unmodifiable(_completedDailyDates);

  bool isDailyCompleted(String dateKey) =>
      _completedDailyDates.contains(dateKey);

  Future<void> initialize() async {
    final json = await _persistence.loadStatsJson();
    if (json != null) {
      _stats = PlayerStats.fromJson(json);
    }
    _completedDailyDates = await _persistence.loadCompletedDailyDates();
    notifyListeners();
  }

  Future<void> recordGameStarted() async {
    _stats = _stats.copyWith(gamesPlayed: _stats.gamesPlayed + 1);
    notifyListeners();
    await _persistence.saveStatsJson(_stats.toJson());
  }

  Future<void> recordAbandonedGame() async {
    if (_stats.currentStreak == 0) return;
    _stats = _stats.copyWith(currentStreak: 0);
    notifyListeners();
    await _persistence.saveStatsJson(_stats.toJson());
  }

  Future<void> recordWin({
    required int moves,
    required int elapsedSeconds,
    String? dailyDateKey,
  }) async {
    final nextStreak = _stats.currentStreak + 1;
    final nextBestStreak = math.max(_stats.bestStreak, nextStreak);
    final nextBestMoves = _stats.bestMoves == null
        ? moves
        : math.min(_stats.bestMoves!, moves);
    final nextBestTime = _stats.bestTimeSeconds == null
        ? elapsedSeconds
        : math.min(_stats.bestTimeSeconds!, elapsedSeconds);

    _stats = _stats.copyWith(
      gamesWon: _stats.gamesWon + 1,
      currentStreak: nextStreak,
      bestStreak: nextBestStreak,
      bestMoves: nextBestMoves,
      bestTimeSeconds: nextBestTime,
    );

    if (dailyDateKey != null) {
      _completedDailyDates = <String>{..._completedDailyDates, dailyDateKey};
      await _persistence.saveCompletedDailyDates(_completedDailyDates);
    }

    notifyListeners();
    await _persistence.saveStatsJson(_stats.toJson());
  }

  Future<void> resetStats() async {
    _stats = const PlayerStats();
    notifyListeners();
    await _persistence.saveStatsJson(_stats.toJson());
  }
}
