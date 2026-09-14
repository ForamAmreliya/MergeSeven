import 'package:flutter/material.dart';

/// Gradient colours for a number tile.
class TileStyle {
  final Color light;
  final Color dark;
  final Color text;
  const TileStyle(this.light, this.dark, [this.text = Colors.white]);

  Color get glow => dark;
}

class TileColors {
  TileColors._();

  static const List<TileStyle> _styles = [
    TileStyle(Color(0xFF4FE3FF), Color(0xFF0A9BF0)), // 2    sky
    TileStyle(Color(0xFF7CF29A), Color(0xFF16B865)), // 4    mint
    TileStyle(Color(0xFFFF8FA3), Color(0xFFF0306A)), // 8    rose
    TileStyle(Color(0xFFB79CFF), Color(0xFF7043F0)), // 16   violet
    TileStyle(Color(0xFFFFD166), Color(0xFFFF9500)), // 32   honey
    TileStyle(Color(0xFFFF9CE6), Color(0xFFD62FB4)), // 64   magenta
    TileStyle(Color(0xFFFFAB73), Color(0xFFFF5A1F)), // 128  tangerine
    TileStyle(Color(0xFF5EF2D6), Color(0xFF0FA99A)), // 256  teal
    TileStyle(Color(0xFF8FA8FF), Color(0xFF3D4FE0)), // 512  royal
    TileStyle(Color(0xFFFF7B7B), Color(0xFFD7263D)), // 1024 ruby
    TileStyle(Color(0xFFFFF07A), Color(0xFFF2B705), Color(0xFF5B3A00)), // 2048 gold
    TileStyle(Color(0xFF4B4470), Color(0xFF1B1633), Color(0xFFFFD166)), // 4096+ onyx
  ];

  static TileStyle of(int value) {
    var index = 0;
    var v = value;
    while (v > 2) {
      v >>= 1;
      index++;
    }
    return _styles[index.clamp(0, _styles.length - 1)];
  }
}

/// App-wide colour tokens that change with light / dark mode.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bgTop;
  final Color bgBottom;
  final Color cell;
  final Color cellEdge;
  final Color card;
  final Color cardBorder;
  final Color textPrimary;
  final Color textMuted;
  final Color accent;
  final Color accent2;
  final Color coin;
  final Color barTrack;

  /// Plain background of the game screen.
  final Color gameBg;

  /// Highlighted board plate, its 3D bottom edge and outline.
  final Color plate;
  final Color plateEdge;
  final Color plateBorder;

  /// Piece slot cards under the board.
  final Color slot;

  const AppPalette({
    required this.bgTop,
    required this.bgBottom,
    required this.cell,
    required this.cellEdge,
    required this.card,
    required this.cardBorder,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.accent2,
    required this.coin,
    required this.barTrack,
    required this.gameBg,
    required this.plate,
    required this.plateEdge,
    required this.plateBorder,
    required this.slot,
  });

  static const light = AppPalette(
    bgTop: Color(0xFFF3EEFF),
    bgBottom: Color(0xFFE3F1FF),
    cell: Color(0xFFD8D0F2),
    cellEdge: Color(0xFFC3B8E8),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE4DCFB),
    textPrimary: Color(0xFF2A2050),
    textMuted: Color(0xFF8A80AE),
    accent: Color(0xFF7048F5),
    accent2: Color(0xFF14C3F0),
    coin: Color(0xFFFFB800),
    barTrack: Color(0xFFE2DAF8),
    gameBg: Color(0xFFF1EEF9),
    plate: Color(0xFFFBF9FF),
    plateEdge: Color(0xFFE0D8F8),
    plateBorder: Color(0xFFDCD4F6),
    slot: Color(0xFFFFFFFF),
  );

  static const dark = AppPalette(
    bgTop: Color(0xFF1B1538),
    bgBottom: Color(0xFF0D0B1F),
    cell: Color(0xFF1B1644),
    cellEdge: Color(0xFF110D2E),
    card: Color(0xFF252047),
    cardBorder: Color(0xFF3A3268),
    textPrimary: Color(0xFFF2EEFF),
    textMuted: Color(0xFF9D94C8),
    accent: Color(0xFF9B7BFF),
    accent2: Color(0xFF3DDCFF),
    coin: Color(0xFFFFC53D),
    barTrack: Color(0xFF3A3268),
    gameBg: Color(0xFF0F0D1C),
    plate: Color(0xFF2D2663),
    plateEdge: Color(0xFF1D1940),
    plateBorder: Color(0xFF7B63E6),
    slot: Color(0xFF1E1942),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bgTop: l(bgTop, other.bgTop),
      bgBottom: l(bgBottom, other.bgBottom),
      cell: l(cell, other.cell),
      cellEdge: l(cellEdge, other.cellEdge),
      card: l(card, other.card),
      cardBorder: l(cardBorder, other.cardBorder),
      textPrimary: l(textPrimary, other.textPrimary),
      textMuted: l(textMuted, other.textMuted),
      accent: l(accent, other.accent),
      accent2: l(accent2, other.accent2),
      coin: l(coin, other.coin),
      barTrack: l(barTrack, other.barTrack),
      gameBg: l(gameBg, other.gameBg),
      plate: l(plate, other.plate),
      plateEdge: l(plateEdge, other.plateEdge),
      plateBorder: l(plateBorder, other.plateBorder),
      slot: l(slot, other.slot),
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
