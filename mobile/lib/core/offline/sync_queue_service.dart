import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/api_exception.dart';
import '../../shared/providers/dio_provider.dart';
import 'app_database.dart';
import 'connectivity_provider.dart';

/// Replays queued offline mutations (currently: transaction creation) once
/// connectivity returns. Each queued row stores the exact endpoint + body
/// the repository would have sent — flushing just re-issues that same POST,
/// so the backend (not the client) remains the source of truth for
/// balances, XP, etc.
class SyncQueueService {
  final Dio _dio;
  bool _flushing = false;

  SyncQueueService(this._dio);

  Future<int> pendingCount({String? workspaceId}) {
    return AppDatabase.instance.countPendingOperations(workspaceId: workspaceId);
  }

  /// Processes the queue in FIFO order. Stops at the first item that still
  /// fails for connectivity reasons (no point trying the rest — assume
  /// still offline, try again on the next trigger). An item that fails for
  /// a genuine server-side reason (validation, conflict, etc.) is dropped
  /// with its error recorded, rather than blocking every later item behind
  /// a mutation the server will never accept.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final pending = await AppDatabase.instance.getPendingOperations();
      for (final op in pending) {
        final id = op['id'] as int;
        final endpoint = op['endpoint'] as String;
        final payload = op['payload'];
        try {
          await _dio.post(endpoint, data: _decodePayload(payload));
          await AppDatabase.instance.deleteOperation(id);
        } on DioException catch (e) {
          final apiError = ApiException.fromDioException(e);
          if (apiError.code == 'CONNECTION_ERROR' || apiError.code == 'TIMEOUT') {
            // Still offline (or server unreachable) — stop, keep the whole
            // queue intact for the next flush attempt.
            break;
          }
          // A real server-side rejection (validation, insufficient balance,
          // etc.) — this mutation will never succeed as-is. Record the
          // reason and drop it rather than blocking everything behind it.
          await AppDatabase.instance.setOperationError(id, apiError.message);
          await AppDatabase.instance.deleteOperation(id);
        }
      }
    } finally {
      _flushing = false;
    }
  }

  static Map<String, dynamic> _decodePayload(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    throw StateError('Invalid queued payload');
  }
}

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  return SyncQueueService(ref.watch(dioProvider));
});

/// Rebuilds whenever the queue is likely to have changed (enqueue/flush) —
/// callers invalidate this manually rather than polling, since the queue
/// only changes in response to explicit app actions.
final pendingSyncCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(syncQueueServiceProvider).pendingCount();
});

/// Side-effect-only provider: watches connectivity and flushes the queue
/// the moment the device comes back online. Instantiated once from the app
/// root (see `MainShellScreen`) via `ref.watch`, not read elsewhere.
final autoFlushOnReconnectProvider = Provider<void>((ref) {
  ref.listen(isOnlineProvider, (previous, next) {
    if (previous == false && next == true) {
      ref.read(syncQueueServiceProvider).flush().then((_) {
        ref.invalidate(pendingSyncCountProvider);
      });
    }
  });
});
