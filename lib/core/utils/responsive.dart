import 'package:flutter/widgets.dart';

/// Scales UI measurements relative to a 390pt-wide phone so that the game
/// looks proportionally the same on small phones, large phones and tablets.
class Responsive {
  final Size size;
  const Responsive(this.size);

  factory Responsive.of(BuildContext context) => Responsive(MediaQuery.sizeOf(context));

  bool get isLandscape => size.width > size.height * 1.05;

  bool get isTablet => size.shortestSide >= 600;

  /// Unit scale factor, clamped so text never becomes tiny or huge.
  double get scale {
    final base = isLandscape ? size.height / 800 : size.width / 390;
    return base.clamp(0.8, 1.6);
  }

  double sp(double v) => v * scale;
}
