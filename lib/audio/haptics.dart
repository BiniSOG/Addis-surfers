import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../settings.dart';

/// Named vibration effects. Each one is a timed pattern with its own
/// intensity curve, so a jump, a landing and a crash all *feel* different.
enum Haptic {
  click,
  laneChange,
  coin,
  jump,
  superJump,
  roll,
  land,
  powerUp,
  magnetOn,
  flyOn,
  gem,
  stumble,
  crash,
  shieldBreak,
  reward,
}

class _Pattern {
  const _Pattern(this.timings, this.intensities, this.fallback);

  /// Alternating wait/vibrate durations in milliseconds (starting with a wait).
  final List<int> timings;

  /// Intensity 0-255 for each entry of [timings] (waits are 0).
  final List<int> intensities;

  /// Used on phones without fine-grained vibration control.
  final Future<void> Function() fallback;
}

class Haptics {
  Haptics._();
  static final Haptics instance = Haptics._();

  bool _hasVibrator = false;
  bool _custom = false;
  DateTime _lastCoin = DateTime.fromMillisecondsSinceEpoch(0);

  static final _patterns = <Haptic, _Pattern>{
    Haptic.click: const _Pattern([0, 10], [0, 50], HapticFeedback.selectionClick),
    Haptic.laneChange: const _Pattern([0, 12], [0, 70], HapticFeedback.selectionClick),
    Haptic.coin: const _Pattern([0, 8], [0, 45], HapticFeedback.selectionClick),
    Haptic.jump: const _Pattern([0, 18], [0, 120], HapticFeedback.lightImpact),
    // Spring: a squash then a bigger release.
    Haptic.superJump: const _Pattern([0, 22, 28, 45], [0, 120, 0, 230], HapticFeedback.mediumImpact),
    // Tumble: two soft bumps.
    Haptic.roll: const _Pattern([0, 16, 45, 16], [0, 100, 0, 70], HapticFeedback.lightImpact),
    Haptic.land: const _Pattern([0, 50], [0, 210], HapticFeedback.heavyImpact),
    Haptic.powerUp: const _Pattern([0, 20, 40, 20, 40, 34], [0, 110, 0, 160, 0, 230],
        HapticFeedback.mediumImpact),
    // Magnet: quick buzzing pulses rising in strength - "zzzzing".
    Haptic.magnetOn: const _Pattern([0, 14, 22, 14, 22, 14, 22, 14, 22, 30],
        [0, 50, 0, 90, 0, 130, 0, 180, 0, 240], HapticFeedback.mediumImpact),
    // Jetpack: an engine rumble building up to takeoff.
    Haptic.flyOn: const _Pattern([0, 70, 15, 90, 15, 140], [0, 70, 0, 150, 0, 255],
        HapticFeedback.heavyImpact),
    Haptic.gem: const _Pattern([0, 22, 55, 45], [0, 150, 0, 235], HapticFeedback.mediumImpact),
    Haptic.stumble: const _Pattern([0, 45, 60, 35], [0, 190, 0, 120], HapticFeedback.mediumImpact),
    Haptic.crash: const _Pattern([0, 110, 50, 180], [0, 255, 0, 200], HapticFeedback.heavyImpact),
    Haptic.shieldBreak: const _Pattern([0, 30, 30, 30, 30, 70], [0, 230, 0, 160, 0, 255],
        HapticFeedback.heavyImpact),
    Haptic.reward: const _Pattern([0, 30, 60, 30, 60, 90], [0, 120, 0, 170, 0, 255],
        HapticFeedback.mediumImpact),
  };

  Future<void> init() async {
    try {
      _hasVibrator = await Vibration.hasVibrator();
      _custom = _hasVibrator &&
          (await Vibration.hasCustomVibrationsSupport() || await Vibration.hasAmplitudeControl());
    } catch (e) {
      debugPrint('Vibration unavailable: $e');
    }
  }

  void play(Haptic h) {
    final s = GameSettings.instance;
    if (!s.haptics) return;
    if (h == Haptic.coin) {
      // Coins come in fast streams; keep them as a light texture.
      final now = DateTime.now();
      if (now.difference(_lastCoin) < const Duration(milliseconds: 110)) return;
      _lastCoin = now;
    }
    final p = _patterns[h]!;
    if (!_custom) {
      p.fallback();
      return;
    }
    final k = s.vibrationStrength;
    Vibration.vibrate(
      pattern: p.timings,
      intensities: [
        for (final i in p.intensities) i == 0 ? 0 : (i * k).round().clamp(1, 255),
      ],
    ).catchError((Object e) => debugPrint('Vibration error: $e'));
  }
}
