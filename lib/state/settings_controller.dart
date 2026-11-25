import 'package:flutter/foundation.dart';

import '../engine/move.dart';
import '../services/audio_service.dart';
import '../services/persistence_service.dart';
import '../theme/deck_palette.dart';

/// Immutable user preferences for gameplay, visual accessibility, and sound.
class AppSettings {
  const AppSettings({
    this.drawMode = DrawMode.draw1,
    this.preferredDealType = DealType.winnable,
    this.showTimer = false,
    this.fourColorDeck = false,
    this.cardScale = CardScale.large,
    this.leftHanded = false,
    this.tableTheme = TableThemeId.heritageGreen,
    this.deckFaceStyle = DeckFaceStyle.americanHeritage,
    this.cardBackStyle = CardBackStyle.crimsonLattice,
    this.sfxVolume = 0.7,
    this.bgmVolume = 0.0,
    this.tutorialCompleted = false,
    this.tutorialPromptDismissed = false,
  });

  final DrawMode drawMode;
  final DealType preferredDealType;
  final bool showTimer;
  final bool fourColorDeck;
  final CardScale cardScale;
  final bool leftHanded;
  final TableThemeId tableTheme;
  final DeckFaceStyle deckFaceStyle;
  final CardBackStyle cardBackStyle;
  final double sfxVolume;
  final double bgmVolume;
  final bool tutorialCompleted;
  final bool tutorialPromptDismissed;

  AppSettings copyWith({
    DrawMode? drawMode,
    DealType? preferredDealType,
    bool? showTimer,
    bool? fourColorDeck,
    CardScale? cardScale,
    bool? leftHanded,
    TableThemeId? tableTheme,
    DeckFaceStyle? deckFaceStyle,
    CardBackStyle? cardBackStyle,
    double? sfxVolume,
    double? bgmVolume,
    bool? tutorialCompleted,
    bool? tutorialPromptDismissed,
  }) {
    return AppSettings(
      drawMode: drawMode ?? this.drawMode,
      preferredDealType: preferredDealType ?? this.preferredDealType,
      showTimer: showTimer ?? this.showTimer,
      fourColorDeck: fourColorDeck ?? this.fourColorDeck,
      cardScale: cardScale ?? this.cardScale,
      leftHanded: leftHanded ?? this.leftHanded,
      tableTheme: tableTheme ?? this.tableTheme,
      deckFaceStyle: deckFaceStyle ?? this.deckFaceStyle,
      cardBackStyle: cardBackStyle ?? this.cardBackStyle,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      bgmVolume: bgmVolume ?? this.bgmVolume,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      tutorialPromptDismissed:
          tutorialPromptDismissed ?? this.tutorialPromptDismissed,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'drawMode': drawMode.name,
      'preferredDealType': preferredDealType.name,
      'showTimer': showTimer,
      'fourColorDeck': fourColorDeck,
      'cardScale': cardScale.name,
      'leftHanded': leftHanded,
      'tableTheme': tableTheme.name,
      'deckFaceStyle': deckFaceStyle.name,
      'cardBackStyle': cardBackStyle.name,
      'sfxVolume': sfxVolume,
      'bgmVolume': bgmVolume,
      'tutorialCompleted': tutorialCompleted,
      'tutorialPromptDismissed': tutorialPromptDismissed,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      drawMode: _enumByName(
        DrawMode.values,
        json['drawMode'] as String?,
        DrawMode.draw1,
      ),
      preferredDealType: _enumByName(
        DealType.values,
        json['preferredDealType'] as String?,
        DealType.winnable,
      ),
      showTimer: json['showTimer'] as bool? ?? false,
      fourColorDeck: json['fourColorDeck'] as bool? ?? false,
      cardScale: _enumByName(
        CardScale.values,
        json['cardScale'] as String?,
        CardScale.large,
      ),
      leftHanded: json['leftHanded'] as bool? ?? false,
      tableTheme: TableThemeId.parseOrFallback(json['tableTheme'] as String?),
      deckFaceStyle: _enumByName(
        DeckFaceStyle.values,
        json['deckFaceStyle'] as String?,
        DeckFaceStyle.americanHeritage,
      ),
      cardBackStyle: _enumByName(
        CardBackStyle.values,
        json['cardBackStyle'] as String?,
        CardBackStyle.crimsonLattice,
      ),
      sfxVolume: (json['sfxVolume'] as num?)?.toDouble() ?? 0.7,
      bgmVolume: (json['bgmVolume'] as num?)?.toDouble() ?? 0.0,
      tutorialCompleted: json['tutorialCompleted'] as bool? ?? false,
      tutorialPromptDismissed:
          json['tutorialPromptDismissed'] as bool? ?? false,
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// Manages and persists [AppSettings] with immediate updates.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required this._persistence,
    required this._audio,
  });

  final PersistenceService _persistence;
  final AudioService _audio;

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  Future<void> initialize() async {
    final json = await _persistence.loadSettingsJson();
    if (json != null) {
      _settings = AppSettings.fromJson(json);
    }
    await _audio.setVolumes(
      bgmVolume: _settings.bgmVolume,
      sfxVolume: _settings.sfxVolume,
    );
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings updated) async {
    _settings = updated;
    notifyListeners();
    await _audio.setVolumes(
      bgmVolume: updated.bgmVolume,
      sfxVolume: updated.sfxVolume,
    );
    await _persistence.saveSettingsJson(updated.toJson());
  }

  Future<void> setDrawMode(DrawMode mode) =>
      updateSettings(_settings.copyWith(drawMode: mode));

  Future<void> setPreferredDealType(DealType type) =>
      updateSettings(_settings.copyWith(preferredDealType: type));

  Future<void> setShowTimer(bool show) =>
      updateSettings(_settings.copyWith(showTimer: show));

  Future<void> setFourColorDeck(bool enabled) =>
      updateSettings(_settings.copyWith(fourColorDeck: enabled));

  Future<void> setCardScale(CardScale scale) =>
      updateSettings(_settings.copyWith(cardScale: scale));

  Future<void> setLeftHanded(bool leftHanded) =>
      updateSettings(_settings.copyWith(leftHanded: leftHanded));

  Future<void> setTableTheme(TableThemeId themeId) =>
      updateSettings(_settings.copyWith(tableTheme: themeId));

  Future<void> setDeckFaceStyle(DeckFaceStyle style) =>
      updateSettings(_settings.copyWith(deckFaceStyle: style));

  Future<void> setCardBackStyle(CardBackStyle style) =>
      updateSettings(_settings.copyWith(cardBackStyle: style));

  Future<void> setSfxVolume(double value) =>
      updateSettings(_settings.copyWith(sfxVolume: value.clamp(0.0, 1.0)));

  Future<void> setBgmVolume(double value) =>
      updateSettings(_settings.copyWith(bgmVolume: value.clamp(0.0, 1.0)));

  Future<void> setTutorialCompleted(bool completed) =>
      updateSettings(_settings.copyWith(tutorialCompleted: completed));

  Future<void> setTutorialPromptDismissed(bool dismissed) =>
      updateSettings(_settings.copyWith(tutorialPromptDismissed: dismissed));
}
