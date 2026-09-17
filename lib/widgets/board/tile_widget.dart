import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/tile.dart';
import '../hex/hex_tile.dart';
import 'board_geometry.dart';

/// A board tile that animates spawning, sliding into merges, upgrading and
/// being smashed.
class TileWidget extends StatelessWidget {
  final TileView tile;
  final BoardGeometry geo;

  const TileWidget({super.key, required this.tile, required this.geo});

  @override
  Widget build(BuildContext context) {
    final r = geo.tileRadius;
    final w = math.sqrt(3) * r;
    final c = geo.centerOf(tile.pos);
    final leaving = tile.phase == TilePhase.mergeOut;
    final smashed = tile.phase == TilePhase.smash;
    return AnimatedPositioned(
      duration: Duration(milliseconds: leaving ? 140 : 190),
      curve: leaving ? Curves.easeInCubic : Curves.easeOut,
      left: c.dx - w / 2,
      top: c.dy - r,
      width: w,
      height: r * 2,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: smashed ? 320 : 170),
        opacity: leaving || smashed ? 0 : 1,
        child: AnimatedScale(
          duration: Duration(milliseconds: smashed ? 320 : 170),
          curve: smashed ? Curves.easeOutBack : Curves.easeIn,
          scale: smashed ? 1.5 : (leaving ? 0.7 : 1),
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 320),
            turns: smashed ? 0.15 : 0,
            child: _PopTile(value: tile.value, radius: r, pops: tile.pops, spawn: tile.phase == TilePhase.spawn),
          ),
        ),
      ),
    );
  }
}

class _PopTile extends StatefulWidget {
  final int value;
  final double radius;
  final int pops;
  final bool spawn;

  const _PopTile({required this.value, required this.radius, required this.pops, required this.spawn});

  @override
  State<_PopTile> createState() => _PopTileState();
}

class _PopTileState extends State<_PopTile> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.spawn ? 0 : 1,
  );
  late Animation<double> _scale = _spawnAnim();

  Animation<double> _spawnAnim() =>
      Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut));

  Animation<double> _popAnim() => TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.28).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 65),
  ]).animate(_c);

  @override
  void initState() {
    super.initState();
    if (widget.spawn) _c.forward();
  }

  @override
  void didUpdateWidget(_PopTile old) {
    super.didUpdateWidget(old);
    if (widget.pops != old.pops) {
      _scale = _popAnim();
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: HexTile(value: widget.value, radius: widget.radius),
    );
  }
}
