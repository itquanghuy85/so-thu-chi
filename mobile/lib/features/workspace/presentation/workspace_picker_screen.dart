import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../domain/workspace.dart';
import 'workspace_notifier.dart';

class WorkspacePickerScreen extends ConsumerStatefulWidget {
  const WorkspacePickerScreen({super.key});

  @override
  ConsumerState<WorkspacePickerScreen> createState() => _WorkspacePickerScreenState();
}

class _WorkspacePickerScreenState extends ConsumerState<WorkspacePickerScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(workspaceNotifierProvider.notifier).loadWorkspaces());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Không gian làm việc'),
        actions: [
          IconButton(
            tooltip: 'Tham gia bằng mã mời',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => _showJoinWorkspaceDialog(context),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (state.isLoading && state.workspaces.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.errorMessage != null && state.workspaces.isEmpty) {
          return Center(child: Text(state.errorMessage!));
        }
        if (state.workspaces.isEmpty) {
          return EmptyStateWidget(
            message: 'Bạn chưa có không gian làm việc nào.\nTạo mới hoặc tham gia bằng mã mời.',
            icon: Icons.business_outlined,
            action: OutlinedButton.icon(
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Tham gia bằng mã mời'),
              onPressed: () => _showJoinWorkspaceDialog(context),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(workspaceNotifierProvider.notifier).loadWorkspaces(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.workspaces.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final workspace = state.workspaces[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.divider),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(
                      workspace.type == WorkspaceType.shop ? Icons.storefront : Icons.house_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(workspace.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${workspace.type == WorkspaceType.shop ? 'Cửa hàng' : 'Gia đình'}'
                    '${workspace.memberCount != null ? ' • ${workspace.memberCount} thành viên' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ref.read(workspaceNotifierProvider.notifier).selectWorkspace(workspace),
                ),
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateWorkspaceSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Tạo mới'),
      ),
    );
  }

  void _showJoinWorkspaceDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _JoinWorkspaceDialog());
  }

  void _showCreateWorkspaceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateWorkspaceSheet(),
    );
  }
}

class _CreateWorkspaceSheet extends ConsumerStatefulWidget {
  const _CreateWorkspaceSheet();

  @override
  ConsumerState<_CreateWorkspaceSheet> createState() => _CreateWorkspaceSheetState();
}

class _CreateWorkspaceSheetState extends ConsumerState<_CreateWorkspaceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  WorkspaceType _type = WorkspaceType.shop;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty || v.length > 100) return 'Tên từ 1 đến 100 ký tự';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(workspaceNotifierProvider.notifier).createWorkspace(
            name: _nameController.text.trim(),
            type: _type,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể tạo không gian làm việc';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetDragHandle()),
            const Text('Tạo không gian làm việc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _WorkspaceTypeCard(
                    label: 'Cửa hàng',
                    icon: Icons.storefront,
                    selected: _type == WorkspaceType.shop,
                    onTap: () => setState(() => _type = WorkspaceType.shop),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WorkspaceTypeCard(
                    label: 'Gia đình',
                    icon: Icons.house_outlined,
                    selected: _type == WorkspaceType.family,
                    onTap: () => setState(() => _type = WorkspaceType.family),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Tên không gian làm việc', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: _validateName,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Bắt đầu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceTypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _WorkspaceTypeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.primary.withValues(alpha: 0.06) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _JoinWorkspaceDialog extends ConsumerStatefulWidget {
  const _JoinWorkspaceDialog();

  @override
  ConsumerState<_JoinWorkspaceDialog> createState() => _JoinWorkspaceDialogState();
}

class _JoinWorkspaceDialogState extends ConsumerState<_JoinWorkspaceDialog> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mã mời');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(workspaceNotifierProvider.notifier).joinWorkspace(code);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể tham gia. Vui lòng thử lại.';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tham gia bằng mã mời'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nhập mã mời do chủ không gian làm việc chia sẻ.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Mã mời',
              errorText: _error,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Tham gia'),
        ),
      ],
    );
  }
}
