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

/// Things that happen during a run. The UI turns these into sounds,
/// haptics and mission progress.
enum GameEvent {
  coin,
  jump,
  roll,
  laneChange,
  stumble,
  crash,
  powerUp,
  gem,
  letter,
  shieldOn,
  shieldBreak,
  jetpack,
  headStart,
  flower,
  chase,
  newBest,
}

/// Per-run statistics, used for missions and the results screen.
class RunStats {
  int coins = 0;
  int jumps = 0;
  int rolls = 0;
  int laneChanges = 0;
  int powerUps = 0;
  int gems = 0;
  int shieldsUsed = 0;
  int headStartsUsed = 0;
  int jetpacks = 0;
  int flowers = 0;
  double roofDistance = 0;
  final List<String> letters = [];
}

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
  static const double shieldDuration = 30;
  static const double headStartDuration = 5;
  static const double headStartBoost = 2.8;

  // ---- Configuration supplied by the app before each run --------------------
  CharacterId character;

  /// Seconds each power-up lasts (upgraded in the shop).
  Map<PowerKind, double> powerDurations = {
    PowerKind.magnet: 10,
    PowerKind.multiplier: 10,
    PowerKind.sneakers: 10,
    PowerKind.jetpack: 7,
    PowerKind.shield: shieldDuration,
  };

  /// Permanent score multiplier from completed mission sets.
  int scoreMultiplier = 1;

  /// Next Daily Word letter to place on the track (null = word complete).
  String? nextLetter;

  /// Best score before this run (for the mid-run "NEW BEST!" moment).
  int bestScore = 0;
  bool _announcedBest = false;

  bool haptics = true;
  bool lowGraphics = false;

  /// Called for every gameplay event.
  void Function(GameEvent event, Object? data)? onEvent;

  /// Called when the player crashes (UI decides continue vs. game over).
  VoidCallback? onCrash;

  // ---- Observable state for the Flutter UI ---------------------------------
  final ValueNotifier<GameState> state = ValueNotifier(GameState.menu);
  final ValueNotifier<int> scoreN = ValueNotifier(0);
  final ValueNotifier<int> coinsN = ValueNotifier(0);
  final ValueNotifier<int> flowersN = ValueNotifier(0);
  final ValueNotifier<Map<PowerKind, double>> powersN = ValueNotifier(const {});

  // ---- Simulation -----------------------------------------------------------
  late TrackGenerator _gen;
  final List<Obstacle> obstacles = [];
  final List<Coin> coins = [];
  final List<PowerUp> powerUps = [];
  final List<Pickup> pickups = [];

  double time = 0;
  double runTime = 0;
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
  bool continuedThisRun = false;
  int revives = 0;
  RunStats stats = RunStats();

  /// Remaining seconds per active power-up, and the duration it started with.
  final Map<PowerKind, double> powers = {};
  final Map<PowerKind, double> powerMax = {};
  double _flyBoost = 1;

  // The street goat that chases you after a stumble.
  double chase = 0;
  double goatX = 0;
  double goatGap = 12;

  late WorldRenderer _renderer;

  bool get rolling => rollTimer > 0;
  bool get flying => (powers[PowerKind.jetpack] ?? 0) > 0;
  bool get shielded => (powers[PowerKind.shield] ?? 0) > 0;
  bool get headStarting => flying && _flyBoost > 1;
  int get coinsThisRun => stats.coins;

  @override
  Color backgroundColor() => const Color(0xFF9FD3F5);

  @override
  Future<void> onLoad() async {
    Textures.build();
    _renderer = WorldRenderer(this);
    _resetWorld(seed: DateTime.now().millisecondsSinceEpoch);
  }

  void _resetWorld({required int seed}) {
    _gen = TrackGenerator(seed)..letter = nextLetter;
    obstacles.clear();
    coins.clear();
    powerUps.clear();
    pickups.clear();
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
    runTime = 0;
    continuedThisRun = false;
    revives = 0;
    stats = RunStats();
    powers.clear();
    powerMax.clear();
    _flyBoost = 1;
    chase = 0;
    goatGap = 12;
    goatX = 0;
    _announcedBest = false;
    powersN.value = const {};
    scoreN.value = 0;
    coinsN.value = 0;
    flowersN.value = 0;
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
      pickups: pickups,
    );
  }

  double get difficulty => (1 - exp(-pz / 3000)).clamp(0.0, 1.0);

  void _emit(GameEvent e, [Object? data]) => onEvent?.call(e, data);

  void _haptic(void Function() f) {
    if (haptics) f();
  }

  // ---- Run lifecycle ---------------------------------------------------------

  void startRun() {
    _resetWorld(seed: DateTime.now().millisecondsSinceEpoch);
    speed = 12;
    // The goat chases you off the platform at the start of every run.
    chase = 3.2;
    goatGap = 1.5;
    state.value = GameState.playing;
    _emit(GameEvent.chase);
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

  void _clearAhead(double distance) {
    obstacles.removeWhere(
      (o) => (o.end > pz - 2 && o.z < pz + distance) || (o.speed > 0 && o.z < pz + 120),
    );
  }

  /// Revives the player after a crash (rewarded ad or gems).
  void continueRun({required bool viaAd}) {
    if (viaAd) continuedThisRun = true;
    revives++;
    chase = 0;
    _clearAhead(45);
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

  /// Daily Word: the app tells the game which letter to place next.
  void setNextLetter(String? letter) {
    nextLetter = letter;
    _gen.letter = letter;
    if (letter == null) pickups.removeWhere((p) => p.kind == PickupKind.letter);
  }

  // ---- Boosts from the shop -------------------------------------------------

  /// Activates a shield (bought in the shop). Returns false if already active.
  bool activateShield() {
    if (state.value != GameState.playing || shielded) return false;
    _startPower(PowerKind.shield, powerDurations[PowerKind.shield]!);
    stats.shieldsUsed++;
    _emit(GameEvent.shieldOn);
    return true;
  }

  /// Head start: blast forward at high speed, invincible, for a few seconds.
  bool useHeadStart() {
    if (state.value != GameState.playing || flying) return false;
    _flyBoost = headStartBoost;
    _startPower(PowerKind.jetpack, headStartDuration);
    stats.headStartsUsed++;
    _emit(GameEvent.headStart);
    return true;
  }

  void _startPower(PowerKind kind, double seconds) {
    powers[kind] = seconds;
    powerMax[kind] = seconds;
    powersN.value = Map.unmodifiable(powers);
  }

  // ---- Input ---------------------------------------------------------------

  void handle(InputAction a) {
    if (state.value != GameState.playing) return;
    switch (a) {
      case InputAction.left:
        if (targetLane > -1) {
          targetLane--;
          stats.laneChanges++;
          _emit(GameEvent.laneChange);
        }
      case InputAction.right:
        if (targetLane < 1) {
          targetLane++;
          stats.laneChanges++;
          _emit(GameEvent.laneChange);
        }
      case InputAction.jump:
        if (grounded && !flying) {
          vy = (powers[PowerKind.sneakers] ?? 0) > 0
              ? sneakerJumpVelocity
              : jumpVelocity;
          grounded = false;
          rollTimer = 0;
          stats.jumps++;
          _emit(GameEvent.jump);
        }
      case InputAction.roll:
        if (flying) return;
        rollTimer = rollDuration;
        if (!grounded) vy = min(vy, -22);
        stats.rolls++;
        _emit(GameEvent.roll);
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
    _updateGoat(dt);
    if (state.value != GameState.playing) {
      return;
    }
    runTime += dt;

    // Speed ramps from 12 to 27 u/s with a long tail.
    final boost = flying ? _flyBoost : 1.0;
    speed = (12 + 15 * difficulty) * boost;
    final dz = speed * dt;
    pz += dz;
    runPhase += dz * 1.25 / boost;
    final x2 = (powers[PowerKind.multiplier] ?? 0) > 0 ? 2 : 1;
    score += dz * x2 * scoreMultiplier * 0.5;
    invincible = max(0, invincible - dt);

    for (final o in obstacles) {
      if (o.speed > 0) o.z -= o.speed * dt;
    }

    // Lateral movement.
    final tx = laneX(targetLane);
    final step = laneSwitchSpeed * dt;
    px = (px - tx).abs() <= step ? tx : px + step * (tx > px ? 1 : -1);
    rollTimer = max(0, rollTimer - dt);

    if (flying) {
      // Jetpack / head start: glide above everything.
      py += (flyHeight - py) * min(1, dt * 4);
      vy = 0;
      grounded = false;
      physLane = (px / laneWidth).round().clamp(-1, 1);
    } else {
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
        } else if (_crash()) {
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
      if (grounded && py >= trainHeight - 0.01) stats.roofDistance += dz;

      if (_hitsBarrier() && _crash()) {
        return;
      }
    }

    _collectStuff(dt);
    _tickPowers(dt);

    obstacles.removeWhere((o) => o.end < pz - 12);
    coins.removeWhere((c) => c.collected || c.z < pz - 8);
    powerUps.removeWhere((p) => p.collected || p.z < pz - 8);
    pickups.removeWhere((p) => p.collected || p.z < pz - 8);
    _generate();

    camX += (px * 0.7 - camX) * min(1, dt * 8);
    camY += (py * 0.7 - camY) * min(1, dt * 5);

    final s = score.floor();
    if (s != scoreN.value) scoreN.value = s;
    if (!_announcedBest && bestScore > 0 && s > bestScore) {
      _announcedBest = true;
      _emit(GameEvent.newBest);
    }
  }

  void _updateGoat(double dt) {
    final st = state.value;
    if (st == GameState.crashed || st == GameState.over) {
      // The goat catches up with you.
      if (chase > 0 || goatGap < 10) {
        chase = max(chase, 0.1);
        goatGap += (0.9 - goatGap) * min(1, dt * 6);
      }
    } else if (st == GameState.playing) {
      if (flying) chase = 0;
      chase = max(0, chase - dt);
      final target = chase > 1 ? 1.6 : 1.6 + (1 - chase) * 10;
      goatGap += (target - goatGap) * min(1, dt * 3);
    } else if (st == GameState.menu) {
      chase = 0;
      goatGap = 12;
    }
    goatX += (px - 0.55 - goatX) * min(1, dt * 5);
  }

  bool get goatVisible => goatGap < 9.5 && state.value != GameState.menu;

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
    _haptic(HapticFeedback.lightImpact);
    targetLane = physLane;
    px = laneX(physLane) + (px > laneX(physLane) ? 0.45 : -0.45) * laneWidth;
    _emit(GameEvent.stumble);
    if (!flying) {
      chase = 4;
      goatGap = min(goatGap, 3);
      _emit(GameEvent.chase);
    }
    if (time - _lastStumble < 4) {
      _crash();
    }
    _lastStumble = time;
  }

  /// Returns true if the run stopped (false if a shield absorbed the hit).
  bool _crash() {
    if (state.value != GameState.playing) return true;
    if (shielded) {
      powers.remove(PowerKind.shield);
      powersN.value = Map.unmodifiable(powers);
      _clearAhead(30);
      invincible = 1.5;
      shake = 0.8;
      _haptic(HapticFeedback.mediumImpact);
      _emit(GameEvent.shieldBreak);
      return false;
    }
    shake = 1.5;
    _haptic(HapticFeedback.heavyImpact);
    state.value = GameState.crashed;
    _emit(GameEvent.crash);
    onCrash?.call();
    return true;
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
        stats.coins++;
        _emit(GameEvent.coin);
      }
    }
    if (coinsN.value != stats.coins) coinsN.value = stats.coins;

    for (final p in powerUps) {
      if (p.collected || flying && p.kind == PowerKind.jetpack) continue;
      if ((p.z - pz).abs() < 0.9 &&
          (laneX(p.lane) - px).abs() < 0.8 &&
          (p.y - cy).abs() < 1.2) {
        p.collected = true;
        stats.powerUps++;
        _startPower(p.kind, powerDurations[p.kind] ?? 10);
        if (p.kind == PowerKind.jetpack) {
          _flyBoost = 1;
          stats.jetpacks++;
          _gen.addSkyCoins(pz + 12, pz + speed * powers[p.kind]! - 10, coins);
          _emit(GameEvent.jetpack);
        } else {
          _emit(GameEvent.powerUp, p.kind);
        }
        _haptic(HapticFeedback.selectionClick);
      }
    }

    for (final p in pickups) {
      if (p.collected) continue;
      if ((p.z - pz).abs() < 0.9 &&
          (laneX(p.lane) - px).abs() < 0.8 &&
          (p.y - cy).abs() < 1.2) {
        p.collected = true;
        if (p.kind == PickupKind.gem) {
          stats.gems++;
          _emit(GameEvent.gem);
        } else if (p.kind == PickupKind.flower) {
          stats.flowers++;
          flowersN.value = stats.flowers;
          _emit(GameEvent.flower);
        } else if (p.letter != null) {
          stats.letters.add(p.letter!);
          _emit(GameEvent.letter, p.letter);
        }
        _haptic(HapticFeedback.selectionClick);
      }
    }
  }

  void _tickPowers(double dt) {
    if (powers.isEmpty) return;
    final wasFlying = flying;
    powers.updateAll((k, v) => v - dt);
    powers.removeWhere((k, v) => v <= 0);
    if (wasFlying && !flying) {
      // Landing: brief invincibility so you never drop into a crash.
      _flyBoost = 1;
      invincible = max(invincible, 1.6);
      vy = 0;
    }
    powersN.value = Map.unmodifiable(powers);
  }

  // ---- Rendering ---------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    _renderer.render(canvas, Size(size.x, size.y));
    super.render(canvas);
  }
}
