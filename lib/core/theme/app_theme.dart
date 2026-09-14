import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const fontFamily = 'Fredoka';

  static ThemeData light() => _build(Brightness.light, AppPalette.light);

  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: brightness,
      primary: p.accent,
      secondary: p.accent2,
      surface: p.card,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: p.bgBottom,
      extensions: [p],
      textTheme: ThemeData(
        brightness: brightness,
      ).textTheme.apply(fontFamily: fontFamily, bodyColor: p.textPrimary, displayColor: p.textPrimary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.barTrack),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
