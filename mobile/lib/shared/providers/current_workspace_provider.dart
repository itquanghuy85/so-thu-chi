import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workspace/domain/workspace.dart';
import '../../features/workspace/presentation/workspace_notifier.dart';

export '../../features/workspace/presentation/workspace_notifier.dart'
    show workspaceNotifierProvider, WorkspaceState, WorkspaceNotifier;

/// Convenience provider exposing just the currently selected [Workspace],
/// derived from [workspaceNotifierProvider]. Screens under the main shell
/// (Dashboard, Vaults, Transactions, Debt) read this to build their
/// `workspace_id` query params — by the time they mount, a workspace is
/// always selected (enforced by the router redirect in app.dart).
final currentWorkspaceProvider = Provider<Workspace?>((ref) {
  return ref.watch(workspaceNotifierProvider).selected;
});

/// Same as [currentWorkspaceProvider] but throws if no workspace is
/// selected yet — safe to use inside the main shell where selection is
/// guaranteed by routing.
final currentWorkspaceIdProvider = Provider<String>((ref) {
  final workspace = ref.watch(currentWorkspaceProvider);
  if (workspace == null) {
    throw StateError('No workspace selected');
  }
  return workspace.id;
});

/// Mục — "cài đặt phân quyền từng người": mirrors the server-side check in
/// `TransactionsService.void()` (owner/manager only) so cashier/member
/// accounts don't see a "Sửa"/"Xoá" action that would just come back as a
/// 403 — purely a UI nicety, the backend is still the actual enforcement.
/// Defaults to `true` if `role` is ever missing so this never blocks a
/// legitimate owner over a parsing gap.
final canEditTransactionsProvider = Provider<bool>((ref) {
  final role = ref.watch(currentWorkspaceProvider)?.role;
  return role == null || role == 'owner' || role == 'manager';
});

/// "Xóa không gian làm việc" (Settings) is destructive and irreversible, so
/// unlike [canEditTransactionsProvider] this defaults to `false` (hidden)
/// if `role` is ever missing, rather than defaulting to visible.
final isWorkspaceOwnerProvider = Provider<bool>((ref) {
  return ref.watch(currentWorkspaceProvider)?.role == 'owner';
});
