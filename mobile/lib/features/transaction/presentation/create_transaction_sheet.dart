import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/amount_text_field.dart';
import '../../category/data/category_repository.dart';
import '../../category/domain/category.dart';
import '../../category/domain/category_icons.dart';
import '../../vault/data/vault_repository.dart';
import '../data/transaction_repository.dart';
import 'debt_transaction_tab.dart';

/// Opens the "create transaction" bottom sheet (Mục 12.5 / 12.5.1), with
/// tabs Thu / Chi / Chuyển tiền / Công nợ. Returns `true` if a transaction
/// was created, so callers can refresh their lists.
Future<bool?> showCreateTransactionSheet(BuildContext context, {int initialTabIndex = 0}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CreateTransactionSheet(initialTabIndex: initialTabIndex),
  );
}

class CreateTransactionSheet extends StatefulWidget {
  final int initialTabIndex;

  const CreateTransactionSheet({super.key, this.initialTabIndex = 0});

  @override
  State<CreateTransactionSheet> createState() => _CreateTransactionSheetState();
}

class _CreateTransactionSheetState extends State<CreateTransactionSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SizedBox(
        height: mediaQuery.size.height * 0.88,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Thêm giao dịch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: const [
                Tab(icon: Icon(Icons.arrow_upward, size: 16), text: 'Thu'),
                Tab(icon: Icon(Icons.arrow_downward, size: 16), text: 'Chi'),
                Tab(icon: Icon(Icons.swap_horiz, size: 16), text: 'Chuyển tiền'),
                Tab(icon: Icon(Icons.person_outline, size: 16), text: 'Công nợ'),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  IncomeTransactionForm(),
                  ExpenseTransactionForm(),
                  TransferTransactionForm(),
                  DebtTransactionTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown listing the workspace's vaults (cash/bank/ewallet), optionally
/// excluding one (used by the transfer tab so "to" != "from").
class VaultDropdownField extends ConsumerWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? excludeVaultId;

  const VaultDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.excludeVaultId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultsAsync = ref.watch(vaultListProvider);
    return vaultsAsync.when(
      data: (vaults) {
        final items = vaults.where((v) => v.id != excludeVaultId).toList();
        return DropdownButtonFormField<String>(
          initialValue: items.any((v) => v.id == value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          items: items
              .map((v) => DropdownMenuItem(
                    value: v.id,
                    child: Text('${v.name} (${formatVND(v.currentBalance)})', overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
          validator: (v) => v == null ? 'Vui lòng chọn túi tiền' : null,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => const Text(
        'Không thể tải danh sách túi tiền',
        style: TextStyle(color: AppColors.error),
      ),
    );
  }
}

/// Grid of category icon cards for the workspace (Mục 12.5: "Danh mục").
/// Optional field — silently shows nothing if categories fail to load.
class CategoryDropdownField extends ConsumerWidget {
  final String group; // 'income' | 'expense'
  final String? value;
  final ValueChanged<String?> onChanged;

  const CategoryDropdownField({
    super.key,
    required this.group,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(group == 'income' ? incomeCategoriesProvider : expenseCategoriesProvider);
    final accent = group == 'income' ? AppColors.income : AppColors.expense;
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Danh mục', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
              children: categories.map((c) => _CategoryCell(
                    category: c,
                    selected: c.id == value,
                    accent: accent,
                    onTap: () => onChanged(c.id == value ? null : c.id),
                  )).toList(),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => const SizedBox.shrink(),
    );
  }
}

class _CategoryCell extends StatelessWidget {
  final Category category;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _CategoryCell({required this.category, required this.selected, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? accent : Colors.transparent, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(categoryIconFor(category.icon), color: selected ? accent : AppColors.textSecondary, size: 22),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? accent : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? validateNote(String? value) {
  if (value != null && value.length > 500) return 'Ghi chú không vượt 500 ký tự';
  return null;
}

class IncomeTransactionForm extends ConsumerStatefulWidget {
  const IncomeTransactionForm({super.key});

  @override
  ConsumerState<IncomeTransactionForm> createState() => _IncomeTransactionFormState();
}

class _IncomeTransactionFormState extends ConsumerState<IncomeTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _toVaultId;
  String? _categoryId;
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
      await ref.read(transactionRepositoryProvider).createIncome(
            workspaceId: workspaceId,
            toVaultId: _toVaultId!,
            amount: parseCurrencyInput(_amountController.text),
            categoryId: _categoryId,
            note: _noteController.text.trim(),
          );
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
          VaultDropdownField(
            label: 'Tiền vào túi',
            value: _toVaultId,
            onChanged: (v) => setState(() => _toVaultId = v),
          ),
          const SizedBox(height: 12),
          CategoryDropdownField(
            group: 'income',
            value: _categoryId,
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          AmountTextField(controller: _amountController),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Ghi chú',
              hintText: 'Nhập ghi chú (không bắt buộc)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              counterText: null,
            ),
            maxLines: 2,
            maxLength: 500,
            validator: validateNote,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.income),
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

class ExpenseTransactionForm extends ConsumerStatefulWidget {
  const ExpenseTransactionForm({super.key});

  @override
  ConsumerState<ExpenseTransactionForm> createState() => _ExpenseTransactionFormState();
}

class _ExpenseTransactionFormState extends ConsumerState<ExpenseTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _fromVaultId;
  String? _categoryId;
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
      await ref.read(transactionRepositoryProvider).createExpense(
            workspaceId: workspaceId,
            fromVaultId: _fromVaultId!,
            amount: parseCurrencyInput(_amountController.text),
            categoryId: _categoryId,
            note: _noteController.text.trim(),
          );
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
          VaultDropdownField(
            label: 'Túi chi',
            value: _fromVaultId,
            onChanged: (v) => setState(() => _fromVaultId = v),
          ),
          const SizedBox(height: 12),
          CategoryDropdownField(
            group: 'expense',
            value: _categoryId,
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          AmountTextField(controller: _amountController),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Ghi chú',
              hintText: 'Nhập ghi chú (không bắt buộc)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              counterText: null,
            ),
            maxLines: 2,
            maxLength: 500,
            validator: validateNote,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
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

class TransferTransactionForm extends ConsumerStatefulWidget {
  const TransferTransactionForm({super.key});

  @override
  ConsumerState<TransferTransactionForm> createState() => _TransferTransactionFormState();
}

class _TransferTransactionFormState extends ConsumerState<TransferTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _fromVaultId;
  String? _toVaultId;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromVaultId != null && _fromVaultId == _toVaultId) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Túi nguồn và túi đích phải khác nhau')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      await ref.read(transactionRepositoryProvider).createTransfer(
            workspaceId: workspaceId,
            fromVaultId: _fromVaultId!,
            toVaultId: _toVaultId!,
            amount: parseCurrencyInput(_amountController.text),
            note: _noteController.text.trim(),
          );
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
          VaultDropdownField(
            label: 'Túi nguồn',
            value: _fromVaultId,
            onChanged: (v) => setState(() => _fromVaultId = v),
          ),
          const SizedBox(height: 12),
          VaultDropdownField(
            label: 'Túi đích',
            value: _toVaultId,
            excludeVaultId: _fromVaultId,
            onChanged: (v) => setState(() => _toVaultId = v),
          ),
          const SizedBox(height: 12),
          AmountTextField(controller: _amountController),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(labelText: 'Lý do (tuỳ chọn)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            maxLines: 2,
            maxLength: 500,
            validator: validateNote,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.transfer),
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
