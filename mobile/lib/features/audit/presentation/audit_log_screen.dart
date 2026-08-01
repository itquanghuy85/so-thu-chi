import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../transaction/domain/transaction.dart';
import '../../transaction/presentation/transaction_display.dart';
import '../data/audit_log_repository.dart';
import '../domain/audit_log_entry.dart';

/// "Lịch sử chỉnh sửa" (Mục — audit log): every transaction edit/void and
/// daily closing, who did it and when. Read-only — nothing here can be
/// undone from the app, it's purely a record.
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Lịch sử chỉnh sửa')),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không thể tải lịch sử'),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => ref.invalidate(auditLogListProvider), child: const Text('Thử lại')),
            ],
          ),
        ),
        data: (page) => page.data.isEmpty
            ? const EmptyStateWidget(icon: Icons.history_rounded, message: 'Chưa có thao tác sửa/xóa nào được ghi lại.')
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(auditLogListProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: page.data.length,
                  itemBuilder: (context, i) => _AuditTile(entry: page.data[i]),
                ),
              ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditLogEntry entry;

  const _AuditTile({required this.entry});

  IconData get _icon => switch (entry.action) {
        'transaction_edit' => Icons.edit_outlined,
        'transaction_void' => Icons.cancel_outlined,
        'daily_closing' => Icons.fact_check_outlined,
        _ => Icons.history_rounded,
      };

  Color get _color => switch (entry.action) {
        'transaction_edit' => AppColors.transfer,
        'transaction_void' => AppColors.error,
        'daily_closing' => AppColors.secondary,
        _ => AppColors.textSecondary,
      };

  String? get _summary {
    final source = entry.action == 'transaction_void' ? entry.before : entry.after;
    if (entry.action == 'daily_closing') {
      final variance = (entry.after?['total_variance'] as num?) ?? 0;
      return variance == 0 ? 'Khớp sổ sách' : 'Chênh lệch ${formatVND(variance)}';
    }
    if (source == null) return null;
    final typeStr = source['type'] as String?;
    final amount = source['amount'] as num?;
    if (typeStr == null || amount == null) return null;
    final label = transactionTypeLabel(transactionTypeFromString(typeStr));
    return '$label ${formatVND(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 18, backgroundColor: _color.withValues(alpha: 0.12), child: Icon(_icon, color: _color, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(auditActionLabel(entry.action), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    Text(DateFormat('HH:mm dd/MM/yyyy').format(entry.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                if (summary != null) ...[
                  const SizedBox(height: 4),
                  Text(summary, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                ],
                const SizedBox(height: 4),
                Text(
                  entry.userName.isEmpty ? 'Không rõ người thực hiện' : 'Bởi ${entry.userName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Lý do: ${entry.note}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
