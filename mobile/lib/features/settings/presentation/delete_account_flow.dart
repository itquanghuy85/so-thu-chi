import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/notifications/notifications_repository.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/providers/secure_storage_provider.dart';
import '../../auth/presentation/auth_notifier.dart';

/// Shared "Xoá tài khoản" confirm-then-delete flow — reused from both Cài
/// đặt → Bảo mật and Trang cá nhân (the two entry points asked for) rather
/// than duplicating this irreversible action's logic in each screen.
Future<void> confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Xoá tài khoản?'),
      content: const Text(
        'Toàn bộ tài khoản và dữ liệu sẽ bị xoá vĩnh viễn, không thể khôi phục. '
        'Nếu bạn đang là chủ sở hữu một không gian làm việc có thành viên khác, '
        'hãy chuyển quyền sở hữu hoặc xoá hết thành viên trước.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Huỷ')),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Xoá vĩnh viễn', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    // Best-effort — stops this device from receiving this account's pushes
    // once deleted. Must run before the server call revokes the token this
    // needs.
    await ref.read(pushNotificationServiceProvider).unregister(
          repository: ref.read(notificationsRepositoryProvider),
          secureStorage: ref.read(secureStorageProvider),
        );
    await ref.read(authNotifierProvider.notifier).deleteAccount();
    await ref.read(workspaceNotifierProvider.notifier).clearSelection();
    // Router redirect (app.dart) sends the user back to Login once
    // authNotifierProvider's state flips to unauthenticated.
    if (context.mounted) Navigator.of(context).pop(); // dismiss the loading dialog
  } catch (e) {
    if (context.mounted) Navigator.of(context).pop(); // dismiss the loading dialog
    final message = e is ApiException ? e.message : 'Không thể xoá tài khoản';
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
