import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/shift.dart';

class ShiftRepository {
  final Dio _dio;

  ShiftRepository(this._dio);

  Future<List<Shift>> getShifts(String workspaceId) async {
    try {
      final response = await _dio.get(ApiEndpoints.shifts(workspaceId));
      final list = response.data as List<dynamic>;
      return list.map((e) => Shift.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// A backend response of `null` (no open shift) arrives as an empty HTTP
  /// body, not the JSON literal `null` — Nest/Express's `res.send(null)`
  /// sends no body at all, which dio decodes as an empty [String], not
  /// Dart `null`. Checking `is! Map` (rather than `== null`) catches that
  /// case along with the real null.
  Future<Shift?> getCurrent(String workspaceId) async {
    try {
      final response = await _dio.get(ApiEndpoints.shiftCurrent(workspaceId));
      if (response.data is! Map<String, dynamic>) return null;
      return Shift.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Shift> open({required String workspaceId, String? note}) async {
    try {
      final response = await _dio.post(ApiEndpoints.shiftOpen(workspaceId), data: {
        if (note != null && note.isNotEmpty) 'note': note,
      });
      return Shift.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Shift> close({required String workspaceId, required String shiftId, String? note}) async {
    try {
      final response = await _dio.post(ApiEndpoints.shiftClose(workspaceId, shiftId), data: {
        if (note != null && note.isNotEmpty) 'note': note,
      });
      return Shift.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepository(ref.watch(dioProvider));
});

final currentShiftProvider = FutureProvider.autoDispose<Shift?>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(shiftRepositoryProvider).getCurrent(workspaceId);
});

final shiftHistoryProvider = FutureProvider.autoDispose<List<Shift>>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(shiftRepositoryProvider).getShifts(workspaceId);
});
