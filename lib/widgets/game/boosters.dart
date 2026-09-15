import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ads/ads_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/game_provider.dart';
import '../../providers/player_provider.dart';
import '../common/bouncy_button.dart';
import 'game_dialogs.dart';
import 'hud.dart';

class BoosterBar extends StatelessWidget {
  final double scale;
  const BoosterBar({super.key, required this.scale});

  /// Asks whether to pay [cost] diamonds or watch a video ad, then runs
  /// [action] if it is still allowed.
  static Future<void> _useBooster(
    BuildContext context, {
    required String name,
    required String description,
    required IconData icon,
    required List<Color> colors,
    required int cost,
    required bool Function() allowed,
    required VoidCallback action,
  }) async {
    if (!allowed()) return;
    final paid = await payWithDiamondsOrAd(
      context,
      name: name,
      description: description,
      icon: icon,
      colors: colors,
      cost: cost,
    );
    if (paid && context.mounted && allowed()) action();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<GameProvider, (bool, bool)>(
      selector: (_, g) => (g.canUndo && !g.gameOver, g.hammerMode),
      builder: (context, state, _) {
        final (canUndo, hammer) = state;
        final game = context.read<GameProvider>();
        const undoColors = [Color(0xFF6FD3FF), Color(0xFF2C7BF2)];
        const smashColors = [Color(0xFFFF9E80), Color(0xFFF0306A)];
        const shuffleColors = [Color(0xFF9DF5B0), Color(0xFF12A67A)];
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            BoosterButton(
              icon: Icons.undo_rounded,
              label: 'Undo',
              cost: GameProvider.costUndo,
              colors: undoColors,
              enabled: canUndo,
              scale: scale,
              onTap: () => _useBooster(
                context,
                name: 'Undo',
                description: 'Take back your last move.',
                icon: Icons.undo_rounded,
                colors: undoColors,
                cost: GameProvider.costUndo,
                allowed: () => game.canUndo && !game.gameOver,
                action: game.undo,
              ),
            ),
            BoosterButton(
              icon: Icons.gavel_rounded,
              label: hammer ? 'Cancel' : 'Smash',
              cost: GameProvider.costSmash,
              colors: smashColors,
              active: hammer,
              showBadge: !hammer,
              scale: scale,
              onTap: hammer
                  ? game.toggleHammer
                  : () => _useBooster(
                      context,
                      name: 'Smash',
                      description: 'Break any one tile on the board.',
                      icon: Icons.gavel_rounded,
                      colors: smashColors,
                      cost: GameProvider.costSmash,
                      allowed: () => game.canSmash && !game.hammerMode,
                      action: game.toggleHammer,
                    ),
            ),
            BoosterButton(
              icon: Icons.autorenew_rounded,
              label: 'Shuffle',
              cost: GameProvider.costShuffle,
              colors: shuffleColors,
              scale: scale,
              onTap: () => _useBooster(
                context,
                name: 'Shuffle',
                description: 'Get 3 brand new pieces.',
                icon: Icons.autorenew_rounded,
                colors: shuffleColors,
                cost: GameProvider.costShuffle,
                allowed: () => game.canShuffle,
                action: game.refreshPieces,
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _Pay { diamonds, ad }

/// Asks the player to pay [cost] diamonds or watch a video ad.
/// Returns true once paid (diamonds spent, or video watched).
Future<bool> payWithDiamondsOrAd(
  BuildContext context, {
  required String name,
  required String description,
  required IconData icon,
  required List<Color> colors,
  required int cost,
}) async {
  final choice = await showGameDialog<_Pay>(
    context,
    _DiamondOrAdDialog(name: name, description: description, icon: icon, colors: colors, cost: cost),
  );
  if (choice == null || !context.mounted) return false;
  switch (choice) {
    case _Pay.diamonds:
      if (!context.read<PlayerProvider>().trySpend(cost)) return false;
      context.read<AudioService>().play(Sfx.coin, volume: 0.7);
      return true;
    case _Pay.ad:
      return context.read<AdsService>().rewardGate(context);
  }
}

class _DiamondOrAdDialog extends StatelessWidget {
  final String name;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final int cost;

  const _DiamondOrAdDialog({
    required this.name,
    required this.description,
    required this.icon,
    required this.colors,
    required this.cost,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final diamonds = context.watch<PlayerProvider>().diamonds;
    final canPay = diamonds >= cost;
    return DialogCard(
      title: name,
      icon: icon,
      headerColors: colors,
      child: Column(
        children: [
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.3, color: p.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'You have ',
                style: TextStyle(fontSize: 15, color: p.textMuted, fontWeight: FontWeight.w500),
              ),
              const DiamondIcon(size: 20),
              const SizedBox(width: 4),
              Text(
                '$diamonds',
                style: TextStyle(fontSize: 18, color: p.textPrimary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'USE $cost',
            icon: Icons.diamond_rounded,
            colors: const [Color(0xFF6FD3FF), Color(0xFF2F6BFF)],
            onTap: canPay ? () => Navigator.pop(context, _Pay.diamonds) : null,
          ),
          if (!canPay)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Not enough diamonds',
                style: TextStyle(fontSize: 13, color: p.textMuted, fontWeight: FontWeight.w500),
              ),
            ),
          const SizedBox(height: 10),
          GradientButton(
            label: 'WATCH AD',
            icon: Icons.play_circle_fill_rounded,
            colors: const [Color(0xFFFFD166), Color(0xFFFF9500)],
            onTap: () => Navigator.pop(context, _Pay.ad),
          ),
        ],
      ),
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
  final bool showBadge;
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
    this.showBadge = true,
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
                if (widget.showBadge)
                  Positioned(
                    right: -8 * s,
                    top: -6 * s,
                    child: _PriceBadge(cost: widget.cost, scale: s),
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

/// Diamond price badge on a booster button.
class _PriceBadge extends StatelessWidget {
  final int cost;
  final double scale;
  const _PriceBadge({required this.cost, required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = scale;
    return Container(
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
          DiamondIcon(size: 13 * s),
          SizedBox(width: 2 * s),
          Text(
            '$cost',
            style: TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w700, color: p.textPrimary),
          ),
        ],
      ),
    );
  }
}
