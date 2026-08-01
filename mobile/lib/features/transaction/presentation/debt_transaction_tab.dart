import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/amount_text_field.dart';
import '../../debt/data/customer_repository.dart';
import '../../debt/domain/customer.dart';
import '../../debt/presentation/create_customer_sheet.dart';
import '../data/transaction_repository.dart';
import 'create_transaction_sheet.dart' show VaultDropdownField, validateNote;

/// "Công nợ" tab in the create-transaction sheet (Mục 12.5.1), with two
/// sub-tabs: "Bán thiếu" (debt_increase) and "Trả nợ" (debt_decrease).
class DebtTransactionTab extends StatefulWidget {
  const DebtTransactionTab({super.key});

  @override
  State<DebtTransactionTab> createState() => _DebtTransactionTabState();
}

class _DebtTransactionTabState extends State<DebtTransactionTab> with SingleTickerProviderStateMixin {
  late final TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _subTabController,
          labelColor: AppColors.debt,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart_outlined, size: 16), text: 'Bán thiếu'),
            Tab(icon: Icon(Icons.payments_outlined, size: 16), text: 'Trả nợ'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: const [
              _BanThieuForm(),
              _TraNoForm(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dropdown listing customers with their current debt balance, plus a
/// quick "add customer" action (Mục 12.5.1: "Dropdown chọn khách hàng (có
/// search)"). A full search box is left for a future pass; the list is
/// short enough for MVP shops to scroll.
class CustomerDropdownField extends ConsumerWidget {
  final String? value;
  final ValueChanged<Customer> onSelected;

  const CustomerDropdownField({super.key, required this.value, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customerListProvider);
    return customersAsync.when(
      data: (customers) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: customers.any((c) => c.id == value) ? value : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Khách hàng', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: customers
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          '${c.name}${c.debtBalance > 0 ? ' (nợ ${formatVND(c.debtBalance)})' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (id) {
                Customer? customer;
                for (final c in customers) {
                  if (c.id == id) {
                    customer = c;
                    break;
                  }
                }
                if (customer != null) onSelected(customer);
              },
              validator: (v) => v == null ? 'Vui lòng chọn khách hàng' : null,
            ),
          ),
          IconButton(
            tooltip: 'Thêm khách hàng',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () async {
              final created = await showCreateCustomerSheet(context);
              if (created != null) onSelected(created);
            },
          ),
        ],
      ),
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => const Text(
        'Không thể tải danh sách khách hàng',
        style: TextStyle(color: AppColors.error),
      ),
    );
  }
}

class _BanThieuForm extends ConsumerStatefulWidget {
  const _BanThieuForm();

  @override
  ConsumerState<_BanThieuForm> createState() => _BanThieuFormState();
}

class _BanThieuFormState extends ConsumerState<_BanThieuForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Customer? _customer;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      await ref.read(transactionRepositoryProvider).createDebtIncrease(
            workspaceId: workspaceId,
            customerId: _customer!.id,
            amount: parseCurrencyInput(_amountController.text),
            note: _noteController.text.trim(),
          );
      ref.invalidate(customerListProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể lưu giao dịch';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomerDropdownField(
            value: _customer?.id,
            onSelected: (c) => setState(() => _customer = c),
          ),
          const SizedBox(height: 12),
          AmountTextField(controller: _amountController),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Ghi chú mặt hàng',
              hintText: 'Ví dụ: 2 cục gà',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 2,
            maxLength: 500,
            validator: validateNote,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.debt),
            child: _isSaving
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class _TraNoForm extends ConsumerStatefulWidget {
  const _TraNoForm();

  @override
  ConsumerState<_TraNoForm> createState() => _TraNoFormState();
}

class _TraNoFormState extends ConsumerState<_TraNoForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  Customer? _customer;
  String? _toVaultId;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _fillFullDebt() {
    if (_customer != null && _customer!.debtBalance > 0) {
      _amountController.text = NumberFormatUtil.grouped(_customer!.debtBalance);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      await ref.read(transactionRepositoryProvider).createDebtDecrease(
            workspaceId: workspaceId,
            customerId: _customer!.id,
            toVaultId: _toVaultId!,
            amount: parseCurrencyInput(_amountController.text),
          );
      ref.invalidate(customerListProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể lưu giao dịch';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomerDropdownField(
            value: _customer?.id,
            onSelected: (c) => setState(() => _customer = c),
          ),
          const SizedBox(height: 12),
          AmountTextField(
            controller: _amountController,
            suffixIcon: TextButton(
              onPressed: _customer == null ? null : _fillFullDebt,
              child: const Text('Trả hết'),
            ),
          ),
          const SizedBox(height: 12),
          VaultDropdownField(
            label: 'Túi nhận tiền',
            value: _toVaultId,
            onChanged: (v) => setState(() => _toVaultId = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.debt),
            child: _isSaving
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

/// Tiny helper to format a numeric amount into the same dot-grouped string
/// [CurrencyInputFormatter] would produce, used by the "Trả hết" quick-fill
/// button.
class NumberFormatUtil {
  static String grouped(num amount) => formatVND(amount).replaceAll('đ', '');
}
