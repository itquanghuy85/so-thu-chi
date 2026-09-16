import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/amount_text_field.dart';
import '../../../shared/widgets/field_suggestion_chips.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../../category/data/category_repository.dart';
import '../../category/domain/category.dart';
import '../../category/domain/category_icons.dart';
import '../../debt/domain/customer.dart';
import '../../vault/data/vault_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';
import 'debt_transaction_tab.dart';
import 'transaction_display.dart' show transactionColor;

/// Opens the "create transaction" bottom sheet (Mục 12.5 / 12.5.1), with
/// tabs Thu / Chi / Chuyển tiền / Công nợ. Returns `true` if a transaction
/// was created, so callers can refresh their lists.
///
/// Deep-link options for starting pre-filled:
/// - [initialTabIndex]: which top tab to open on (0 Thu, 1 Chi, 2 Chuyển,
///   3 Công nợ).
/// - [debtSubTabIndex]: which Công nợ sub-tab when that tab is shown
///   (0 Bán thiếu, 1 Trả nợ, 2 Mua chịu NCC, 3 Đã trả NCC).
/// - [preselectedCustomer]/[preselectedSupplier]: pre-picks the customer or
///   supplier in the Công nợ forms (used from the customer/supplier detail
///   screens so the user doesn't have to re-pick the person they came from).
/// - [expenseVaultId]/[expenseAmount]: pre-fills the Chi tab (used by the
///   "Đã trả NCC" follow-up so the matching expense is quick to confirm).
Future<bool?> showCreateTransactionSheet(
  BuildContext context, {
  int initialTabIndex = 0,
  int debtSubTabIndex = 0,
  Customer? preselectedCustomer,
  Customer? preselectedSupplier,
  String? expenseVaultId,
  int? expenseAmount,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The sheet paints its own rounded, tinted-header background below
    // (see CreateTransactionSheet.build) instead of the modal route's flat
    // default — transparent here so that shows through cleanly.
    backgroundColor: Colors.transparent,
    builder: (_) => CreateTransactionSheet(
      initialTabIndex: initialTabIndex,
      debtSubTabIndex: debtSubTabIndex,
      preselectedCustomer: preselectedCustomer,
      preselectedSupplier: preselectedSupplier,
      expenseVaultId: expenseVaultId,
      expenseAmount: expenseAmount,
    ),
  );
}

class CreateTransactionSheet extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final int debtSubTabIndex;
  final Customer? preselectedCustomer;
  final Customer? preselectedSupplier;
  final String? expenseVaultId;
  final int? expenseAmount;

  const CreateTransactionSheet({
    super.key,
    this.initialTabIndex = 0,
    this.debtSubTabIndex = 0,
    this.preselectedCustomer,
    this.preselectedSupplier,
    this.expenseVaultId,
    this.expenseAmount,
  });

  @override
  ConsumerState<CreateTransactionSheet> createState() => _CreateTransactionSheetState();
}

class _CreateTransactionSheetState extends ConsumerState<CreateTransactionSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ValueNotifier<bool> _dirty = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
    // Repaints the tab bar as the selected (or actively swiped-to) tab
    // changes, so its color always matches whichever type is showing —
    // not just a single flat accent for the whole sheet regardless of tab.
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dirty.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Closes the sheet, but only after warning the user if any tab holds
  /// typed/selected data they'd lose. Drives the X button, the system back
  /// gesture and the barrier tap alike (all funnel through [PopScope]).
  Future<void> _maybeClose() async {
    if (!_dirty.value) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đóng mà không lưu?'),
        content: const Text('Dữ liệu bạn vừa nhập trên các thẻ (Thu/Chi/Chuyển/Công nợ) sẽ bị mất.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ở lại chỉnh tiếp')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Đóng')),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.of(context).pop();
  }

  static const _tabIcons = [Icons.arrow_upward, Icons.arrow_downward, Icons.swap_horiz, Icons.person_outline];
  static const _tabLabels = ['Thu', 'Chi', 'Chuyển tiền', 'Công nợ'];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final tabColors = [
      transactionColor(TransactionType.income, style),
      transactionColor(TransactionType.expense, style),
      transactionColor(TransactionType.transfer, style),
      transactionColor(TransactionType.debtIncrease, style),
    ];
    final currentAccent = tabColors[_tabController.index];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _maybeClose();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: SizedBox(
          height: mediaQuery.size.height * 0.88,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: n.surface,
            child: Column(
              children: [
                // Tinted with whichever tab is active — the same "this
                // section owns this color" wash every screen's Scaffold
                // uses (n.tint), so the header no longer sits at the exact
                // same flat color as the sheet body below the divider.
                Container(
                  color: n.tint(currentAccent),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const SheetDragHandle(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Thêm giao dịch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: n.textPrimary)),
                            IconButton(
                              icon: Icon(Icons.close, color: n.textSecondary),
                              onPressed: _maybeClose,
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        controller: _tabController,
                        labelColor: currentAccent,
                        unselectedLabelColor: n.textSecondary,
                        indicatorColor: currentAccent,
                        isScrollable: true,
                        tabAlignment: TabAlignment.center,
                        tabs: List.generate(4, (i) {
                          return Tab(
                            height: 56,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: tabColors[i],
                                  child: Icon(_tabIcons[i], size: 14, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(_tabLabels[i], style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: n.divider),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      IncomeTransactionForm(dirty: _dirty),
                      ExpenseTransactionForm(
                        dirty: _dirty,
                        initialVaultId: widget.expenseVaultId,
                        initialAmount: widget.expenseAmount,
                      ),
                      TransferTransactionForm(dirty: _dirty),
                      DebtTransactionTab(
                        dirty: _dirty,
                        initialSubTabIndex: widget.debtSubTabIndex,
                        preselectedCustomer: widget.preselectedCustomer,
                        preselectedSupplier: widget.preselectedSupplier,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
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
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Danh mục', style: TextStyle(fontWeight: FontWeight.w600, color: n.textPrimary)),
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
                    // Each category keeps its own color (keyed by its
                    // stable icon slug, falling back to its id for
                    // user-created categories with no icon) — distinct
                    // per-category color, not one flat income/expense
                    // accent shared by the whole grid.
                    color: categoryColorFor(c.icon ?? c.id, style),
                    neutrals: n,
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
  final Color color;
  final ScreenNeutrals neutrals;
  final VoidCallback onTap;

  const _CategoryCell({
    required this.category,
    required this.selected,
    required this.color,
    required this.neutrals,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = neutrals;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: n.isGame
            ? n.cardDecoration(radius: 12, accent: color)
            : BoxDecoration(
                color: selected ? color.withValues(alpha: 0.12) : n.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
              ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 14,
              // Colored badge for every category, selected or not — a
              // selected one goes solid (icon flips to white) so the state
              // still reads clearly against its own colorful background.
              backgroundColor: selected ? color : color.withValues(alpha: 0.16),
              child: Icon(categoryIconFor(category.icon), color: selected ? Colors.white : color, size: 16),
            ),
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
                  color: selected ? color : n.textPrimary,
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
  final ValueNotifier<bool> dirty;

  const IncomeTransactionForm({super.key, required this.dirty});

  @override
  ConsumerState<IncomeTransactionForm> createState() => _IncomeTransactionFormState();
}

class _IncomeTransactionFormState extends ConsumerState<IncomeTransactionForm>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _costController = TextEditingController();
  final _noteController = TextEditingController();
  String? _toVaultId;
  String? _categoryId;
  bool _isSaving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_markDirty);
    _costController.addListener(_markDirty);
    _noteController.addListener(_markDirty);
  }

  void _markDirty() => widget.dirty.value = true;

  @override
  void dispose() {
    _amountController.dispose();
    _costController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      final costText = _costController.text.trim();
      await ref.read(transactionRepositoryProvider).createIncome(
            workspaceId: workspaceId,
            toVaultId: _toVaultId!,
            amount: parseCurrencyInput(_amountController.text),
            categoryId: _categoryId,
            note: _noteController.text.trim(),
            costAmount: costText.isEmpty ? null : parseCurrencyInput(costText),
          );
      await FieldHistory.record(workspaceId: workspaceId, fieldKey: 'amount_income', value: _amountController.text);
      await FieldHistory.record(workspaceId: workspaceId, fieldKey: 'note_income', value: _noteController.text);
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
    super.build(context);
    final accent = transactionColor(TransactionType.income, ref.watch(visualStyleProvider));
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          VaultDropdownField(
            label: 'Tiền vào túi',
            value: _toVaultId,
            onChanged: (v) => setState(() {
              _toVaultId = v;
              widget.dirty.value = true;
            }),
          ),
          const SizedBox(height: 12),
          CategoryDropdownField(
            group: 'income',
            value: _categoryId,
            onChanged: (v) => setState(() {
              _categoryId = v;
              widget.dirty.value = true;
            }),
          ),
          const SizedBox(height: 12),
          AmountTextField(controller: _amountController, accent: accent),
          FieldSuggestionChips(fieldKey: 'amount_income', controller: _amountController, accent: accent),
          const SizedBox(height: 12),
          AmountTextField(
            controller: _costController,
            label: 'Giá vốn hàng bán (không bắt buộc)',
            required: false,
            accent: accent,
            suffixIcon: Tooltip(
              message: 'Để trống nếu chưa muốn tính lợi nhuận theo đơn này.\nNhập vào để hệ thống tự tính Lợi nhuận = Thu − Vốn trong báo cáo.',
              child: const Icon(Icons.info_outline, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Ghi chú',
              hintText: 'Nhập ghi chú (không bắt buộc)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.6)),
              counterText: null,
            ),
            maxLines: 2,
            maxLength: 500,
            validator: validateNote,
          ),
          FieldSuggestionChips(fieldKey: 'note_income', controller: _noteController, accent: accent),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: accent),
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
  final ValueNotifier<bool> dirty;
  final String? initialVaultId;
  final int? initialAmount;

  const ExpenseTransactionForm({
    super.key,
    required this.dirty,
    this.initialVaultId,
    this.initialAmount,
  });

  @override
  ConsumerState<ExpenseTransactionForm> createState() => _ExpenseTransactionFormState();
}

class _ExpenseTransactionFormState extends ConsumerState<ExpenseTransactionForm>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _fromVaultId;
  String? _categoryId;
  bool _isSaving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fromVaultId = widget.initialVaultId;
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = formatVND(widget.initialAmount!).replaceAll('đ', '');
    }
    _amountController.addListener(_markDirty);
    _noteController.addListener(_markDirty);
  }

  void _markDirty() => widget.dirty.value = true;

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
      await FieldHistory.record(workspaceId: workspaceId, fieldKey: 'amount_expense', value: _amountController.text);
      await FieldHistory.record(workspaceId: workspaceId, fieldKey: 'note_expense', value: _noteController.text);
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
    super.build(context);
    final accent = transactionColor(TransactionType.expense, ref.watch(visualStyleProvider));
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          VaultDropdownField(
            label: 'Túi chi',
            value: _fromVaultId,
            onChanged: (v) => setState(() {
              _fromVaultId = v;
              widget.dirty.value = true;
            }),
          ),
          const SizedBox(height: 12),
          CategoryDropdownField(
            group: 'expense',
            value: _categoryId,
            onChanged: (v) => setState(() {
              _categoryId = v;
              widget.dirty.value = true;
            }),
          ),
          const SizedBox(height: 12),
          AmountTextField(controller: _amountController, accent: accent),
          FieldSuggestionChips(fieldKey: 'amount_expense', controller: _amountController, accent: accent),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Ghi chú',
              hintText: 'Nhập ghi chú (không bắt buộc)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.6)),
              counterText: null,
            ),
            maxLines: 2,
            maxLength: 500,
            validator: validateNote,
          ),
          FieldSuggestionChips(fieldKey: 'note_expense', controller: _noteController, accent: accent),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: accent),
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
  final ValueNotifier<bool> dirty;

  const TransferTransactionForm({super.key, required this.dirty});

  @override
  ConsumerState<TransferTransactionForm> createState() => _TransferTransactionFormState();
}

class _TransferTransactionFormState extends ConsumerState<TransferTransactionForm>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _fromVaultId;
  String? _toVaultId;
  bool _isSaving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_markDirty);
    _noteController.addListener(_markDirty);
  }

  void _markDirty() => widget.dirty.value = true;

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
      await FieldHistory.record(workspaceId: workspaceId, fieldKey: 'note_transfer', value: _noteController.text);
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
    super.build(context);
    final accent = transactionColor(TransactionType.transfer, ref.watch(visualStyleProvider));
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          VaultDropdownField(
            label: 'Túi nguồn',
            value: _fromVaultId,
            onChanged: (v) => setState(() {
              _fromVaultId = v;
              widget.dirty.value = true;
            }),
          ),
          const SizedBox(height: 12),
          VaultDropdownField(
            label: 'Túi đích',
            value: _toVaultId,
            excludeVaultId: _fromVaultId,
            onChanged: (v) => setState(() {
              _toVaultId = v;
              widget.dirty.value = true;
            }),
          ),
          const SizedBox(height: 12),
          AmountTextField(controller: _amountController, accent: accent),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Lý do (tuỳ chọn)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.6)),
            ),
            maxLines: 2,
            maxLength: 500,
            validator: validateNote,
          ),
          FieldSuggestionChips(fieldKey: 'note_transfer', controller: _noteController, accent: accent),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: accent),
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
