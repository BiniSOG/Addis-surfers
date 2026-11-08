import 'dart:math';

import 'entities.dart';

/// Procedurally lays out obstacles, coins and power-ups ahead of the player.
///
/// Fairness rules:
///  * at any z at most two lanes are blocked by trains (one is always open);
///  * barriers (jump / roll) are never placed right behind a train end;
///  * oncoming trains only spawn in a lane that has been empty for a long
///    stretch, so they never drive "through" other objects.
class TrackGenerator {
  TrackGenerator(int seed) : _rng = Random(seed);

  final Random _rng;
  double _nextRowZ = 40;
  double _nextPowerZ = 160;
  final List<double> _trainEnd = [-1e9, -1e9, -1e9];
  final List<double> _laneLast = [-1e9, -1e9, -1e9];
  final List<double> _coinLast = [-1e9, -1e9, -1e9];

  static const _lanes = [-1, 0, 1];

  int _idx(int lane) => lane + 1;

  void generateUntil({
    required double targetZ,
    required double speed,
    required double difficulty,
    required List<Obstacle> obstacles,
    required List<Coin> coins,
    required List<PowerUp> powerUps,
  }) {
    while (_nextRowZ < targetZ) {
      final z = _nextRowZ;
      _row(z, difficulty, obstacles, coins);
      if (z > _nextPowerZ) {
        _placePowerUp(z, powerUps);
        _nextPowerZ = z + 280 + _rng.nextDouble() * 260;
      }
      final rowTime = 1.55 - 0.6 * difficulty;
      _nextRowZ += max(16.0, speed * rowTime) + _rng.nextDouble() * 4;
    }
  }

  bool _laneClear(int lane, double z, double margin) =>
      _laneLast[_idx(lane)] + margin <= z;

  int _trainsActiveAt(double z, {int? except}) {
    var n = 0;
    for (final l in _lanes) {
      if (l != except && _trainEnd[_idx(l)] > z) n++;
    }
    return n;
  }

  List<int> _shuffledLanes() => [..._lanes]..shuffle(_rng);

  void _row(double z, double d, List<Obstacle> obs, List<Coin> coins) {
    final r = _rng.nextDouble();
    final used = <int>{};
    if (r < 0.10) {
      // Breather: just coins.
    } else if (r < 0.42) {
      _trainRow(z, d, obs, coins, used);
    } else if (r < 0.75) {
      _barrierRow(z, d, obs, coins, used);
    } else {
      // Mixed: one train + one barrier.
      final lanes = _shuffledLanes();
      for (final l in lanes) {
        if (_tryTrain(l, z, d, obs, coins, allowMoving: false)) {
          used.add(l);
          break;
        }
      }
      for (final l in lanes) {
        if (used.contains(l)) continue;
        if (_tryBarrier(l, z, d, obs, coins)) {
          used.add(l);
          break;
        }
      }
    }
    // Fill one free lane with a coin trail.
    for (final l in _shuffledLanes()) {
      if (used.contains(l)) continue;
      if (_trainEnd[_idx(l)] > z - 4 || !_laneClear(l, z - 4, 2)) continue;
      if (_rng.nextDouble() < 0.75) {
        final n = 5 + _rng.nextInt(5);
        for (var i = 0; i < n; i++) {
          coins.add(Coin(laneX(l), 0.6, z - 4 + i * 1.6));
        }
        _coinLast[_idx(l)] = z - 4 + n * 1.6;
      }
      break;
    }
  }

  void _trainRow(
    double z,
    double d,
    List<Obstacle> obs,
    List<Coin> coins,
    Set<int> used,
  ) {
    final want = _rng.nextDouble() < 0.25 + 0.45 * d ? 2 : 1;
    for (final l in _shuffledLanes()) {
      if (used.length >= want) break;
      if (_tryTrain(l, z, d, obs, coins, allowMoving: true)) used.add(l);
    }
  }

  bool _tryTrain(
    int lane,
    double z,
    double d,
    List<Obstacle> obs,
    List<Coin> coins, {
    required bool allowMoving,
  }) {
    final i = _idx(lane);
    if (!_laneClear(lane, z, 7) || _trainEnd[i] > z - 7) return false;
    if (_trainsActiveAt(z, except: lane) >= 2) return false;

    // Oncoming train?
    final othersQuiet = _lanes
        .where((l) => l != lane)
        .every((l) => _trainEnd[_idx(l)] < z - 60);
    if (allowMoving &&
        othersQuiet &&
        _laneLast[i] < z - 60 &&
        _coinLast[i] < z - 60 &&
        _rng.nextDouble() < 0.12 + 0.25 * d) {
      final cars = 1 + _rng.nextInt(2);
      final len = cars * carLength;
      obs.add(Obstacle(
        kind: ObstacleKind.train,
        lane: lane,
        z: z,
        length: len,
        speed: 6 + 4 * d + _rng.nextDouble() * 2,
        variant: _rng.nextInt(4),
      ));
      _trainEnd[i] = z + len;
      _laneLast[i] = z + len;
      return true;
    }

    final cars = 1 + _rng.nextInt(d > 0.4 ? 3 : 2);
    final len = cars * carLength;
    var start = z;
    final ramp = _rng.nextDouble() < 0.35;
    if (ramp) {
      obs.add(Obstacle(
        kind: ObstacleKind.ramp,
        lane: lane,
        z: z,
        length: rampLength,
      ));
      start = z + rampLength;
      // Coins up the ramp and along the roof.
      for (var c = 0.0; c < rampLength; c += 1.75) {
        coins.add(
          Coin(laneX(lane), 0.6 + trainHeight * (c / rampLength), z + c),
        );
      }
      for (var c = 1.0; c < len - 1; c += 1.6) {
        coins.add(Coin(laneX(lane), trainHeight + 0.6, start + c));
      }
    }
    obs.add(Obstacle(
      kind: ObstacleKind.train,
      lane: lane,
      z: start,
      length: len,
      variant: _rng.nextInt(4),
    ));
    _trainEnd[i] = start + len;
    _laneLast[i] = start + len;
    return true;
  }

  void _barrierRow(
    double z,
    double d,
    List<Obstacle> obs,
    List<Coin> coins,
    Set<int> used,
  ) {
    final all = d > 0.35 && _rng.nextDouble() < 0.18;
    final want = all ? 3 : (_rng.nextDouble() < 0.3 + 0.4 * d ? 2 : 1);
    for (final l in _shuffledLanes()) {
      if (used.length >= want) break;
      if (_tryBarrier(l, z, d, obs, coins)) used.add(l);
    }
  }

  bool _tryBarrier(
    int lane,
    double z,
    double d,
    List<Obstacle> obs,
    List<Coin> coins,
  ) {
    final i = _idx(lane);
    if (!_laneClear(lane, z, 9) || _trainEnd[i] > z - 9) return false;
    final high = _rng.nextDouble() < 0.4;
    obs.add(Obstacle(
      kind: high ? ObstacleKind.highBarrier : ObstacleKind.lowBarrier,
      lane: lane,
      z: z,
      variant: _rng.nextInt(3),
    ));
    _laneLast[i] = z + 0.5;
    if (!high && _rng.nextDouble() < 0.6) {
      // Coin arc over the low barrier.
      for (var k = -2; k <= 2; k++) {
        final h = 0.6 + 1.0 * (1 - (k * k) / 5.0);
        coins.add(Coin(laneX(lane), h, z + k * 1.4));
      }
      _coinLast[i] = z + 3;
    }
    return true;
  }

  void _placePowerUp(double z, List<PowerUp> powerUps) {
    for (final l in _shuffledLanes()) {
      final pz = z - 8;
      if (_trainEnd[_idx(l)] > pz - 2 || !_laneClear(l, pz, 1)) continue;
      final kind = PowerKind.values[_rng.nextInt(PowerKind.values.length)];
      powerUps.add(PowerUp(kind, l, 0.9, pz));
      return;
    }
  }
}
