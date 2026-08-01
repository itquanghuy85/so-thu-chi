import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/section_app_bar.dart';
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
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.audit, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(title: 'Lịch sử chỉnh sửa', accent: accent),
      body: logsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: n.isGame ? accent : null)),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Không thể tải lịch sử', style: TextStyle(color: n.textPrimary)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => ref.invalidate(auditLogListProvider), child: const Text('Thử lại')),
            ],
          ),
        ),
        data: (page) => page.data.isEmpty
            ? EmptyStateWidget(icon: Icons.history_rounded, message: 'Chưa có thao tác sửa/xóa nào được ghi lại.', accent: accent)
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

class _AuditTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final n = neutralsFor(ref.watch(visualStyleProvider));
    final summary = _summary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: n.cardDecoration(radius: 14),
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
                    Expanded(child: Text(auditActionLabel(entry.action), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: n.textPrimary))),
                    Text(DateFormat('HH:mm dd/MM/yyyy').format(entry.createdAt), style: TextStyle(fontSize: 11, color: n.textSecondary)),
                  ],
                ),
                if (summary != null) ...[
                  const SizedBox(height: 4),
                  Text(summary, style: TextStyle(fontSize: 12, color: n.textPrimary)),
                ],
                const SizedBox(height: 4),
                Text(
                  entry.userName.isEmpty ? 'Không rõ người thực hiện' : 'Bởi ${entry.userName}',
                  style: TextStyle(fontSize: 11, color: n.textSecondary),
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Lý do: ${entry.note}', style: TextStyle(fontSize: 11, color: n.textSecondary, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
