import 'dart:math' as math;
import 'dart:ui';

import '../../models/hex_coord.dart';
import '../../providers/game_provider.dart';

/// Maps board cells to pixels for a given layout size.
class BoardGeometry {
  final Size size;

  /// Circumradius of one cell (spacing unit; tiles are drawn slightly smaller).
  final double cell;

  const BoardGeometry(this.size, this.cell);

  /// Largest cell that fits the whole hexagon board inside [size].
  factory BoardGeometry.fit(Size size) {
    const r = GameProvider.boardRadius;
    final plateRadius = r * math.sqrt(3) + 1.15; // in cell units
    // Extra cell units for the plate's outline, halo and 3D bottom edge.
    final byWidth = size.width / (plateRadius * 2 + 0.5);
    final byHeight = size.height / (plateRadius * math.sqrt(3) + 0.8);
    return BoardGeometry(size, math.min(byWidth, byHeight));
  }

  Offset get center => size.center(Offset.zero);

  double get tileRadius => cell * 0.97;

  double get plateRadius => (GameProvider.boardRadius * math.sqrt(3) + 1.15) * cell;

  Offset centerOf(HexCoord c) => center + c.toPixel(cell);

  /// Cell under a local position, or null when outside the board.
  HexCoord? hit(Offset local, {double tolerance = 1.0}) {
    final h = HexCoord.fromPixel(local - center, cell);
    if (!GameProvider.isOnBoard(h)) return null;
    if ((centerOf(h) - local).distance > cell * tolerance) return null;
    return h;
  }
}
