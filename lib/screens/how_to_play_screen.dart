import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../core/utils/routes.dart';
import '../providers/settings_provider.dart';
import '../widgets/common/bouncy_button.dart';
import '../widgets/common/game_background.dart';
import '../widgets/game/hud.dart';
import '../widgets/hex/hex_tile.dart';
import 'game_screen.dart';

class HowToPlayScreen extends StatefulWidget {
  final bool openGameAfter;
  const HowToPlayScreen({super.key, this.openGameAfter = false});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _count = 4;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _count - 1) {
      _pages.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      return;
    }
    context.read<SettingsProvider>().markTutorialSeen();
    if (widget.openGameAfter) {
      Navigator.of(context).pushReplacement(fadeRoute(const GameScreen()));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = Responsive.of(context).scale;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 12 * s),
                child: Column(
                  children: [
                    Row(
                      children: [
                        RoundIconButton(
                          icon: Icons.close_rounded,
                          size: 46 * s,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        Text(
                          'How to play',
                          style: TextStyle(fontSize: 24 * s, fontWeight: FontWeight.w700, color: p.textPrimary),
                        ),
                        const Spacer(),
                        SizedBox(width: 46 * s),
                      ],
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pages,
                        onPageChanged: (i) => setState(() => _index = i),
                        children: [
                          _Page(
                            title: 'Drag & Drop',
                            body:
                                'You get 3 pieces at a time. Drag any of them onto empty cells that match its shape. Use all 3 to get a new set.',
                            illustration: _DropDemo(scale: s),
                          ),
                          _Page(
                            title: 'Match 3 to Merge',
                            body:
                                'Connect 3 or more tiles with the same number and they merge into one tile with double the value.',
                            illustration: _MergeDemo(scale: s),
                          ),
                          _Page(
                            title: 'Chain Combos',
                            body:
                                'A merged tile keeps merging when it touches 2 more of the same number. Chains give huge bonus points!',
                            illustration: _ChainDemo(scale: s),
                          ),
                          _Page(
                            title: 'Goals & Boosters',
                            body:
                                'Reach the goal tile and level up to earn coins. Spend them on boosters when you get stuck.',
                            illustration: _BoosterDemo(scale: s),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _count; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _index ? 26 : 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: i == _index ? p.accent : p.barTrack,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 18 * s),
                    GradientButton(
                      label: _index == _count - 1 ? (widget.openGameAfter ? "LET'S PLAY" : 'GOT IT') : 'NEXT',
                      icon: _index == _count - 1 ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded,
                      height: 60 * s,
                      fontSize: 22 * s,
                      colors: [const Color(0xFFB79CFF), p.accent],
                      onTap: _next,
                    ),
                    SizedBox(height: 8 * s),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final String title;
  final String body;
  final Widget illustration;

  const _Page({required this.title, required this.body, required this.illustration});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HudCard(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: Center(child: illustration),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                title,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: p.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, height: 1.4, color: p.textMuted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Base for the looping tutorial animations.
abstract class _Demo extends StatefulWidget {
  final double scale;
  const _Demo({required this.scale});

  Duration get duration => const Duration(milliseconds: 2600);

  Widget buildFrame(BuildContext context, double t);

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(animation: _c, builder: (context, _) => widget.buildFrame(context, _c.value)),
  );
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

Widget _emptyCell(BuildContext context, double r) =>
    CustomPaint(size: Size(math.sqrt(3) * r, 2 * r), painter: _CellPainter(context.palette.cell));

class _CellPainter extends CustomPainter {
  final Color color;
  _CellPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(roundedHexPath(size.center(Offset.zero), size.height / 2 * 0.88), Paint()..color = color);

  @override
  bool shouldRepaint(_CellPainter old) => old.color != color;
}

class _DropDemo extends _Demo {
  const _DropDemo({required super.scale});

  @override
  Widget buildFrame(BuildContext context, double t) {
    final r = 30.0 * scale;
    final w = math.sqrt(3) * r;
    final move = Curves.easeInOutCubic.transform(_seg(t, 0.15, 0.55));
    final landed = t > 0.55;
    final start = Offset(w * 1.5, r * 4.2);
    final end = Offset(w * 1.5, r * 1.0);
    final pos = Offset.lerp(start, end, move)!;
    return SizedBox(
      width: w * 3,
      height: r * 5.6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < 3; i++) Positioned(left: w * i, top: 0, child: _emptyCell(context, r)),
          Positioned(left: 0, top: 0, child: HexTile(value: 4, radius: r)),
          Positioned(
            left: pos.dx - w / 2,
            top: pos.dy - r,
            child: Transform.scale(
              scale: landed ? 1 : 1.1,
              child: HexTile(value: 2, radius: r),
            ),
          ),
          if (!landed)
            Positioned(
              left: pos.dx - 6 * scale,
              top: pos.dy + r * 0.6,
              child: Icon(
                Icons.touch_app_rounded,
                size: 40 * scale,
                color: context.palette.textPrimary.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }
}

class _MergeDemo extends _Demo {
  const _MergeDemo({required super.scale});

  @override
  Widget buildFrame(BuildContext context, double t) {
    final r = 30.0 * scale;
    final w = math.sqrt(3) * r;
    // [2] [ ] [2]  -> drop a 2 in the middle -> three 2s merge into a 4.
    final drop = Curves.easeOutBack.transform(_seg(t, 0.08, 0.28));
    final slide = Curves.easeInCubic.transform(_seg(t, 0.42, 0.56));
    final pop = _seg(t, 0.56, 0.8);
    final merged = t >= 0.56;
    return SizedBox(
      width: w * 3,
      height: r * 2.6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < 3; i++) Positioned(left: w * i, top: r * 0.3, child: _emptyCell(context, r)),
          if (!merged) ...[
            Positioned(
              left: w * slide,
              top: r * 0.3,
              child: HexTile(value: 2, radius: r),
            ),
            Positioned(
              left: w * (2 - slide),
              top: r * 0.3,
              child: HexTile(value: 2, radius: r),
            ),
            Positioned(
              left: w,
              top: r * 0.3,
              child: Transform.scale(
                scale: drop,
                child: HexTile(value: 2, radius: r),
              ),
            ),
          ] else
            Positioned(
              left: w,
              top: r * 0.3,
              child: Transform.scale(
                scale: 1 + math.sin(pop * math.pi) * 0.25,
                child: HexTile(value: 4, radius: r),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChainDemo extends _Demo {
  const _ChainDemo({required super.scale});

  @override
  Duration get duration => const Duration(milliseconds: 3600);

  @override
  Widget buildFrame(BuildContext context, double t) {
    final r = 24.0 * scale;
    final w = math.sqrt(3) * r;
    final center = Offset(w * 1.5, r * 2.5);
    Offset around(int deg) => center + Offset(math.cos(deg * math.pi / 180), math.sin(deg * math.pi / 180)) * w;

    // Pairs around the centre: 2s on the left, 4s top-right, 8s at the bottom.
    const groups = [
      (2, [180, 240]),
      (4, [300, 0]),
      (8, [60, 120]),
    ];
    const switchAt = [0.3, 0.5, 0.7];
    var stage = 0;
    for (final at in switchAt) {
      if (t >= at) stage++;
    }
    final drop = Curves.easeOutBack.transform(_seg(t, 0.05, 0.2));
    final pulse = stage == 0
        ? drop
        : 1 + math.sin(_seg(t, switchAt[stage - 1], switchAt[stage - 1] + 0.12) * math.pi) * 0.25;

    Widget at(Offset c, Widget child) => Positioned(left: c.dx - w / 2, top: c.dy - r, child: child);

    return SizedBox(
      width: w * 3,
      height: r * 5.2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          at(center, _emptyCell(context, r)),
          for (var deg = 0; deg < 360; deg += 60) at(around(deg), _emptyCell(context, r)),
          for (var g = 0; g < groups.length; g++)
            if (stage <= g)
              for (final deg in groups[g].$2)
                at(
                  Offset.lerp(
                    around(deg),
                    center,
                    Curves.easeInCubic.transform(_seg(t, switchAt[g] - 0.08, switchAt[g])),
                  )!,
                  HexTile(value: groups[g].$1, radius: r),
                ),
          at(
            center,
            Transform.scale(
              scale: pulse,
              child: HexTile(value: 2 << stage, radius: r),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoosterDemo extends _Demo {
  const _BoosterDemo({required super.scale});

  @override
  Widget buildFrame(BuildContext context, double t) {
    final p = context.palette;
    final bob = math.sin(t * math.pi * 2) * 4;
    Widget item(IconData icon, List<Color> colors, String label, int i) => Column(
      children: [
        Transform.translate(
          offset: Offset(0, math.sin((t + i / 4) * math.pi * 2) * 4),
          child: Container(
            width: 50 * scale,
            height: 50 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: colors),
            ),
            child: Icon(icon, color: Colors.white, size: 26 * scale),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 13 * scale, color: p.textMuted, fontWeight: FontWeight.w600),
        ),
      ],
    );
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, bob),
              child: HexTile(value: 32, radius: 30 * scale),
            ),
            SizedBox(width: 14 * scale),
            Icon(Icons.arrow_forward_rounded, color: p.textMuted),
            SizedBox(width: 14 * scale),
            CoinIcon(size: 40 * scale),
          ],
        ),
        SizedBox(height: 18 * scale),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18 * scale,
          runSpacing: 10,
          children: [
            item(Icons.undo_rounded, const [Color(0xFF6FD3FF), Color(0xFF2C7BF2)], 'Undo', 0),
            item(Icons.gavel_rounded, const [Color(0xFFFF9E80), Color(0xFFF0306A)], 'Smash', 1),
            item(Icons.autorenew_rounded, const [Color(0xFF9DF5B0), Color(0xFF12A67A)], 'Shuffle', 2),
          ],
        ),
      ],
    );
  }
}
