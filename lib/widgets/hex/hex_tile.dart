import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Hexagon path with softly rounded corners.
Path roundedHexPath(Offset c, double r, {double corner = 0.2, bool flatTop = false}) {
  final start = flatTop ? 0.0 : -30.0;
  final pts = List.generate(6, (i) {
    final a = (start + 60.0 * i) * math.pi / 180;
    return c + Offset(math.cos(a), math.sin(a)) * r;
  });
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final p = pts[i];
    final a = Offset.lerp(p, pts[(i + 5) % 6], corner / 2)!;
    final b = Offset.lerp(p, pts[(i + 1) % 6], corner / 2)!;
    i == 0 ? path.moveTo(a.dx, a.dy) : path.lineTo(a.dx, a.dy);
    path.quadraticBezierTo(p.dx, p.dy, b.dx, b.dy);
  }
  return path..close();
}

String formatTileValue(int v) {
  if (v >= 1000000) return '${v ~/ 1000000}M';
  if (v >= 100000) return '${v ~/ 1000}K';
  return '$v';
}

/// Pre-renders every tile look once into a GPU image. Drawing a cached image
/// is far cheaper than repainting gradients, strokes and text shadows on every
/// frame, which keeps the board smooth on low-end phones.
class TileImageCache {
  TileImageCache._();

  static final Map<String, ui.Image> _images = {};

  /// Image height relative to the radius; leaves room for the drop shadow.
  static const heightFactor = 2.2;

  static ui.Image get(int value, double radius, double dpr) {
    final rPx = math.max(4, (radius * dpr).round()).toDouble();
    final key = '$value@${rPx.toInt()}';
    final cached = _images[key];
    if (cached != null) return cached;

    final w = (math.sqrt(3) * rPx).ceil();
    final h = (heightFactor * rPx).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _drawTile(canvas, Offset(w / 2, rPx), rPx, value);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    if (_images.length > 240) _images.clear();
    return _images[key] = image;
  }

  static void _drawTile(Canvas canvas, Offset c, double r, int value) {
    final style = TileColors.of(value);
    final depth = r * 0.1;
    final faceR = r * 0.9;

    // Ground shadow + 3D side.
    canvas.drawPath(
      roundedHexPath(c + Offset(0, depth * 1.6), faceR),
      Paint()..color = style.dark.withValues(alpha: 0.28),
    );
    canvas.drawPath(
      roundedHexPath(c + Offset(0, depth * 0.55), faceR),
      Paint()..color = Color.lerp(style.dark, Colors.black, 0.22)!,
    );

    // Gradient face.
    final faceCenter = c - Offset(0, depth * 0.45);
    final face = roundedHexPath(faceCenter, faceR);
    final rect = Rect.fromCircle(center: faceCenter, radius: faceR);
    canvas.drawPath(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.light, style.dark],
        ).createShader(rect),
    );

    // Gloss highlight on the upper half.
    canvas.save();
    canvas.clipPath(face);
    canvas.drawOval(
      Rect.fromCenter(center: faceCenter - Offset(r * 0.22, r * 0.55), width: r * 1.5, height: r * 0.9),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.restore();
    canvas.drawPath(
      roundedHexPath(faceCenter, faceR * 0.93),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..color = Colors.white.withValues(alpha: 0.28),
    );

    // Number.
    final label = formatTileValue(value);
    final factor = switch (label.length) {
      1 => 0.8,
      2 => 0.74,
      3 => 0.6,
      4 => 0.48,
      _ => 0.4,
    };
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: r * factor,
          height: 1.0,
          color: style.text,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.25), offset: Offset(0, r * 0.05), blurRadius: r * 0.06),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, faceCenter - Offset(tp.width / 2, tp.height / 2 + r * 0.02));
    tp.dispose();
  }
}

/// Paints one glossy number tile centred in the canvas.
class HexTilePainter extends CustomPainter {
  final int value;

  /// Circumradius of the hex. Defaults to half the canvas height.
  final double? radius;
  final double opacity;
  final double dpr;

  HexTilePainter(this.value, {this.radius, this.opacity = 1, this.dpr = 3});

  static final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius ?? size.height / 2;
    final c = size.center(Offset.zero);
    final image = TileImageCache.get(value, r, dpr);
    final w = math.sqrt(3) * r;
    _paint.color = Color.fromRGBO(255, 255, 255, opacity);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(c.dx - w / 2, c.dy - r, w, r * TileImageCache.heightFactor),
      _paint,
    );
  }

  @override
  bool shouldRepaint(HexTilePainter old) =>
      old.value != value || old.radius != radius || old.opacity != opacity || old.dpr != dpr;
}

/// A single number tile sized by its circumradius [radius].
class HexTile extends StatelessWidget {
  final int value;
  final double radius;
  final double opacity;

  const HexTile({super.key, required this.value, required this.radius, this.opacity = 1});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(math.sqrt(3) * radius, radius * 2),
      painter: HexTilePainter(value, radius: radius, opacity: opacity, dpr: MediaQuery.devicePixelRatioOf(context)),
    );
  }
}
