import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/audio_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final AudioService audio;

  SettingsProvider(this._prefs, this.audio) {
    _sound = _prefs.getBool('sound') ?? true;
    _haptics = _prefs.getBool('haptics') ?? true;
    _voice = _prefs.getBool('voice') ?? true;
    _themeMode = ThemeMode.values[_prefs.getInt('themeMode') ?? 0];
    _tutorialSeen = _prefs.getBool('tutorialSeen') ?? false;
    audio
      ..soundOn = _sound
      ..hapticsOn = _haptics
      ..voiceOn = _voice;
  }

  late bool _sound;
  late bool _haptics;
  late bool _voice;
  late ThemeMode _themeMode;
  late bool _tutorialSeen;

  bool get sound => _sound;
  bool get haptics => _haptics;
  bool get voice => _voice;
  ThemeMode get themeMode => _themeMode;
  bool get tutorialSeen => _tutorialSeen;

  set sound(bool v) {
    _sound = audio.soundOn = v;
    _prefs.setBool('sound', v);
    notifyListeners();
  }

  set voice(bool v) {
    _voice = audio.voiceOn = v;
    _prefs.setBool('voice', v);
    notifyListeners();
  }

  set haptics(bool v) {
    _haptics = audio.hapticsOn = v;
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
