import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/offline/app_database.dart';
import '../../core/offline/connectivity_provider.dart';
import '../../core/offline/sync_queue_service.dart';
import '../../core/utils/currency_formatter.dart';

/// Thin status strip (Mục 14): shown whenever the device is offline, there
/// are still queued mutations waiting to sync, or (Mục — "lưu offline
/// trước, sync nền sau") the server has genuinely rejected one. Absent
/// entirely when everything is caught up — no permanent chrome for the
/// common case. Failed rows take priority over pending/offline ones since
/// they need the user's attention, not just time.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final failedCount = ref.watch(failedSyncCountProvider).valueOrNull ?? 0;

    if (isOnline && pendingCount == 0 && failedCount == 0) return const SizedBox.shrink();

    final String label;
    final Color color;
    final IconData icon;
    final VoidCallback? onTap;
    if (failedCount > 0) {
      color = AppColors.error;
      icon = Icons.error_outline;
      label = '$failedCount giao dịch bị từ chối — bấm để xem';
      onTap = () => _showFailedOperationsSheet(context, ref);
    } else if (!isOnline) {
      color = AppColors.expense;
      icon = Icons.cloud_off_outlined;
      label = pendingCount > 0
          ? 'Không có mạng — $pendingCount giao dịch đang chờ đồng bộ'
          : 'Không có mạng — đang hiển thị dữ liệu đã lưu';
      onTap = null;
    } else {
      color = AppColors.transfer;
      icon = Icons.sync;
      label = 'Đang đồng bộ $pendingCount giao dịch...';
      onTap = null;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: color.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
            if (onTap != null) Icon(Icons.chevron_right, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  void _showFailedOperationsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _FailedOperationsSheet(),
    );
  }
}

class _FailedOperationsSheet extends ConsumerStatefulWidget {
  const _FailedOperationsSheet();

  @override
  ConsumerState<_FailedOperationsSheet> createState() => _FailedOperationsSheetState();
}

class _FailedOperationsSheetState extends ConsumerState<_FailedOperationsSheet> {
  List<Map<String, dynamic>>? _ops;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ops = await AppDatabase.instance.getFailedOperations();
    if (mounted) setState(() => _ops = ops);
  }

  Future<void> _dismiss(int id) async {
    await AppDatabase.instance.dismissFailedOperation(id);
    ref.invalidate(failedSyncCountProvider);
    await _load();
  }

  Future<void> _dismissAll() async {
    await AppDatabase.instance.clearAllFailedOperations();
    ref.invalidate(failedSyncCountProvider);
    await _load();
  }

  String _summarize(Map<String, dynamic> op) {
    final payload = op['payload'] as Map<String, dynamic>;
    final amount = (payload['amount'] as num?) ?? 0;
    final note = payload['note'] as String?;
    return '${formatVND(amount)}${(note ?? '').isNotEmpty ? ' • $note' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final ops = _ops;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Giao dịch bị từ chối', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Các giao dịch này đã lưu tạm trên máy nhưng máy chủ từ chối khi đồng bộ — có thể do không đủ số dư hoặc dữ liệu không hợp lệ. Bạn có thể xoá và nhập lại.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Xóa tất cả'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: (_ops?.isEmpty ?? true) ? null : _dismissAll,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ops == null
                  ? const Center(child: CircularProgressIndicator())
                  : ops.isEmpty
                      ? const Center(child: Text('Không còn giao dịch nào bị từ chối'))
                      : ListView.separated(
                          itemCount: ops.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final op = ops[i];
                            final id = op['id'] as int;
                            final createdAt = DateTime.fromMillisecondsSinceEpoch(op['created_at'] as int);
                            final error = op['last_error'] as String? ?? 'Không rõ lỗi';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.error_outline, color: AppColors.error),
                              title: Text(_summarize(op), style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${DateFormat('HH:mm dd/MM/yyyy', 'vi_VN').format(createdAt)}\n$error',
                                style: const TextStyle(fontSize: 12, color: AppColors.error),
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                tooltip: 'Xoá',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _dismiss(id),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
