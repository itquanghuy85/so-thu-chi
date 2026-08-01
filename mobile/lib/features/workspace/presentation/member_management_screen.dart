import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/section_app_bar.dart';
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
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.member, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(title: 'Thành viên', accent: accent),
      body: workspaceAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: n.isGame ? accent : null)),
        error: (error, _) => Center(child: Text('Không thể tải thông tin', style: TextStyle(color: n.textPrimary))),
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
                    gradient: LinearGradient(colors: n.isGame ? [accent, Color.lerp(accent, Colors.black, 0.35)!] : AppColors.heroGradient(accent), begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: n.isGame ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))] : null,
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
                Text('${members.length} thành viên', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary)),
                const SizedBox(height: 8),
                ...members.map((m) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: n.cardDecoration(radius: 12),
                      child: ListTile(
                        leading: InitialsAvatar(name: m.fullName.isEmpty ? m.email : m.fullName),
                        title: Text(m.fullName.isEmpty ? m.email : m.fullName, style: TextStyle(fontWeight: FontWeight.w600, color: n.textPrimary)),
                        subtitle: Text('${m.email}${m.email.isNotEmpty ? ' • ' : ''}${_roleLabel(m.role)}', style: TextStyle(color: n.textSecondary)),
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
