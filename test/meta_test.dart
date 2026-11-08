import 'package:addis_surfers/game/entities.dart';
import 'package:addis_surfers/meta/daily.dart';
import 'package:addis_surfers/meta/economy.dart';
import 'package:addis_surfers/meta/missions.dart';
import 'package:addis_surfers/progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('mission sets have three distinct missions with growing targets', () {
    for (var level = 0; level < 40; level++) {
      final ms = missionsForLevel(level);
      expect(ms.length, 3);
      expect(ms.map((m) => m.type).toSet().length, 3);
      expect(ms.every((m) => m.target > 0), isTrue);
    }
    final t0 = missionsForLevel(0).first.target;
    expect(t0, greaterThan(0));
  });

  test('upgrades lengthen power-ups and revive costs double', () {
    for (final k in Economy.upgradable) {
      expect(Economy.duration(k, 5), greaterThan(Economy.duration(k, 0)));
    }
    expect([0, 1, 2, 3].map(Economy.reviveCost).toList(), [1, 2, 4, 8]);
  });

  test('daily words are valid and have meanings', () {
    for (final w in dailyWords) {
      expect(RegExp(r'^[A-Z]+$').hasMatch(w), isTrue, reason: w);
      expect(dailyWordMeanings.containsKey(w), isTrue, reason: w);
    }
    expect(dailyWords.contains(wordForDate(DateTime(2026, 11, 8))), isTrue);
  });

  group('Progress', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('daily reward can be claimed once per day', () async {
      final p = await Progress.load();
      expect(p.claimableDailyIndex, 0);
      final r = await p.claimDaily();
      expect(r, isNotNull);
      expect(p.coins, dailyRewards[0].amount);
      expect(p.claimableDailyIndex, isNull);
      expect(await p.claimDaily(), isNull);
    });

    test('daily word letters must be collected in order and pay out', () async {
      final p = await Progress.load();
      final word = p.dailyWord;
      expect(await p.collectLetter('#'), isFalse);
      for (var i = 0; i < word.length; i++) {
        expect(p.nextDailyLetter, word[i]);
        final done = await p.collectLetter(word[i]);
        expect(done, i == word.length - 1);
      }
      expect(p.dailyWordDone, isTrue);
      expect(p.coins, dailyWordCoins);
      expect(p.gems, dailyWordGems);
    });

    test('completing a mission set raises the multiplier', () async {
      final p = await Progress.load();
      expect(p.scoreMultiplier, 1);
      final targets = p.missions.map((m) => m.target).toList();
      final upd = await p.commitMissionRun(targets);
      expect(upd.setCompleted, isTrue);
      expect(p.scoreMultiplier, 2);
      expect(p.missionProgress, [0, 0, 0]);
      expect(p.gems, 1);
    });

    test('buying upgrades spends coins and caps at max level', () async {
      final p = await Progress.load();
      await p.addCoins(100000);
      for (var i = 0; i < Economy.maxUpgradeLevel; i++) {
        expect(await p.buyUpgrade(PowerKind.magnet), isTrue);
      }
      expect(await p.buyUpgrade(PowerKind.magnet), isFalse);
      expect(p.upgradeLevel(PowerKind.magnet), Economy.maxUpgradeLevel);
      final spent = Economy.upgradeCosts.reduce((a, b) => a + b);
      expect(p.coins, 100000 - spent);
    });

    test('reset keeps settings', () async {
      SharedPreferences.setMockInitialValues({'set_music': 0.2, 'coins': 50});
      final p = await Progress.load();
      await p.resetAll();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('set_music'), 0.2);
      expect(p.coins, 0);
    });
  });
}
