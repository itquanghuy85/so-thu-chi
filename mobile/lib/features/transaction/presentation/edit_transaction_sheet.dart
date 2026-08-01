import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/amount_text_field.dart';
import '../../../shared/widgets/field_suggestion_chips.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../../debt/domain/customer.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';
import 'create_transaction_sheet.dart' show VaultDropdownField, CategoryDropdownField;
import 'debt_transaction_tab.dart' show CustomerDropdownField;
import 'transaction_display.dart' show transactionColor;

/// Opens the "sửa giao dịch" sheet (Mục — never mutates the original; the
/// backend voids it and creates a fresh one with these values — see
/// `TransactionsService.edit`). Returns the replacement [Transaction] if
/// saved, `null` if cancelled.
Future<Transaction?> showEditTransactionSheet(BuildContext context, Transaction transaction) {
  return showModalBottomSheet<Transaction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => EditTransactionSheet(transaction: transaction),
  );
}

class EditTransactionSheet extends ConsumerStatefulWidget {
  final Transaction transaction;

  const EditTransactionSheet({super.key, required this.transaction});

  @override
  ConsumerState<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<EditTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(text: formatVND(widget.transaction.amount).replaceAll('đ', ''));
  late final _costController = TextEditingController(
    text: widget.transaction.costAmount != null ? formatVND(widget.transaction.costAmount!).replaceAll('đ', '') : '',
  );
  late final _noteController = TextEditingController(text: widget.transaction.note ?? '');
  final _reasonController = TextEditingController();
  late TransactionType _type = widget.transaction.type;
  String? _vaultId;
  String? _toVaultId;
  String? _categoryId;
  String? _customerId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _vaultId = t.fromVault?.id;
    _toVaultId = t.toVault?.id;
    _categoryId = t.category?.id;
    _customerId = t.customer?.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _costController.dispose();
    _noteController.dispose();
    _reasonController.dispose();
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
    if ((_type == TransactionType.debtIncrease || _type == TransactionType.debtDecrease) && _customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn khách hàng')));
      return;
    }

    setState(() => _saving = true);
    try {
      final costText = _costController.text.trim();
      final updated = await ref.read(transactionRepositoryProvider).editTransaction(
            id: widget.transaction.id,
            type: transactionTypeToString(_type),
            amount: parseCurrencyInput(_amountController.text),
            categoryId: _categoryId,
            fromVaultId: (_type == TransactionType.expense || _type == TransactionType.transfer) ? _vaultId : null,
            toVaultId: (_type == TransactionType.income || _type == TransactionType.transfer || _type == TransactionType.debtDecrease) ? _toVaultId : null,
            customerId: _customerId,
            note: _noteController.text.trim(),
            costAmount: _type == TransactionType.income && costText.isNotEmpty ? parseCurrencyInput(costText) : null,
            reason: _reasonController.text.trim(),
          );
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      await FieldHistory.record(
        workspaceId: workspaceId,
        fieldKey: 'note_${transactionTypeToString(_type)}',
        value: _noteController.text,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể sửa giao dịch';
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
              child: Text('Sửa giao dịch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Giao dịch cũ sẽ được hủy và thay bằng giao dịch mới với thông tin bên dưới — mọi thay đổi đều được ghi lại trong lịch sử chỉnh sửa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
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
                      const SizedBox(height: 12),
                      AmountTextField(controller: _costController, label: 'Giá vốn hàng bán (không bắt buộc)', required: false),
                    ] else if (_type == TransactionType.expense) ...[
                      VaultDropdownField(label: 'Túi chi tiền', value: _vaultId, onChanged: (v) => setState(() => _vaultId = v)),
                      const SizedBox(height: 12),
                      CategoryDropdownField(group: 'expense', value: _categoryId, onChanged: (v) => setState(() => _categoryId = v)),
                    ] else if (_type == TransactionType.transfer) ...[
                      VaultDropdownField(label: 'Túi nguồn', value: _vaultId, onChanged: (v) => setState(() => _vaultId = v)),
                      const SizedBox(height: 12),
                      VaultDropdownField(label: 'Túi đích', value: _toVaultId, excludeVaultId: _vaultId, onChanged: (v) => setState(() => _toVaultId = v)),
                    ] else if (_type == TransactionType.debtIncrease) ...[
                      CustomerDropdownField(value: _customerId, onSelected: (Customer c) => setState(() => _customerId = c.id)),
                    ] else if (_type == TransactionType.debtDecrease) ...[
                      CustomerDropdownField(value: _customerId, onSelected: (Customer c) => setState(() => _customerId = c.id)),
                      const SizedBox(height: 12),
                      VaultDropdownField(label: 'Túi nhận tiền', value: _toVaultId, onChanged: (v) => setState(() => _toVaultId = v)),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      maxLines: 2,
                      maxLength: 500,
                    ),
                    FieldSuggestionChips(
                      key: ValueKey(_type),
                      fieldKey: 'note_${transactionTypeToString(_type)}',
                      controller: _noteController,
                      accent: transactionColor(_type),
                    ),
                    TextFormField(
                      controller: _reasonController,
                      decoration: InputDecoration(labelText: 'Lý do sửa (không bắt buộc)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      maxLines: 2,
                      maxLength: 200,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Lưu thay đổi'),
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

