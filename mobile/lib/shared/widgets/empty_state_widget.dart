import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/screen_neutrals.dart';
import '../../core/theme/visual_style_provider.dart';

/// Simple "Chưa có dữ liệu" placeholder used across empty vault/transaction/
/// customer lists (spec Mục 12.16 empty-state pattern). Reads the ambient
/// visual style so it looks right whether the screen around it is Classic,
/// Tối, or Game Leon, without every caller having to pass colors in.
class EmptyStateWidget extends ConsumerWidget {
  final String message;
  final IconData icon;
  final Widget? action;
  final Color? accent;

  const EmptyStateWidget({
    super.key,
    this.message = 'Chưa có dữ liệu',
    this.icon = Icons.inbox_outlined,
    this.action,
    this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = neutralsFor(ref.watch(visualStyleProvider));
    final iconColor = accent ?? AppColors.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: n.isGame ? 0.16 : 0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: iconColor.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: n.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
