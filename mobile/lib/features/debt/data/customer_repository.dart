import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/offline/app_database.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/customer.dart';

class CustomerRepository {
  final Dio _dio;

  CustomerRepository(this._dio);

  Future<List<Customer>> getCustomers(String workspaceId) async {
    final cacheKey = 'customers:$workspaceId';
    try {
      final response = await _dio.get(ApiEndpoints.customers(workspaceId));
      await AppDatabase.instance.putCache(cacheKey, workspaceId, response.data);
      final list = response.data as List<dynamic>;
      return list.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final apiError = ApiException.fromDioException(e);
      if (apiError.code == 'CONNECTION_ERROR' || apiError.code == 'TIMEOUT') {
        final cached = await AppDatabase.instance.getCache(cacheKey);
        if (cached is List<dynamic>) {
          return cached.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
      throw apiError;
    }
  }

  Future<Customer> createCustomer({
    required String workspaceId,
    required String name,
    String? phone,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.customers(workspaceId), data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<DebtHistoryEntry>> getDebtHistory(String customerId) async {
    try {
      final response = await _dio.get(ApiEndpoints.customerDebtHistory(customerId));
      final list = response.data as List<dynamic>;
      return list.map((e) => DebtHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(dioProvider));
});

/// Customers (with debt balances) for the currently selected workspace.
final customerListProvider = FutureProvider.autoDispose<List<Customer>>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(customerRepositoryProvider).getCustomers(workspaceId);
});
