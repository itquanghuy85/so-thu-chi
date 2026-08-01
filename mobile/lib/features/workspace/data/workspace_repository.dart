import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/offline/app_database.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/workspace.dart';

const _workspacesCacheKey = 'workspaces';

class WorkspaceRepository {
  final Dio _dio;

  WorkspaceRepository(this._dio);

  /// Cached (Mục 14) so a cold start while offline can still resolve which
  /// workspace was selected and route straight into the main shell instead
  /// of stalling on an empty Workspace Picker — see
  /// `AuthNotifier._restoreSession` for the matching session-restore fix.
  Future<List<Workspace>> getWorkspaces() async {
    try {
      final response = await _dio.get(ApiEndpoints.workspaces);
      await AppDatabase.instance.putCache(_workspacesCacheKey, '', response.data);
      final list = response.data as List<dynamic>;
      return list.map((e) => Workspace.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final apiError = ApiException.fromDioException(e);
      if (apiError.code == 'CONNECTION_ERROR' || apiError.code == 'TIMEOUT') {
        final cached = await AppDatabase.instance.getCache(_workspacesCacheKey);
        if (cached is List<dynamic>) {
          return cached.map((e) => Workspace.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
      throw apiError;
    }
  }

  Future<Workspace> createWorkspace({required String name, required WorkspaceType type}) async {
    try {
      final response = await _dio.post(ApiEndpoints.workspaces, data: {
        'name': name,
        'type': workspaceTypeToString(type),
      });
      return Workspace.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Workspace> getWorkspace(String id) async {
    try {
      final response = await _dio.get(ApiEndpoints.workspace(id));
      return Workspace.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// "Tham gia bằng mã mời" (Mục 8.5).
  Future<Workspace> joinWorkspace(String inviteCode) async {
    try {
      final response = await _dio.post(ApiEndpoints.joinWorkspace, data: {'invite_code': inviteCode});
      return Workspace.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<String> regenerateInviteCode(String workspaceId) async {
    try {
      final response = await _dio.post(ApiEndpoints.regenerateInviteCode(workspaceId));
      return (response.data as Map<String, dynamic>)['invite_code'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> removeMember({required String workspaceId, required String userId}) async {
    try {
      await _dio.delete(ApiEndpoints.removeMember(workspaceId, userId));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  return WorkspaceRepository(ref.watch(dioProvider));
});
