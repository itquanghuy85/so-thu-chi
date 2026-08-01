import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/daily_closing.dart';

class DailyClosingRepository {
  final Dio _dio;

  DailyClosingRepository(this._dio);

  Future<List<DailyClosing>> getHistory(String workspaceId) async {
    try {
      final response = await _dio.get(ApiEndpoints.dailyClosings(workspaceId));
      final list = response.data as List<dynamic>;
      return list.map((e) => DailyClosing.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// `closing` is null when today hasn't been closed yet.
  Future<DailyClosing?> getTodayStatus(String workspaceId) async {
    try {
      final response = await _dio.get(ApiEndpoints.dailyClosingToday(workspaceId));
      final body = response.data as Map<String, dynamic>;
      final closing = body['closing'];
      return closing is Map<String, dynamic> ? DailyClosing.fromJson(closing) : null;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<DailyClosing> close({
    required String workspaceId,
    required List<({String vaultId, num actualBalance})> entries,
    String? note,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.dailyClosings(workspaceId), data: {
        'entries': entries.map((e) => {'vault_id': e.vaultId, 'actual_balance': e.actualBalance}).toList(),
        if (note != null && note.isNotEmpty) 'note': note,
      });
      return DailyClosing.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final dailyClosingRepositoryProvider = Provider<DailyClosingRepository>((ref) {
  return DailyClosingRepository(ref.watch(dioProvider));
});

final dailyClosingTodayProvider = FutureProvider.autoDispose<DailyClosing?>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(dailyClosingRepositoryProvider).getTodayStatus(workspaceId);
});

final dailyClosingHistoryProvider = FutureProvider.autoDispose<List<DailyClosing>>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(dailyClosingRepositoryProvider).getHistory(workspaceId);
});
