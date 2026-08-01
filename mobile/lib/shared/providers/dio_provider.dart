import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import 'secure_storage_provider.dart';

/// Shared [Dio] instance with the auth interceptor wired up (see
/// [DioClient]). On an unrecoverable 401 (refresh also failed), it flips
/// [authNotifierProvider] back to unauthenticated so `go_router`'s redirect
/// sends the user to Login.
///
/// Note: this closure only *reads* [authNotifierProvider] lazily when an
/// error actually occurs (not during this provider's own build), so it does
/// not form a build-time circular dependency even though
/// `authRepositoryProvider` itself depends on [dioProvider].
final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final client = DioClient(
    secureStorage: storage,
    onUnauthenticated: () async {
      ref.read(authNotifierProvider.notifier).handleUnauthenticated();
    },
  );
  return client.dio;
});
