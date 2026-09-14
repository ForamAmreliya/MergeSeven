import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/audio_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/piece.dart';
import '../../providers/game_provider.dart';
import '../board/drag_controller.dart';
import '../hex/piece_view.dart';

/// Three piece slots. Drag any piece onto the board.
class PieceSlots extends StatelessWidget {
  final DragController drag;
  final double scale;

  const PieceSlots({super.key, required this.drag, required this.scale});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final gap = 10 * scale;
        final side = ((c.maxWidth - gap * 2) / GameProvider.traySize).clamp(60.0, c.maxHeight);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < GameProvider.traySize; i++) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox.square(
                dimension: side,
                child: _Slot(key: ValueKey('slot$i'), index: i, drag: drag, side: side),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  final int index;
  final DragController drag;
  final double side;

  const _Slot({super.key, required this.index, required this.drag, required this.side});

  void _startDrag(BuildContext context, Piece piece, Offset pointer) {
    final game = context.read<GameProvider>();
    if (game.busy || game.gameOver) return;
    if (game.hammerMode) game.toggleHammer();
    final box = context.findRenderObject() as RenderBox;
    drag.start(index, piece, pointer, box.localToGlobal(box.size.center(Offset.zero)));
    context.read<AudioService>().haptic();
  }

  void _endDrag(BuildContext context) {
    if (drag.piece == null || drag.slot != index) return;
    final target = drag.end();
    if (target != null) {
      context.read<GameProvider>().place(index, target);
    } else {
      context.read<AudioService>().play(Sfx.error, volume: 0.35);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cellRadius = side / 4.4;
    return Selector<GameProvider, (Piece?, bool)>(
      selector: (_, g) => (g.tray[index], g.tray[index] != null && !g.slotFits(index)),
      builder: (context, data, _) {
        final (piece, blocked) = data;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: piece == null ? null : (d) => _startDrag(context, piece, d.globalPosition),
          onPanUpdate: piece == null ? null : (d) => drag.update(d.globalPosition),
          onPanEnd: piece == null ? null : (_) => _endDrag(context),
          onPanCancel: piece == null ? null : () => _endDrag(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: p.slot,
              borderRadius: BorderRadius.circular(side * 0.18),
              border: Border.all(color: p.plateBorder, width: 1.5),
              boxShadow: [BoxShadow(color: p.plateEdge, offset: const Offset(0, 4))],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (piece != null)
                  ValueListenableBuilder<Piece?>(
                    valueListenable: drag.active,
                    builder: (context, dragging, child) => AnimatedOpacity(
                      duration: Duration(milliseconds: dragging != null ? 60 : 200),
                      opacity: dragging != null && drag.slot == index ? 0 : (blocked ? 0.4 : 1),
                      child: child,
                    ),
                    child: _DealIn(
                      key: ValueKey(piece.id),
                      delay: index * 0.18,
                      child: PieceView(piece: piece, cellRadius: cellRadius),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pops a freshly dealt piece in, staggered by slot.
class _DealIn extends StatelessWidget {
  final double delay;
  final Widget child;
  const _DealIn({super.key, required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + (delay * 1000).round()),
      builder: (context, t, child) {
        final local = ((t * (1 + delay)) - delay).clamp(0.0, 1.0);
        final v = Curves.easeOutBack.transform(local);
        return Opacity(
          opacity: local,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 30),
            child: Transform.scale(scale: 0.5 + 0.5 * v, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

/// Draws the dragged piece under the finger at full board size.
class FloatingPieceLayer extends StatelessWidget {
  final DragController drag;
  const FloatingPieceLayer({super.key, required this.drag});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<Piece?>(
        valueListenable: drag.active,
        builder: (context, piece, _) {
          if (piece == null) return const SizedBox.expand();
          final r = drag.geometry?.tileRadius ?? 30;
          final side = PieceView.boxSize(r);
          final view = TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: PieceView(piece: piece, cellRadius: r),
          );
          return ValueListenableBuilder<Offset?>(
            valueListenable: drag.position,
            child: view,
            builder: (context, global, child) {
              if (global == null) return const SizedBox.expand();
              final box = context.findRenderObject() as RenderBox?;
              final local = box != null && box.hasSize ? box.globalToLocal(global) : global;
              return Stack(
                children: [Positioned(left: local.dx - side / 2, top: local.dy - side / 2, child: child!)],
              );
            },
          );
        },
      ),
    );
  }
}
