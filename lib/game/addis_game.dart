import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../characters.dart';
import 'entities.dart';
import 'renderer.dart';
import 'textures.dart';
import 'track_generator.dart';

enum GameState { menu, playing, paused, crashed, over }

enum InputAction { left, right, jump, roll }

/// Core endless-runner simulation. Rendering lives in [WorldRenderer].
class AddisGame extends FlameGame with KeyboardEvents {
  AddisGame({required this.character});

  // ---- Tunables -------------------------------------------------------------
  static const double gravity = 32;
  static const double jumpVelocity = 10.2; // apex ~1.6
  static const double sneakerJumpVelocity = 14.6; // apex ~3.3 (onto trains)
  static const double stepUp = 0.45;
  static const double laneSwitchSpeed = laneWidth / 0.13;
  static const double rollDuration = 0.62;
  static const double powerDuration = 12;

  // ---- Observable state for the Flutter UI ---------------------------------
  final ValueNotifier<GameState> state = ValueNotifier(GameState.menu);
  final ValueNotifier<int> scoreN = ValueNotifier(0);
  final ValueNotifier<int> coinsN = ValueNotifier(0);
  final ValueNotifier<Map<PowerKind, double>> powersN = ValueNotifier(const {});

  CharacterId character;

  // ---- Simulation -----------------------------------------------------------
  late TrackGenerator _gen;
  final List<Obstacle> obstacles = [];
  final List<Coin> coins = [];
  final List<PowerUp> powerUps = [];

  double time = 0;
  double pz = 0; // player distance along the track
  double px = 0; // player x
  double py = 0; // player height (feet)
  double vy = 0;
  bool grounded = true;
  int targetLane = 0;
  int physLane = 0;
  double rollTimer = 0;
  double speed = 0;
  double runPhase = 0;
  double camX = 0;
  double camY = 0;
  double shake = 0;
  double invincible = 0;
  double _lastStumble = -100;
  double score = 0;
  int coinsThisRun = 0;
  bool continuedThisRun = false;
  final Map<PowerKind, double> powers = {};

  late WorldRenderer _renderer;

  /// Called when the player crashes (UI decides continue vs. game over).
  VoidCallback? onCrash;

  bool get rolling => rollTimer > 0;

  @override
  Color backgroundColor() => const Color(0xFF9FD3F5);

  @override
  Future<void> onLoad() async {
    Textures.build();
    _renderer = WorldRenderer(this);
    _resetWorld(seed: DateTime.now().millisecondsSinceEpoch);
  }

  void _resetWorld({required int seed}) {
    _gen = TrackGenerator(seed);
    obstacles.clear();
    coins.clear();
    powerUps.clear();
    pz = 0;
    px = 0;
    py = 0;
    vy = 0;
    grounded = true;
    targetLane = 0;
    physLane = 0;
    rollTimer = 0;
    speed = 0;
    camX = 0;
    camY = 0;
    invincible = 0;
    score = 0;
    coinsThisRun = 0;
    continuedThisRun = false;
    powers.clear();
    powersN.value = const {};
    scoreN.value = 0;
    coinsN.value = 0;
    _generate();
  }

  void _generate() {
    _gen.generateUntil(
      targetZ: pz + 140,
      speed: max(speed, 12),
      difficulty: difficulty,
      obstacles: obstacles,
      coins: coins,
      powerUps: powerUps,
    );
  }

  double get difficulty => (1 - exp(-pz / 3000)).clamp(0.0, 1.0);

  // ---- Run lifecycle ---------------------------------------------------------

  void startRun() {
    _resetWorld(seed: DateTime.now().millisecondsSinceEpoch);
    speed = 12;
    state.value = GameState.playing;
  }

  void pause() {
    if (state.value == GameState.playing) state.value = GameState.paused;
  }

  void resume() {
    if (state.value == GameState.paused) state.value = GameState.playing;
  }

  void goToMenu() {
    _resetWorld(seed: DateTime.now().millisecondsSinceEpoch);
    state.value = GameState.menu;
  }

  /// Revives the player after a crash (rewarded ad).
  void continueRun() {
    continuedThisRun = true;
    obstacles.removeWhere(
      (o) => (o.end > pz - 2 && o.z < pz + 45) || (o.speed > 0 && o.z < pz + 120),
    );
    invincible = 2.5;
    rollTimer = 0;
    vy = 0;
    if (py > 0) grounded = false;
    targetLane = physLane;
    px = laneX(physLane);
    state.value = GameState.playing;
  }

  void endRun() {
    state.value = GameState.over;
  }

  int get finalScore => score.floor();

  // ---- Input ---------------------------------------------------------------

  void handle(InputAction a) {
    if (state.value != GameState.playing) return;
    switch (a) {
      case InputAction.left:
        if (targetLane > -1) targetLane--;
      case InputAction.right:
        if (targetLane < 1) targetLane++;
      case InputAction.jump:
        if (grounded) {
          vy = (powers[PowerKind.sneakers] ?? 0) > 0
              ? sneakerJumpVelocity
              : jumpVelocity;
          grounded = false;
          rollTimer = 0;
        }
      case InputAction.roll:
        rollTimer = rollDuration;
        if (!grounded) vy = min(vy, -22);
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      handle(InputAction.left);
    } else if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      handle(InputAction.right);
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyW ||
        k == LogicalKeyboardKey.space) {
      handle(InputAction.jump);
    } else if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
      handle(InputAction.roll);
    } else if (k == LogicalKeyboardKey.keyP || k == LogicalKeyboardKey.escape) {
      state.value == GameState.paused ? resume() : pause();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---- Simulation step -------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    dt = min(dt, 1 / 30);
    time += dt;
    shake = max(0, shake - dt * 3);
    if (state.value != GameState.playing) {
      return;
    }

    // Speed ramps from 12 to 27 u/s with a long tail.
    speed = 12 + 15 * difficulty;
    final dz = speed * dt;
    pz += dz;
    runPhase += dz * 1.25;
    final mult = (powers[PowerKind.multiplier] ?? 0) > 0 ? 2 : 1;
    score += dz * mult;
    invincible = max(0, invincible - dt);

    for (final o in obstacles) {
      if (o.speed > 0) o.z -= o.speed * dt;
    }

    // Lateral movement.
    final tx = laneX(targetLane);
    final step = laneSwitchSpeed * dt;
    px = (px - tx).abs() <= step ? tx : px + step * (tx > px ? 1 : -1);

    // Vertical movement and collisions.
    rollTimer = max(0, rollTimer - dt);
    vy -= gravity * dt;
    py += vy * dt;

    final newLane = (px / laneWidth).round().clamp(-1, 1);
    if (newLane != physLane) {
      final surfNew = surfaceAt(newLane, pz);
      if (surfNew - py > stepUp && invincible <= 0) {
        _stumble();
      } else {
        physLane = newLane;
      }
    }

    final surf = surfaceAt(physLane, pz);
    if (py < surf - stepUp) {
      if (invincible > 0) {
        py = surf;
        vy = 0;
      } else {
        _crash();
        return;
      }
    }
    if (py <= surf) {
      py = surf;
      vy = 0;
      grounded = true;
    } else {
      grounded = false;
    }

    if (_hitsBarrier()) {
      _crash();
      return;
    }

    _collectStuff(dt);
    _tickPowers(dt);

    obstacles.removeWhere((o) => o.end < pz - 12);
    coins.removeWhere((c) => c.collected || c.z < pz - 8);
    powerUps.removeWhere((p) => p.collected || p.z < pz - 8);
    _generate();

    camX += (px * 0.7 - camX) * min(1, dt * 8);
    camY += (py * 0.7 - camY) * min(1, dt * 5);

    final s = score.floor();
    if (s != scoreN.value) scoreN.value = s;
  }

  /// Height of the walkable surface at ([lane], [z]).
  double surfaceAt(int lane, double z) {
    var h = 0.0;
    for (final o in obstacles) {
      if (o.lane != lane || z < o.z || z > o.end) continue;
      if (o.kind == ObstacleKind.train) {
        h = max(h, trainHeight);
      } else if (o.kind == ObstacleKind.ramp) {
        h = max(h, trainHeight * ((z - o.z) / o.length));
      }
    }
    return h;
  }

  bool _hitsBarrier() {
    if (invincible > 0) return false;
    final height = rolling ? rollHeight : playerHeight;
    for (final o in obstacles) {
      if (o.lane != physLane || (o.z - pz).abs() > 0.55) continue;
      if (o.kind == ObstacleKind.lowBarrier && py < 0.8) return true;
      if (o.kind == ObstacleKind.highBarrier && py + height > 1.05 && py < 2.6) {
        return true;
      }
    }
    return false;
  }

  void _stumble() {
    shake = 1;
    HapticFeedback.lightImpact();
    targetLane = physLane;
    px = laneX(physLane) + (px > laneX(physLane) ? 0.45 : -0.45) * laneWidth;
    if (time - _lastStumble < 4) {
      _crash();
    }
    _lastStumble = time;
  }

  void _crash() {
    if (state.value != GameState.playing) return;
    shake = 1.5;
    HapticFeedback.heavyImpact();
    state.value = GameState.crashed;
    onCrash?.call();
  }

  void _collectStuff(double dt) {
    final magnet = (powers[PowerKind.magnet] ?? 0) > 0;
    final cy = py + 0.7;
    for (final c in coins) {
      if (c.collected) continue;
      final ahead = c.z - pz;
      if (magnet && ahead < 16 && ahead > -1) c.magnetized = true;
      if (c.magnetized) {
        final k = min(1.0, dt * 12);
        c.x += (px - c.x) * k;
        c.y += (cy - c.y) * k;
        c.z += (pz + 0.3 - c.z) * k;
      }
      if ((c.z - pz).abs() < 0.8 &&
          (c.x - px).abs() < 0.8 &&
          (c.y - cy).abs() < 1.1) {
        c.collected = true;
        coinsThisRun++;
      }
    }
    if (coinsN.value != coinsThisRun) coinsN.value = coinsThisRun;

    for (final p in powerUps) {
      if (p.collected) continue;
      if ((p.z - pz).abs() < 0.9 &&
          (laneX(p.lane) - px).abs() < 0.8 &&
          (p.y - (py + 0.7)).abs() < 1.2) {
        p.collected = true;
        powers[p.kind] = powerDuration;
        HapticFeedback.selectionClick();
      }
    }
  }

  void _tickPowers(double dt) {
    if (powers.isEmpty) return;
    powers.updateAll((k, v) => v - dt);
    powers.removeWhere((k, v) => v <= 0);
    powersN.value = Map.unmodifiable(powers);
  }

  // ---- Rendering ---------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    _renderer.render(canvas, Size(size.x, size.y));
    super.render(canvas);
  }
}
