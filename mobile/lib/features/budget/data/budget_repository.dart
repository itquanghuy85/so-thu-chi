import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/budget.dart';

class BudgetRepository {
  final Dio _dio;

  BudgetRepository(this._dio);

  Future<List<Budget>> getBudgets(String workspaceId) async {
    try {
      final response = await _dio.get(ApiEndpoints.budgets(workspaceId));
      final list = response.data as List<dynamic>;
      return list.map((e) => Budget.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Budget> createBudget({required String workspaceId, String? categoryId, required num limitAmount}) async {
    try {
      final response = await _dio.post(ApiEndpoints.budgets(workspaceId), data: {
        if (categoryId != null) 'category_id': categoryId,
        'limit_amount': limitAmount,
      });
      return Budget.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Budget> updateBudget({required String workspaceId, required String budgetId, required num limitAmount}) async {
    try {
      final response = await _dio.patch(ApiEndpoints.budget(workspaceId, budgetId), data: {'limit_amount': limitAmount});
      return Budget.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteBudget({required String workspaceId, required String budgetId}) async {
    try {
      await _dio.delete(ApiEndpoints.budget(workspaceId, budgetId));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(dioProvider));
});

final budgetListProvider = FutureProvider.autoDispose<List<Budget>>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(budgetRepositoryProvider).getBudgets(workspaceId);
});
