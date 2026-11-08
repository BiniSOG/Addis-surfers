import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'characters.dart';

/// Persistent player progress (coins, best score, unlocks).
class Progress extends ChangeNotifier {
  Progress._(this._prefs);

  static late Progress instance;

  static Future<Progress> load() async {
    final prefs = await SharedPreferences.getInstance();
    instance = Progress._(prefs);
    return instance;
  }

  final SharedPreferences _prefs;

  int get coins => _prefs.getInt('coins') ?? 0;
  int get bestScore => _prefs.getInt('best') ?? 0;
  int get runsPlayed => _prefs.getInt('runs') ?? 0;
  bool get tutorialSeen => _prefs.getBool('tutorialSeen') ?? false;

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

  Future<void> addCoins(int amount) async {
    await _prefs.setInt('coins', coins + amount);
    notifyListeners();
  }

  /// Records a finished run. Returns true if it is a new best score.
  Future<bool> recordRun({required int score, required int coinsCollected}) async {
    final isBest = score > bestScore;
    if (isBest) await _prefs.setInt('best', score);
    await _prefs.setInt('runs', runsPlayed + 1);
    await _prefs.setInt('coins', coins + coinsCollected);
    notifyListeners();
    return isBest;
  }

  Future<void> markTutorialSeen() => _prefs.setBool('tutorialSeen', true);

  Future<void> select(CharacterId id) async {
    if (!unlocked.contains(id)) return;
    await _prefs.setString('selected', id.name);
    notifyListeners();
  }

  /// Tries to buy [id]; returns false if the player can't afford it.
  Future<bool> unlock(CharacterId id) async {
    final info = characterInfo(id);
    if (unlocked.contains(id)) return true;
    if (coins < info.price) return false;
    await _prefs.setInt('coins', coins - info.price);
    await _prefs.setStringList(
      'unlocked',
      [...unlocked.map((e) => e.name), id.name],
    );
    await _prefs.setString('selected', id.name);
    notifyListeners();
    return true;
  }
}
