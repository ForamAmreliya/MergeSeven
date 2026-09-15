import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/audio_service.dart';
import '../models/hex_coord.dart';
import '../models/piece.dart';
import '../models/tile.dart';
import 'player_provider.dart';

/// All rules of MergeSeven:
///  * Three pieces (one or two hexes) are dealt at a time. Drag any of them
///    onto empty cells; when all three are used a new set is dealt.
///  * Three or more touching tiles with the same number merge into the dropped
///    cell, doubling its value. Merges chain into combos.
///  * Merges give score and XP; reaching the goal tile or filling the XP bar
///    rewards diamonds. Boosters (undo, smash, shuffle) cost diamonds or a
///    video ad; continuing after game over needs a video ad.
///  * The game ends when none of the remaining pieces has room on the board.
class GameProvider extends ChangeNotifier {
  GameProvider(this._prefs, this._player, this._audio) {
    if (!_restore()) _reset();
  }

  final SharedPreferences _prefs;
  final PlayerProvider _player;
  final AudioService _audio;
  final math.Random _rng = math.Random();

  static const int boardRadius = 3;

  /// Diamond prices (each can also be paid by watching a video ad).
  static const int costUndo = 10;
  static const int costSmash = 20;
  static const int costShuffle = 20;
  static const int costContinue = 40;
  static const int traySize = 3;
  static const _saveKey = 'savedGame';

  // The player's level and goal live outside the saved game, so they survive
  // game overs, restarts and new games. "Reset progress" clears them.
  static const levelKey = 'currentLevel';
  static const goalKey = 'currentGoal';
  static const xpKey = 'currentXp';

  /// How many touching equal tiles are needed for a merge.
  static const int mergeCount = 3;

  static final List<HexCoord> cells = [
    for (var r = -boardRadius; r <= boardRadius; r++)
      for (var q = math.max(-boardRadius, -r - boardRadius); q <= math.min(boardRadius, -r + boardRadius); q++)
        HexCoord(q, r),
  ];
  static final Set<HexCoord> _cellSet = cells.toSet();

  static bool isOnBoard(HexCoord c) => _cellSet.contains(c);

  // ------------------------------------------------------------------ state
  final Map<HexCoord, Tile> _board = {};
  final LinkedHashMap<int, Tile> _tiles = LinkedHashMap();
  int _nextId = 1;

  List<Piece?> _tray = List.filled(traySize, null);

  int _score = 0;
  int _level = 1;
  int _xp = 0;
  int _goal = 32;
  int _peak = 2;
  int _combo = 0;
  int _biggestGroup = 0;

  bool _busy = false;
  bool _gameOver = false;
  bool _hammerMode = false;
  _Snapshot? _undo;

  int _tilesVersion = 0;
  List<TileView>? _viewsCache;

  final _events = StreamController<GameEvent>.broadcast();

  // ---------------------------------------------------------------- getters
  Stream<GameEvent> get events => _events.stream;

  /// The three piece slots; a slot is null once its piece has been used.
  List<Piece?> get tray => _tray;
  int get score => _score;
  int get level => _level;
  int get xp => _xp;
  int get xpToNext => 30 + (_level - 1) * 12;
  double get levelProgress => (_xp / xpToNext).clamp(0.0, 1.0);
  int get goal => _goal;
  bool get busy => _busy;
  bool get gameOver => _gameOver;
  bool get hammerMode => _hammerMode;
  bool get canUndo => _undo != null && !_busy;
  int get tilesVersion => _tilesVersion;
  int get highestTile => _board.values.fold(0, (m, t) => math.max(m, t.value));
  bool get hasSavedGame => _prefs.containsKey(_saveKey);

  List<TileView> get tiles => _viewsCache ??= _tiles.values.map((t) => t.view).toList(growable: false);

  bool isEmpty(HexCoord c) => isOnBoard(c) && !_board.containsKey(c);

  bool canPlace(Piece piece, HexCoord anchor) => piece.cellsAt(anchor).every(isEmpty);

  // ------------------------------------------------------------- lifecycle
  /// Starts a new game (New Game or Restart): only the board, score and
  /// pieces are cleared. The player stays on the same level with the same
  /// level-bar progress and goal (so goal rewards can't be farmed).
  void newGame() {
    _reset();
    _level = _prefs.getInt(levelKey) ?? 1;
    _xp = _prefs.getInt(xpKey) ?? 0;
    _goal = _prefs.getInt(goalKey) ?? 32;
    _dealTray(); // deal again so pieces match the level
    _player.gameStarted();
    _save();
    notifyListeners();
  }

  /// Restart button (same as a new game at the current level).
  void restartLevel() => newGame();

  void _reset() {
    _board.clear();
    _tiles.clear();
    _score = 0;
    _level = 1;
    _xp = 0;
    _goal = 32;
    _peak = 2;
    _undo = null;
    _busy = false;
    _gameOver = false;
    _hammerMode = false;
    _dealTray();
    _tilesChanged();
  }

  // ---------------------------------------------------------------- actions
  void rejectDrop() {
    _audio.play(Sfx.error, volume: 0.5);
    _events.add(const InvalidMoveEvent());
  }

  /// Drops the piece from tray [slot] with its first hex on [anchor].
  Future<void> place(int slot, HexCoord anchor) async {
    final piece = _tray[slot];
    if (_busy || _gameOver || piece == null || !canPlace(piece, anchor)) {
      rejectDrop();
      return;
    }
    _undo = _snapshot();
    _hammerMode = false;
    final placed = piece.cellsAt(anchor);
    for (var i = 0; i < placed.length; i++) {
      _addTile(piece.values[i], placed[i]);
    }
    _tray = [..._tray]..[slot] = null;
    _busy = true;
    _tilesChanged();
    _audio.play(Sfx.place);
    _audio.haptic();
    notifyListeners();

    await _delay(120);
    _combo = 0;
    _biggestGroup = 0;
    for (final cell in placed) {
      await _resolve(cell);
    }
    _praise();
    if (_tray.every((p) => p == null)) _dealTray();
    _endTurn();
  }

  // ----------------------------------------------------------------- merges
  Future<void> _resolve(HexCoord cell) async {
    while (true) {
      final anchor = _board[cell];
      if (anchor == null) return;
      final group = _flood(cell, anchor.value);
      if (group.length < mergeCount) return;

      _combo++;
      _biggestGroup = math.max(_biggestGroup, group.length);
      final absorbed = <Tile>[];
      for (final c in group) {
        if (c == cell) continue;
        final t = _board.remove(c)!;
        t
          ..pos = cell
          ..phase = TilePhase.mergeOut;
        absorbed.add(t);
      }
      _tilesChanged();
      _audio.merge(_combo);
      _audio.haptic(_combo > 2 ? HapticStrength.medium : HapticStrength.light);
      notifyListeners();

      await _delay(170);
      for (final t in absorbed) {
        _tiles.remove(t.id);
      }
      anchor
        ..value *= 2
        ..phase = TilePhase.idle
        ..pops += 1;
      final points = anchor.value * (group.length - 2) * _combo;
      _score += points;
      _peak = math.max(_peak, anchor.value);
      _xp += _log2(anchor.value) + (_combo - 1) * 2;
      _events.add(MergeEvent(cell, anchor.value, points, _combo));
      _checkGoal(anchor.value);
      _checkLevel();
      _tilesChanged();
      notifyListeners();
      await _delay(150);
    }
  }

  List<HexCoord> _flood(HexCoord start, int value, [Map<HexCoord, int>? extra]) {
    final seen = <HexCoord>{start};
    final queue = [start];
    while (queue.isNotEmpty) {
      final c = queue.removeLast();
      for (final n in c.neighbors) {
        if (!seen.contains(n) && (extra?[n] ?? _board[n]?.value) == value) {
          seen.add(n);
          queue.add(n);
        }
      }
    }
    return seen.toList();
  }

  /// Existing tiles that would merge if [piece] were dropped at [anchor].
  Set<HexCoord> mergePreview(Piece piece, HexCoord anchor) {
    final cells = piece.cellsAt(anchor);
    final placed = {for (var i = 0; i < cells.length; i++) cells[i]: piece.values[i]};
    final result = <HexCoord>{};
    placed.forEach((cell, value) {
      final group = _flood(cell, value, placed);
      if (group.length >= mergeCount) {
        result.addAll(group.where((c) => !placed.containsKey(c)));
      }
    });
    return result;
  }

  /// Cheers the player after a good move.
  void _praise() {
    if (_combo == 0) return;
    final (int tier, List<String> words) = switch (_combo) {
      >= 4 => (3, const ['UNBELIEVABLE!', 'INCREDIBLE!']),
      3 => (2, const ['PERFECT!', 'AMAZING!']),
      2 => (1, const ['EXCELLENT!', 'GREAT!']),
      _ when _biggestGroup >= 4 => (1, const ['EXCELLENT!', 'GREAT!']),
      _ => (0, const ['GOOD JOB!', 'NICE!', 'WELL DONE!']),
    };
    // Simple merges are cheered only now and then so it stays special.
    if (tier == 0 && _rng.nextDouble() > 0.4) return;
    final word = words[_rng.nextInt(words.length)];
    _events.add(PraiseEvent(word, tier));
    _audio.speak(word);
  }

  void _checkGoal(int value) {
    if (value < _goal) return;
    while (value >= _goal) {
      final reward = 10 + _log2(_goal) * 4;
      _player.addDiamonds(reward);
      _events.add(GoalReachedEvent(_goal, reward));
      _goal *= 2;
    }
    _audio.play(Sfx.coin);
    _audio.haptic(HapticStrength.heavy);
  }

  void _checkLevel() {
    while (_xp >= xpToNext) {
      _xp -= xpToNext;
      _level++;
      final reward = 5 + _level; // level 2 -> 7, level 10 -> 15
      _player.addDiamonds(reward);
      _events.add(LevelUpEvent(_level, reward));
      _audio.play(Sfx.levelUp);
    }
  }

  void _endTurn() {
    for (final t in _tiles.values) {
      t.phase = TilePhase.idle;
    }
    _busy = false;
    _player.reportProgress(score: _score, tile: highestTile, level: _level);
    _checkGameOver();
    _save();
    notifyListeners();
  }

  void _checkGameOver() {
    if (_gameOver || _anyPieceFits()) return;
    _gameOver = true;
    _hammerMode = false;
    _audio.play(Sfx.gameOver);
    _audio.haptic(HapticStrength.heavy);
    _events.add(const GameOverEvent());
  }

  bool _fits(Piece p) {
    for (final c in cells) {
      if (_board.containsKey(c)) continue;
      // Pieces keep the direction they were dealt with (no rotation).
      if (canPlace(p, c)) return true;
    }
    return false;
  }

  bool _anyPieceFits() => _tray.any((p) => p != null && _fits(p));

  /// Whether the piece in [slot] has room somewhere on the board.
  bool slotFits(int slot) {
    final p = _tray[slot];
    return p != null && _fits(p);
  }

  // --------------------------------------------------------------- boosters
  // Boosters are paid by the UI (diamonds or a video ad) before calling these.

  bool get canSmash => !_busy && !_gameOver && _board.isNotEmpty;
  bool get canShuffle => !_busy && !_gameOver;

  void undo() {
    if (!canUndo) return;
    _undo!.restoreInto(this);
    _undo = null;
    _gameOver = false;
    _hammerMode = false;
    _tilesChanged();
    _save();
    notifyListeners();
  }

  /// Deals a brand new set of three pieces.
  void refreshPieces() {
    if (!canShuffle) return;
    _hammerMode = false;
    _dealTray();
    _checkGameOver();
    _audio.play(Sfx.click);
    _save();
    notifyListeners();
  }

  void toggleHammer() {
    if (_busy || _gameOver) return;
    if (_hammerMode) {
      _hammerMode = false;
    } else if (_board.isEmpty) {
      _audio.play(Sfx.error, volume: 0.5);
      return;
    } else {
      _hammerMode = true;
      _audio.play(Sfx.click);
    }
    notifyListeners();
  }

  Future<void> smash(HexCoord cell) async {
    if (!_hammerMode || _busy || !_board.containsKey(cell)) return;
    _hammerMode = false;
    _undo = null;
    await _removeTiles([cell]);
    _endTurn();
  }

  /// A tap on the board: smashes the tile when the hammer is active.
  void tapCell(HexCoord cell) {
    if (_hammerMode && !_busy && !_gameOver) smash(cell);
  }

  /// Continue after game over by clearing the smallest tiles.
  Future<void> revive() async {
    if (!_gameOver) return;
    _gameOver = false;
    final sorted = _board.values.toList()..sort((a, b) => a.value - b.value);
    await _removeTiles(sorted.take(7).map((t) => t.pos).toList());
    _dealRescueTray();
    _endTurn();
  }

  /// After a paid Continue: replaces the stuck pieces with 3 new ones that
  /// each have room on the board, so the player is never left holding a
  /// piece that can't be placed.
  void _dealRescueTray() {
    _tray = [for (var i = 0; i < traySize; i++) _fittingPiece()];
  }

  Piece _fittingPiece() {
    for (var attempt = 0; attempt < 40; attempt++) {
      final piece = _generatePiece();
      if (_fits(piece)) return piece;
    }
    return Piece([_randomValue()]); // a single hex fits any empty cell
  }

  Future<void> _removeTiles(List<HexCoord> positions) async {
    _busy = true;
    final removed = <Tile>[];
    for (final p in positions) {
      final t = _board.remove(p);
      if (t == null) continue;
      t.phase = TilePhase.smash;
      removed.add(t);
    }
    _tilesChanged();
    _audio.play(Sfx.smash);
    _audio.haptic(HapticStrength.heavy);
    notifyListeners();
    await _delay(360);
    for (final t in removed) {
      _tiles.remove(t.id);
    }
    _tilesChanged();
  }

  // ----------------------------------------------------------------- pieces
  /// Deals three fresh pieces, preferring a set where at least one fits.
  void _dealTray() {
    var set = List<Piece?>.generate(traySize, (_) => _generatePiece());
    for (var attempt = 0; attempt < 8 && _board.isNotEmpty; attempt++) {
      if (set.any((p) => _fits(p!))) break;
      set = List<Piece?>.generate(traySize, (_) => _generatePiece());
    }
    _tray = set;
  }

  Piece _generatePiece() {
    final first = _randomValue();
    if (_rng.nextDouble() < 0.45) {
      final second = _rng.nextDouble() < 0.3 ? first : _randomValue();
      return Piece([first, second], turns: _rng.nextInt(6));
    }
    return Piece([first]);
  }

  int _randomValue() {
    // Highest number a new piece may carry. A new game deals only 2s; 4 is
    // unlocked once an 8 is made (or at level 3), 8 after a 16 (or level 5),
    // and so on up to 256.
    final maxExp = math.max(_log2(_peak) - 1, 1 + (_level - 1) ~/ 2).clamp(1, 8);

    // Half of the time deal a number that is already on the board, so pieces
    // are useful for building merges.
    if (_board.isNotEmpty && _rng.nextDouble() < 0.5) {
      final onBoard = [
        for (final t in _board.values)
          if (_log2(t.value) <= maxExp) t.value,
      ];
      if (onBoard.isNotEmpty) return onBoard[_rng.nextInt(onBoard.length)];
    }

    // Otherwise any number in range; smaller numbers are a bit more common.
    final weights = [for (var e = 1; e <= maxExp; e++) math.pow(0.6, e - 1)];
    var roll = _rng.nextDouble() * weights.fold<double>(0, (a, b) => a + b);
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return 1 << (i + 1);
    }
    return 2;
  }

  // ---------------------------------------------------------------- helpers
  void _addTile(int value, HexCoord pos, {TilePhase phase = TilePhase.spawn}) {
    final t = Tile(id: _nextId++, value: value, pos: pos, phase: phase);
    _board[pos] = t;
    _tiles[t.id] = t;
  }

  void _tilesChanged() {
    _tilesVersion++;
    _viewsCache = null;
  }

  static int _log2(int v) => v <= 1 ? 0 : (math.log(v) / math.ln2).round();

  static Future<void> _delay(int ms) => Future.delayed(Duration(milliseconds: ms));

  _Snapshot _snapshot() => _Snapshot(
    tiles: {for (final e in _board.entries) e.key: e.value.value},
    tray: _tray,
    score: _score,
    level: _level,
    xp: _xp,
    goal: _goal,
    peak: _peak,
  );

  // ------------------------------------------------------------ persistence
  void _save() {
    _prefs.setInt(levelKey, _level);
    _prefs.setInt(xpKey, _xp);
    _prefs.setInt(goalKey, _goal);
    if (_gameOver) {
      _prefs.remove(_saveKey);
      return;
    }
    _prefs.setString(_saveKey, jsonEncode(_snapshot().toJson()));
  }

  bool _restore() {
    final raw = _prefs.getString(_saveKey);
    if (raw == null) return false;
    try {
      _Snapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>).restoreInto(this);
      for (final t in _tiles.values) {
        t.phase = TilePhase.idle;
      }
      if (_tray.every((p) => p == null)) _dealTray();
      _prefs.setInt(levelKey, _level);
      _prefs.setInt(xpKey, _xp);
      _prefs.setInt(goalKey, _goal);
      _tilesChanged();
      _gameOver = !_anyPieceFits();
      return true;
    } catch (e) {
      debugPrint('Could not restore saved game: $e');
      _prefs.remove(_saveKey);
      return false;
    }
  }

  @override
  void dispose() {
    _events.close();
    super.dispose();
  }
}

class _Snapshot {
  final Map<HexCoord, int> tiles;
  final List<Piece?> tray;
  final int score, level, xp, goal, peak;

  _Snapshot({
    required this.tiles,
    required this.tray,
    required this.score,
    required this.level,
    required this.xp,
    required this.goal,
    required this.peak,
  });

  void restoreInto(GameProvider g) {
    g._board.clear();
    g._tiles.clear();
    tiles.forEach((pos, value) => g._addTile(value, pos, phase: TilePhase.spawn));
    g
      .._tray = List<Piece?>.of(tray)
      .._score = score
      .._level = level
      .._xp = xp
      .._goal = goal
      .._peak = peak;
  }

  Map<String, dynamic> toJson() => {
    'tiles': [
      for (final e in tiles.entries) [e.key.q, e.key.r, e.value],
    ],
    'tray': [for (final p in tray) p?.toJson()],
    'score': score,
    'level': level,
    'xp': xp,
    'goal': goal,
    'peak': peak,
  };

  factory _Snapshot.fromJson(Map<String, dynamic> j) {
    Piece? piece(Object? json) => json == null ? null : Piece.fromJson(json as Map<String, dynamic>);
    final List<Piece?> tray;
    if (j['tray'] is List) {
      tray = [for (final p in j['tray'] as List) piece(p)];
    } else {
      // Saves from the older single-piece version.
      tray = [piece(j['current']), piece(j['next']), piece(j['hold'])];
    }
    return _Snapshot(
      tiles: {for (final t in (j['tiles'] as List).cast<List>()) HexCoord(t[0] as int, t[1] as int): t[2] as int},
      tray: [...tray.take(GameProvider.traySize), for (var i = tray.length; i < GameProvider.traySize; i++) null],
      score: j['score'] as int,
      level: j['level'] as int,
      xp: j['xp'] as int,
      goal: j['goal'] as int,
      peak: j['peak'] as int,
    );
  }
}
