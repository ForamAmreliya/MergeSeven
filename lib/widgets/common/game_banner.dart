import 'package:flutter/material.dart';

/// Pops a short celebratory message in the middle of the screen.
class GameBanner extends StatefulWidget {
  const GameBanner({super.key});

  @override
  State<GameBanner> createState() => GameBannerState();
}

class GameBannerState extends State<GameBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  String _title = '';
  String? _subtitle;
  List<Color> _colors = const [Colors.purple, Colors.blue];
  IconData? _icon;

  void show(String title, {String? subtitle, required List<Color> colors, IconData? icon}) {
    setState(() {
      _title = title;
      _subtitle = subtitle;
      _colors = colors;
      _icon = icon;
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
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          if (_c.value == 0 || _c.value == 1) return const SizedBox.shrink();
          final v = _c.value;
          final scale = v < 0.2 ? Curves.elasticOut.transform(v / 0.2) : 1.0;
          final opacity = v > 0.8 ? (1 - v) / 0.2 : 1.0;
          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, v > 0.8 ? -40 * (v - 0.8) / 0.2 : 0),
              child: Transform.scale(scale: 0.5 + 0.5 * scale, child: child),
            ),
          );
        },
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _colors),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 3),
              boxShadow: [BoxShadow(color: _colors.last.withValues(alpha: 0.45), offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_icon != null) Icon(_icon, color: Colors.white, size: 40),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    shadows: [Shadow(color: Colors.black26, offset: Offset(0, 3))],
                  ),
                ),
                if (_subtitle != null)
                  Text(
                    _subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
