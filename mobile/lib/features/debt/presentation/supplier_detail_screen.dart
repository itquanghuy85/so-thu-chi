import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../../transaction/presentation/create_transaction_sheet.dart';
import '../data/supplier_repository.dart';
import '../domain/customer.dart';

/// Màu đại diện cho công nợ phải trả (NCC) — cam/đỏ để phân biệt với
/// công nợ phải thu (tím).
const _supplierColor = Color(0xFFE65100);

class SupplierDetailScreen extends ConsumerWidget {
  final Customer supplier;

  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_payableHistoryProvider(supplier.id));
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.debt, style);

    return Scaffold(
      backgroundColor: n.tint(_supplierColor),
      appBar: SectionAppBar(
        title: supplier.name,
        style: style,
        actions: [
          IconButton(
            tooltip: 'Xoá nhà cung cấp',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteSupplier(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_payableHistoryProvider(supplier.id));
          ref.invalidate(supplierListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                InitialsAvatar(name: supplier.name, radius: 26),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supplier.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: n.textPrimary)),
                    if ((supplier.phone ?? '').isNotEmpty) Text(supplier.phone!, style: TextStyle(color: n.textSecondary)),
                    Text('Nhà cung cấp', style: TextStyle(color: _supplierColor, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: supplier.debtBalance > 0
                    ? _supplierColor.withValues(alpha: n.isGame ? 0.16 : 0.08)
                    : AppColors.income.withValues(alpha: n.isGame ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: n.isGame
                    ? Border.all(color: (supplier.debtBalance > 0 ? _supplierColor : AppColors.income).withValues(alpha: 0.4))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bạn đang nợ NCC', style: TextStyle(color: n.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    formatVND(supplier.debtBalance),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: supplier.debtBalance > 0 ? _supplierColor : AppColors.income,
                    ),
                  ),
                  if (supplier.debtBalance <= 0)
                    Text('Đã tất toán ✓', style: TextStyle(color: AppColors.income, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            historyAsync.when(
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: n.isGame ? accent : null)),
                ),
              ),
              error: (_, __) => Container(
                padding: const EdgeInsets.all(16),
                decoration: n.cardDecoration(radius: 16),
                child: Row(
                  children: [
                    Expanded(child: Text('Không thể tải thông tin NCC', style: TextStyle(color: n.textSecondary))),
                    TextButton(
                      onPressed: () => ref.invalidate(_payableHistoryProvider(supplier.id)),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
              data: (entries) {
                final totalBought = entries.where((e) => e.type == 'debt_increase').fold<num>(0, (s, e) => s + e.amount);
                final totalPaid = entries.where((e) => e.type == 'debt_decrease').fold<num>(0, (s, e) => s + e.amount);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: n.cardDecoration(radius: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thông tin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary)),
                      const SizedBox(height: 10),
                      if (supplier.createdAt != null)
                        _InfoRow(label: 'Ngày thêm', value: DateFormat('dd/MM/yyyy', 'vi_VN').format(supplier.createdAt!), neutrals: n),
                      _InfoRow(label: 'Tổng đã mua chịu', value: formatVND(totalBought), neutrals: n),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: n.isGame ? accent : null),
                ),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Không thể tải lịch sử', style: TextStyle(color: n.textSecondary)),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Chưa có giao dịch nào.', style: TextStyle(color: n.textSecondary)),
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
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Mua chịu NCC'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: _supplierColor,
                    side: const BorderSide(color: _supplierColor),
                  ),
                  onPressed: () async {
                    final created = await showCreateTransactionSheet(
                      context,
                      initialTabIndex: 3,
                      debtSubTabIndex: 2,
                      preselectedSupplier: supplier,
                    );
                    if (created == true) {
                      ref.invalidate(_payableHistoryProvider(supplier.id));
                      ref.invalidate(supplierListProvider);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Đã trả NCC'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.income,
                  ),
                  onPressed: () async {
                    final created = await showCreateTransactionSheet(
                      context,
                      initialTabIndex: 3,
                      debtSubTabIndex: 3,
                      preselectedSupplier: supplier,
                    );
                    if (created == true) {
                      ref.invalidate(_payableHistoryProvider(supplier.id));
                      ref.invalidate(supplierListProvider);
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

  Future<void> _deleteSupplier(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá nhà cung cấp?'),
        content: Text('Xoá "${supplier.name}" vĩnh viễn. Nếu còn công nợ chưa tất toán, thao tác sẽ bị từ chối.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(supplierRepositoryProvider).deleteSupplier(supplier.id);
      ref.invalidate(supplierListProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể xoá nhà cung cấp';
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

final _payableHistoryProvider =
    FutureProvider.autoDispose.family<List<DebtHistoryEntry>, String>((ref, supplierId) async {
  return ref.watch(supplierRepositoryProvider).getPayableHistory(supplierId);
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
    // Màu ngược với khách hàng: tăng nợ = đỏ/cam, trả NCC = xanh lá
    final color = isIncrease ? _supplierColor : AppColors.income;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(isIncrease ? Icons.shopping_bag_outlined : Icons.payments_outlined, color: color, size: 18),
      ),
      title: Text(isIncrease ? 'Mua chịu NCC' : 'Đã trả NCC', style: TextStyle(color: neutrals.textPrimary)),
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
