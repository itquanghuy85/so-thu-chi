import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../../transaction/presentation/create_transaction_sheet.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

/// Chi tiết khách hàng / công nợ (Mục 12.10 drill-down): debt summary,
/// "Thông tin khác" (created date + totals derived from real debt-history
/// entries), and the debt-history timeline. No due-date/overdue fields are
/// shown — the API doesn't return them yet (see mobile/README.md).
class CustomerDetailScreen extends ConsumerWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_debtHistoryProvider(customer.id));

    return Scaffold(
      backgroundColor: AppColors.tint(AppColors.debt),
      appBar: SectionAppBar(title: customer.name, accent: AppColors.debt),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_debtHistoryProvider(customer.id));
          ref.invalidate(customerListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                InitialsAvatar(name: customer.name, radius: 26),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    if ((customer.phone ?? '').isNotEmpty) Text(customer.phone!, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: customer.debtBalance > 0 ? AppColors.expense.withValues(alpha: 0.08) : AppColors.income.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tổng nợ hiện tại', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    formatVND(customer.debtBalance),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: customer.debtBalance > 0 ? AppColors.expense : AppColors.income,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            historyAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => const SizedBox.shrink(),
              data: (entries) {
                final totalBought = entries.where((e) => e.type == 'debt_increase').fold<num>(0, (s, e) => s + e.amount);
                final totalPaid = entries.where((e) => e.type == 'debt_decrease').fold<num>(0, (s, e) => s + e.amount);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Thông tin khác', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      if (customer.createdAt != null)
                        _InfoRow(label: 'Ngày tạo', value: DateFormat('dd/MM/yyyy', 'vi_VN').format(customer.createdAt!)),
                      _InfoRow(label: 'Tổng đã mua (bán thiếu)', value: formatVND(totalBought)),
                      _InfoRow(label: 'Tổng đã trả', value: formatVND(totalPaid)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('Lịch sử giao dịch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            historyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Không thể tải lịch sử', style: TextStyle(color: AppColors.textSecondary)),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Chưa có giao dịch công nợ nào.', style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return Column(children: entries.map((e) => _HistoryTile(entry: e)).toList());
              },
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Tạo đơn bán thiếu'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), foregroundColor: AppColors.debt),
                  onPressed: () async {
                    final created = await showCreateTransactionSheet(context, initialTabIndex: 3);
                    if (created == true) {
                      ref.invalidate(_debtHistoryProvider(customer.id));
                      ref.invalidate(customerListProvider);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Ghi nhận trả nợ'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: AppColors.income),
                  onPressed: () async {
                    final created = await showCreateTransactionSheet(context, initialTabIndex: 3);
                    if (created == true) {
                      ref.invalidate(_debtHistoryProvider(customer.id));
                      ref.invalidate(customerListProvider);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _debtHistoryProvider =
    FutureProvider.autoDispose.family<List<DebtHistoryEntry>, String>((ref, customerId) async {
  return ref.watch(customerRepositoryProvider).getDebtHistory(customerId);
});

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final DebtHistoryEntry entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isIncrease = entry.type == 'debt_increase';
    final color = isIncrease ? AppColors.debt : AppColors.income;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(isIncrease ? Icons.shopping_cart_outlined : Icons.attach_money, color: color, size: 18),
      ),
      title: Text(isIncrease ? 'Bán thiếu' : 'Trả nợ'),
      subtitle: Text(
        [
          DateFormat('HH:mm dd/MM/yyyy', 'vi_VN').format(entry.createdAt),
          if ((entry.note ?? '').isNotEmpty) entry.note!,
        ].join(' • '),
      ),
      trailing: Text(
        '${isIncrease ? '+' : '-'}${formatVND(entry.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
