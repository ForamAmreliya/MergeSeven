import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/game_provider.dart';
import '../common/bouncy_button.dart';
import 'hud.dart';

class BoosterBar extends StatelessWidget {
  final double scale;
  const BoosterBar({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Selector<GameProvider, (bool, bool)>(
      selector: (_, g) => (g.canUndo && !g.gameOver, g.hammerMode),
      builder: (context, state, _) {
        final (canUndo, hammer) = state;
        final game = context.read<GameProvider>();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            BoosterButton(
              icon: Icons.undo_rounded,
              label: 'Undo',
              cost: GameProvider.costUndo,
              colors: const [Color(0xFF6FD3FF), Color(0xFF2C7BF2)],
              enabled: canUndo,
              scale: scale,
              onTap: game.undo,
            ),
            BoosterButton(
              icon: Icons.gavel_rounded,
              label: hammer ? 'Cancel' : 'Smash',
              cost: GameProvider.costHammer,
              colors: const [Color(0xFFFF9E80), Color(0xFFF0306A)],
              active: hammer,
              scale: scale,
              onTap: game.toggleHammer,
            ),
            BoosterButton(
              icon: Icons.autorenew_rounded,
              label: 'Shuffle',
              cost: GameProvider.costRefresh,
              colors: const [Color(0xFF9DF5B0), Color(0xFF12A67A)],
              scale: scale,
              onTap: game.refreshPieces,
            ),
          ],
        );
      },
    );
  }
}

class BoosterButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final int cost;
  final List<Color> colors;
  final bool enabled;
  final bool active;
  final double scale;
  final VoidCallback onTap;

  const BoosterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.cost,
    required this.colors,
    required this.scale,
    required this.onTap,
    this.enabled = true,
    this.active = false,
  });

  @override
  State<BoosterButton> createState() => _BoosterButtonState();
}

class _BoosterButtonState extends State<BoosterButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(BoosterButton old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = widget.scale;
    final size = 54 * s;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: BouncyButton(
        onTap: widget.enabled ? widget.onTap : null,
        sound: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: widget.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5 * s),
                      boxShadow: [
                        BoxShadow(
                          color: widget.colors.last.withValues(alpha: 0.35 + _pulse.value * 0.4),
                          spreadRadius: _pulse.value * 4,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: size * 0.48),
                ),
                Positioned(
                  right: -8 * s,
                  top: -6 * s,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 1.5 * s),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.cardBorder),
                      boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0, 2))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CoinIcon(size: 13 * s),
                        SizedBox(width: 2 * s),
                        Text(
                          '${widget.cost}',
                          style: TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w700, color: p.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4 * s),
            Text(
              widget.label,
              style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w600, color: p.textMuted, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}
