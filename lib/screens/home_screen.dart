import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../core/utils/routes.dart';
import '../providers/game_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common/bouncy_button.dart';
import '../widgets/common/game_background.dart';
import '../widgets/game/hud.dart';
import '../widgets/hex/hex_tile.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static void startNewGame(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    context.read<GameProvider>().newGame();
    if (!settings.tutorialSeen) {
      Navigator.of(context).push(fadeRoute(const HowToPlayScreen(openGameAfter: true)));
    } else {
      Navigator.of(context).push(fadeRoute(const GameScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = Responsive.of(context);
    final s = res.scale;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 12 * s),
            child: Column(
              children: [
                _Header(scale: s),
                Expanded(
                  child: res.isLandscape
                      ? Row(
                          children: [
                            Expanded(
                              child: Center(child: _Hero(scale: s)),
                            ),
                            SizedBox(width: 24 * s),
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(child: _Menu(scale: s)),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              children: [
                                const Spacer(),
                                _Hero(scale: s),
                                const Spacer(),
                                _Menu(scale: s),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final double scale;
  const _Header({required this.scale});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        DiamondCard(scale: scale),
        const Spacer(),
        RoundIconButton(
          icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: 46 * scale,
          onTap: () => context.read<SettingsProvider>().toggleDark(Theme.of(context).brightness),
        ),
        SizedBox(width: 10 * scale),
        RoundIconButton(
          icon: Icons.settings_rounded,
          size: 46 * scale,
          onTap: () => Navigator.of(context).push(fadeRoute(const SettingsScreen())),
        ),
      ],
    );
  }
}

/// Bobbing hex cluster logo and gradient title.
class _Hero extends StatefulWidget {
  final double scale;
  const _Hero({required this.scale});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = widget.scale;
    final r = 38.0 * s;
    final w = math.sqrt(3) * r;
    const tiles = [(2, 0.0, -0.9), (4, -0.55, 0.9), (8, 0.55, 0.9)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: w * 2.4,
          height: r * 4.2,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(
              children: [
                for (var i = 0; i < tiles.length; i++)
                  Positioned(
                    left: w * 1.2 + tiles[i].$2 * w * 1.04 - w / 2,
                    top: r * 2.1 + tiles[i].$3 * r - r + math.sin((_c.value + i / 3) * math.pi * 2) * 5 * s,
                    child: HexTile(value: tiles[i].$1, radius: r),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10 * s),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ShaderMask(
            shaderCallback: (rect) =>
                LinearGradient(colors: [p.accent, const Color(0xFFFF6FA5), const Color(0xFFFFB443)]).createShader(rect),
            child: Text(
              'MergeSeven',
              style: TextStyle(fontSize: 56 * s, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
            ),
          ),
        ),
        SizedBox(height: 4 * s),
        Text(
          'Hexa Merge Puzzle',
          style: TextStyle(fontSize: 17 * s, color: p.textMuted, fontWeight: FontWeight.w500, letterSpacing: 1.5),
        ),
      ],
    );
  }
}

class _Menu extends StatelessWidget {
  final double scale;
  const _Menu({required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Consumer<PlayerProvider>(
          builder: (context, player, _) => Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.emoji_events_rounded,
                  color: p.coin,
                  label: 'Best',
                  value: '${player.bestScore}',
                  scale: s,
                ),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: _StatTile(
                  label: 'Top tile',
                  value: player.bestTile == 0 ? '-' : formatTileValue(player.bestTile),
                  scale: s,
                  leading: HexTile(value: math.max(2, player.bestTile), radius: 11 * s),
                ),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: _StatTile(
                  icon: Icons.bar_chart_rounded,
                  color: p.accent2,
                  label: 'Level',
                  value: '${player.bestLevel}',
                  scale: s,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 22 * s),
        Selector<GameProvider, bool>(
          selector: (_, g) => g.hasSavedGame && !g.gameOver && (g.score > 0 || g.tiles.isNotEmpty),
          builder: (context, canContinue, _) => Column(
            children: [
              if (canContinue) ...[
                GradientButton(
                  label: 'CONTINUE',
                  icon: Icons.play_arrow_rounded,
                  height: 64 * s,
                  fontSize: 24 * s,
                  colors: const [Color(0xFF7CF29A), Color(0xFF12A67A)],
                  onTap: () => Navigator.of(context).push(fadeRoute(const GameScreen())),
                ),
                SizedBox(height: 12 * s),
              ],
              GradientButton(
                label: 'NEW GAME',
                icon: canContinue ? Icons.refresh_rounded : Icons.play_arrow_rounded,
                height: (canContinue ? 56 : 64) * s,
                fontSize: (canContinue ? 20 : 24) * s,
                colors: [const Color(0xFFB79CFF), p.accent],
                onTap: () => HomeScreen.startNewGame(context),
              ),
            ],
          ),
        ),
        SizedBox(height: 12 * s),
        GradientButton(
          label: 'HOW TO PLAY',
          icon: Icons.lightbulb_rounded,
          height: 52 * s,
          fontSize: 18 * s,
          colors: const [Color(0xFFFFD166), Color(0xFFFF9500)],
          onTap: () => Navigator.of(context).push(fadeRoute(const HowToPlayScreen())),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData? icon;
  final Color? color;
  final Widget? leading;
  final String label;
  final String value;
  final double scale;

  const _StatTile({this.icon, this.color, this.leading, required this.label, required this.value, required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = scale;
    return HudCard(
      padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 10 * s),
      child: Column(
        children: [
          SizedBox(
            height: 24 * s,
            child: Center(
              child: leading ?? Icon(icon, color: color, size: 24 * s),
            ),
          ),
          SizedBox(height: 4 * s),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(fontSize: 20 * s, fontWeight: FontWeight.w700, color: p.textPrimary, height: 1.1),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12 * s, color: p.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
