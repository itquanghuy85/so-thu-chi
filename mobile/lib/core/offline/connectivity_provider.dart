import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live online/offline state (Mục 14), used to show the offline banner and
/// to trigger a sync-queue flush the moment connectivity returns.
///
/// Note: this reflects the *device's* network state (Wi-Fi/mobile data
/// associated), not a guarantee the backend is actually reachable — a
/// captive portal or a backend that's down would still read as "online"
/// here. Repositories still handle that case the same way they always did
/// (an `ApiException` with code `CONNECTION_ERROR`/`TIMEOUT` from the
/// failed request itself), this provider is only used for the proactive
/// banner + auto-flush trigger, not as the sole offline detection method.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final result = ref.watch(connectivityStreamProvider).valueOrNull;
  if (result == null) return true; // optimistic until the first event arrives
  return result.any((r) => r != ConnectivityResult.none);
});
