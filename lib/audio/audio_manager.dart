import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../settings.dart';

enum Music { menu, run }

enum Sfx {
  coin,
  jump,
  roll,
  swipe,
  crash,
  powerup,
  gem,
  letter,
  shieldBreak,
  mission,
  click,
  tick,
  go,
  jetpack,
  stumble,
  purchase,
}

/// Background music and sound effects. All audio is original and generated
/// by tools/generate_audio.py in Ethiopian qenet scales.
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  static const _musicFiles = {
    Music.menu: 'music/tezeta.mp3',
    Music.run: 'music/merkato_run.mp3',
  };

  static String _sfxFile(Sfx s) => switch (s) {
        Sfx.shieldBreak => 'sfx/shield_break.mp3',
        _ => 'sfx/${s.name}.mp3',
      };

  final Map<Sfx, AudioPool> _pools = {};
  Music? _current;
  bool _musicPaused = false;
  bool _ready = false;
  final GameSettings _settings = GameSettings.instance;

  Future<void> init() async {
    if (_ready) return;
    try {
      // Play nicely with other apps and never steal audio focus from our own
      // music when a sound effect fires.
      final ctx = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
        respectSilence: true,
      ).build();
      await AudioPlayer.global.setAudioContext(ctx);
      await FlameAudio.bgm.initialize(audioContext: ctx);
      for (final s in Sfx.values) {
        final many = s == Sfx.coin || s == Sfx.swipe || s == Sfx.jump;
        _pools[s] = await FlameAudio.createPool(
          _sfxFile(s),
          minPlayers: 1,
          maxPlayers: many ? 4 : 2,
          audioContext: ctx,
        );
      }
      _ready = true;
      _settings.addListener(_applyVolume);
      final pending = _current;
      _current = null;
      if (pending != null) await play(pending);
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  void _applyVolume() {
    if (!_ready) return;
    final v = _settings.musicVolume;
    FlameAudio.bgm.audioPlayer.setVolume(v);
    if (v <= 0.001 && FlameAudio.bgm.isPlaying) {
      FlameAudio.bgm.pause();
    } else if (v > 0.001 && !FlameAudio.bgm.isPlaying && _current != null && !_musicPaused) {
      FlameAudio.bgm.resume();
    }
  }

  Future<void> play(Music m) async {
    if (_current == m && (FlameAudio.bgm.isPlaying || _settings.musicVolume <= 0.001)) return;
    _current = m;
    _musicPaused = false;
    if (!_ready) return;
    try {
      await FlameAudio.bgm.play(_musicFiles[m]!, volume: _settings.musicVolume);
      if (_settings.musicVolume <= 0.001) await FlameAudio.bgm.pause();
    } catch (e) {
      debugPrint('Music error: $e');
    }
  }

  Future<void> pauseMusic() async {
    _musicPaused = true;
    if (_ready && FlameAudio.bgm.isPlaying) await FlameAudio.bgm.pause();
  }

  Future<void> resumeMusic() async {
    _musicPaused = false;
    if (_ready && _current != null && _settings.musicVolume > 0.001) {
      await FlameAudio.bgm.resume();
    }
  }

  void sfx(Sfx s, {double volume = 1}) {
    if (!_ready) return;
    final v = _settings.sfxVolume * volume;
    if (v <= 0.001) return;
    unawaited(_pools[s]?.start(volume: v).catchError((Object e) {
      debugPrint('SFX error: $e');
      return () async {};
    }));
  }
}
