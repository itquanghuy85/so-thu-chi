import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/gamification_profile.dart';

class GamificationRepository {
  final Dio _dio;

  GamificationRepository(this._dio);

  Future<GamificationProfile> getProfile(String workspaceId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.gamificationProfile,
        queryParameters: {'workspace_id': workspaceId},
      );
      return GamificationProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<GamificationProfile> claimQuest(String workspaceId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.claimQuest,
        data: {'workspace_id': workspaceId},
      );
      return GamificationProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return GamificationRepository(ref.watch(dioProvider));
});

final gamificationProfileProvider = FutureProvider.autoDispose<GamificationProfile>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return ref.watch(gamificationRepositoryProvider).getProfile(workspaceId);
});
