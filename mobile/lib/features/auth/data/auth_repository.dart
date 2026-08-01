import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/offline/app_database.dart';
import '../../../shared/providers/dio_provider.dart';
import '../../../shared/providers/secure_storage_provider.dart';
import '../domain/user.dart';

/// Cache key for the last-known user profile, used so a cold app start
/// while offline (Mục 14) can still restore the session — see
/// `AuthNotifier._restoreSession`.
const _authMeCacheKey = 'auth_me';

/// Result of a successful login/register call.
class AuthResult {
  final User user;
  final String accessToken;
  final String refreshToken;

  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  AuthRepository(this._dio, this._secureStorage);

  Future<AuthResult> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.register, data: {
        'email': email,
        'password': password,
        'full_name': fullName,
      });
      final result = AuthResult.fromJson(response.data as Map<String, dynamic>);
      await _persistTokens(result);
      await _cacheUser((response.data as Map<String, dynamic>)['user'] as Map<String, dynamic>);
      return result;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.login, data: {
        'email': email,
        'password': password,
      });
      final result = AuthResult.fromJson(response.data as Map<String, dynamic>);
      await _persistTokens(result);
      await _cacheUser((response.data as Map<String, dynamic>)['user'] as Map<String, dynamic>);
      return result;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Exchanges a Firebase ID token (obtained after a Google/Apple sign-in on
  /// the client) for this app's own access/refresh token pair. The backend
  /// verifies the token with `firebase-admin` and finds-or-creates the user
  /// by email — see backend `POST /auth/social-login`.
  ///
  /// Retries once on a connectivity-only failure: the native Google/Apple
  /// sign-in sheet briefly switches away to another Activity, and some OEM
  /// Android skins (observed on this project's OPPO/ColorOS test device)
  /// throttle background network egress for the split second right after
  /// the app regains foreground — the very next request can spuriously fail
  /// with a connection error even though the backend was reachable a moment
  /// before and immediately after. A single short-delayed retry absorbs
  /// that window without masking a real backend-down situation (which fails
  /// the same way on the retry too, and still surfaces to the user).
  Future<AuthResult> socialLogin({
    required String idToken,
    required String provider,
  }) async {
    try {
      return await _postSocialLogin(idToken: idToken, provider: provider);
    } on ApiException catch (e) {
      if (e.code != 'CONNECTION_ERROR') rethrow;
      await Future.delayed(const Duration(milliseconds: 1200));
      return _postSocialLogin(idToken: idToken, provider: provider);
    }
  }

  Future<AuthResult> _postSocialLogin({required String idToken, required String provider}) async {
    try {
      final response = await _dio.post(ApiEndpoints.socialLogin, data: {
        'id_token': idToken,
        'provider': provider,
      });
      final result = AuthResult.fromJson(response.data as Map<String, dynamic>);
      await _persistTokens(result);
      await _cacheUser((response.data as Map<String, dynamic>)['user'] as Map<String, dynamic>);
      return result;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Fetches the current user profile. Throws [ApiException] on failure
  /// (including 401 when there is no valid/refreshable token).
  Future<User> me() async {
    try {
      final response = await _dio.get(ApiEndpoints.me);
      final json = response.data as Map<String, dynamic>;
      await _cacheUser(json);
      return User.fromJson(json);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Returns the last-known user profile from a prior successful
  /// login/register/social-login/`/auth/me` call, or null if the user has
  /// never successfully authenticated on this device. Used only when a cold
  /// start's `/auth/me` call fails for connectivity reasons (Mục 14) — see
  /// `AuthNotifier._restoreSession`.
  Future<User?> readCachedUser() async {
    final cached = await AppDatabase.instance.getCache(_authMeCacheKey);
    if (cached is Map<String, dynamic>) return User.fromJson(cached);
    return null;
  }

  Future<void> _cacheUser(Map<String, dynamic> userJson) {
    return AppDatabase.instance.putCache(_authMeCacheKey, '', userJson);
  }

  Future<void> _persistTokens(AuthResult result) async {
    await _secureStorage.write(key: SecureStorageKeys.accessToken, value: result.accessToken);
    await _secureStorage.write(key: SecureStorageKeys.refreshToken, value: result.refreshToken);
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: SecureStorageKeys.accessToken);
    await _secureStorage.delete(key: SecureStorageKeys.refreshToken);
  }

  Future<String?> readAccessToken() {
    return _secureStorage.read(key: SecureStorageKeys.accessToken);
  }
}

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider), ref.watch(secureStorageProvider));
});
