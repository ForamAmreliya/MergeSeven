import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Long-lived player progress shared by every screen.
class PlayerProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  /// Diamonds a brand-new player starts with.
  static const startingDiamonds = 0;

  // Diamonds are stored under the old 'coins' key so existing balances carry
  // over.
  static const _diamondsKey = 'coins';

  PlayerProvider(this._prefs) {
    _diamonds = _prefs.getInt(_diamondsKey) ?? startingDiamonds;
    _bestScore = _prefs.getInt('bestScore') ?? 0;
    _bestTile = _prefs.getInt('bestTile') ?? 0;
    _gamesPlayed = _prefs.getInt('gamesPlayed') ?? 0;
    _bestLevel = _prefs.getInt('bestLevel') ?? 1;
  }

  late int _diamonds;
  late int _bestScore;
  late int _bestTile;
  late int _gamesPlayed;
  late int _bestLevel;

  int get diamonds => _diamonds;
  int get bestScore => _bestScore;
  int get bestTile => _bestTile;
  int get gamesPlayed => _gamesPlayed;
  int get bestLevel => _bestLevel;

  void addDiamonds(int amount) {
    _diamonds += amount;
    _prefs.setInt(_diamondsKey, _diamonds);
    notifyListeners();
  }

  bool trySpend(int amount) {
    if (_diamonds < amount) return false;
    addDiamonds(-amount);
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
    for (final k in [
      _diamondsKey,
      'bestScore',
      'bestTile',
      'gamesPlayed',
      'bestLevel',
      'currentLevel',
      'currentGoal',
      'currentXp',
    ]) {
      _prefs.remove(k);
    }
    _diamonds = startingDiamonds;
    _bestScore = _bestTile = _gamesPlayed = 0;
    _bestLevel = 1;
    notifyListeners();
  }
}
