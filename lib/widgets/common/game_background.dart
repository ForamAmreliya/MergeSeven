import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../hex/hex_tile.dart';

/// Gradient backdrop with soft hexagons.
///
/// It is painted once and never animates, so no screen pays for a background
/// that keeps redrawing while the player is reading or playing.
class GameBackground extends StatelessWidget {
  final Widget child;

  const GameBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bgTop, p.bgBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: _HexPainter(p.accent, p.accent2))),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  final Color a;
  final Color b;

  const _HexPainter(this.a, this.b);

  static final List<_Blob> _blobs = List.generate(12, (i) {
    final rng = math.Random(i * 97 + 13);
    return _Blob(
      rng.nextDouble(),
      rng.nextDouble(),
      18 + rng.nextDouble() * 46,
      (rng.nextDouble() - 0.5) * 0.8,
      rng.nextBool(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final blob in _blobs) {
      canvas.save();
      canvas.translate(blob.x * size.width, blob.y * size.height);
      canvas.rotate(blob.angle);
      canvas.drawPath(
        roundedHexPath(Offset.zero, blob.size),
        Paint()..color = (blob.useA ? a : b).withValues(alpha: 0.09),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.a != a || old.b != b;
}

class _Blob {
  final double x, y, size, angle;
  final bool useA;
  const _Blob(this.x, this.y, this.size, this.angle, this.useA);
}
