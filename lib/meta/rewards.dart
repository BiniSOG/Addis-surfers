import 'dart:math';

/// A prize from the Lucky Spin or a Mesob Surprise basket.
enum PrizeKind { coins, gems, shield, headStart, mesob, character }

class Prize {
  const Prize(this.kind, this.amount, {this.weight = 1});
  final PrizeKind kind;
  final int amount;
  final double weight;

  String get label => switch (kind) {
        PrizeKind.coins => '$amount coins',
        PrizeKind.gems => amount == 1 ? '1 gem' : '$amount gems',
        PrizeKind.shield => amount == 1 ? 'Shield' : '$amount Shields',
        PrizeKind.headStart => amount == 1 ? 'Head Start' : '$amount Head Starts',
        PrizeKind.mesob => 'Mesob Surprise',
        PrizeKind.character => 'New character!',
      };

  String get shortLabel => switch (kind) {
        PrizeKind.coins => '$amount',
        PrizeKind.gems => '$amount',
        PrizeKind.shield => 'x$amount',
        PrizeKind.headStart => 'x$amount',
        PrizeKind.mesob => 'BOX',
        PrizeKind.character => 'NEW',
      };
}

/// The eight segments of the Lucky Spin wheel, clockwise from the top.
const spinPrizes = [
  Prize(PrizeKind.coins, 100, weight: 24),
  Prize(PrizeKind.gems, 1, weight: 10),
  Prize(PrizeKind.coins, 250, weight: 20),
  Prize(PrizeKind.shield, 1, weight: 12),
  Prize(PrizeKind.coins, 500, weight: 12),
  Prize(PrizeKind.headStart, 1, weight: 8),
  Prize(PrizeKind.mesob, 1, weight: 9),
  Prize(PrizeKind.gems, 3, weight: 5),
];

/// Extra spins a day unlocked by watching a rewarded ad.
const maxAdSpinsPerDay = 3;

/// Possible contents of a Mesob Surprise basket.
const mesobPrizes = [
  Prize(PrizeKind.coins, 200, weight: 26),
  Prize(PrizeKind.coins, 500, weight: 20),
  Prize(PrizeKind.coins, 1200, weight: 9),
  Prize(PrizeKind.gems, 1, weight: 14),
  Prize(PrizeKind.gems, 3, weight: 4),
  Prize(PrizeKind.shield, 2, weight: 12),
  Prize(PrizeKind.headStart, 1, weight: 10),
  Prize(PrizeKind.character, 1, weight: 2),
];

const mesobPrice = 750;

int pickWeighted(List<Prize> prizes, Random rng) {
  final total = prizes.fold<double>(0, (a, p) => a + p.weight);
  var r = rng.nextDouble() * total;
  for (var i = 0; i < prizes.length; i++) {
    r -= prizes[i].weight;
    if (r <= 0) return i;
  }
  return prizes.length - 1;
}
