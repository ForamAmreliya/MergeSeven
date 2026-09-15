import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/responsive.dart';
import '../models/tile.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/ads/banner_ad_view.dart';
import '../widgets/board/board_view.dart';
import '../widgets/board/drag_controller.dart';
import '../widgets/common/bouncy_button.dart';
import '../widgets/common/confetti_overlay.dart';
import '../core/theme/app_colors.dart';
import '../widgets/common/game_banner.dart';
import '../widgets/game/boosters.dart';
import '../widgets/game/game_dialogs.dart';
import '../widgets/game/hud.dart';
import '../widgets/game/piece_tray.dart';
import '../widgets/common/praise_text.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final DragController _drag = DragController();
  final _confetti = GlobalKey<ConfettiOverlayState>();
  final _banner = GlobalKey<GameBannerState>();
  final _praise = GlobalKey<PraiseTextState>();
  StreamSubscription<GameEvent>? _sub;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    final game = context.read<GameProvider>();
    _drag.canPlace = game.canPlace;
    _sub = game.events.listen(_onEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && game.gameOver) _showGameOver();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _drag.dispose();
    super.dispose();
  }

  void _onEvent(GameEvent e) {
    if (!mounted) return;
    switch (e) {
      case GoalReachedEvent(:final goal, :final diamonds):
        _confetti.currentState?.burst(count: 140);
        _banner.currentState?.show(
          'GOAL $goal!',
          subtitle: '+$diamonds diamonds',
          icon: Icons.emoji_events_rounded,
          colors: const [Color(0xFFFFC94D), Color(0xFFFF7A00)],
        );
      case LevelUpEvent(:final level, :final diamonds):
        _confetti.currentState?.burst(count: 80);
        _banner.currentState?.show(
          'LEVEL $level',
          subtitle: '+$diamonds diamonds',
          icon: Icons.keyboard_double_arrow_up_rounded,
          colors: const [Color(0xFF9B7BFF), Color(0xFF14C3F0)],
        );
      case PraiseEvent(:final text, :final tier):
        _praise.currentState?.show(text, tier);
      case GameOverEvent():
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _showGameOver();
        });
      default:
        break;
    }
  }

  Future<void> _pause() async {
    if (_dialogOpen) return;
    _drag.cancel();
    _dialogOpen = true;
    final action = await showGameDialog<PauseAction>(context, const PauseDialog());
    _dialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case PauseAction.restart:
        context.read<GameProvider>().restartLevel();
      case PauseAction.home:
        Navigator.of(context).pop();
      default:
        break;
    }
  }

  Future<void> _showGameOver() async {
    final game = context.read<GameProvider>();
    if (_dialogOpen || !game.gameOver) return;
    _drag.cancel();
    _dialogOpen = true;
    final action = await showGameDialog<GameOverAction>(context, const GameOverDialog(), dismissible: false);
    _dialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case GameOverAction.revive:
        final paid = await payWithDiamondsOrAd(
          context,
          name: 'Continue',
          description: 'Clear the 7 smallest tiles and keep playing.',
          icon: Icons.favorite_rounded,
          colors: const [Color(0xFFFF9CE6), Color(0xFFD62FB4)],
          cost: GameProvider.costContinue,
        );
        if (!mounted) return;
        paid ? game.revive() : _showGameOver();
      case GameOverAction.restart:
        game.restartLevel();
      case GameOverAction.home:
      case null:
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = Responsive.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        // Plain, theme-coloured background so the board stands out.
        backgroundColor: context.palette.gameBg,
        // Full-width banner pinned to the bottom, right above the system
        // navigation bar. Takes no space until an ad has loaded.
        bottomNavigationBar: const BannerAdView(),
        body: Stack(
          children: [
            SafeArea(child: res.isLandscape ? _landscape(res) : _portrait(res)),
            Positioned.fill(child: FloatingPieceLayer(drag: _drag)),
            Positioned.fill(child: GameBanner(key: _banner)),
            Positioned.fill(child: ConfettiOverlay(key: _confetti)),
          ],
        ),
      ),
    );
  }

  Widget _topBar(double s) {
    return Row(
      children: [
        RoundIconButton(icon: Icons.pause_rounded, size: 44 * s, onTap: _pause),
        SizedBox(width: 10 * s),
        Expanded(child: LevelBar(scale: s)),
        SizedBox(width: 10 * s),
        Builder(
          builder: (context) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return RoundIconButton(
              icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 44 * s,
              onTap: () => context.read<SettingsProvider>().toggleDark(Theme.of(context).brightness),
            );
          },
        ),
      ],
    );
  }

  Widget _scoreRow(double s) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ScoreCard(scale: s),
          ),
        ),
        GoalBadge(scale: s),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: DiamondCard(scale: s),
          ),
        ),
      ],
    );
  }

  /// Board with the smash hint and praise words over its top edge, so showing
  /// the hint never resizes (and re-renders) the board.
  Widget _board(double s) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: 8 * s),
            child: BoardView(drag: _drag),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(child: _ModeHint(scale: s)),
        ),
        // Praise words swipe across the top of the board, under the score.
        Positioned(
          left: 0,
          right: 0,
          top: -4 * s,
          height: 84 * s,
          child: PraiseText(key: _praise),
        ),
      ],
    );
  }

  Widget _tray(double s, double width) {
    final side = math.min((width - 20 * s) / GameProvider.traySize, 130 * s);
    return SizedBox(
      height: side,
      child: PieceSlots(drag: _drag, scale: s),
    );
  }

  Widget _portrait(Responsive res) {
    final s = res.scale;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: LayoutBuilder(
          builder: (context, c) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 14 * s),
              child: Column(
                children: [
                  SizedBox(height: 8 * s),
                  _topBar(s),
                  SizedBox(height: 10 * s),
                  _scoreRow(s),
                  Expanded(child: _board(s)),
                  SizedBox(height: 10 * s),
                  BoosterBar(scale: s),
                  SizedBox(height: 8 * s),
                  _tray(s, c.maxWidth),
                  SizedBox(height: 10 * s),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _landscape(Responsive res) {
    final s = res.scale;
    return Padding(
      padding: EdgeInsets.all(12 * s),
      child: Row(
        children: [
          Expanded(
            child: Column(children: [Expanded(child: _board(s))]),
          ),
          SizedBox(width: 16 * s),
          SizedBox(
            width: math.min(440, res.size.width * 0.42),
            child: LayoutBuilder(
              builder: (context, c) => Column(
                children: [
                  _topBar(s),
                  SizedBox(height: 10 * s),
                  _scoreRow(s),
                  const Spacer(),
                  BoosterBar(scale: s),
                  SizedBox(height: 10 * s),
                  _tray(s, c.maxWidth),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeHint extends StatelessWidget {
  final double scale;
  const _ModeHint({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Selector<GameProvider, bool>(
      selector: (_, g) => g.hammerMode,
      builder: (context, hammer, _) {
        final (IconData icon, String text, List<Color> colors)? hint = hammer
            ? (Icons.gavel_rounded, 'Tap a tile to smash it', const [Color(0xFFFF9E80), Color(0xFFF0306A)])
            : null;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: hint == null
              ? const SizedBox.shrink()
              : Center(
                  key: ValueKey(hint.$2),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 6 * scale),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: hint.$3),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(hint.$1, color: Colors.white, size: 16 * scale),
                        SizedBox(width: 6 * scale),
                        Text(
                          hint.$2,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14 * scale),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
