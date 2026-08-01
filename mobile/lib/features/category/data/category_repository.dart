import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/offline/app_database.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/category.dart';

class CategoryRepository {
  final Dio _dio;

  CategoryRepository(this._dio);

  Future<List<Category>> getCategories({
    required String workspaceId,
    required String group, // 'income' | 'expense'
  }) async {
    final cacheKey = 'categories:$workspaceId:$group';
    try {
      final response = await _dio.get(
        ApiEndpoints.categories(workspaceId),
        queryParameters: {'group': group},
      );
      await AppDatabase.instance.putCache(cacheKey, workspaceId, response.data);
      final list = response.data as List<dynamic>;
      return list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final apiError = ApiException.fromDioException(e);
      if (apiError.code == 'CONNECTION_ERROR' || apiError.code == 'TIMEOUT') {
        final cached = await AppDatabase.instance.getCache(cacheKey);
        if (cached is List<dynamic>) {
          return cached.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
      throw apiError;
    }
  }

  Future<Category> createCategory({
    required String workspaceId,
    required String name,
    required String group, // 'income' | 'expense'
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.categories(workspaceId), data: {
        'name': name,
        'group_name': group,
      });
      return Category.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Category> renameCategory({
    required String workspaceId,
    required String categoryId,
    required String name,
  }) async {
    try {
      final response = await _dio.patch(ApiEndpoints.category(workspaceId, categoryId), data: {'name': name});
      return Category.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Throws [ApiException] with code `CONFLICT` if the category is already
  /// used by transactions (backend-enforced, Mục 12.19).
  Future<void> deleteCategory({required String workspaceId, required String categoryId}) async {
    try {
      await _dio.delete(ApiEndpoints.category(workspaceId, categoryId));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(dioProvider));
});

/// Expense categories for the current workspace, used by the "Chi" tab in
/// the create-transaction sheet.
final expenseCategoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(categoryRepositoryProvider).getCategories(workspaceId: workspaceId, group: 'expense');
});

/// Income categories for the current workspace, used by the "Thu" tab
/// ("Khác" source -> optional category picker).
final incomeCategoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(categoryRepositoryProvider).getCategories(workspaceId: workspaceId, group: 'income');
});
