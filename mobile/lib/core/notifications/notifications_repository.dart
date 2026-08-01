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

  Future<void> unregisterToken() async {
    try {
      await _dio.delete(ApiEndpoints.fcmToken);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(dioProvider));
});
