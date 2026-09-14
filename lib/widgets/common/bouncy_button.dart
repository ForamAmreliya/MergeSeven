import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/audio_service.dart';

/// Wraps any widget with a springy press effect, click sound and haptic.
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool sound;

  const BouncyButton({super.key, required this.child, this.onTap, this.sound = true});

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapCancel: () => _set(false),
      onTapUp: enabled ? (_) => _set(false) : null,
      onTap: enabled
          ? () {
              final audio = context.read<AudioService>();
              if (widget.sound) audio.play(Sfx.click, volume: 0.7);
              audio.haptic();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: Duration(milliseconds: _down ? 80 : 260),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// Big rounded gradient call-to-action button.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final List<Color> colors;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;

  const GradientButton({
    super.key,
    required this.label,
    required this.colors,
    this.icon,
    this.onTap,
    this.height = 60,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final shade = Color.lerp(colors.last, Colors.black, 0.25)!;
    return BouncyButton(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: height,
          padding: EdgeInsets.only(bottom: height * 0.08),
          decoration: BoxDecoration(
            color: shade,
            borderRadius: BorderRadius.circular(height * 0.36),
            boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.25), offset: const Offset(0, 6))],
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(height * 0.36),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: fontSize * 1.25),
                  SizedBox(width: fontSize * 0.4),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: fontSize,
                        letterSpacing: 1,
                        shadows: [Shadow(color: shade.withValues(alpha: 0.6), offset: const Offset(0, 2))],
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

/// Square icon button used in headers.
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final Color? background;

  const RoundIconButton({super.key, required this.icon, this.onTap, this.size = 46, this.color, this.background});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = background ?? theme.colorScheme.surface;
    return BouncyButton(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(size * 0.32),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.18), offset: const Offset(0, 4))],
        ),
        child: Icon(icon, size: size * 0.52, color: color ?? theme.colorScheme.primary),
      ),
    );
  }
}
