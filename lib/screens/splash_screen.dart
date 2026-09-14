import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/routes.dart';
import '../widgets/hex/hex_tile.dart';
import 'home_screen.dart';

/// Animated intro: the logo drops in, the title bounces letter by letter and a
/// loading bar fills before handing over to the home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const colors = [Color(0xFF7C4DFF), Color(0xFF26146E)];

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat();

  @override
  void initState() {
    super.initState();
    _intro.forward().whenComplete(_goHome);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/logo.png'), context);
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute(const HomeScreen()));
  }

  @override
  void dispose() {
    _intro.dispose();
    _float.dispose();
    super.dispose();
  }

  Animation<double> _interval(double a, double b, [Curve curve = Curves.easeOut]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(a, b, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = math.min(size.shortestSide * 0.42, 220.0);
    final logo = _interval(0, 0.45, Curves.elasticOut);
    final bar = _interval(0.35, 1, Curves.easeInOut);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: SplashScreen.colors),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(child: CustomPaint(painter: _SparklePainter(_float))),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([_intro, _float]),
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, math.sin(_float.value * math.pi * 2) * 6),
                        child: Transform.rotate(
                          angle: (1 - logo.value) * -0.6,
                          child: Transform.scale(scale: logo.value, child: child),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(logoSize * 0.22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 40,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Image.asset('assets/images/logo.png', width: logoSize, height: logoSize),
                      ),
                    ),
                    SizedBox(height: logoSize * 0.18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _BouncyTitle(animation: _intro, fontSize: logoSize * 0.3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FadeTransition(
                      opacity: _interval(0.4, 0.7),
                      child: Text(
                        'MERGE  ·  MATCH  ·  MASTER',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: logoSize * 0.075,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: size.height * 0.1,
                child: Center(
                  child: FadeTransition(
                    opacity: _interval(0.3, 0.5),
                    child: Container(
                      width: math.min(size.width * 0.5, 240),
                      height: 10,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: AnimatedBuilder(
                        animation: bar,
                        builder: (_, _) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: bar.value.clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(colors: [Color(0xFFFFD166), Color(0xFFFF7A9C)]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BouncyTitle extends StatelessWidget {
  final Animation<double> animation;
  final double fontSize;
  const _BouncyTitle({required this.animation, required this.fontSize});

  static const _letters = ['M', 'e', 'r', 'g', 'e', 'S', 'e', 'v', 'e', 'n'];
  static const _colors = [
    Color(0xFF4FE3FF),
    Color(0xFF7CF29A),
    Color(0xFFFFD166),
    Color(0xFFFF8FA3),
    Color(0xFFFF9CE6),
    Color(0xFFB79CFF),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _letters.length; i++)
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final start = 0.2 + i * 0.035;
              final t = ((animation.value - start) / 0.25).clamp(0.0, 1.0);
              final v = Curves.elasticOut.transform(t);
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(offset: Offset(0, (1 - v) * fontSize), child: child),
              );
            },
            child: Text(
              _letters[i],
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
                shadows: [
                  Shadow(color: _colors[i % _colors.length], offset: const Offset(0, 4)),
                  Shadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(0, 8), blurRadius: 12),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Animation<double> t;
  _SparklePainter(this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final r = 10 + rng.nextDouble() * 34;
      final phase = rng.nextDouble();
      final y = baseY + math.sin((t.value + phase) * math.pi * 2) * 14;
      final alpha = 0.05 + 0.06 * (0.5 + 0.5 * math.sin((t.value * 2 + phase) * math.pi * 2));
      canvas.drawPath(roundedHexPath(Offset(x, y), r), Paint()..color = Colors.white.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => false;
}
