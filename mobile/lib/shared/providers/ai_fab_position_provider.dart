import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/secure_storage_keys.dart';
import 'secure_storage_provider.dart';

/// Persists where the user last parked the draggable "Trợ lý AI" button, so
/// the shell restores it on the next launch instead of snapping back to the
/// default spot.
///
/// Stores the position as a **ratio** of the draggable range (0..1) rather
/// than an absolute pixel offset, so it stays correct after a rotation or on
/// a device with a different screen height. `null` means "nothing saved yet"
/// — the button then uses its default position.
class AiFabPositionNotifier extends StateNotifier<double?> {
  final FlutterSecureStorage _secureStorage;

  AiFabPositionNotifier(this._secureStorage) : super(null) {
    _restore();
  }

  Future<void> _restore() async {
    final saved = await _secureStorage.read(key: SecureStorageKeys.aiFabTopRatio);
    final ratio = double.tryParse(saved ?? '');
    if (ratio != null && ratio.isFinite) {
      state = ratio.clamp(0.0, 1.0);
    }
  }

  Future<void> saveRatio(double ratio) async {
    final safe = ratio.clamp(0.0, 1.0);
    state = safe;
    await _secureStorage.write(key: SecureStorageKeys.aiFabTopRatio, value: safe.toStringAsFixed(4));
  }
}

final aiFabPositionProvider = StateNotifierProvider<AiFabPositionNotifier, double?>((ref) {
  return AiFabPositionNotifier(ref.watch(secureStorageProvider));
});