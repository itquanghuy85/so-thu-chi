import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../shared/providers/secure_storage_provider.dart';

/// Tracks whether this device has already dismissed the first-launch
/// onboarding tour (Mục — "Onboarding tour overlay"). `null` means "not
/// determined yet" (still reading from secure storage) — the router
/// redirect in app.dart treats that the same as "seen" so a slow read
/// never blocks a returning user from reaching the app.
class OnboardingNotifier extends StateNotifier<bool?> {
  final FlutterSecureStorage _secureStorage;

  OnboardingNotifier(this._secureStorage) : super(null) {
    _restore();
  }

  Future<void> _restore() async {
    final saved = await _secureStorage.read(key: SecureStorageKeys.onboardingSeen);
    state = saved == 'true';
  }

  Future<void> markSeen() async {
    state = true;
    await _secureStorage.write(key: SecureStorageKeys.onboardingSeen, value: 'true');
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, bool?>((ref) {
  return OnboardingNotifier(ref.watch(secureStorageProvider));
});
