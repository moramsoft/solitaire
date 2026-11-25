import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';

/// Persistence contract for zero-loss game saves, settings, and player stats.
abstract class PersistenceService {
  Future<GameState?> loadActiveGame();
  Future<void> saveActiveGame(GameState state);
  Future<void> clearActiveGame();

  Future<Map<String, dynamic>?> loadSettingsJson();
  Future<void> saveSettingsJson(Map<String, dynamic> json);

  Future<Map<String, dynamic>?> loadStatsJson();
  Future<void> saveStatsJson(Map<String, dynamic> json);

  Future<Set<String>> loadCompletedDailyDates();
  Future<void> saveCompletedDailyDates(Set<String> dates);

  Future<Map<String, dynamic>?> loadQuestsJson();
  Future<void> saveQuestsJson(Map<String, dynamic> json);
}

/// SharedPreferences-backed persistence used in production and tests with
/// `SharedPreferences.setMockInitialValues`.
class SharedPrefsPersistenceService implements PersistenceService {
  SharedPrefsPersistenceService(this._prefs);

  static const String _keyActiveGame = 'cleardeck_active_game_v1';
  static const String _keySettings = 'cleardeck_settings_v1';
  static const String _keyStats = 'cleardeck_stats_v1';
  static const String _keyDailyCompleted = 'cleardeck_daily_completed_v1';
  static const String _keyQuests = 'cleardeck_quests_v1';

  final SharedPreferences _prefs;

  @override
  Future<GameState?> loadActiveGame() async {
    final raw = _prefs.getString(_keyActiveGame);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return GameState.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveActiveGame(GameState state) async {
    await _prefs.setString(_keyActiveGame, jsonEncode(state.toJson()));
  }

  @override
  Future<void> clearActiveGame() async {
    await _prefs.remove(_keyActiveGame);
  }

  @override
  Future<Map<String, dynamic>?> loadSettingsJson() async {
    final raw = _prefs.getString(_keySettings);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSettingsJson(Map<String, dynamic> json) async {
    await _prefs.setString(_keySettings, jsonEncode(json));
  }

  @override
  Future<Map<String, dynamic>?> loadStatsJson() async {
    final raw = _prefs.getString(_keyStats);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveStatsJson(Map<String, dynamic> json) async {
    await _prefs.setString(_keyStats, jsonEncode(json));
  }

  @override
  Future<Set<String>> loadCompletedDailyDates() async {
    final list = _prefs.getStringList(_keyDailyCompleted);
    if (list == null) return <String>{};
    return list.toSet();
  }

  @override
  Future<void> saveCompletedDailyDates(Set<String> dates) async {
    final sorted = dates.toList()..sort();
    await _prefs.setStringList(_keyDailyCompleted, sorted);
  }

  @override
  Future<Map<String, dynamic>?> loadQuestsJson() async {
    final raw = _prefs.getString(_keyQuests);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveQuestsJson(Map<String, dynamic> json) async {
    await _prefs.setString(_keyQuests, jsonEncode(json));
  }
}

/// Lightweight in-memory persistence implementation for isolated unit tests.
class InMemoryPersistenceService implements PersistenceService {
  GameState? _activeGame;
  Map<String, dynamic>? _settings;
  Map<String, dynamic>? _stats;
  Set<String> _dailyDates = <String>{};
  Map<String, dynamic>? _quests;

  @override
  Future<GameState?> loadActiveGame() async => _activeGame;

  @override
  Future<void> saveActiveGame(GameState state) async {
    _activeGame = state;
  }

  @override
  Future<void> clearActiveGame() async {
    _activeGame = null;
  }

  @override
  Future<Map<String, dynamic>?> loadSettingsJson() async => _settings;

  @override
  Future<void> saveSettingsJson(Map<String, dynamic> json) async {
    _settings = Map<String, dynamic>.from(json);
  }

  @override
  Future<Map<String, dynamic>?> loadStatsJson() async => _stats;

  @override
  Future<void> saveStatsJson(Map<String, dynamic> json) async {
    _stats = Map<String, dynamic>.from(json);
  }

  @override
  Future<Set<String>> loadCompletedDailyDates() async =>
      Set<String>.from(_dailyDates);

  @override
  Future<void> saveCompletedDailyDates(Set<String> dates) async {
    _dailyDates = Set<String>.from(dates);
  }

  @override
  Future<Map<String, dynamic>?> loadQuestsJson() async => _quests;

  @override
  Future<void> saveQuestsJson(Map<String, dynamic> json) async {
    _quests = Map<String, dynamic>.from(json);
  }
}
