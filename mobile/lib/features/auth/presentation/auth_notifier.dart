import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/social_auth_service.dart';
import '../domain/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;

  const AuthState({required this.status, this.user});

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);
  const AuthState.authenticated(User user) : this(status: AuthStatus.authenticated, user: user);
}

/// Holds the app-wide authentication state. On construction it checks
/// whether a token is already stored (e.g. app relaunch) and validates it
/// against `GET /auth/me`.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final SocialAuthService _socialAuth = SocialAuthService();

  AuthNotifier(this._repository) : super(const AuthState.unknown()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await _repository.readAccessToken();
    if (token == null || token.isEmpty) {
      state = const AuthState.unauthenticated();
      return;
    }
    try {
      final user = await _repository.me();
      state = AuthState.authenticated(user);
    } on ApiException catch (e) {
      if (e.code == 'CONNECTION_ERROR' || e.code == 'TIMEOUT') {
        // Offline-first (Mục 14): a cold start with no network can't prove
        // the token is still valid, but it can't prove it's invalid either
        // — don't force a login screen the user has no way to act on while
        // offline, and don't discard a token that might still be good.
        // Trust the last-known session (cached at login time and refreshed
        // on every successful `/auth/me`); if the token really is dead, the
        // dio interceptor's refresh flow will catch it and log out on the
        // first real request once back online.
        final cachedUser = await _repository.readCachedUser();
        state = cachedUser != null ? AuthState.authenticated(cachedUser) : const AuthState.unauthenticated();
        return;
      }
      // Genuine auth failure (401 the refresh flow couldn't recover from) —
      // the token really is dead.
      await _repository.clearTokens();
      state = const AuthState.unauthenticated();
    } catch (_) {
      await _repository.clearTokens();
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _repository.login(email: email, password: password);
    state = AuthState.authenticated(result.user);
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final result = await _repository.register(email: email, password: password, fullName: fullName);
    state = AuthState.authenticated(result.user);
  }

  Future<void> socialSignIn({required String idToken, required String provider}) async {
    final result = await _repository.socialLogin(idToken: idToken, provider: provider);
    state = AuthState.authenticated(result.user);
  }

  Future<void> logout() async {
    await _repository.clearTokens();
    await _socialAuth.signOut();
    state = const AuthState.unauthenticated();
  }

  /// Invoked by the Dio interceptor when a token refresh fails, so the
  /// router redirect can send the user back to Login. Tokens are already
  /// cleared by the interceptor at this point.
  void handleUnauthenticated() {
    if (state.status != AuthStatus.unauthenticated) {
      state = const AuthState.unauthenticated();
    }
  }
}

final StateNotifierProvider<AuthNotifier, AuthState> authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

/// Rethrows repository errors as a friendly message string, used by
/// login/register screens to show a SnackBar.
String describeAuthError(Object error) {
  if (error is ApiException) return error.message;
  return 'Đã có lỗi xảy ra. Vui lòng thử lại.';
}
