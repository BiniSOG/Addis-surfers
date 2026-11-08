import 'dart:math';

/// Mission types. "Run" missions must be done in a single run; "total"
/// missions accumulate across runs.
enum MissionType {
  coinsRun,
  scoreRun,
  roofRun,
  jumpsTotal,
  rollsTotal,
  powerUpsTotal,
  laneChangesTotal,
  runsTotal,
}

class Mission {
  const Mission(this.type, this.target);
  final MissionType type;
  final int target;

  bool get perRun =>
      type == MissionType.coinsRun || type == MissionType.scoreRun || type == MissionType.roofRun;

  String get description => switch (type) {
        MissionType.coinsRun => 'Collect $target coins in one run',
        MissionType.scoreRun => 'Score $target points in one run',
        MissionType.roofRun => 'Run ${target}m on train roofs in one run',
        MissionType.jumpsTotal => 'Jump $target times',
        MissionType.rollsTotal => 'Roll $target times',
        MissionType.powerUpsTotal => 'Collect $target power-ups',
        MissionType.laneChangesTotal => 'Switch tracks $target times',
        MissionType.runsTotal => 'Play $target runs',
      };
}

const _base = {
  MissionType.coinsRun: 50,
  MissionType.scoreRun: 600,
  MissionType.roofRun: 60,
  MissionType.jumpsTotal: 25,
  MissionType.rollsTotal: 20,
  MissionType.powerUpsTotal: 4,
  MissionType.laneChangesTotal: 60,
  MissionType.runsTotal: 4,
};

int _nice(double v) {
  if (v < 20) return v.round();
  if (v < 200) return (v / 5).round() * 5;
  if (v < 2000) return (v / 50).round() * 50;
  return (v / 500).round() * 500;
}

/// The three missions of a mission set. Each completed set raises the
/// permanent score multiplier by one.
List<Mission> missionsForLevel(int level) {
  final rng = Random(level * 7919 + 13);
  final types = [...MissionType.values]..shuffle(rng);
  return [
    for (final t in types.take(3)) Mission(t, _nice(_base[t]! * (1 + 0.45 * level))),
  ];
}

/// Value a run contributes to a mission.
int runValue(MissionType t, {
  required int coins,
  required int score,
  required double roof,
  required int jumps,
  required int rolls,
  required int powerUps,
  required int laneChanges,
}) =>
    switch (t) {
      MissionType.coinsRun => coins,
      MissionType.scoreRun => score,
      MissionType.roofRun => roof.floor(),
      MissionType.jumpsTotal => jumps,
      MissionType.rollsTotal => rolls,
      MissionType.powerUpsTotal => powerUps,
      MissionType.laneChangesTotal => laneChanges,
      MissionType.runsTotal => 1,
    };
