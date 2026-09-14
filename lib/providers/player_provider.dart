import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Long-lived player progress shared by every screen.
class PlayerProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  PlayerProvider(this._prefs) {
    _coins = _prefs.getInt('coins') ?? 200;
    _bestScore = _prefs.getInt('bestScore') ?? 0;
    _bestTile = _prefs.getInt('bestTile') ?? 0;
    _gamesPlayed = _prefs.getInt('gamesPlayed') ?? 0;
    _bestLevel = _prefs.getInt('bestLevel') ?? 1;
  }

  late int _coins;
  late int _bestScore;
  late int _bestTile;
  late int _gamesPlayed;
  late int _bestLevel;

  int get coins => _coins;
  int get bestScore => _bestScore;
  int get bestTile => _bestTile;
  int get gamesPlayed => _gamesPlayed;
  int get bestLevel => _bestLevel;

  void addCoins(int amount) {
    _coins += amount;
    _prefs.setInt('coins', _coins);
    notifyListeners();
  }

  bool trySpend(int amount) {
    if (_coins < amount) return false;
    addCoins(-amount);
    return true;
  }

  void reportProgress({required int score, required int tile, required int level}) {
    var changed = false;
    if (score > _bestScore) {
      _bestScore = score;
      _prefs.setInt('bestScore', score);
      changed = true;
    }
    if (tile > _bestTile) {
      _bestTile = tile;
      _prefs.setInt('bestTile', tile);
      changed = true;
    }
    if (level > _bestLevel) {
      _bestLevel = level;
      _prefs.setInt('bestLevel', level);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void gameStarted() {
    _gamesPlayed++;
    _prefs.setInt('gamesPlayed', _gamesPlayed);
    notifyListeners();
  }

  void resetAll() {
    for (final k in ['coins', 'bestScore', 'bestTile', 'gamesPlayed', 'bestLevel']) {
      _prefs.remove(k);
    }
    _coins = 200;
    _bestScore = _bestTile = _gamesPlayed = 0;
    _bestLevel = 1;
    notifyListeners();
  }
}
