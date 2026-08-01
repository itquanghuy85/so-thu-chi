import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/audit_log_entry.dart';

class AuditLogRepository {
  final Dio _dio;

  AuditLogRepository(this._dio);

  Future<AuditLogPage> getLogs(String workspaceId, {int page = 1, int limit = 30}) async {
    try {
      final response = await _dio.get(ApiEndpoints.auditLogs(workspaceId), queryParameters: {'page': page, 'limit': limit});
      return AuditLogPage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepository(ref.watch(dioProvider));
});

final auditLogListProvider = FutureProvider.autoDispose<AuditLogPage>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(auditLogRepositoryProvider).getLogs(workspaceId);
});
