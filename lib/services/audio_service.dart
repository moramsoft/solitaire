import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Audio service contract supporting independent BGM/SFX sliders and strict
/// lifecycle teardown when the app leaves the foreground.
abstract class AudioService {
  double get bgmVolume;
  double get sfxVolume;
  bool get isPaused;

  Future<void> setVolumes({double? bgmVolume, double? sfxVolume});
  Future<void> pauseAll();
  Future<void> resumeIfEnabled();

  void playCardMove();
  void playCardFlip();
  void playFoundationPlace();
  void playWin();
}

/// Lightweight audio & haptic implementation used in headless unit/widget tests.
class LightweightAudioService implements AudioService {
  double _bgmVolume = 0.0;
  double _sfxVolume = 0.7;
  bool _isPaused = false;

  @override
  double get bgmVolume => _bgmVolume;

  @override
  double get sfxVolume => _sfxVolume;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> setVolumes({double? bgmVolume, double? sfxVolume}) async {
    if (bgmVolume != null) {
      _bgmVolume = bgmVolume.clamp(0.0, 1.0);
    }
    if (sfxVolume != null) {
      _sfxVolume = sfxVolume.clamp(0.0, 1.0);
    }
  }

  @override
  Future<void> pauseAll() async {
    _isPaused = true;
  }

  @override
  Future<void> resumeIfEnabled() async {
    _isPaused = false;
  }

  @override
  void playCardMove() {
    if (_isPaused || _sfxVolume <= 0.01) return;
    _safeFeedback(light: true);
  }

  @override
  void playCardFlip() {
    if (_isPaused || _sfxVolume <= 0.01) return;
    _safeFeedback(light: true);
  }

  @override
  void playFoundationPlace() {
    if (_isPaused || _sfxVolume <= 0.01) return;
    _safeFeedback(light: true);
  }

  @override
  void playWin() {
    if (_isPaused || _sfxVolume <= 0.01) return;
    _safeFeedback(light: false);
  }

  void _safeFeedback({required bool light}) {
    try {
      if (light) {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // Safe no-op in headless test or desktop contexts.
    }
  }
}

/// Production tactile ASMR audio implementation backed by `audioplayers`.
/// Strictly stops/pauses all players on backgrounding so audio never leaks.
class AssetAudioService implements AudioService {
  AssetAudioService() {
    _configurePlayer(_movePlayer);
    _configurePlayer(_flipPlayer);
    _configurePlayer(_chimePlayer);
    _configurePlayer(_winPlayer);
  }

  final AudioPlayer _movePlayer = AudioPlayer(playerId: 'sfx_move');
  final AudioPlayer _flipPlayer = AudioPlayer(playerId: 'sfx_flip');
  final AudioPlayer _chimePlayer = AudioPlayer(playerId: 'sfx_chime');
  final AudioPlayer _winPlayer = AudioPlayer(playerId: 'sfx_win');

  double _bgmVolume = 0.0;
  double _sfxVolume = 0.7;
  bool _isPaused = false;

  void _configurePlayer(AudioPlayer player) {
    unawaited(player.setReleaseMode(ReleaseMode.stop).catchError((_) {}));
    unawaited(player.setPlayerMode(PlayerMode.lowLatency).catchError((_) {}));
    unawaited(player.setVolume(_sfxVolume).catchError((_) {}));
  }

  @override
  double get bgmVolume => _bgmVolume;

  @override
  double get sfxVolume => _sfxVolume;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> setVolumes({double? bgmVolume, double? sfxVolume}) async {
    if (bgmVolume != null) {
      _bgmVolume = bgmVolume.clamp(0.0, 1.0);
    }
    if (sfxVolume != null) {
      _sfxVolume = sfxVolume.clamp(0.0, 1.0);
      for (final p in <AudioPlayer>[
        _movePlayer,
        _flipPlayer,
        _chimePlayer,
        _winPlayer,
      ]) {
        try {
          await p.setVolume(_sfxVolume);
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> pauseAll() async {
    _isPaused = true;
    for (final p in <AudioPlayer>[
      _movePlayer,
      _flipPlayer,
      _chimePlayer,
      _winPlayer,
    ]) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }

  @override
  Future<void> resumeIfEnabled() async {
    _isPaused = false;
  }

  @override
  void playCardMove() {
    if (_isPaused || _sfxVolume <= 0.01) return;
    _playAsset(_movePlayer, 'audio/card_slide.wav', lightHaptic: true);
  }

  @override
  void playCardFlip() {
    if (_isPaused || _sfxVolume <= 0.01) return;
    _playAsset(_flipPlayer, 'audio/card_flip.wav', lightHaptic: true);
  }

  @override
  void playFoundationPlace() {
    if (_isPaused || _sfxVolume <= 0.01) return;
    _playAsset(_chimePlayer, 'audio/foundation_chime.wav', lightHaptic: true);
  }

  @override
  void playWin() {
    if (_isPaused || _sfxVolume <= 0.01) return;
    _playAsset(_winPlayer, 'audio/win_fanfare.wav', lightHaptic: false);
  }

  void _playAsset(
    AudioPlayer player,
    String assetPath, {
    required bool lightHaptic,
  }) {
    unawaited(() async {
      try {
        await player.stop();
        await player.play(AssetSource(assetPath));
      } catch (_) {}
    }());
    try {
      if (lightHaptic) {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }
}
