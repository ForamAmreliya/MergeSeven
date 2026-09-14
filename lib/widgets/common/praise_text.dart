import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Big cheer word ("GOOD JOB!", "PERFECT!") that swipes in from the left,
/// pops, and swipes out to the right.
class PraiseText extends StatefulWidget {
  const PraiseText({super.key});

  @override
  State<PraiseText> createState() => PraiseTextState();
}

class PraiseTextState extends State<PraiseText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  String _text = '';
  int _tier = 0;

  static const _gradients = [
    [Color(0xFF7CF29A), Color(0xFF14C3F0)], // good job
    [Color(0xFF4FE3FF), Color(0xFF9B7BFF)], // excellent
    [Color(0xFFFFD166), Color(0xFFFF6FA5)], // perfect
    [Color(0xFFFF9CE6), Color(0xFFFFB443), Color(0xFF7CF29A)], // unbelievable
  ];

  void show(String text, int tier) {
    setState(() {
      _text = text;
      _tier = tier.clamp(0, _gradients.length - 1);
    });
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            if (t == 0 || t == 1) return const SizedBox.shrink();
            final w = box.maxWidth;
            double dx;
            double skew;
            if (t < 0.22) {
              final v = Curves.easeOutBack.transform(t / 0.22);
              dx = (1 - v) * -w;
              skew = (1 - v) * 0.35;
            } else if (t < 0.78) {
              dx = 0;
              skew = 0;
            } else {
              final v = Curves.easeInCubic.transform((t - 0.78) / 0.22);
              dx = v * w;
              skew = -v * 0.35;
            }
            // Little pop right after it lands.
            final pop = t >= 0.22 && t < 0.4 ? math.sin((t - 0.22) / 0.18 * math.pi) * 0.12 : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.skewX(skew)..scaleByDouble(1 + pop, 1 + pop, 1, 1),
                child: child,
              ),
            );
          },
          child: Center(child: _word(box.maxWidth)),
        ),
      ),
    );
  }

  Widget _word(double width) {
    final size = (width * (0.1 + _tier * 0.01)).clamp(30.0, 60.0);
    final style = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: 1.2,
      letterSpacing: 1.5,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        children: [
          // Thick outline + drop shadow behind the gradient fill.
          Transform.translate(
            offset: Offset(0, size * 0.08),
            child: Text(
              _text,
              style: style.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * 0.2
                  ..strokeJoin = StrokeJoin.round
                  ..color = const Color(0x55000000),
              ),
            ),
          ),
          Text(
            _text,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = size * 0.2
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.white,
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => LinearGradient(
              colors: _gradients[_tier],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect),
            child: Text(_text, style: style.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
