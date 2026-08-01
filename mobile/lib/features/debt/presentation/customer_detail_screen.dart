import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
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
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.debt, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(title: customer.name, accent: accent),
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
                    Text(customer.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: n.textPrimary)),
                    if ((customer.phone ?? '').isNotEmpty) Text(customer.phone!, style: TextStyle(color: n.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: customer.debtBalance > 0 ? AppColors.expense.withValues(alpha: n.isGame ? 0.16 : 0.08) : AppColors.income.withValues(alpha: n.isGame ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: n.isGame ? Border.all(color: (customer.debtBalance > 0 ? AppColors.expense : AppColors.income).withValues(alpha: 0.4)) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tổng nợ hiện tại', style: TextStyle(color: n.textSecondary)),
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
                  decoration: n.cardDecoration(radius: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thông tin khác', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary)),
                      const SizedBox(height: 10),
                      if (customer.createdAt != null)
                        _InfoRow(label: 'Ngày tạo', value: DateFormat('dd/MM/yyyy', 'vi_VN').format(customer.createdAt!), neutrals: n),
                      _InfoRow(label: 'Tổng đã mua (bán thiếu)', value: formatVND(totalBought), neutrals: n),
                      _InfoRow(label: 'Tổng đã trả', value: formatVND(totalPaid), neutrals: n),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text('Lịch sử giao dịch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary)),
            const SizedBox(height: 8),
            historyAsync.when(
              loading: () => Center(
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator(color: n.isGame ? accent : null)),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Không thể tải lịch sử', style: TextStyle(color: n.textSecondary)),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Chưa có giao dịch công nợ nào.', style: TextStyle(color: n.textSecondary)),
                  );
                }
                return Column(children: entries.map((e) => _HistoryTile(entry: e, neutrals: n)).toList());
              },
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: n.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Tạo đơn bán thiếu'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), foregroundColor: accent),
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
  final ScreenNeutrals neutrals;

  const _InfoRow({required this.label, required this.value, required this.neutrals});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: neutrals.textSecondary)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: neutrals.textPrimary)),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final DebtHistoryEntry entry;
  final ScreenNeutrals neutrals;

  const _HistoryTile({required this.entry, required this.neutrals});

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
      title: Text(isIncrease ? 'Bán thiếu' : 'Trả nợ', style: TextStyle(color: neutrals.textPrimary)),
      subtitle: Text(
        [
          DateFormat('HH:mm dd/MM/yyyy', 'vi_VN').format(entry.createdAt),
          if ((entry.note ?? '').isNotEmpty) entry.note!,
        ].join(' • '),
        style: TextStyle(color: neutrals.textSecondary),
      ),
      trailing: Text(
        '${isIncrease ? '+' : '-'}${formatVND(entry.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
