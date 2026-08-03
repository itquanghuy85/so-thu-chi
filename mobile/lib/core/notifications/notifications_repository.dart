import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_endpoints.dart';
import '../errors/api_exception.dart';
import '../../shared/providers/dio_provider.dart';

class NotificationsRepository {
  final Dio _dio;

  NotificationsRepository(this._dio);

  Future<void> registerToken(String token) async {
    try {
      await _dio.patch(ApiEndpoints.fcmToken, data: {'token': token});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Removes only this one device's registration — see
  /// `NotificationsService.unregisterToken`'s doc comment on the backend
  /// for why it needs the specific token, not just "the" token for the
  /// signed-in account.
  Future<void> unregisterToken(String token) async {
    try {
      await _dio.delete(ApiEndpoints.fcmToken, data: {'token': token});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(dioProvider));
});
