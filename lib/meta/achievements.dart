import 'rewards.dart';

/// Lifetime statistics that achievements are measured against.
enum Stat {
  runs,
  coins,
  bestScore,
  jetpacks,
  roofDistance,
  wordsCompleted,
  flowers,
  charactersOwned,
  missionLevel,
  boxesOpened,
  revives,
}

class Achievement {
  const Achievement(this.id, this.title, this.description, this.stat, this.target, this.reward);
  final String id;
  final String title;
  final String description;
  final Stat stat;
  final int target;
  final Prize reward;
}

const achievements = [
  Achievement('first_run', 'First Steps', 'Finish your first run', Stat.runs, 1,
      Prize(PrizeKind.coins, 100)),
  Achievement('runs_25', 'Regular Runner', 'Play 25 runs', Stat.runs, 25, Prize(PrizeKind.gems, 1)),
  Achievement('runs_200', 'Marathon of Addis', 'Play 200 runs', Stat.runs, 200,
      Prize(PrizeKind.gems, 3)),
  Achievement('coins_1k', 'Pocket Change', 'Collect 1,000 coins', Stat.coins, 1000,
      Prize(PrizeKind.coins, 300)),
  Achievement('coins_25k', 'Merkato Merchant', 'Collect 25,000 coins', Stat.coins, 25000,
      Prize(PrizeKind.gems, 3)),
  Achievement('score_5k', 'On the Move', 'Score 5,000 in one run', Stat.bestScore, 5000,
      Prize(PrizeKind.coins, 500)),
  Achievement('score_25k', 'Bole Express', 'Score 25,000 in one run', Stat.bestScore, 25000,
      Prize(PrizeKind.gems, 2)),
  Achievement('score_100k', 'Legend of Entoto', 'Score 100,000 in one run', Stat.bestScore, 100000,
      Prize(PrizeKind.gems, 5)),
  Achievement('jet_10', 'High Flyer', 'Use 10 jetpacks', Stat.jetpacks, 10, Prize(PrizeKind.gems, 1)),
  Achievement('roof_2k', 'Rooftop Runner', 'Run 2,000 m on train roofs', Stat.roofDistance, 2000,
      Prize(PrizeKind.mesob, 1)),
  Achievement('words_3', 'Wordsmith', 'Complete 3 Daily Words', Stat.wordsCompleted, 3,
      Prize(PrizeKind.gems, 2)),
  Achievement('flowers_500', 'Adey Abeba', 'Pick 500 Meskel daisies', Stat.flowers, 500,
      Prize(PrizeKind.gems, 2)),
  Achievement('crew_all', 'Full Crew', 'Unlock every character', Stat.charactersOwned, 3,
      Prize(PrizeKind.gems, 5)),
  Achievement('missions_10', 'Mission Master', 'Reach a x11 score multiplier', Stat.missionLevel, 10,
      Prize(PrizeKind.gems, 3)),
  Achievement('boxes_10', 'Basket Weaver', 'Open 10 Mesob Surprises', Stat.boxesOpened, 10,
      Prize(PrizeKind.headStart, 2)),
];
