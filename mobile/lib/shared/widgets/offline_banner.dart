import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/offline/connectivity_provider.dart';
import '../../core/offline/sync_queue_service.dart';

/// Thin status strip (Mục 14): shown whenever the device is offline, or
/// whenever there are still queued mutations waiting to sync (which can
/// briefly outlive the offline period itself, right up until the flush
/// finishes). Absent entirely when everything is caught up — no permanent
/// chrome for the common case.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);
    final pendingCount = pendingCountAsync.valueOrNull ?? 0;

    if (isOnline && pendingCount == 0) return const SizedBox.shrink();

    final String label;
    final Color color;
    final IconData icon;
    if (!isOnline) {
      color = AppColors.expense;
      icon = Icons.cloud_off_outlined;
      label = pendingCount > 0
          ? 'Không có mạng — $pendingCount giao dịch đang chờ đồng bộ'
          : 'Không có mạng — đang hiển thị dữ liệu đã lưu';
    } else {
      color = AppColors.transfer;
      icon = Icons.sync;
      label = 'Đang đồng bộ $pendingCount giao dịch...';
    }

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
