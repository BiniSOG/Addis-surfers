import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player settings, persisted on the device.
class GameSettings extends ChangeNotifier {
  GameSettings._(this._prefs);

  static late GameSettings instance;

  static Future<GameSettings> load() async {
    instance = GameSettings._(await SharedPreferences.getInstance());
    return instance;
  }

  final SharedPreferences _prefs;

  double get musicVolume => _prefs.getDouble('set_music') ?? 0.6;
  double get sfxVolume => _prefs.getDouble('set_sfx') ?? 0.9;
  bool get haptics => _prefs.getBool('set_haptics') ?? true;
  double get vibrationStrength => _prefs.getDouble('set_vib') ?? 0.8;

  Future<void> setVibrationStrength(double v) async {
    await _prefs.setDouble('set_vib', v.clamp(0.1, 1.0));
    notifyListeners();
  }
  bool get lowGraphics => _prefs.getBool('set_lowgfx') ?? false;
  bool get swipeHints => _prefs.getBool('set_hints') ?? true;

  Future<void> setMusicVolume(double v) async {
    await _prefs.setDouble('set_music', v);
    notifyListeners();
  }

  Future<void> setSfxVolume(double v) async {
    await _prefs.setDouble('set_sfx', v);
    notifyListeners();
  }

  Future<void> setHaptics(bool v) async {
    await _prefs.setBool('set_haptics', v);
    notifyListeners();
  }

  Future<void> setLowGraphics(bool v) async {
    await _prefs.setBool('set_lowgfx', v);
    notifyListeners();
  }
}
