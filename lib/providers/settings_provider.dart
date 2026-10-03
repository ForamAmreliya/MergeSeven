import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/haptics_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final HapticsService _service;

  SettingsProvider(this._prefs, this._service) {
    _haptics = _prefs.getBool('haptics') ?? true;
    _themeMode = ThemeMode.values[_prefs.getInt('themeMode') ?? 0];
    _tutorialSeen = _prefs.getBool('tutorialSeen') ?? false;
    _service.hapticsOn = _haptics;
  }

  late bool _haptics;
  late ThemeMode _themeMode;
  late bool _tutorialSeen;

  bool get haptics => _haptics;
  ThemeMode get themeMode => _themeMode;
  bool get tutorialSeen => _tutorialSeen;

  set haptics(bool v) {
    _haptics = _service.hapticsOn = v;
    _prefs.setBool('haptics', v);
    notifyListeners();
  }

  set themeMode(ThemeMode v) {
    _themeMode = v;
    _prefs.setInt('themeMode', v.index);
    notifyListeners();
  }

  /// Flips between light and dark, resolving "system" against the platform.
  void toggleDark(Brightness current) {
    themeMode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void markTutorialSeen() {
    if (_tutorialSeen) return;
    _tutorialSeen = true;
    _prefs.setBool('tutorialSeen', true);
  }
}
