import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Simple "Chưa có dữ liệu" placeholder used across empty vault/transaction/
/// customer lists (spec Mục 12.16 empty-state pattern).
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    this.message = 'Chưa có dữ liệu',
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: AppColors.primary.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
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
