import 'package:addis_surfers/game/entities.dart';
import 'package:addis_surfers/game/track_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('track generator always leaves at least one lane without a train', () {
    for (var seed = 0; seed < 40; seed++) {
      final gen = TrackGenerator(seed);
      final obstacles = <Obstacle>[];
      gen.generateUntil(
        targetZ: 6000,
        speed: 20,
        difficulty: 1,
        obstacles: obstacles,
        coins: [],
        powerUps: [],
      );
      final trains = obstacles.where((o) => o.kind == ObstacleKind.train && o.speed == 0);
      for (var z = 0.0; z < 6000; z += 0.5) {
        final blocked = trains.where((t) => z >= t.z && z <= t.end).map((t) => t.lane).toSet();
        expect(blocked.length, lessThan(3), reason: 'seed $seed z $z');
      }
    }
  });
}
