import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/game_provider.dart';
import '../../providers/player_provider.dart';
import '../hex/hex_tile.dart';

/// Rounded card used by HUD panels.
class HudCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const HudCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: p.cardBorder, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

/// Counts smoothly between values.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle style;
  const AnimatedCount({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(v.round().toString(), style: style, maxLines: 1),
    );
  }
}

class LevelBar extends StatelessWidget {
  final double scale;
  const LevelBar({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Selector<GameProvider, (int, double)>(
      selector: (_, g) => (g.level, g.levelProgress),
      builder: (context, data, _) {
        final (level, progress) = data;
        return SizedBox(
          height: 34 * scale,
          child: Row(
            children: [
              _LevelBadge(level: level, scale: scale, filled: true),
              Expanded(
                child: Container(
                  height: 16 * scale,
                  margin: EdgeInsets.symmetric(horizontal: 4 * scale),
                  padding: EdgeInsets.all(3 * scale),
                  decoration: BoxDecoration(color: p.barTrack, borderRadius: BorderRadius.circular(20)),
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: progress),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => Container(
                          width: math.max(c.maxWidth * v, 10 * scale),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(colors: [Color(0xFF7CF29A), Color(0xFF14C3F0)]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _LevelBadge(level: level + 1, scale: scale, filled: false),
            ],
          ),
        );
      },
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int level;
  final double scale;
  final bool filled;
  const _LevelBadge({required this.level, required this.scale, required this.filled});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey(level),
        width: 34 * scale,
        height: 34 * scale,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: filled ? LinearGradient(colors: [p.accent, p.accent2]) : null,
          color: filled ? null : p.card,
          border: Border.all(color: filled ? Colors.white.withValues(alpha: 0.8) : p.cardBorder, width: 2),
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              '$level',
              style: TextStyle(
                fontSize: 15 * scale,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : p.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScoreCard extends StatelessWidget {
  final double scale;
  const ScoreCard({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return HudCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SCORE',
            style: TextStyle(fontSize: 11 * scale, color: p.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Selector<GameProvider, int>(
              selector: (_, g) => g.score,
              builder: (_, score, _) => AnimatedCount(
                value: score,
                style: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.w700, color: p.textPrimary, height: 1.1),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded, size: 15 * scale, color: p.coin),
              SizedBox(width: 3 * scale),
              Selector<PlayerProvider, int>(
                selector: (_, pl) => pl.bestScore,
                builder: (_, best, _) => Text(
                  '$best',
                  style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w600, color: p.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CoinCard extends StatelessWidget {
  final double scale;
  const CoinCard({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return HudCard(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 8 * scale),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoinIcon(size: 24 * scale),
          SizedBox(width: 6 * scale),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Selector<PlayerProvider, int>(
                selector: (_, pl) => pl.coins,
                builder: (_, coins, _) => AnimatedCount(
                  value: coins,
                  style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w700, color: p.textPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE17A), Color(0xFFFFA800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFFFF3C4), width: size * 0.08),
      ),
      child: Icon(Icons.star_rounded, size: size * 0.66, color: Colors.white),
    );
  }
}

/// The goal tile to reach. Static glow (no per-frame work); it pops when a
/// new goal is set.
class GoalBadge extends StatelessWidget {
  final double scale;
  const GoalBadge({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = scale;
    return Selector<GameProvider, int>(
      selector: (_, g) => g.goal,
      builder: (context, goal, _) {
        final style = TileColors.of(goal);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 84 * s,
              height: 84 * s,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(size: Size.square(84 * s), painter: _GlowHexPainter(style.dark, p.card)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                      child: child,
                    ),
                    child: HexTile(key: ValueKey(goal), value: goal, radius: 30 * s),
                  ),
                ],
              ),
            ),
            Text(
              'GOAL',
              style: TextStyle(
                fontSize: 11 * s,
                fontWeight: FontWeight.w700,
                color: p.textMuted,
                letterSpacing: 2,
                height: 1,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GlowHexPainter extends CustomPainter {
  final Color color;
  final Color card;
  _GlowHexPainter(this.color, this.card);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // Soft halo from layered translucent hexes instead of an expensive blur.
    for (final (scale, alpha) in const [(1.0, 0.10), (0.96, 0.14), (0.93, 0.2)]) {
      canvas.drawPath(roundedHexPath(c, r * scale), Paint()..color = color.withValues(alpha: alpha));
    }
    canvas.drawPath(roundedHexPath(c, r * 0.88), Paint()..color = card);
  }

  @override
  bool shouldRepaint(_GlowHexPainter old) => old.color != color || old.card != card;
}
