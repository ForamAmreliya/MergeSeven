import 'hex_coord.dart';

/// A piece the player drops onto the board: one hex, or two joined hexes.
class Piece {
  final List<int> values;

  /// Total clockwise 60° turns applied. Kept unbounded so the rotation
  /// animation always spins forward; the orientation is `turns % 6`.
  final int turns;

  /// Unique per generated piece (kept across rotations) so the UI can animate
  /// a freshly dealt piece.
  final int id;

  static int _ids = 0;

  Piece(this.values, {this.turns = 0, int? id}) : id = id ?? ++_ids;

  bool get isPair => values.length == 2;

  int get orientation => turns % 6;

  HexCoord get direction => HexCoord.directions[orientation];

  Piece rotated() => Piece(values, turns: turns + 1, id: id);

  /// Cells covered when the first hex sits on [anchor].
  List<HexCoord> cellsAt(HexCoord anchor) => isPair ? [anchor, anchor + direction] : [anchor];

  Map<String, dynamic> toJson() => {'v': values, 't': turns};

  factory Piece.fromJson(Map<String, dynamic> j) => Piece((j['v'] as List).cast<int>(), turns: j['t'] as int? ?? 0);
}
