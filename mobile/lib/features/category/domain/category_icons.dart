import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/dark_colors.dart';
import '../../../core/constants/game_colors.dart';
import '../../../core/theme/visual_style_provider.dart';

/// Maps the stable `icon` key seeded by the backend (see backend
/// `categories.constants.ts`) to a Material icon. Falls back to a generic
/// icon for user-created categories (which currently have no icon picker
/// UI, per README "Known simplifications") or unrecognized keys.
IconData categoryIconFor(String? key) {
  switch (key) {
    case 'sales':
      return Icons.storefront;
    case 'salary':
      return Icons.payments;
    case 'gift':
      return Icons.card_giftcard;
    case 'refund':
      return Icons.replay_circle_filled;
    case 'investment':
      return Icons.trending_up;
    case 'debt_collect':
      return Icons.request_page;
    case 'stock':
      return Icons.shopping_bag;
    case 'electricity':
      return Icons.bolt;
    case 'water':
      return Icons.water_drop;
    case 'food':
      return Icons.restaurant;
    case 'transport':
      return Icons.local_shipping;
    case 'rent':
      return Icons.store;
    case 'other':
      return Icons.more_horiz;
    default:
      return Icons.label_outline;
  }
}

/// Deterministic per-category color (same key always gets the same color
/// within a style), so category cards read distinctly instead of every one
/// sharing a single flat income/expense accent. Dispatches to each visual
/// style's own palette — `DarkColors`/`GameColors` are already tuned for
/// contrast on their own surfaces, so this never risks a Classic hue
/// clashing on a dark or neon background.
Color categoryColorFor(String key, AppVisualStyle style) {
  return switch (style) {
    AppVisualStyle.dark => DarkColors.forKey(key),
    AppVisualStyle.gameLeon => GameColors.forKey(key),
    AppVisualStyle.classic => AppColors.forKey(key),
  };
}
