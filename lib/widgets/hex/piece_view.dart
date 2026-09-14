import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/piece.dart';
import 'hex_tile.dart';

/// Renders a [Piece] centred in a square box. Pairs smoothly spin to their
/// orientation.
class PieceView extends StatelessWidget {
  final Piece piece;
  final double cellRadius;
  final double opacity;

  const PieceView({super.key, required this.piece, required this.cellRadius, this.opacity = 1});

  /// Side length of the square box that fits the piece in any orientation.
  static double boxSize(double cellRadius) => math.sqrt(3) * cellRadius + cellRadius * 2.1;

  @override
  Widget build(BuildContext context) {
    final side = boxSize(cellRadius);
    if (!piece.isPair) {
      return SizedBox.square(
        dimension: side,
        child: Center(
          child: HexTile(value: piece.values[0], radius: cellRadius, opacity: opacity),
        ),
      );
    }
    return SizedBox.square(
      dimension: side,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: piece.turns * math.pi / 3),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (context, angle, _) {
          final half = math.sqrt(3) * cellRadius / 2;
          final dir = Offset(math.cos(angle), math.sin(angle)) * half;
          final center = Offset(side / 2, side / 2);
          return Stack(
            clipBehavior: Clip.none,
            children: [_cell(center - dir, piece.values[0]), _cell(center + dir, piece.values[1])],
          );
        },
      ),
    );
  }

  Widget _cell(Offset c, int value) {
    final w = math.sqrt(3) * cellRadius;
    return Positioned(
      left: c.dx - w / 2,
      top: c.dy - cellRadius,
      child: HexTile(value: value, radius: cellRadius, opacity: opacity),
    );
  }
}
