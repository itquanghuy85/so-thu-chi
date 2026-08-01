import 'package:flutter/material.dart';

/// Palette for the "Tối" (Dark) visual style — a professional dark mode,
/// deliberately distinct from "Game Leon" (Mục 16.2, arcade/neon): same
/// brand accent hues as the Classic theme (just lightened where needed for
/// AA contrast on a dark surface, per Material's own dark-theme guidance),
/// dark neutrals swapped in for background/surface/text. No mascot, no
/// glow effects — the same finance-app seriousness as Classic, just dark.
class DarkColors {
  DarkColors._();

  static const Color background = Color(0xFF0E1417);
  static const Color surface = Color(0xFF1A2226);
  static const Color surfaceAlt = Color(0xFF222C31);
  static const Color divider = Color(0xFF313C42);
  static const Color textPrimary = Color(0xFFEDF2F4);
  static const Color textSecondary = Color(0xFF93A3AB);

  // Same hue families as AppColors, lightened for legibility on dark
  // surfaces — a user should recognize "this is still the same app", just
  // dark, not a different brand.
  static const Color primary = Color(0xFF5B9EF3);
  static const Color primaryDark = Color(0xFF3E7AD1);
  static const Color secondary = Color(0xFF33C9B3);

  static const Color income = Color(0xFF5FCE72);
  static const Color expense = Color(0xFFFF6E6E);
  static const Color transfer = Color(0xFFFFC94F);
  static const Color debt = Color(0xFFB98BF0);
  static const Color reports = Color(0xFF37D6BE);
  static const Color error = Color(0xFFFF6E6E);

  static const List<Color> headerGradient = [Color(0xFF15427A), Color(0xFF0F5C50)];

  static const List<Color> avatarPalette = [
    Color(0xFF5B9EF3),
    Color(0xFFB98BF0),
    Color(0xFF33C9B3),
    Color(0xFFFFA85C),
    Color(0xFFFF7FAE),
    Color(0xFF5FCE72),
    Color(0xFFC49A7A),
    Color(0xFF4FC3D9),
  ];

  static Color forKey(String key) {
    final hash = key.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return avatarPalette[hash % avatarPalette.length];
  }

  /// A very subtle wash of [accent] over the dark surface — the dark-mode
  /// counterpart to `AppColors.tint`.
  static Color tint(Color accent) => Color.alphaBlend(accent.withValues(alpha: 0.10), background);
}
