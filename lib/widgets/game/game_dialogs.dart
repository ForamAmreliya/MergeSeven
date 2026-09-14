import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/game_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../common/bouncy_button.dart';
import '../hex/hex_tile.dart';
import '../../models/piece.dart';
import '../hex/piece_view.dart';
import 'hud.dart';

/// Shows [child] in a springy popup card.
Future<T?> showGameDialog<T>(BuildContext context, Widget child, {bool dismissible = true}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'dialog',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (_, _, _) => child,
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut, reverseCurve: Curves.easeIn),
        child: child,
      ),
    ),
  );
}

class DialogCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final List<Color> headerColors;

  const DialogCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.headerColors = const [Color(0xFF9B7BFF), Color(0xFF14C3F0)],
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 30),
                  padding: const EdgeInsets.fromLTRB(22, 46, 22, 22),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: p.cardBorder, width: 2),
                    boxShadow: [
                      BoxShadow(color: headerColors.last.withValues(alpha: 0.3), offset: const Offset(0, 14)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: p.textPrimary),
                      ),
                      const SizedBox(height: 14),
                      child,
                    ],
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: headerColors),
                    border: Border.all(color: p.card, width: 5),
                  ),
                  child: Icon(icon ?? Icons.star_rounded, color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum PauseAction { resume, restart, home }

class PauseDialog extends StatelessWidget {
  const PauseDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DialogCard(
      title: 'Paused',
      icon: Icons.pause_rounded,
      child: Column(
        children: [
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ToggleChip(
                  icon: settings.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  label: 'Sound',
                  on: settings.sound,
                  onTap: () => settings.sound = !settings.sound,
                ),
                const SizedBox(width: 12),
                _ToggleChip(
                  icon: Icons.vibration_rounded,
                  label: 'Haptics',
                  on: settings.haptics,
                  onTap: () => settings.haptics = !settings.haptics,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: 'RESUME',
            icon: Icons.play_arrow_rounded,
            colors: const [Color(0xFF7CF29A), Color(0xFF12A67A)],
            onTap: () => Navigator.pop(context, PauseAction.resume),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: 'RESTART',
                  height: 50,
                  fontSize: 17,
                  colors: const [Color(0xFFFFD166), Color(0xFFFF9500)],
                  onTap: () => Navigator.pop(context, PauseAction.restart),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  label: 'HOME',
                  height: 50,
                  fontSize: 17,
                  colors: [p.accent.withValues(alpha: 0.85), p.accent],
                  onTap: () => Navigator.pop(context, PauseAction.home),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _ToggleChip({required this.icon, required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return BouncyButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: on ? p.accent : p.barTrack, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: on ? Colors.white : p.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: on ? Colors.white : p.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

enum GameOverAction { restart, revive, home }

/// Shown when none of the remaining pieces has room left on the board.
class GameOverDialog extends StatelessWidget {
  const GameOverDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final game = context.read<GameProvider>();
    final player = context.read<PlayerProvider>();
    final isBest = game.score > 0 && game.score >= player.bestScore;
    final canRevive = player.coins >= GameProvider.costRevive;
    return DialogCard(
      title: 'Out of Space!',
      icon: Icons.grid_off_rounded,
      headerColors: const [Color(0xFFFF8FA3), Color(0xFFF0306A)],
      child: Column(
        children: [
          Text(
            'There is no room on the board for these pieces.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.3, color: p.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          // The pieces that could not be placed.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0306A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF0306A).withValues(alpha: 0.45), width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final piece in game.tray.whereType<Piece>())
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: PieceView(piece: piece, cellRadius: 15),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(label: isBest ? 'NEW BEST!' : 'SCORE', value: '${game.score}'),
              ),
              Expanded(
                child: Column(
                  children: [
                    HexTile(value: game.highestTile == 0 ? 2 : game.highestTile, radius: 20),
                    const SizedBox(height: 4),
                    Text(
                      'TOP TILE',
                      style: TextStyle(fontSize: 11, color: p.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _Stat(label: 'LEVEL', value: '${game.level}'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: 'RESTART',
            icon: Icons.replay_rounded,
            colors: const [Color(0xFF7CF29A), Color(0xFF12A67A)],
            onTap: () => Navigator.pop(context, GameOverAction.restart),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: 'CONTINUE',
                  icon: Icons.favorite_rounded,
                  height: 50,
                  fontSize: 16,
                  colors: const [Color(0xFFFF9CE6), Color(0xFFD62FB4)],
                  onTap: canRevive ? () => Navigator.pop(context, GameOverAction.revive) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GradientButton(
                  label: 'HOME',
                  icon: Icons.home_rounded,
                  height: 50,
                  fontSize: 16,
                  colors: [p.accent.withValues(alpha: 0.85), p.accent],
                  onTap: () => Navigator.pop(context, GameOverAction.home),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CoinIcon(size: 15),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Continue: ${GameProvider.costRevive} coins, clears 7 tiles',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: p.textMuted, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        FittedBox(
          child: Text(
            value,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: p.textPrimary),
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: p.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
      ],
    );
  }
}
