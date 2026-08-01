import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/dark_colors.dart';
import '../constants/game_colors.dart';
import 'visual_style_provider.dart';

/// Every major section of the app (the 5 bottom-nav tabs, plus each of the
/// Settings sub-screens) has one accent color that stays consistent
/// wherever that section shows up — its bottom-nav icon, its AppBar, its
/// Settings tile icon, its FAB. This is the single source of truth for
/// that mapping across all 3 visual styles, so `MainShellScreen`'s bottom
/// nav and every screen's `SectionAppBar` never drift out of sync.
enum AppSection {
  dashboard,
  transactions,
  vaults,
  debt,
  reports,
  budget,
  recurring,
  shift,
  dailyClosing,
  category,
  member,
  security,
  audit,
  settings,
}

class _Accent {
  final Color classic;
  final Color dark;
  final Color game;
  const _Accent({required this.classic, required this.dark, required this.game});
}

const Map<AppSection, _Accent> _accents = {
  AppSection.dashboard: _Accent(classic: AppColors.primary, dark: DarkColors.primary, game: GameColors.cyan),
  AppSection.transactions: _Accent(classic: AppColors.transfer, dark: DarkColors.transfer, game: GameColors.gold),
  AppSection.vaults: _Accent(classic: AppColors.secondary, dark: DarkColors.secondary, game: GameColors.lime),
  AppSection.debt: _Accent(classic: AppColors.debt, dark: DarkColors.debt, game: GameColors.magenta),
  AppSection.reports: _Accent(classic: AppColors.reports, dark: DarkColors.reports, game: GameColors.violet),
  AppSection.budget: _Accent(classic: AppColors.income, dark: DarkColors.income, game: GameColors.lime),
  AppSection.recurring: _Accent(classic: AppColors.transfer, dark: DarkColors.transfer, game: GameColors.gold),
  AppSection.shift: _Accent(classic: AppColors.secondary, dark: DarkColors.secondary, game: GameColors.cyan),
  AppSection.dailyClosing: _Accent(classic: AppColors.reports, dark: DarkColors.reports, game: GameColors.violet),
  AppSection.category: _Accent(classic: AppColors.debt, dark: DarkColors.debt, game: GameColors.magenta),
  AppSection.member: _Accent(classic: AppColors.debt, dark: DarkColors.debt, game: GameColors.magenta),
  AppSection.security: _Accent(classic: AppColors.income, dark: DarkColors.income, game: GameColors.lime),
  AppSection.audit: _Accent(classic: AppColors.transfer, dark: DarkColors.transfer, game: GameColors.gold),
  AppSection.settings: _Accent(classic: AppColors.primary, dark: DarkColors.primary, game: GameColors.cyan),
};

Color sectionAccent(AppSection section, AppVisualStyle style) {
  final a = _accents[section]!;
  return switch (style) {
    AppVisualStyle.dark => a.dark,
    AppVisualStyle.gameLeon => a.game,
    AppVisualStyle.classic => a.classic,
  };
}
