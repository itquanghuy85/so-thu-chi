import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../data/workspace_repository.dart';
import '../domain/workspace.dart';

final _workspaceDetailProvider = FutureProvider.autoDispose.family<Workspace, String>((ref, workspaceId) async {
  return ref.watch(workspaceRepositoryProvider).getWorkspace(workspaceId);
});

String _roleLabel(String role) => switch (role) {
      'owner' => 'Chủ sở hữu',
      'manager' => 'Quản lý',
      'cashier' => 'Thu ngân',
      _ => 'Thành viên',
    };

/// Quản lý thành viên (Mục 8.5 / 12.13): share the workspace's invite code
/// (regenerate if needed) and list/remove members. Only the owner sees the
/// "Xoá" action and the regenerate button — enforced both here and
/// server-side.
class MemberManagementScreen extends ConsumerWidget {
  final String workspaceId;
  final String currentUserId;

  const MemberManagementScreen({super.key, required this.workspaceId, required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceAsync = ref.watch(_workspaceDetailProvider(workspaceId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Thành viên')),
      body: workspaceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(child: Text('Không thể tải thông tin')),
        data: (workspace) {
          final isOwner = workspace.ownerId == currentUserId;
          final members = workspace.members ?? [];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_workspaceDetailProvider(workspaceId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.headerGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mã mời không gian làm việc', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              workspace.inviteCode ?? '—',
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 2),
                            ),
                          ),
                          if (workspace.inviteCode != null)
                            IconButton(
                              tooltip: 'Sao chép',
                              icon: const Icon(Icons.copy, color: Colors.white),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: workspace.inviteCode!));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép mã mời')));
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Chia sẻ mã này để mời người khác tham gia', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      if (isOwner) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Tạo mã mới'),
                          onPressed: () => _regenerateCode(context, ref),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('${members.length} thành viên', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                ...members.map((m) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: ListTile(
                        leading: InitialsAvatar(name: m.fullName.isEmpty ? m.email : m.fullName),
                        title: Text(m.fullName.isEmpty ? m.email : m.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${m.email}${m.email.isNotEmpty ? ' • ' : ''}${_roleLabel(m.role)}'),
                        trailing: isOwner && m.userId != currentUserId
                            ? IconButton(
                                icon: const Icon(Icons.person_remove_outlined, color: AppColors.error),
                                onPressed: () => _confirmRemove(context, ref, m),
                              )
                            : null,
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _regenerateCode(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(workspaceRepositoryProvider).regenerateInviteCode(workspaceId);
      ref.invalidate(_workspaceDetailProvider(workspaceId));
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể tạo mã mời mới';
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, WorkspaceMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá thành viên?'),
        content: Text('Bạn có chắc muốn xoá "${member.fullName.isEmpty ? member.email : member.fullName}" khỏi không gian làm việc?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(workspaceRepositoryProvider).removeMember(workspaceId: workspaceId, userId: member.userId);
      ref.invalidate(_workspaceDetailProvider(workspaceId));
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể xoá thành viên';
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
