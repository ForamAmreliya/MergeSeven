import 'hex_coord.dart';

enum TilePhase { spawn, idle, mergeOut, smash }

/// Immutable snapshot of a tile, used by the UI to render and animate.
class TileView {
  final int id;
  final int value;
  final HexCoord pos;
  final TilePhase phase;

  /// Incremented every time the tile upgrades, to retrigger its pop animation.
  final int pops;

  const TileView({required this.id, required this.value, required this.pos, required this.phase, required this.pops});
}

/// Mutable tile owned by the game logic.
class Tile {
  final int id;
  int value;
  HexCoord pos;
  TilePhase phase;
  int pops = 0;

  Tile({required this.id, required this.value, required this.pos, this.phase = TilePhase.spawn});

  TileView get view => TileView(id: id, value: value, pos: pos, phase: phase, pops: pops);
}

/// One-off things that happened in the game that the UI may celebrate.
sealed class GameEvent {
  const GameEvent();
}

class MergeEvent extends GameEvent {
  final HexCoord at;
  final int value;
  final int points;
  final int combo;
  const MergeEvent(this.at, this.value, this.points, this.combo);
}

class GoalReachedEvent extends GameEvent {
  final int goal;
  final int diamonds;
  const GoalReachedEvent(this.goal, this.diamonds);
}

class LevelUpEvent extends GameEvent {
  final int level;
  final int diamonds;
  const LevelUpEvent(this.level, this.diamonds);
}

/// Cheer text after a good move; higher [tier] means a better move.
class PraiseEvent extends GameEvent {
  final String text;
  final int tier;
  const PraiseEvent(this.text, this.tier);
}

class InvalidMoveEvent extends GameEvent {
  const InvalidMoveEvent();
}

class GameOverEvent extends GameEvent {
  const GameOverEvent();
}
