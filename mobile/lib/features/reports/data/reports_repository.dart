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

  /// Per-day revenue/expense/profit rows for [fromDate, toDate] (inclusive
  /// on both ends). Days with no transactions simply have no row.
  Future<List<DailySummary>> getDailySummary({
    required String workspaceId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await _dio.get(ApiEndpoints.dailySummaryReport, queryParameters: {
        'workspace_id': workspaceId,
        'from_date': _dateOnly(fromDate),
        'to_date': _dateOnly(toDate),
      });
      return (response.data as List<dynamic>).map((e) => DailySummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(dioProvider));
});
