import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tile.dart';
import '../../providers/game_provider.dart';
import '../hex/hex_tile.dart';
import 'board_geometry.dart';
import 'drag_controller.dart';
import 'tile_widget.dart';

class BoardView extends StatelessWidget {
  final DragController drag;

  const BoardView({super.key, required this.drag});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final geo = BoardGeometry.fit(constraints.biggest);
        drag.geometry = geo;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final cell = geo.hit(d.localPosition);
            if (cell != null) context.read<GameProvider>().tapCell(cell);
          },
          child: SizedBox(
            key: drag.boardKey,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Selector<GameProvider, bool>(
                    selector: (_, g) => g.hammerMode,
                    builder: (context, hammer, _) => CustomPaint(
                      painter: _BoardPainter(geo, palette, hammer, MediaQuery.devicePixelRatioOf(context)),
                    ),
                  ),
                ),
                Positioned.fill(child: _TilesLayer(geo: geo)),
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _PreviewPainter(
                          geo,
                          drag,
                          context.read<GameProvider>(),
                          MediaQuery.devicePixelRatioOf(context),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(child: _ScorePopups(geo: geo)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TilesLayer extends StatelessWidget {
  final BoardGeometry geo;
  const _TilesLayer({required this.geo});

  @override
  Widget build(BuildContext context) {
    return Selector<GameProvider, int>(
      selector: (_, g) => g.tilesVersion,
      builder: (context, _, _) {
        final tiles = context.read<GameProvider>().tiles;
        return Stack(
          clipBehavior: Clip.none,
          children: [for (final t in tiles) TileWidget(key: ValueKey(t.id), tile: t, geo: geo)],
        );
      },
    );
  }
}

/// Static board: a soft hexagon plate with recessed empty cells.
///
/// The ~80 shapes are rendered once into an image and then blitted, so the
/// board costs almost nothing per frame while pieces are dragged or merging.
class _BoardPainter extends CustomPainter {
  final BoardGeometry geo;
  final AppPalette p;
  final bool hammer;
  final double dpr;

  _BoardPainter(this.geo, this.p, this.hammer, this.dpr);

  static ui.Image? _image;
  static Object? _imageKey;

  @override
  void paint(Canvas canvas, Size size) {
    final key = (size, p, hammer, dpr);
    if (_image == null || _imageKey != key) {
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder)..scale(dpr);
      _draw(c);
      final picture = recorder.endRecording();
      _image = picture.toImageSync(math.max(1, (size.width * dpr).ceil()), math.max(1, (size.height * dpr).ceil()));
      picture.dispose();
      _imageKey = key;
    }
    final image = _image!;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, image.width / dpr, image.height / dpr),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _draw(Canvas canvas) {
    final c = geo.center;
    final plate = roundedHexPath(c, geo.plateRadius, corner: 0.16, flatTop: true);
    final ring = hammer ? const Color(0xFFFF5A6E) : p.plateBorder;

    // Soft halo, 3D bottom edge, then the solid plate.
    canvas.drawPath(
      roundedHexPath(c + Offset(0, geo.cell * 0.1), geo.plateRadius + geo.cell * 0.22, corner: 0.16, flatTop: true),
      Paint()..color = ring.withValues(alpha: 0.18),
    );
    canvas.drawPath(plate.shift(Offset(0, geo.cell * 0.2)), Paint()..color = p.plateEdge);
    canvas.drawPath(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(p.plate, Colors.white, 0.08)!, p.plate],
        ).createShader(Rect.fromCircle(center: c, radius: geo.plateRadius)),
    );
    canvas.drawPath(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geo.cell * (hammer ? 0.12 : 0.07)
        ..color = ring,
    );

    // Recessed empty cells.
    final r = geo.tileRadius * 0.9;
    final edge = Paint()..color = p.cellEdge;
    final face = Paint()..color = p.cell;
    for (final cell in GameProvider.cells) {
      final center = geo.centerOf(cell);
      canvas.drawPath(roundedHexPath(center, r), edge);
      canvas.drawPath(roundedHexPath(center + Offset(0, r * 0.07), r * 0.94), face);
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.geo.size != geo.size || old.p != p || old.hammer != hammer || old.dpr != dpr;
}

/// Ghost of the dragged piece and rings around the tiles it would merge with.
class _PreviewPainter extends CustomPainter {
  final BoardGeometry geo;
  final DragController drag;
  final GameProvider game;
  final double dpr;

  _PreviewPainter(this.geo, this.drag, this.game, this.dpr) : super(repaint: drag.target);

  @override
  void paint(Canvas canvas, Size size) {
    final anchor = drag.target.value;
    final piece = drag.piece;
    if (anchor == null || piece == null) return;
    final cells = piece.cellsAt(anchor);
    final r = geo.tileRadius;

    for (var i = 0; i < cells.length; i++) {
      final center = geo.centerOf(cells[i]);
      canvas.save();
      canvas.translate(center.dx - math.sqrt(3) * r / 2, center.dy - r);
      HexTilePainter(piece.values[i], radius: r, opacity: 0.5, dpr: dpr).paint(canvas, Size(math.sqrt(3) * r, r * 2));
      canvas.restore();
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..color = Colors.white.withValues(alpha: 0.9);
    for (final cell in game.mergePreview(piece, anchor)) {
      canvas.drawPath(roundedHexPath(geo.centerOf(cell) - Offset(0, r * 0.05), r * 0.9), ring);
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.geo.size != geo.size || old.drag != drag || old.dpr != dpr;
}

/// "+64" floating labels at each merge.
class _ScorePopups extends StatefulWidget {
  final BoardGeometry geo;
  const _ScorePopups({required this.geo});

  @override
  State<_ScorePopups> createState() => _ScorePopupsState();
}

class _ScorePopupsState extends State<_ScorePopups> {
  final List<_Popup> _popups = [];
  StreamSubscription<GameEvent>? _sub;
  int _ids = 0;

  @override
  void initState() {
    super.initState();
    _sub = context.read<GameProvider>().events.listen((e) {
      if (e is MergeEvent && mounted) {
        setState(() => _popups.add(_Popup(_ids++, e)));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cell = widget.geo.cell;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final p in _popups)
          Positioned(
            key: ValueKey(p.id),
            left: widget.geo.centerOf(p.event.at).dx - cell * 2,
            top: widget.geo.centerOf(p.event.at).dy - cell * 1.4,
            width: cell * 4,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              onEnd: () => setState(() => _popups.remove(p)),
              builder: (context, t, child) => Opacity(
                opacity: t < 0.7 ? 1 : (1 - t) / 0.3,
                child: Transform.translate(
                  offset: Offset(0, -cell * 1.2 * Curves.easeOut.transform(t)),
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * Curves.elasticOut.transform(math.min(1, t * 2.5)),
                    child: child,
                  ),
                ),
              ),
              child: _PopupLabel(event: p.event, cell: cell),
            ),
          ),
      ],
    );
  }
}

class _Popup {
  final int id;
  final MergeEvent event;
  _Popup(this.id, this.event);
}

class _PopupLabel extends StatelessWidget {
  final MergeEvent event;
  final double cell;
  const _PopupLabel({required this.event, required this.cell});

  @override
  Widget build(BuildContext context) {
    final color = TileColors.of(event.value).dark;
    TextStyle style(double size) => TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: size,
      color: Colors.white,
      height: 1,
      shadows: [
        Shadow(color: color, blurRadius: 0, offset: const Offset(0, 2)),
        Shadow(color: color.withValues(alpha: 0.6), offset: const Offset(0, 4)),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (event.combo > 1) Text('COMBO x${event.combo}', style: style(cell * 0.42)),
        Text('+${event.points}', style: style(cell * 0.62)),
      ],
    );
  }
}
