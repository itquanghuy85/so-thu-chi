import 'package:flutter/material.dart';

/// Color palette for the Classic theme (Mục 12.3).
///
/// The spec (Mục 16.2) only defines a palette for the out-of-scope "Game
/// Leon" theme; these Classic colors are a reasonable choice for a
/// finance/cash-flow app and are used consistently across the MVP screens.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1565C0); // blue - trust/finance
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color secondary = Color(0xFF00897B); // teal accent

  static const Color income = Color(0xFF2E7D32); // green
  static const Color expense = Color(0xFFC62828); // red
  static const Color transfer = Color(0xFFF9A825); // amber
  static const Color debt = Color(0xFF6A1B9A); // purple

  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color error = Color(0xFFC62828);
  static const Color divider = Color(0xFFE0E0E0);

  /// Báo cáo tab accent (Mục 12.12) — teal-green, matches the "Tổng tài
  /// sản" report-tile gradient's first stop.
  static const Color reports = Color(0xFF11998E);

  /// Header/hero gradient (Dashboard top card, Splash background).
  static const List<Color> headerGradient = [Color(0xFF1565C0), Color(0xFF00897B)];

  /// A very light wash of [accent] over white — used as a tab screen's
  /// `Scaffold.backgroundColor` so the whole canvas subtly reads as
  /// "belonging" to that tab's color, not just its AppBar (Mục 12: each
  /// bottom-nav tab has its own accent, matching `MainShellScreen`'s
  /// `_navItems`).
  static Color tint(Color accent) => Color.alphaBlend(accent.withValues(alpha: 0.05), Colors.white);

  /// Two-tone gradient built from a tab's accent — used for that tab's
  /// hero/summary card, so it visually continues the color set by the
  /// AppBar above it instead of every tab reusing the same blue
  /// [headerGradient].
  static List<Color> heroGradient(Color accent) => [accent, Color.lerp(accent, Colors.black, 0.18)!];

  /// The 4 report-tile gradients (Mục 12.12 grid: Dòng tiền / Lợi nhuận /
  /// Tổng tài sản / Công nợ).
  static const List<Color> reportCashflow = [Color(0xFF2F80ED), Color(0xFF56CCF2)];
  static const List<Color> reportProfit = [Color(0xFF7F5AF0), Color(0xFFB39BFF)];
  static const List<Color> reportNetWorth = [Color(0xFF11998E), Color(0xFF38EF7D)];
  static const List<Color> reportDebt = [Color(0xFFF2994A), Color(0xFFF7B267)];

  /// Deterministic palette used for avatar-initials circles and category
  /// icon backgrounds, cycled by a name/id hash so the same person/category
  /// always gets the same color within a session.
  static const List<Color> avatarPalette = [
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFF00897B),
    Color(0xFFEF6C00),
    Color(0xFFC2185B),
    Color(0xFF2E7D32),
    Color(0xFF5D4037),
    Color(0xFF00838F),
  ];

  static Color forKey(String key) {
    final hash = key.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return avatarPalette[hash % avatarPalette.length];
  }
}
