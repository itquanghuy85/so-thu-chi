import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/offline/app_database.dart';
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
  ///
  /// Cached/replayed offline like `VaultRepository.getVaults` and
  /// `TransactionRepository.getTransactions` — the Dashboard's
  /// `dashboardDataProvider` combines all three via `Future.wait`, so
  /// leaving this one uncached meant it alone threw offline and failed the
  /// whole combined future, hiding the vaults/transactions data that *did*
  /// have a cached fallback behind a generic "can't load" error.
  Future<List<DailySummary>> getDailySummary({
    required String workspaceId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final cacheKey = 'daily_summary:$workspaceId:${_dateOnly(fromDate)}:${_dateOnly(toDate)}';
    try {
      final response = await _dio.get(ApiEndpoints.dailySummaryReport, queryParameters: {
        'workspace_id': workspaceId,
        'from_date': _dateOnly(fromDate),
        'to_date': _dateOnly(toDate),
      });
      await AppDatabase.instance.putCache(cacheKey, workspaceId, response.data);
      return (response.data as List<dynamic>).map((e) => DailySummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final apiError = ApiException.fromDioException(e);
      if (apiError.code == 'CONNECTION_ERROR' || apiError.code == 'TIMEOUT') {
        final cached = await AppDatabase.instance.getCache(cacheKey);
        if (cached is List<dynamic>) {
          return cached.map((e) => DailySummary.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
      throw apiError;
    }
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(dioProvider));
});
