import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../data/category_repository.dart';
import '../domain/category.dart';
import '../domain/category_icons.dart';

/// Danh mục thu/chi (Mục 12.19). Rename + delete (delete is blocked
/// server-side with a friendly message if the category is already used by
/// a transaction) + "+ Thêm danh mục" — new/renamed categories keep a
/// generic icon since there's no icon-picker UI yet (see mobile/README.md).
class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends ConsumerState<CategoryManagementScreen> {
  String _group = 'income';

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(_group == 'income' ? incomeCategoriesProvider : expenseCategoriesProvider);
    final typeColor = _group == 'income' ? AppColors.income : AppColors.expense;
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.category, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(title: 'Danh mục', accent: accent),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'income', label: Text('Thu nhập')),
                ButtonSegment(value: 'expense', label: Text('Chi tiêu')),
              ],
              selected: {_group},
              onSelectionChanged: (s) => setState(() => _group = s.first),
            ),
          ),
          Expanded(
            child: categoriesAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: n.isGame ? accent : null)),
              error: (error, _) => Center(child: Text('Không thể tải danh mục', style: TextStyle(color: n.textPrimary))),
              data: (categories) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(incomeCategoriesProvider);
                  ref.invalidate(expenseCategoriesProvider);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final c = categories[index];
                    return Container(
                      decoration: n.cardDecoration(radius: 12),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: typeColor.withValues(alpha: 0.12), child: Icon(categoryIconFor(c.icon), color: typeColor)),
                        title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w600, color: n.textPrimary)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 20, color: n.textSecondary),
                              onPressed: () => _showRenameSheet(context, c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                              onPressed: () => _confirmDelete(context, c),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        onPressed: () => _showAddCategorySheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm danh mục'),
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context) {
    showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddCategorySheet(initialGroup: _group),
    );
  }

  void _showRenameSheet(BuildContext context, Category category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RenameCategorySheet(category: category),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá danh mục?'),
        content: Text('Bạn có chắc muốn xoá "${category.name}"? Không thể xoá nếu đã có giao dịch sử dụng.'),
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
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      await ref.read(categoryRepositoryProvider).deleteCategory(workspaceId: workspaceId, categoryId: category.id);
      ref.invalidate(_group == 'income' ? incomeCategoriesProvider : expenseCategoriesProvider);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể xoá danh mục';
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _RenameCategorySheet extends ConsumerStatefulWidget {
  final Category category;

  const _RenameCategorySheet({required this.category});

  @override
  ConsumerState<_RenameCategorySheet> createState() => _RenameCategorySheetState();
}

class _RenameCategorySheetState extends ConsumerState<_RenameCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.category.name);
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      await ref.read(categoryRepositoryProvider).renameCategory(
            workspaceId: workspaceId,
            categoryId: widget.category.id,
            name: _nameController.text.trim(),
          );
      ref.invalidate(widget.category.groupName == 'income' ? incomeCategoriesProvider : expenseCategoriesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể cập nhật danh mục';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetDragHandle()),
            const Text('Sửa danh mục', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Tên danh mục', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên danh mục' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCategorySheet extends ConsumerStatefulWidget {
  final String initialGroup;

  const _AddCategorySheet({required this.initialGroup});

  @override
  ConsumerState<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends ConsumerState<_AddCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late String _group = widget.initialGroup;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      await ref.read(categoryRepositoryProvider).createCategory(
            workspaceId: workspaceId,
            name: _nameController.text.trim(),
            group: _group,
          );
      ref.invalidate(_group == 'income' ? incomeCategoriesProvider : expenseCategoriesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể thêm danh mục';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetDragHandle()),
            const Text('Thêm danh mục', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'income', label: Text('Thu nhập')),
                ButtonSegment(value: 'expense', label: Text('Chi tiêu')),
              ],
              selected: {_group},
              onSelectionChanged: (s) => setState(() => _group = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Tên danh mục', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên danh mục' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
