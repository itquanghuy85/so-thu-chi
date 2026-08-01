import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Không gian làm việc'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
          return const _LoadingState();
        }
        if (state.errorMessage != null && state.workspaces.isEmpty) {
          return _ErrorState(
            message: state.errorMessage!,
            onRetry: () => ref.read(workspaceNotifierProvider.notifier).loadWorkspaces(),
          );
        }
        if (state.workspaces.isEmpty) {
          return _EmptyState(
            onCreate: (type) => _showCreateWorkspaceSheet(context, initialType: type),
            onJoin: () => _showJoinWorkspaceDialog(context),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(workspaceNotifierProvider.notifier).loadWorkspaces(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: state.workspaces.length,
            itemBuilder: (context, index) => _WorkspaceTile(
              workspace: state.workspaces[index],
              onTap: () => ref.read(workspaceNotifierProvider.notifier).selectWorkspace(state.workspaces[index]),
            ),
          ),
        );
      }),
      floatingActionButton: state.workspaces.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCreateWorkspaceSheet(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Tạo mới'),
            ),
    );
  }

  void _showJoinWorkspaceDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _JoinWorkspaceDialog());
  }

  void _showCreateWorkspaceSheet(BuildContext context, {WorkspaceType? initialType}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateWorkspaceSheet(initialType: initialType),
    );
  }
}

/// Shown while `GET /workspaces` is in flight. A bare spinner reads as a
/// frozen app on a slow connection — the free-tier backend can take up to
/// ~50s to wake from idle (see backend/README.md) — so a reassurance line
/// fades in if loading runs past a few seconds, instead of leaving the
/// user staring at an unexplained spinner.
class _LoadingState extends StatefulWidget {
  const _LoadingState();

  @override
  State<_LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<_LoadingState> {
  bool _showHint = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showHint = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          AnimatedOpacity(
            opacity: _showHint ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Đang kết nối máy chủ lần đầu, có thể mất khoảng 30–50 giây...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textSecondary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

/// First-run empty state (Mục 8: right after registering, before any
/// workspace exists) — previously a generic icon + one line of text + a
/// FAB tucked in the corner, easy to miss and gave no sense of what a
/// "workspace" even is. Now leads with the two real choices up front so
/// the very next tap creates one, with the type already decided.
class _EmptyState extends StatelessWidget {
  final ValueChanged<WorkspaceType> onCreate;
  final VoidCallback onJoin;

  const _EmptyState({required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.headerGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: const Icon(Icons.workspaces_outline, size: 42, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tạo không gian làm việc đầu tiên',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Đây là nơi lưu toàn bộ giao dịch, túi tiền và báo cáo của bạn. Chọn loại phù hợp để bắt đầu:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.storefront_rounded,
                  title: 'Cửa hàng',
                  subtitle: 'Bán hàng, quản lý kho, nhân viên',
                  color: AppColors.primary,
                  onTap: () => onCreate(WorkspaceType.shop),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.house_rounded,
                  title: 'Gia đình',
                  subtitle: 'Thu chi sinh hoạt hàng ngày',
                  color: AppColors.secondary,
                  onTap: () => onCreate(WorkspaceType.family),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          TextButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.group_add_outlined, size: 18),
            label: const Text('Có mã mời? Tham gia không gian có sẵn'),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ChoiceCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  final Workspace workspace;
  final VoidCallback onTap;

  const _WorkspaceTile({required this.workspace, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = workspace.type == WorkspaceType.shop ? AppColors.primary : AppColors.secondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(workspace.type == WorkspaceType.shop ? Icons.storefront_rounded : Icons.house_rounded, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workspace.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                      '${workspace.type == WorkspaceType.shop ? 'Cửa hàng' : 'Gia đình'}'
                      '${workspace.memberCount != null ? ' • ${workspace.memberCount} thành viên' : ''}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateWorkspaceSheet extends ConsumerStatefulWidget {
  final WorkspaceType? initialType;

  const _CreateWorkspaceSheet({this.initialType});

  @override
  ConsumerState<_CreateWorkspaceSheet> createState() => _CreateWorkspaceSheetState();
}

class _CreateWorkspaceSheetState extends ConsumerState<_CreateWorkspaceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late WorkspaceType _type = widget.initialType ?? WorkspaceType.shop;
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
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetDragHandle()),
            const SizedBox(height: 4),
            const Text('Tạo không gian làm việc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _WorkspaceTypeCard(
                    label: 'Cửa hàng',
                    icon: Icons.storefront_rounded,
                    selected: _type == WorkspaceType.shop,
                    onTap: () => setState(() => _type = WorkspaceType.shop),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WorkspaceTypeCard(
                    label: 'Gia đình',
                    icon: Icons.house_rounded,
                    selected: _type == WorkspaceType.family,
                    onTap: () => setState(() => _type = WorkspaceType.family),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameController,
              autofocus: widget.initialType != null,
              decoration: InputDecoration(
                labelText: 'Tên không gian làm việc',
                hintText: _type == WorkspaceType.shop ? 'Ví dụ: Cửa hàng Minh Anh' : 'Ví dụ: Gia đình mình',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              validator: _validateName,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _isSaving ? null : _submit,
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Bắt đầu', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
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
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
          color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textPrimary, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
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
            autocorrect: false,
            enableSuggestions: false,
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
