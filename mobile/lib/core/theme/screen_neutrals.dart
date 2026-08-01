import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/dark_colors.dart';
import '../constants/game_colors.dart';
import 'visual_style_provider.dart';

/// The handful of neutral tokens (background/surface/text/divider) that
/// differ between the app's 3 visual styles. Brand accent colors
/// (primary/income/expense/transfer/debt/...) deliberately stay the exact
/// same `AppColors` hue in Classic *and* Tối (dark mode), per the "giữ
/// nguyên màu thương hiệu" design direction — only neutrals swap. Game
/// Leon reuses its own established `GameColors` accents instead (already
/// distinct/vivid by design).
///
/// Dashboard and Thành tích keep their own bespoke, hand-built Game Leon
/// widgets (mascot, XP bar, treasure chests — see `game_dashboard_body.dart`
/// / `game_gamification_body.dart`) since those are the flagship screens
/// for that style. Every other screen reskins through this class instead:
/// same Classic layout, neutrals (and glow, when [isGame]) swapped — this
/// is what makes Game Leon and Tối both "apply app-wide" without a bespoke
/// hand-built screen for every single list/form in the app.
class ScreenNeutrals {
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color shadow;
  final bool isGame;

  const ScreenNeutrals({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.shadow,
    this.isGame = false,
  });

  static const classic = ScreenNeutrals(
    background: AppColors.background,
    surface: AppColors.surface,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    divider: AppColors.divider,
    shadow: Colors.black,
  );

  static const dark = ScreenNeutrals(
    background: DarkColors.background,
    surface: DarkColors.surface,
    textPrimary: DarkColors.textPrimary,
    textSecondary: DarkColors.textSecondary,
    divider: DarkColors.divider,
    shadow: Colors.black,
  );

  static const game = ScreenNeutrals(
    background: GameColors.bgTop,
    surface: GameColors.surface,
    textPrimary: GameColors.textPrimary,
    textSecondary: GameColors.textSecondary,
    divider: GameColors.surfaceBorder,
    shadow: Colors.black,
    isGame: true,
  );

  /// Tint a tab/section accent for use as this style's Scaffold background
  /// wash — mirrors `AppColors.tint`, dark/game-aware.
  Color tint(Color accent) {
    if (isGame) return background;
    if (this == dark) return DarkColors.tint(accent);
    return AppColors.tint(accent);
  }

  /// Card decoration every reskinned list/detail tile uses — a plain
  /// shadowed surface in Classic/Tối, a neon-bordered glow in Game Leon.
  BoxDecoration cardDecoration({double radius = 16, Color? accent}) {
    if (isGame) {
      final border = accent ?? GameColors.surfaceBorder;
      return BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
          if (accent != null) BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 14, spreadRadius: -6),
        ],
      );
    }
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [BoxShadow(color: shadow.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
    );
  }
}

ScreenNeutrals neutralsFor(AppVisualStyle style) => switch (style) {
      AppVisualStyle.dark => ScreenNeutrals.dark,
      AppVisualStyle.gameLeon => ScreenNeutrals.game,
      AppVisualStyle.classic => ScreenNeutrals.classic,
    };

/// The one gradient every `SectionAppBar` uses, regardless of which
/// section it belongs to — each style's own primary/brand hue pair, so the
/// app reads as one coherent product instead of a different flat color
/// per tab (Giao dịch's amber, Công nợ's purple, ...).
List<Color> headerGradientFor(AppVisualStyle style) => switch (style) {
      AppVisualStyle.dark => DarkColors.headerGradient,
      AppVisualStyle.gameLeon => GameColors.headerGradient,
      AppVisualStyle.classic => AppColors.headerGradient,
    };
