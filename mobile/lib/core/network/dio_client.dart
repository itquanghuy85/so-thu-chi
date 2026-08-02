import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_endpoints.dart';
import '../constants/secure_storage_keys.dart';

/// Wraps a configured [Dio] instance with:
/// - a request interceptor that attaches `Authorization: Bearer <token>`
///   from secure storage;
/// - a response-error interceptor that, on `401 Unauthorized`, attempts a
///   single token refresh via `POST /auth/refresh` and retries the original
///   request. Concurrent 401s share a single in-flight refresh call.
/// - if the refresh itself fails, tokens are cleared and [onUnauthenticated]
///   is invoked so the app can navigate back to Login.
class DioClient {
  final Dio dio;
  final FlutterSecureStorage secureStorage;
  final Future<void> Function()? onUnauthenticated;

  /// Plain client (no auth header, no interceptors) used only for the
  /// refresh call itself, to avoid recursively triggering the interceptor.
  late final Dio _refreshDio;

  Future<bool>? _refreshInFlight;

  DioClient({required this.secureStorage, this.onUnauthenticated})
      : dio = Dio(
          BaseOptions(
            baseUrl: ApiEndpoints.baseUrl,
            // Connect is capped shorter than receive/send: if a TCP
            // handshake hasn't completed in 8s the path is broken (a
            // router isolating this device from the backend host, wrong
            // Wi-Fi, etc.) — waiting the full receive/send budget for that
            // case just makes every screen feel frozen. Once actually
            // connected, a slow mobile connection genuinely transferring
            // data gets more slack.
            //
            // receive/send used to be 12s, which is shorter than the free-
            // tier backend's own documented cold-start time (up to ~50s
            // after ~15 min idle — see workspace_picker_screen.dart's
            // "Đang kết nối máy chủ lần đầu..." hint and backend/README.md)
            // — meaning the very first request after any idle period was
            // liable to time out client-side before the server even
            // finished waking up, surfaced as "kết nối máy chủ quá thời
            // gian" on actions like Khôi phục that happened to be the first
            // request in a while. 60s gives real margin above that.
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 60),
            contentType: 'application/json',
          ),
        ) {
    _refreshDio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await secureStorage.read(key: SecureStorageKeys.accessToken);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final isRefreshCall = error.requestOptions.path == ApiEndpoints.refresh;

          if (isUnauthorized && !isRefreshCall) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              try {
                final retryResponse = await _retry(error.requestOptions);
                return handler.resolve(retryResponse);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            } else {
              await secureStorage.delete(key: SecureStorageKeys.accessToken);
              await secureStorage.delete(key: SecureStorageKeys.refreshToken);
              if (onUnauthenticated != null) {
                await onUnauthenticated!();
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() {
    // Share a single in-flight refresh across concurrent 401s.
    _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight!;
  }

  Future<bool> _performRefresh() async {
    try {
      final refreshToken = await secureStorage.read(key: SecureStorageKeys.refreshToken);
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await _refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = response.data['access_token'] as String?;
      final newRefreshToken = response.data['refresh_token'] as String?;
      if (newAccessToken == null || newRefreshToken == null) return false;

      await secureStorage.write(key: SecureStorageKeys.accessToken, value: newAccessToken);
      await secureStorage.write(key: SecureStorageKeys.refreshToken, value: newRefreshToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = await secureStorage.read(key: SecureStorageKeys.accessToken);
    final options = Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}
