import 'dart:math';

import 'package:addis_surfers/game/entities.dart';
import 'package:addis_surfers/game/track_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates runs (player moving, oncoming trains driving towards them) and
/// checks that nothing visible ever overlaps in the same lane.
void main() {
  test('no visible overlaps between trains, barriers and pickups', () {
    for (var seed = 0; seed < 30; seed++) {
      final gen = TrackGenerator(seed);
      final obstacles = <Obstacle>[];
      final coins = <Coin>[];
      final powerUps = <PowerUp>[];
      final pickups = <Pickup>[];
      var pz = 0.0;
      const dt = 1 / 30;
      for (var step = 0; step < 30 * 240; step++) {
        final difficulty = (1 - exp(-pz / 3000)).clamp(0.0, 1.0);
        final speed = 12 + 15 * difficulty;
        pz += speed * dt;
        for (final o in obstacles) {
          if (o.speed > 0 && o.z > pz - 6) o.z -= o.speed * dt;
        }
        obstacles.removeWhere((o) => o.end < pz - 12);
        coins.removeWhere((c) => c.z < pz - 8);
        powerUps.removeWhere((p) => p.z < pz - 8);
        pickups.removeWhere((p) => p.z < pz - 8);
        gen.generateUntil(
          targetZ: pz + 140,
          speed: speed,
          difficulty: difficulty,
          obstacles: obstacles,
          coins: coins,
          powerUps: powerUps,
          pickups: pickups,
        );
        if (step % 3 != 0) continue;
        final visibleFrom = pz - 6;
        for (var i = 0; i < obstacles.length; i++) {
          final a = obstacles[i];
          if (a.end < visibleFrom) continue;
          for (var j = i + 1; j < obstacles.length; j++) {
            final b = obstacles[j];
            if (b.lane != a.lane || b.end < visibleFrom) continue;
            final overlap = a.z < b.end - 0.01 && b.z < a.end - 0.01;
            expect(overlap, isFalse,
                reason: 'seed $seed pz ${pz.toStringAsFixed(1)}: ${a.kind}@${a.z.toStringAsFixed(1)} '
                    'overlaps ${b.kind}@${b.z.toStringAsFixed(1)} in lane ${a.lane}');
          }
        }
        for (final t in obstacles.where((o) => o.speed > 0 && o.end > visibleFrom)) {
          bool inside(double z, int lane) => lane == t.lane && z > t.z && z < t.end;
          for (final p in pickups) {
            expect(inside(p.z, p.lane), isFalse, reason: 'seed $seed: train drives through ${p.kind}');
          }
          for (final p in powerUps) {
            expect(inside(p.z, p.lane), isFalse, reason: 'seed $seed: train drives through power-up');
          }
          for (final c in coins) {
            if (c.y > 3) continue; // sky coins (jetpack) are above trains
            expect(inside(c.z, (c.x / laneWidth).round()), isFalse,
                reason: 'seed $seed: train drives through a coin');
          }
        }
      }
    }
  });
}
