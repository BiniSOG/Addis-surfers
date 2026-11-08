import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';

import '../settings.dart';

/// Which version of the soundtrack is playing. All versions share the same
/// timeline, so switching between them keeps the beat.
enum MusicMode {
  /// Muffled, "from the next room" - menus and results.
  menu,

  /// The full track - running.
  run,

  /// Shimmering phaser - coin magnet active.
  magnet,

  /// Heavy bass - super-jump shoes active.
  shoes,

  /// Airy and echoing - jetpack / head start.
  fly,
}

enum Sfx {
  coin,
  jump,
  superJump,
  roll,
  land,
  swipe,
  crash,
  tapeStop,
  powerup,
  magnet,
  fly,
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
  bleat,
  spinTick,
  boxOpen,
  flower,
}

/// Adaptive background music and sound effects.
///
/// Music uses two players: when the mode changes (e.g. the magnet starts),
/// the idle player loads that version of the song at the current position
/// and the two crossfade, so the music morphs instead of restarting.
class AudioManager with WidgetsBindingObserver {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  static const _musicFiles = {
    MusicMode.menu: 'music/groove_menu.m4a',
    MusicMode.run: 'music/groove.m4a',
    MusicMode.magnet: 'music/groove_magnet.m4a',
    MusicMode.shoes: 'music/groove_shoes.m4a',
    MusicMode.fly: 'music/groove_fly.m4a',
  };

  /// Relative loudness of each version (the menu sits further back).
  static const _modeGain = {
    MusicMode.menu: 0.75,
    MusicMode.run: 1.0,
    MusicMode.magnet: 1.0,
    MusicMode.shoes: 1.0,
    MusicMode.fly: 0.95,
  };

  static String _sfxFile(Sfx s) => switch (s) {
        Sfx.shieldBreak => 'sfx/shield_break.mp3',
        Sfx.spinTick => 'sfx/spin_tick.mp3',
        Sfx.boxOpen => 'sfx/box_open.mp3',
        Sfx.superJump => 'sfx/super_jump.mp3',
        Sfx.tapeStop => 'sfx/tape_stop.mp3',
        _ => 'sfx/${s.name}.mp3',
      };

  final Map<Sfx, AudioPool> _pools = {};
  final GameSettings _settings = GameSettings.instance;
  late final List<AudioPlayer> _players;
  int _active = 0;
  MusicMode? _mode;
  bool _ready = false;
  bool _musicPaused = false;
  bool _appBackground = false;
  double _duck = 1;
  Timer? _fadeTimer;
  Timer? _duckTimer;
  Future<void> _queue = Future.value();

  AudioPlayer get _current => _players[_active];
  AudioPlayer get _other => _players[1 - _active];

  double _volumeFor(MusicMode m) => _settings.musicVolume * (_modeGain[m] ?? 1) * _duck;

  Future<void> init() async {
    if (_ready) return;
    try {
      // Mix with other apps and never steal audio focus from our own music
      // when a sound effect fires.
      final ctx = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
        respectSilence: true,
      ).build();
      await AudioPlayer.global.setAudioContext(ctx);
      _players = [
        for (var i = 0; i < 2; i++)
          AudioPlayer(playerId: 'music_$i')..audioCache = FlameAudio.audioCache,
      ];
      for (final p in _players) {
        await p.setAudioContext(ctx);
        await p.setReleaseMode(ReleaseMode.loop);
      }
      for (final s in Sfx.values) {
        final many = s == Sfx.coin || s == Sfx.swipe || s == Sfx.jump || s == Sfx.spinTick ||
            s == Sfx.flower;
        _pools[s] = await FlameAudio.createPool(
          _sfxFile(s),
          minPlayers: 1,
          maxPlayers: many ? 4 : 2,
          audioContext: ctx,
        );
      }
      _ready = true;
      _settings.addListener(_applyVolume);
      WidgetsBinding.instance.addObserver(this);
      final pending = _mode;
      _mode = null;
      if (pending != null) setMode(pending);
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready) return;
    if (state == AppLifecycleState.resumed) {
      _appBackground = false;
      if (!_musicPaused && _mode != null && _settings.musicVolume > 0.001) _current.resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _appBackground = true;
      _current.pause();
    }
  }

  void _applyVolume() {
    if (!_ready || _mode == null) return;
    final v = _volumeFor(_mode!);
    _current.setVolume(v);
    if (v <= 0.001) {
      _current.pause();
    } else if (!_musicPaused && !_appBackground && _current.state != PlayerState.playing) {
      _current.resume();
    }
  }

  /// Switches the soundtrack version, crossfading in time with the beat.
  void setMode(MusicMode mode) {
    if (_mode == mode) {
      if (_musicPaused) resumeMusic();
      return;
    }
    final first = _mode == null || !_ready || _current.source == null;
    _mode = mode;
    if (!_ready) return;
    _queue = _queue.then((_) => _switchTo(mode, fromNothing: first));
  }

  Future<void> _switchTo(MusicMode mode, {required bool fromNothing}) async {
    if (_mode != mode) return; // superseded while queued
    try {
      _musicPaused = false;
      final file = _musicFiles[mode]!;
      final target = _volumeFor(mode);
      if (fromNothing) {
        await _current.setVolume(target);
        await _current.setSource(AssetSource(file));
        if (target > 0.001 && !_appBackground) await _current.resume();
        debugPrint('AddisAudio: music started in ${mode.name} mode');
        return;
      }
      Duration pos = Duration.zero;
      if (_current.source != null) {
        pos = await _current.getCurrentPosition() ?? Duration.zero;
      }
      final next = _other;
      await next.setVolume(0);
      await next.setSource(AssetSource(file));
      // Compensate for the time it takes the new player to start.
      await next.seek(pos + const Duration(milliseconds: 90));
      if (target > 0.001 && !_appBackground) await next.resume();
      final old = _current;
      _active = 1 - _active;
      debugPrint('AddisAudio: music -> ${mode.name} at ${pos.inMilliseconds} ms');
      await _crossfade(old, next, target);
    } catch (e) {
      debugPrint('Music switch failed: $e');
    }
  }

  Future<void> _crossfade(AudioPlayer out, AudioPlayer inn, double target) {
    _fadeTimer?.cancel();
    final done = Completer<void>();
    const steps = 10;
    final start = out.volume;
    var i = 0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      i++;
      final f = i / steps;
      out.setVolume(start * (1 - f));
      inn.setVolume(target * f);
      if (i >= steps) {
        t.cancel();
        out.stop();
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }

  /// Briefly dips the music (used while rolling).
  void duck({double to = 0.55, Duration hold = const Duration(milliseconds: 420)}) {
    if (!_ready || _mode == null) return;
    _duck = to;
    _current.setVolume(_volumeFor(_mode!));
    _duckTimer?.cancel();
    _duckTimer = Timer(hold, () {
      _duck = 1;
      if (_mode != null) _current.setVolume(_volumeFor(_mode!));
    });
  }

  Future<void> pauseMusic() async {
    _musicPaused = true;
    if (_ready) await _current.pause();
  }

  Future<void> resumeMusic() async {
    if (!_musicPaused) return;
    _musicPaused = false;
    if (_ready && _mode != null && _settings.musicVolume > 0.001 && !_appBackground) {
      await _current.resume();
    }
  }

  /// Crash: the song grinds to a halt like a turntable losing power.
  Future<void> tapeStop() async {
    sfx(Sfx.tapeStop, volume: _settings.musicVolume);
    await pauseMusic();
  }

  void sfx(Sfx s, {double volume = 1}) {
    if (!_ready) return;
    final v = (_settings.sfxVolume * volume).clamp(0.0, 1.0);
    if (v <= 0.001) return;
    unawaited(_pools[s]?.start(volume: v).catchError((Object e) {
      debugPrint('SFX error: $e');
      return () async {};
    }));
  }
}
