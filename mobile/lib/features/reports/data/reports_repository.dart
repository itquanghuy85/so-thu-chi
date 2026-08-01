import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/cashflow_report.dart';

class ReportsRepository {
  final Dio _dio;

  ReportsRepository(this._dio);

  Future<CashflowReport> getCashflow({required String workspaceId, required ReportPeriod period}) async {
    try {
      final response = await _dio.get(ApiEndpoints.cashflowReport, queryParameters: {
        'workspace_id': workspaceId,
        'period': period.apiValue,
      });
      return CashflowReport.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(dioProvider));
});
