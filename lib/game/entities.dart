/// World constants and entity types. World units are roughly metres:
/// x = sideways (lanes), y = up, z = forward along the track.
library;

const double laneWidth = 1.5;
const double trainWidth = 1.3;
const double trainHeight = 2.2;
const double carLength = 11.0;
const double rampLength = 7.0;
const double playerHeight = 1.3;
const double rollHeight = 0.6;

double laneX(int lane) => lane * laneWidth;

enum ObstacleKind { train, ramp, lowBarrier, highBarrier }

class Obstacle {
  Obstacle({
    required this.kind,
    required this.lane,
    required this.z,
    this.length = 0.4,
    this.speed = 0,
    this.variant = 0,
  });

  final ObstacleKind kind;
  final int lane;

  /// Near end of the obstacle (closest to the player).
  double z;
  final double length;

  /// Units/second towards the player (oncoming trains).
  final double speed;
  final int variant;

  double get end => z + length;
  bool get isSolidBlock => kind == ObstacleKind.train;
}

class Coin {
  Coin(this.x, this.y, this.z);
  double x, y, z;
  bool collected = false;
  bool magnetized = false;
}

enum PowerKind { magnet, multiplier, sneakers }

class PowerUp {
  PowerUp(this.kind, this.lane, this.y, this.z);
  final PowerKind kind;
  final int lane;
  final double y;
  final double z;
  bool collected = false;
}
