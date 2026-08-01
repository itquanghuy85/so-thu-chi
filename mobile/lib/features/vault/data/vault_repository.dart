import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/offline/app_database.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/vault.dart';

class ReconcileResult {
  final Vault vault;
  final num difference;

  const ReconcileResult({required this.vault, required this.difference});

  factory ReconcileResult.fromJson(Map<String, dynamic> json) {
    return ReconcileResult(
      vault: Vault.fromJson(json['vault'] as Map<String, dynamic>),
      difference: (json['difference'] as num?) ?? 0,
    );
  }
}

class VaultRepository {
  final Dio _dio;

  VaultRepository(this._dio);

  Future<List<Vault>> getVaults(String workspaceId) async {
    final cacheKey = 'vaults:$workspaceId';
    try {
      final response = await _dio.get(ApiEndpoints.vaults(workspaceId));
      await AppDatabase.instance.putCache(cacheKey, workspaceId, response.data);
      final list = response.data as List<dynamic>;
      return list.map((e) => Vault.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final apiError = ApiException.fromDioException(e);
      if (apiError.code == 'CONNECTION_ERROR' || apiError.code == 'TIMEOUT') {
        final cached = await AppDatabase.instance.getCache(cacheKey);
        if (cached is List<dynamic>) {
          return cached.map((e) => Vault.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
      throw apiError;
    }
  }

  Future<Vault> createVault({
    required String workspaceId,
    required String name,
    required VaultType type,
    num? initialBalance,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.vaults(workspaceId), data: {
        'name': name,
        'type': vaultTypeToString(type),
        if (initialBalance != null) 'initial_balance': initialBalance,
      });
      return Vault.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ReconcileResult> reconcile({
    required String vaultId,
    required num actualBalance,
    String? reason,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.reconcileVault(vaultId), data: {
        'actual_balance': actualBalance,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      return ReconcileResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository(ref.watch(dioProvider));
});

/// Vaults for the currently selected workspace (cash/bank/ewallet only,
/// per the endpoint contract). Used by both the Vaults tab and the
/// Dashboard (total balance + carousel). Call `ref.invalidate(vaultListProvider)`
/// after create/reconcile to refresh.
final vaultListProvider = FutureProvider.autoDispose<List<Vault>>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(vaultRepositoryProvider).getVaults(workspaceId);
});
