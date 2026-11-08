import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'characters.dart';
import 'game/entities.dart';
import 'meta/daily.dart';
import 'meta/economy.dart';
import 'meta/missions.dart';

/// Result of applying a finished (or ongoing) run to the missions.
class MissionUpdate {
  MissionUpdate({required this.newlyCompleted, required this.setCompleted});
  final List<Mission> newlyCompleted;
  final bool setCompleted;
}

/// Persistent player progress: currencies, unlocks, upgrades, inventory,
/// missions, daily rewards and the Daily Word.
class Progress extends ChangeNotifier {
  Progress._(this._prefs);

  static late Progress instance;

  static Future<Progress> load() async {
    final prefs = await SharedPreferences.getInstance();
    instance = Progress._(prefs);
    return instance;
  }

  final SharedPreferences _prefs;

  Future<void> _setInt(String k, int v) => _prefs.setInt(k, v);
  int _int(String k, [int d = 0]) => _prefs.getInt(k) ?? d;

  // ---------------------------------------------------------------- basics

  int get coins => _int('coins');
  int get gems => _int('gems');
  int get bestScore => _int('best');
  int get runsPlayed => _int('runs');
  bool get tutorialSeen => _prefs.getBool('tutorialSeen') ?? false;

  Future<void> addCoins(int amount) async {
    await _setInt('coins', coins + amount);
    notifyListeners();
  }

  Future<void> addGems(int amount) async {
    await _setInt('gems', gems + amount);
    notifyListeners();
  }

  Future<bool> spendCoins(int amount) async {
    if (coins < amount) return false;
    await _setInt('coins', coins - amount);
    notifyListeners();
    return true;
  }

  Future<bool> spendGems(int amount) async {
    if (gems < amount) return false;
    await _setInt('gems', gems - amount);
    notifyListeners();
    return true;
  }

  Future<void> markTutorialSeen() => _prefs.setBool('tutorialSeen', true);

  Future<void> resetTutorial() async {
    await _prefs.setBool('tutorialSeen', false);
    notifyListeners();
  }

  /// Records a finished run. Returns true if it is a new best score.
  Future<bool> recordRun({
    required int score,
    required int coinsCollected,
    required int gemsCollected,
  }) async {
    final isBest = score > bestScore;
    if (isBest) await _setInt('best', score);
    await _setInt('runs', runsPlayed + 1);
    await _setInt('coins', coins + coinsCollected);
    await _setInt('gems', gems + gemsCollected);
    notifyListeners();
    return isBest;
  }

  // ------------------------------------------------------------ characters

  CharacterId get selected {
    final name = _prefs.getString('selected');
    return CharacterId.values.firstWhere(
      (c) => c.name == name,
      orElse: () => CharacterId.meaza,
    );
  }

  Set<CharacterId> get unlocked {
    final list = _prefs.getStringList('unlocked') ?? const [];
    return {
      for (final c in characters)
        if (c.price == 0 || list.contains(c.id.name)) c.id,
    };
  }

  Future<void> select(CharacterId id) async {
    if (!unlocked.contains(id)) return;
    await _prefs.setString('selected', id.name);
    notifyListeners();
  }

  Future<bool> unlock(CharacterId id) async {
    final info = characterInfo(id);
    if (unlocked.contains(id)) return true;
    if (coins < info.price) return false;
    await _setInt('coins', coins - info.price);
    await _prefs.setStringList(
      'unlocked',
      [...unlocked.map((e) => e.name), id.name],
    );
    await _prefs.setString('selected', id.name);
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------- upgrades & items

  int upgradeLevel(PowerKind k) => _int('up_${k.name}');

  Map<PowerKind, double> get powerDurations => {
        for (final k in PowerKind.values) k: Economy.duration(k, upgradeLevel(k)),
      };

  Future<bool> buyUpgrade(PowerKind k) async {
    final lvl = upgradeLevel(k);
    if (lvl >= Economy.maxUpgradeLevel) return false;
    if (!await spendCoins(Economy.upgradeCosts[lvl])) return false;
    await _setInt('up_${k.name}', lvl + 1);
    notifyListeners();
    return true;
  }

  int get shields => _int('inv_shield');
  int get headStarts => _int('inv_headstart');

  Future<void> addShields(int n) async {
    await _setInt('inv_shield', shields + n);
    notifyListeners();
  }

  Future<void> addHeadStarts(int n) async {
    await _setInt('inv_headstart', headStarts + n);
    notifyListeners();
  }

  Future<bool> useShield() async {
    if (shields <= 0) return false;
    await addShields(-1);
    return true;
  }

  Future<bool> useHeadStart() async {
    if (headStarts <= 0) return false;
    await addHeadStarts(-1);
    return true;
  }

  // -------------------------------------------------------------- missions

  int get missionLevel => _int('mission_level');
  int get scoreMultiplier =>
      (1 + missionLevel).clamp(1, Economy.maxScoreMultiplier);
  List<Mission> get missions => missionsForLevel(missionLevel);

  List<int> get missionProgress {
    final raw = _prefs.getStringList('mission_progress');
    if (raw == null || raw.length != 3) return [0, 0, 0];
    return raw.map((e) => int.tryParse(e) ?? 0).toList();
  }

  /// Progress including an in-flight run (for the HUD and live toasts).
  List<int> liveProgress(List<int> runValues) {
    final stored = missionProgress;
    final ms = missions;
    return [
      for (var i = 0; i < 3; i++)
        ms[i].perRun
            ? (runValues[i] > stored[i] ? runValues[i] : stored[i])
            : stored[i] + runValues[i],
    ];
  }

  /// Commits a run's values to the current mission set.
  Future<MissionUpdate> commitMissionRun(List<int> runValues) async {
    final ms = missions;
    final before = missionProgress;
    final after = liveProgress(runValues);
    final newly = <Mission>[
      for (var i = 0; i < 3; i++)
        if (before[i] < ms[i].target && after[i] >= ms[i].target) ms[i],
    ];
    await _prefs.setStringList('mission_progress', after.map((e) => '$e').toList());
    var setDone = false;
    if (List.generate(3, (i) => after[i] >= ms[i].target).every((d) => d)) {
      setDone = true;
      await _setInt('mission_level', missionLevel + 1);
      await _prefs.setStringList('mission_progress', const ['0', '0', '0']);
      await _setInt('coins', coins + 250 * missionLevel);
      await _setInt('gems', gems + 1);
    }
    notifyListeners();
    return MissionUpdate(newlyCompleted: newly, setCompleted: setDone);
  }

  /// Skip one mission for gems.
  Future<bool> skipMission(int index, int gemCost) async {
    if (!await spendGems(gemCost)) return false;
    final p = missionProgress;
    p[index] = missions[index].target;
    await _prefs.setStringList('mission_progress', p.map((e) => '$e').toList());
    await commitMissionRun(const [0, 0, 0]);
    return true;
  }

  // ---------------------------------------------------------- daily reward

  int get dailyStreak => _int('daily_streak');
  String? get lastDailyClaim => _prefs.getString('daily_last');

  /// Index (0-6) of today's reward, or null if already claimed today.
  int? get claimableDailyIndex {
    final now = DateTime.now();
    final today = dateKey(now);
    final last = lastDailyClaim;
    if (last == today) return null;
    final yesterday = dateKey(now.subtract(const Duration(days: 1)));
    final continuing = last == yesterday;
    return continuing ? dailyStreak % dailyRewards.length : 0;
  }

  Future<DailyReward?> claimDaily() async {
    final idx = claimableDailyIndex;
    if (idx == null) return null;
    final r = dailyRewards[idx];
    switch (r.kind) {
      case RewardKind.coins:
        await _setInt('coins', coins + r.amount);
      case RewardKind.gems:
        await _setInt('gems', gems + r.amount);
      case RewardKind.shield:
        await _setInt('inv_shield', shields + r.amount);
      case RewardKind.headStart:
        await _setInt('inv_headstart', headStarts + r.amount);
    }
    if (r.bonusGems > 0) await _setInt('gems', gems + r.bonusGems);
    await _setInt('daily_streak', idx + 1);
    await _prefs.setString('daily_last', dateKey(DateTime.now()));
    notifyListeners();
    return r;
  }

  // ------------------------------------------------------------ daily word

  String get dailyWord => wordForDate(DateTime.now());

  int get dailyWordCollected {
    if (_prefs.getString('word_date') != dateKey(DateTime.now())) return 0;
    return _int('word_count');
  }

  bool get dailyWordDone => dailyWordCollected >= dailyWord.length;

  String? get nextDailyLetter =>
      dailyWordDone ? null : dailyWord[dailyWordCollected];

  /// Adds a collected letter. Returns true if this completed the word.
  Future<bool> collectLetter(String letter) async {
    if (dailyWordDone || letter != nextDailyLetter) return false;
    final n = dailyWordCollected + 1;
    await _prefs.setString('word_date', dateKey(DateTime.now()));
    await _setInt('word_count', n);
    final done = n >= dailyWord.length;
    if (done) {
      await _setInt('coins', coins + dailyWordCoins);
      await _setInt('gems', gems + dailyWordGems);
    }
    notifyListeners();
    return done;
  }

  // -------------------------------------------------------------- danger

  /// Wipes progress but keeps the player's settings.
  Future<void> resetAll() async {
    for (final k in _prefs.getKeys().toList()) {
      if (!k.startsWith('set_')) await _prefs.remove(k);
    }
    notifyListeners();
  }
}
