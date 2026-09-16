import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/recurring_transaction.dart';

class RecurringRepository {
  final Dio _dio;

  RecurringRepository(this._dio);

  Future<List<RecurringTransaction>> getRecurring(String workspaceId) async {
    try {
      final response = await _dio.get(ApiEndpoints.recurring(workspaceId));
      final list = response.data as List<dynamic>;
      return list.map((e) => RecurringTransaction.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<RecurringTransaction> create({
    required String workspaceId,
    required String type,
    required num amount,
    String? categoryId,
    String? fromVaultId,
    String? toVaultId,
    String? customerId,
    String? note,
    required String frequency,
    required DateTime startDate,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.recurring(workspaceId), data: {
        'type': type,
        'amount': amount,
        if (categoryId != null) 'category_id': categoryId,
        if (fromVaultId != null) 'from_vault_id': fromVaultId,
        if (toVaultId != null) 'to_vault_id': toVaultId,
        if (customerId != null) 'customer_id': customerId,
        if (note != null && note.isNotEmpty) 'note': note,
        'frequency': frequency,
        'start_date': startDate.toIso8601String(),
      });
      return RecurringTransaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> setActive({required String workspaceId, required String id, required bool active}) async {
    try {
      await _dio.patch(ApiEndpoints.recurringItem(workspaceId, id), data: {'active': active});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Edit an existing recurring template. Same body shape as [create] — the
  /// server applies only the fields that differ.
  Future<RecurringTransaction> update({
    required String workspaceId,
    required String id,
    required String type,
    required num amount,
    String? categoryId,
    String? fromVaultId,
    String? toVaultId,
    String? customerId,
    String? note,
    required String frequency,
    required DateTime startDate,
  }) async {
    try {
      final response = await _dio.patch(ApiEndpoints.recurringItem(workspaceId, id), data: {
        'type': type,
        'amount': amount,
        if (categoryId != null) 'category_id': categoryId,
        if (fromVaultId != null) 'from_vault_id': fromVaultId,
        if (toVaultId != null) 'to_vault_id': toVaultId,
        if (customerId != null) 'customer_id': customerId,
        if (note != null && note.isNotEmpty) 'note': note,
        'frequency': frequency,
        'start_date': startDate.toIso8601String(),
      });
      return RecurringTransaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> delete({required String workspaceId, required String id}) async {
    try {
      await _dio.delete(ApiEndpoints.recurringItem(workspaceId, id));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Materializes every due occurrence — see RecurringService.runDue on the
  /// backend. Returns how many transactions were just created so the caller
  /// can decide whether to refresh the Dashboard/transaction list.
  Future<int> runDue(String workspaceId) async {
    try {
      final response = await _dio.post(ApiEndpoints.recurringRunDue(workspaceId));
      return (response.data as Map<String, dynamic>)['created_count'] as int? ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(dioProvider));
});

final recurringListProvider = FutureProvider.autoDispose<List<RecurringTransaction>>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(recurringRepositoryProvider).getRecurring(workspaceId);
});
