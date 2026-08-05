import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/offline/app_database.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/customer.dart';

/// Quản lý nhà cung cấp (công nợ phải trả).
///
/// Nhà cung cấp (NCC) được lưu trên server cùng endpoint `/customers` như
/// khách hàng thông thường — không cần backend mới. Một bảng SQLite cục bộ
/// [AppDatabase.supplier_flags] phân biệt NCC với khách hàng. Giao dịch
/// dùng cùng các loại `debt_increase` / `debt_decrease` nên số dư hiển thị
/// đúng hoàn toàn qua `Customer.debtBalance` từ server.
///
/// Lưu ý về túi tiền với "Đã trả NCC": backend `debt_decrease` ghi nhận
/// tiền VÀO túi (vì thiết kế cho khách trả nợ). Để cân đối số dư túi,
/// UI sẽ nhắc người dùng tạo thêm giao dịch Chi tương ứng.
class SupplierRepository {
  final Dio _dio;

  SupplierRepository(this._dio);

  Future<List<Customer>> getSuppliers(String workspaceId) async {
    final supplierIds = await AppDatabase.instance.getSupplierIds(workspaceId);
    if (supplierIds.isEmpty) return [];

    final cacheKey = 'customers:$workspaceId';
    try {
      final response = await _dio.get(ApiEndpoints.customers(workspaceId));
      await AppDatabase.instance.putCache(cacheKey, workspaceId, response.data);
      final list = response.data as List<dynamic>;
      return list
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .where((c) => supplierIds.contains(c.id))
          .toList();
    } on DioException catch (e) {
      final apiError = ApiException.fromDioException(e);
      if (apiError.code == 'CONNECTION_ERROR' || apiError.code == 'TIMEOUT') {
        final cached = await AppDatabase.instance.getCache(cacheKey);
        if (cached is List<dynamic>) {
          return cached
              .map((e) => Customer.fromJson(e as Map<String, dynamic>))
              .where((c) => supplierIds.contains(c.id))
              .toList();
        }
      }
      throw apiError;
    }
  }

  Future<Customer> createSupplier({
    required String workspaceId,
    required String name,
    String? phone,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.customers(workspaceId), data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
      final supplier = Customer.fromJson(response.data as Map<String, dynamic>);
      await AppDatabase.instance.markAsSupplier(supplier.id, workspaceId);
      return supplier;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteSupplier(String customerId) async {
    try {
      await _dio.delete(ApiEndpoints.deleteCustomer(customerId));
      await AppDatabase.instance.removeSupplierFlag(customerId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<DebtHistoryEntry>> getPayableHistory(String supplierId) async {
    try {
      final response = await _dio.get(ApiEndpoints.customerDebtHistory(supplierId));
      final list = response.data as List<dynamic>;
      return list.map((e) => DebtHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(ref.watch(dioProvider));
});

final supplierListProvider = FutureProvider.autoDispose<List<Customer>>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(supplierRepositoryProvider).getSuppliers(workspaceId);
});
