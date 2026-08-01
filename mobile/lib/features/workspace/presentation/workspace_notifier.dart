import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/secure_storage_provider.dart';
import '../data/workspace_repository.dart';
import '../domain/workspace.dart';

class WorkspaceState {
  final List<Workspace> workspaces;
  final Workspace? selected;
  final bool isLoading;
  final String? errorMessage;

  const WorkspaceState({
    this.workspaces = const [],
    this.selected,
    this.isLoading = false,
    this.errorMessage,
  });

  WorkspaceState copyWith({
    List<Workspace>? workspaces,
    Workspace? selected,
    bool clearSelected = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WorkspaceState(
      workspaces: workspaces ?? this.workspaces,
      selected: clearSelected ? null : (selected ?? this.selected),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Loads the user's workspaces and tracks which one is currently active.
/// The selected workspace id is persisted in secure storage so it survives
/// app restarts (still requires the workspace to exist in the freshly
/// fetched list).
class WorkspaceNotifier extends StateNotifier<WorkspaceState> {
  final WorkspaceRepository _repository;
  final FlutterSecureStorage _secureStorage;

  WorkspaceNotifier(this._repository, this._secureStorage) : super(const WorkspaceState());

  Future<void> loadWorkspaces() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final workspaces = await _repository.getWorkspaces();
      Workspace? selected;
      final savedId = await _secureStorage.read(key: SecureStorageKeys.selectedWorkspaceId);
      if (savedId != null) {
        for (final w in workspaces) {
          if (w.id == savedId) {
            selected = w;
            break;
          }
        }
      }
      state = state.copyWith(workspaces: workspaces, selected: selected, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  Future<void> selectWorkspace(Workspace workspace) async {
    await _secureStorage.write(key: SecureStorageKeys.selectedWorkspaceId, value: workspace.id);
    state = state.copyWith(selected: workspace);
  }

  Future<Workspace> createWorkspace({required String name, required WorkspaceType type}) async {
    final created = await _repository.createWorkspace(name: name, type: type);
    state = state.copyWith(workspaces: [...state.workspaces, created]);
    await selectWorkspace(created);
    return created;
  }

  /// "Tham gia bằng mã mời" (Mục 8.5) — joins and immediately selects the
  /// workspace so the router sends the user straight into the app.
  Future<Workspace> joinWorkspace(String inviteCode) async {
    final joined = await _repository.joinWorkspace(inviteCode);
    final already = state.workspaces.any((w) => w.id == joined.id);
    state = state.copyWith(workspaces: already ? state.workspaces : [...state.workspaces, joined]);
    await selectWorkspace(joined);
    return joined;
  }

  Future<void> clearSelection() async {
    await _secureStorage.delete(key: SecureStorageKeys.selectedWorkspaceId);
    state = state.copyWith(clearSelected: true, workspaces: const []);
  }
}

final workspaceNotifierProvider = StateNotifierProvider<WorkspaceNotifier, WorkspaceState>((ref) {
  return WorkspaceNotifier(
    ref.watch(workspaceRepositoryProvider),
    ref.watch(secureStorageProvider),
  );
});
