import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/amount_text_field.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../../category/data/category_repository.dart';
import '../../category/domain/category.dart';
import '../data/budget_repository.dart';
import '../domain/budget.dart';

/// Ngân sách theo danh mục/tháng (Mục — "Budgets"). Every budget is
/// implicitly "this calendar month" — see Budget.entity.ts's doc comment
/// for why there's no explicit period column.
class BudgetManagementScreen extends ConsumerWidget {
  const BudgetManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetListProvider);
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.budget, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(title: 'Ngân sách', accent: accent),
      body: budgetsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: n.isGame ? accent : null)),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Không thể tải ngân sách', style: TextStyle(color: n.textPrimary)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => ref.invalidate(budgetListProvider), child: const Text('Thử lại')),
            ],
          ),
        ),
        data: (budgets) => budgets.isEmpty
            ? EmptyStateWidget(
                icon: Icons.pie_chart_outline,
                message: 'Chưa có ngân sách nào.\nĐặt hạn mức chi tiêu theo tháng để kiểm soát dòng tiền tốt hơn.',
                accent: accent,
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(budgetListProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: budgets.length,
                  itemBuilder: (context, i) => _BudgetTile(budget: budgets[i], neutrals: n),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBudgetSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showBudgetSheet(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _BudgetFormSheet(),
    );
    if (created == true) ref.invalidate(budgetListProvider);
  }
}

class _BudgetTile extends ConsumerWidget {
  final Budget budget;
  final ScreenNeutrals neutrals;

  const _BudgetTile({required this.budget, required this.neutrals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = budget.overBudget ? AppColors.error : (budget.progress > 0.8 ? AppColors.transfer : AppColors.income);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: neutrals.cardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  budget.categoryName ?? 'Tổng chi tiêu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: neutrals.textPrimary),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: neutrals.textSecondary),
                onSelected: (action) => _handleAction(context, ref, action),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa hạn mức')),
                  PopupMenuItem(value: 'delete', child: Text('Xoá')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: budget.progress.clamp(0, 1).toDouble(),
              minHeight: 10,
              backgroundColor: neutrals.divider,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${formatVND(budget.spentThisMonth)} / ${formatVND(budget.limitAmount)}', style: TextStyle(fontSize: 12, color: neutrals.textSecondary)),
              Text(
                budget.overBudget ? 'Vượt ${formatVND(budget.spentThisMonth - budget.limitAmount)}' : 'Còn lại ${formatVND(budget.remaining)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action) async {
    if (action == 'edit') {
      final updated = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _BudgetFormSheet(editing: budget),
      );
      if (updated == true) ref.invalidate(budgetListProvider);
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xoá ngân sách?'),
          content: Text('Xoá ngân sách "${budget.categoryName ?? 'Tổng chi tiêu'}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Xoá', style: TextStyle(color: AppColors.error))),
          ],
        ),
      );
      if (confirmed == true) {
        try {
          final workspaceId = ref.read(currentWorkspaceIdProvider);
          await ref.read(budgetRepositoryProvider).deleteBudget(workspaceId: workspaceId, budgetId: budget.id);
          ref.invalidate(budgetListProvider);
        } catch (e) {
          final message = e is ApiException ? e.message : 'Không thể xoá ngân sách';
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }
  }
}

class _BudgetFormSheet extends ConsumerStatefulWidget {
  final Budget? editing;

  const _BudgetFormSheet({this.editing});

  @override
  ConsumerState<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<_BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: widget.editing != null ? NumberFormatHelper.grouped(widget.editing!.limitAmount) : '',
  );
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.editing?.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      final amount = parseCurrencyInput(_amountController.text);
      final repo = ref.read(budgetRepositoryProvider);
      if (widget.editing != null) {
        await repo.updateBudget(workspaceId: workspaceId, budgetId: widget.editing!.id, limitAmount: amount);
      } else {
        await repo.createBudget(workspaceId: workspaceId, categoryId: _categoryId, limitAmount: amount);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể lưu ngân sách';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SheetDragHandle()),
              const SizedBox(height: 8),
              Text(isEditing ? 'Sửa hạn mức' : 'Thêm ngân sách', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              if (!isEditing) ...[
                Consumer(
                  builder: (context, ref, _) {
                    final categoriesAsync = ref.watch(expenseCategoriesProvider);
                    return categoriesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Không thể tải danh mục'),
                      data: (categories) => DropdownButtonFormField<String?>(
                        initialValue: _categoryId,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: 'Danh mục (để trống = tổng chi tiêu)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Tổng chi tiêu (tất cả danh mục)')),
                          ...categories.map((Category c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              AmountTextField(controller: _amountController, label: 'Hạn mức mỗi tháng'),
              const SizedBox(height: 16),
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
    );
  }
}

class NumberFormatHelper {
  static String grouped(num amount) => formatVND(amount).replaceAll('đ', '');
}
