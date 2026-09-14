import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../hex/hex_tile.dart';

/// Gradient backdrop with drifting translucent hexagons.
///
/// The animation lives in its own repaint boundary so it never forces the
/// content above it to rebuild or repaint.
class GameBackground extends StatefulWidget {
  final Widget child;
  final bool animate;

  const GameBackground({super.key, required this.child, this.animate = true});

  @override
  State<GameBackground> createState() => _GameBackgroundState();
}

class _GameBackgroundState extends State<GameBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(GameBackground old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

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
            child: RepaintBoundary(child: CustomPaint(painter: _HexDriftPainter(_c, p.accent, p.accent2))),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _HexDriftPainter extends CustomPainter {
  final Animation<double> t;
  final Color a;
  final Color b;

  _HexDriftPainter(this.t, this.a, this.b) : super(repaint: t);

  static final List<_Blob> _blobs = List.generate(12, (i) {
    final rng = math.Random(i * 97 + 13);
    return _Blob(
      rng.nextDouble(),
      rng.nextDouble(),
      18 + rng.nextDouble() * 46,
      rng.nextDouble() * math.pi * 2,
      rng.nextBool(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final blob in _blobs) {
      final phase = t.value * math.pi * 2 + blob.phase;
      final y = ((blob.y - t.value * 0.35) % 1.2 - 0.1) * size.height;
      final x = blob.x * size.width + math.sin(phase) * 18;
      final color = (blob.useA ? a : b).withValues(alpha: 0.09);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(phase * 0.5) * 0.4);
      canvas.drawPath(roundedHexPath(Offset.zero, blob.size), Paint()..color = color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HexDriftPainter old) => old.a != a || old.b != b;
}

class _Blob {
  final double x, y, size, phase;
  final bool useA;
  const _Blob(this.x, this.y, this.size, this.phase, this.useA);
}
