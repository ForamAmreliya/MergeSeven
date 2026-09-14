import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../models/hex_coord.dart';
import '../../models/piece.dart';
import 'board_geometry.dart';

/// Tracks the piece being dragged. State is split into several small
/// notifiers so a finger move only repaints the floating piece, and the board
/// preview only repaints when the snapped target cell actually changes.
class DragController {
  final GlobalKey boardKey = GlobalKey();
  BoardGeometry? geometry;

  /// Returns whether the piece can be dropped with its first cell on anchor.
  bool Function(Piece piece, HexCoord anchor) canPlace = (_, _) => false;

  /// Global position of the floating piece centre; null when not dragging.
  final ValueNotifier<Offset?> position = ValueNotifier(null);

  /// Snapped anchor cell when the drop would be valid.
  final ValueNotifier<HexCoord?> target = ValueNotifier(null);

  /// The piece being dragged; null when idle.
  final ValueNotifier<Piece?> active = ValueNotifier(null);

  /// Tray slot the dragged piece came from.
  int slot = -1;

  Piece? get piece => active.value;
  Offset _grabOffset = Offset.zero;

  bool get isDragging => position.value != null;

  /// How far above the finger the piece floats, so it stays visible.
  double get _lift => (geometry?.cell ?? 30) * 2.4;

  void start(int fromSlot, Piece p, Offset pointer, Offset pieceCenter) {
    slot = fromSlot;
    active.value = p;
    // Keep the grab point horizontally but lift the piece above the finger.
    _grabOffset = Offset((pieceCenter.dx - pointer.dx) * 0.5, -_lift);
    update(pointer);
  }

  void update(Offset pointer) {
    final p = piece;
    if (p == null) return;
    final center = pointer + _grabOffset;
    position.value = center;
    target.value = _snap(p, center);
  }

  /// Ends the drag and returns the snapped cell, or null for an invalid drop.
  HexCoord? end() {
    final result = target.value;
    cancel();
    return result;
  }

  void cancel() {
    position.value = null;
    active.value = null;
    target.value = null;
  }

  HexCoord? _snap(Piece p, Offset globalCenter) {
    final geo = geometry;
    final box = boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (geo == null || box == null || !box.hasSize) return null;
    var local = box.globalToLocal(globalCenter);
    if (p.isPair) {
      final a = p.orientation * math.pi / 3;
      local -= Offset(math.cos(a), math.sin(a)) * (math.sqrt(3) * geo.cell / 2);
    }
    final anchor = geo.hit(local, tolerance: 1.25);
    if (anchor == null || !canPlace(p, anchor)) return null;
    return anchor;
  }

  void dispose() {
    position.dispose();
    active.dispose();
    target.dispose();
  }
}
