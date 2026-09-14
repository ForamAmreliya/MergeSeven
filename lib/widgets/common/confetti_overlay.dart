import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight confetti. Particle positions are computed from time alone, so
/// there is no per-frame allocation and nothing paints while idle.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => ConfettiOverlayState();
}

class ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  List<_Particle> _particles = const [];
  final _rng = math.Random();

  static const _colors = [
    Color(0xFF4FE3FF),
    Color(0xFF7CF29A),
    Color(0xFFFF8FA3),
    Color(0xFFB79CFF),
    Color(0xFFFFD166),
    Color(0xFFFF9CE6),
  ];

  void burst({int count = 110}) {
    _particles = List.generate(count, (i) {
      final angle = -math.pi / 2 + (_rng.nextDouble() - 0.5) * math.pi * 0.9;
      final speed = 0.55 + _rng.nextDouble() * 0.75;
      return _Particle(
        vx: math.cos(angle) * speed * 0.7,
        vy: math.sin(angle) * speed,
        spin: (_rng.nextDouble() - 0.5) * 16,
        sway: _rng.nextDouble() * 6,
        w: 6 + _rng.nextDouble() * 7,
        h: 9 + _rng.nextDouble() * 9,
        color: _colors[i % _colors.length],
        fromLeft: i.isEven,
      );
    });
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _ConfettiPainter(_c, this), size: Size.infinite),
      ),
    );
  }
}

class _Particle {
  final double vx, vy, spin, sway, w, h;
  final Color color;
  final bool fromLeft;
  const _Particle({
    required this.vx,
    required this.vy,
    required this.spin,
    required this.sway,
    required this.w,
    required this.h,
    required this.color,
    required this.fromLeft,
  });
}

class _ConfettiPainter extends CustomPainter {
  final AnimationController c;
  final ConfettiOverlayState state;

  _ConfettiPainter(this.c, this.state) : super(repaint: c);

  @override
  void paint(Canvas canvas, Size size) {
    if (!c.isAnimating) return;
    final t = c.value * 2.8; // seconds
    final fade = c.value > 0.75 ? (1 - c.value) / 0.25 : 1.0;
    final paint = Paint();
    for (final p in state._particles) {
      // Two cannons in the lower corners shooting inward and up.
      final ox = p.fromLeft ? 0.0 : size.width;
      final dirX = p.fromLeft ? 1.0 : -1.0;
      final x = ox + dirX * (p.vx.abs() + 0.15) * size.width * t * 0.9 + math.sin(t * p.sway) * 12;
      final y = size.height * 0.85 + p.vy * size.height * 1.5 * t + 0.55 * size.height * t * t;
      if (y > size.height + 20) continue;
      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      canvas.scale(1, math.cos(t * p.sway * 1.7).abs() * 0.8 + 0.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
