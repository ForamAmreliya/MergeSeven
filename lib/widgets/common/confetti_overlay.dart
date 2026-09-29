import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Lightweight confetti.
///
/// Every piece is drawn from one tiny image in a single `drawAtlas` call, with
/// buffers that are allocated once and reused, so a burst costs almost nothing
/// per frame. Positions come from the elapsed time alone and nothing paints
/// while idle.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => ConfettiOverlayState();
}

class ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final _rng = math.Random();

  /// Per-piece data, packed so painting only reads plain numbers.
  Float32List _data = Float32List(0);
  Int32List _baseColors = Int32List(0);

  // Reused every frame by the painter.
  Float32List _transforms = Float32List(0);
  Float32List _rects = Float32List(0);
  Int32List _colors = Int32List(0);

  static const _fields = 6; // vx, vy, spin, sway, scale, fromLeft
  static ui.Image? _piece;

  static const _palette = [
    Color(0xFF4FE3FF),
    Color(0xFF7CF29A),
    Color(0xFFFF8FA3),
    Color(0xFFB79CFF),
    Color(0xFFFFD166),
    Color(0xFFFF9CE6),
  ];

  /// One white rounded rectangle; colours come from the atlas call.
  static ui.Image _pieceImage() {
    if (_piece != null) return _piece!;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(1, 1, 14, 22), const Radius.circular(4)),
      Paint()..color = Colors.white,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(16, 24);
    picture.dispose();
    return _piece = image;
  }

  void burst({int count = 70}) {
    if (count * _fields != _data.length) {
      _data = Float32List(count * _fields);
      _baseColors = Int32List(count);
      _transforms = Float32List(count * 4);
      _rects = Float32List(count * 4);
      _colors = Int32List(count);
    }
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (_rng.nextDouble() - 0.5) * math.pi * 0.9;
      final speed = 0.55 + _rng.nextDouble() * 0.75;
      final o = i * _fields;
      _data[o] = math.cos(angle) * speed * 0.7;
      _data[o + 1] = math.sin(angle) * speed;
      _data[o + 2] = (_rng.nextDouble() - 0.5) * 12; // spin
      _data[o + 3] = 2 + _rng.nextDouble() * 5; // sway
      _data[o + 4] = 0.55 + _rng.nextDouble() * 0.5; // scale
      _data[o + 5] = i.isEven ? 1 : -1; // launched from left / right
      _baseColors[i] = _palette[i % _palette.length].toARGB32();
      // Source rectangle: the whole piece image.
      final r = i * 4;
      _rects[r] = 0;
      _rects[r + 1] = 0;
      _rects[r + 2] = 16;
      _rects[r + 3] = 24;
    }
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

class _ConfettiPainter extends CustomPainter {
  final AnimationController c;
  final ConfettiOverlayState state;

  _ConfettiPainter(this.c, this.state) : super(repaint: c);

  static final Paint _paint = Paint()..filterQuality = FilterQuality.low;

  @override
  void paint(Canvas canvas, Size size) {
    if (!c.isAnimating) return;
    final data = state._data;
    final count = data.length ~/ ConfettiOverlayState._fields;
    if (count == 0) return;

    final t = c.value * 2.6; // seconds
    final fade = c.value > 0.75 ? (1 - c.value) / 0.25 : 1.0;
    final alpha = (fade.clamp(0.0, 1.0) * 255).round();
    final transforms = state._transforms;
    final colors = state._colors;

    var visible = 0;
    for (var i = 0; i < count; i++) {
      final o = i * ConfettiOverlayState._fields;
      final vx = data[o];
      final vy = data[o + 1];
      final spin = data[o + 2];
      final sway = data[o + 3];
      final scale = data[o + 4];
      final fromLeft = data[o + 5] > 0;

      final y = size.height * 0.85 + vy * size.height * 1.5 * t + 0.55 * size.height * t * t;
      if (y > size.height + 24) continue;
      final ox = fromLeft ? 0.0 : size.width;
      final dir = fromLeft ? 1.0 : -1.0;
      final x = ox + dir * (vx.abs() + 0.15) * size.width * t * 0.9 + math.sin(t * sway) * 12;

      // RSTransform: scaled cosine / sine, then the translation.
      final angle = spin * t;
      final scos = math.cos(angle) * scale;
      final ssin = math.sin(angle) * scale;
      final v = visible * 4;
      transforms[v] = scos;
      transforms[v + 1] = ssin;
      transforms[v + 2] = x - (scos * 8 - ssin * 12);
      transforms[v + 3] = y - (ssin * 8 + scos * 12);
      colors[visible] = (state._baseColors[i] & 0x00FFFFFF) | (alpha << 24);
      visible++;
    }
    if (visible == 0) return;

    canvas.drawRawAtlas(
      ConfettiOverlayState._pieceImage(),
      Float32List.sublistView(transforms, 0, visible * 4),
      Float32List.sublistView(state._rects, 0, visible * 4),
      Int32List.sublistView(colors, 0, visible),
      BlendMode.modulate,
      null,
      _paint,
    );
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
