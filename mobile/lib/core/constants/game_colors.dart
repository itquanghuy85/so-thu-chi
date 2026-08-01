import 'package:flutter/material.dart';

/// Palette for the "Game Leon" visual style (Mục 16.2) — a dark arcade look
/// deliberately distinct from the Classic finance-app palette, built around
/// neon glows, gold "coin" accents, and gem-toned gradients.
class GameColors {
  GameColors._();

  static const Color bgTop = Color(0xFF1A1030);
  static const Color bgBottom = Color(0xFF2E1854);
  static const List<Color> bgGradient = [bgTop, bgBottom];

  static const Color surface = Color(0xFF2A1F4A);
  static const Color surfaceLight = Color(0xFF382A61);
  static const Color surfaceBorder = Color(0xFF4A3A7A);

  static const Color gold = Color(0xFFFFC94A);
  static const Color goldDark = Color(0xFFE0A020);
  static const Color cyan = Color(0xFF34E4EA);
  static const Color magenta = Color(0xFFFF4FA3);
  static const Color lime = Color(0xFF7CFF6B);
  static const Color violet = Color(0xFFB088FF);
  static const Color coral = Color(0xFFFF6B6B);

  static const Color textPrimary = Color(0xFFF5F0FF);
  static const Color textSecondary = Color(0xFFB3A6DB);

  static const List<Color> xpBarGradient = [cyan, violet];
  static const List<Color> goldGradient = [Color(0xFFFFE08A), gold, goldDark];
  static const List<Color> chestGradient = [Color(0xFF6A4A2E), Color(0xFF8A5E36)];

  /// Deterministic accent per vault/achievement id, mirroring
  /// `AppColors.forKey` but from the vivid game palette.
  static const List<Color> accentPalette = [cyan, magenta, lime, violet, coral, gold];

  static Color forKey(String key) {
    final hash = key.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return accentPalette[hash % accentPalette.length];
  }

  /// Leon the lion's fur/mane colors — kept centralized so the mascot reads
  /// consistently everywhere it's drawn.
  static const Color leonMane = Color(0xFFFF9F1C);
  static const Color leonManeDark = Color(0xFFD97706);
  static const Color leonFace = Color(0xFFFFC978);
  static const Color leonMuzzle = Color(0xFFFFF3D6);
  static const Color leonNose = Color(0xFF6B4226);
}
