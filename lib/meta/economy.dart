import '../game/entities.dart';

/// Shop prices and upgrade curves.
class Economy {
  const Economy._();

  static const maxUpgradeLevel = 5;

  /// Coin cost to go from level i to i+1.
  static const upgradeCosts = [400, 900, 2000, 4500, 9000];

  static const upgradable = [
    PowerKind.magnet,
    PowerKind.multiplier,
    PowerKind.sneakers,
    PowerKind.jetpack,
  ];

  static double duration(PowerKind kind, int level) => switch (kind) {
        PowerKind.jetpack => 7 + 1.5 * level,
        PowerKind.shield => 30,
        _ => 10 + 2.5 * level,
      };

  static const shieldPrice = 600;
  static const headStartPrice = 1500;

  /// Trade gems for coins.
  static const gemsForCoinsGems = 5;
  static const gemsForCoinsCoins = 3000;

  /// Gem cost of the n-th revive in one run (0-based): 1, 2, 4, 8...
  static int reviveCost(int revivesSoFar) => 1 << revivesSoFar.clamp(0, 4);

  static const maxScoreMultiplier = 30;
}

String powerName(PowerKind k) => switch (k) {
      PowerKind.magnet => 'Coin Magnet',
      PowerKind.multiplier => 'x2 Score',
      PowerKind.sneakers => 'Super Jump',
      PowerKind.jetpack => 'Jetpack',
      PowerKind.shield => 'Gasha Shield',
    };
