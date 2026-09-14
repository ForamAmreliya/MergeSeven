import 'dart:math' as math;
import 'dart:ui';

/// Axial coordinate on a pointy-top hexagon grid.
///
/// `q` grows to the right, `r` grows downward. The third cube coordinate is
/// `s = -q - r`.
class HexCoord {
  final int q;
  final int r;

  const HexCoord(this.q, this.r);

  int get s => -q - r;

  /// Clockwise neighbour directions, starting at "east" (0°) in 60° steps.
  static const List<HexCoord> directions = [
    HexCoord(1, 0),
    HexCoord(0, 1),
    HexCoord(-1, 1),
    HexCoord(-1, 0),
    HexCoord(0, -1),
    HexCoord(1, -1),
  ];

  HexCoord operator +(HexCoord other) => HexCoord(q + other.q, r + other.r);

  Iterable<HexCoord> get neighbors => directions.map((d) => this + d);

  int distanceTo(HexCoord o) => ((q - o.q).abs() + (r - o.r).abs() + (s - o.s).abs()) ~/ 2;

  /// Center of this cell in pixels for a hex of circumradius [size],
  /// relative to the center of cell (0, 0).
  Offset toPixel(double size) => Offset(size * math.sqrt(3) * (q + r / 2), size * 1.5 * r);

  /// Nearest cell to a pixel position (inverse of [toPixel]).
  static HexCoord fromPixel(Offset p, double size) {
    final fq = (math.sqrt(3) / 3 * p.dx - p.dy / 3) / size;
    final fr = (2 / 3 * p.dy) / size;
    return _round(fq, fr, -fq - fr);
  }

  static HexCoord _round(double fq, double fr, double fs) {
    var rq = fq.round();
    var rr = fr.round();
    final rs = fs.round();
    final dq = (rq - fq).abs();
    final dr = (rr - fr).abs();
    final ds = (rs - fs).abs();
    if (dq > dr && dq > ds) {
      rq = -rr - rs;
    } else if (dr > ds) {
      rr = -rq - rs;
    }
    return HexCoord(rq, rr);
  }

  List<int> toJson() => [q, r];

  factory HexCoord.fromJson(List<dynamic> j) => HexCoord(j[0] as int, j[1] as int);

  @override
  bool operator ==(Object other) => other is HexCoord && other.q == q && other.r == r;

  @override
  int get hashCode => q * 31 + r;

  @override
  String toString() => 'Hex($q,$r)';
}
