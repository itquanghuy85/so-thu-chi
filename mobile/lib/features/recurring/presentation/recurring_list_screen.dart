import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/amount_text_field.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../../debt/domain/customer.dart';
import '../../transaction/domain/transaction.dart';
import '../../transaction/presentation/create_transaction_sheet.dart' show VaultDropdownField, CategoryDropdownField;
import '../../transaction/presentation/debt_transaction_tab.dart' show CustomerDropdownField;
import '../../transaction/presentation/transaction_display.dart';
import '../data/recurring_repository.dart';
import '../domain/recurring_transaction.dart';

/// Giao dịch định kỳ (Mục — "Recurring transactions"). The backend has no
/// cron/scheduler; due occurrences are materialized lazily via
/// `POST .../recurring/run-due`, called once from the Dashboard on load
/// (see dashboard_notifier.dart) — this screen is purely CRUD for the
/// templates themselves.
class RecurringListScreen extends ConsumerWidget {
  const RecurringListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Giao dịch định kỳ')),
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không thể tải danh sách'),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => ref.invalidate(recurringListProvider), child: const Text('Thử lại')),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.repeat_rounded,
                message: 'Chưa có giao dịch định kỳ nào.\nThêm tiền thuê, lương nhân viên... để tự động ghi sổ mỗi kỳ.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(recurringListProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _RecurringTile(item: items[i]),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const _RecurringFormSheet(),
          );
          if (created == true) ref.invalidate(recurringListProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecurringTile extends ConsumerWidget {
  final RecurringTransaction item;

  const _RecurringTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = transactionColor(item.type);
    final desc = [item.category?.name, item.fromVault?.name, item.toVault?.name, item.customer?.name].whereType<String>().join(' • ');
    return Opacity(
      opacity: item.active ? 1 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.12), child: Icon(transactionIcon(item.type), color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${transactionTypeLabel(item.type)} • ${formatVND(item.amount)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  if (desc.isNotEmpty) Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '${frequencyLabel(item.frequency)} • Lần tới: ${DateFormat('dd/MM/yyyy').format(item.nextRunDate)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Switch(
              value: item.active,
              onChanged: (v) async {
                try {
                  final workspaceId = ref.read(currentWorkspaceIdProvider);
                  await ref.read(recurringRepositoryProvider).setActive(workspaceId: workspaceId, id: item.id, active: v);
                  ref.invalidate(recurringListProvider);
                } catch (e) {
                  final message = e is ApiException ? e.message : 'Không thể cập nhật';
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 20),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Xoá giao dịch định kỳ?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
                      TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Xoá', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final workspaceId = ref.read(currentWorkspaceIdProvider);
                  await ref.read(recurringRepositoryProvider).delete(workspaceId: workspaceId, id: item.id);
                  ref.invalidate(recurringListProvider);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringFormSheet extends ConsumerStatefulWidget {
  const _RecurringFormSheet();

  @override
  ConsumerState<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<_RecurringFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  DateTime _startDate = DateTime.now();
  String? _vaultId;
  String? _toVaultId;
  String? _categoryId;
  Customer? _customer;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_type == TransactionType.expense || _type == TransactionType.transfer) && _vaultId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn túi tiền')));
      return;
    }
    if ((_type == TransactionType.income || _type == TransactionType.transfer || _type == TransactionType.debtDecrease) && _toVaultId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn túi nhận')));
      return;
    }
    if ((_type == TransactionType.debtIncrease || _type == TransactionType.debtDecrease) && _customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn khách hàng')));
      return;
    }

    setState(() => _saving = true);
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      await ref.read(recurringRepositoryProvider).create(
            workspaceId: workspaceId,
            type: transactionTypeToString(_type),
            amount: parseCurrencyInput(_amountController.text),
            categoryId: _categoryId,
            fromVaultId: (_type == TransactionType.expense || _type == TransactionType.transfer) ? _vaultId : null,
            toVaultId: (_type == TransactionType.income || _type == TransactionType.transfer || _type == TransactionType.debtDecrease) ? _toVaultId : null,
            customerId: _customer?.id,
            note: _noteController.text.trim(),
            frequency: frequencyToString(_frequency),
            startDate: _startDate,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể tạo giao dịch định kỳ';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Center(child: SheetDragHandle()),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Thêm giao dịch định kỳ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('Loại giao dịch', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _TypeChip(label: 'Thu', selected: _type == TransactionType.income, color: AppColors.income, onTap: () => setState(() => _type = TransactionType.income)),
                        _TypeChip(label: 'Chi', selected: _type == TransactionType.expense, color: AppColors.expense, onTap: () => setState(() => _type = TransactionType.expense)),
                        _TypeChip(label: 'Chuyển tiền', selected: _type == TransactionType.transfer, color: AppColors.transfer, onTap: () => setState(() => _type = TransactionType.transfer)),
                        _TypeChip(label: 'Bán thiếu', selected: _type == TransactionType.debtIncrease, color: AppColors.debt, onTap: () => setState(() => _type = TransactionType.debtIncrease)),
                        _TypeChip(label: 'Trả nợ', selected: _type == TransactionType.debtDecrease, color: AppColors.debt, onTap: () => setState(() => _type = TransactionType.debtDecrease)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AmountTextField(controller: _amountController),
                    const SizedBox(height: 12),
                    if (_type == TransactionType.income) ...[
                      VaultDropdownField(label: 'Túi nhận tiền', value: _toVaultId, onChanged: (v) => setState(() => _toVaultId = v)),
                      const SizedBox(height: 12),
                      CategoryDropdownField(group: 'income', value: _categoryId, onChanged: (v) => setState(() => _categoryId = v)),
                    ] else if (_type == TransactionType.expense) ...[
                      VaultDropdownField(label: 'Túi chi tiền', value: _vaultId, onChanged: (v) => setState(() => _vaultId = v)),
                      const SizedBox(height: 12),
                      CategoryDropdownField(group: 'expense', value: _categoryId, onChanged: (v) => setState(() => _categoryId = v)),
                    ] else if (_type == TransactionType.transfer) ...[
                      VaultDropdownField(label: 'Túi nguồn', value: _vaultId, onChanged: (v) => setState(() => _vaultId = v)),
                      const SizedBox(height: 12),
                      VaultDropdownField(label: 'Túi đích', value: _toVaultId, excludeVaultId: _vaultId, onChanged: (v) => setState(() => _toVaultId = v)),
                    ] else if (_type == TransactionType.debtIncrease) ...[
                      CustomerDropdownField(value: _customer?.id, onSelected: (c) => setState(() => _customer = c)),
                    ] else if (_type == TransactionType.debtDecrease) ...[
                      CustomerDropdownField(value: _customer?.id, onSelected: (c) => setState(() => _customer = c)),
                      const SizedBox(height: 12),
                      VaultDropdownField(label: 'Túi nhận tiền', value: _toVaultId, onChanged: (v) => setState(() => _toVaultId = v)),
                    ],
                    const SizedBox(height: 12),
                    const Text('Lặp lại', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: RecurringFrequency.values
                          .map((f) => ChoiceChip(
                                label: Text(frequencyLabel(f)),
                                selected: _frequency == f,
                                onSelected: (_) => setState(() => _frequency = f),
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(color: _frequency == f ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                side: BorderSide.none,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bắt đầu từ', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                      trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      },
                    ),
                    TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      maxLines: 2,
                      maxLength: 500,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Lưu'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    );
  }
}
