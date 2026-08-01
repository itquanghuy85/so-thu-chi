import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../shared/providers/secure_storage_provider.dart';

/// Backs "Cài PIN / Vân tay" (Mục 14): the PIN itself is stored directly in
/// [FlutterSecureStorage] (Android Keystore / iOS Keychain — the same
/// OS-level encryption already relied on for the access/refresh tokens),
/// not hashed client-side; there's no server round-trip involved, this is
/// purely a local re-entry gate, not an auth credential.
class AppLockService {
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  AppLockService(this._secureStorage);

  Future<bool> hasPin() async {
    final pin = await _secureStorage.read(key: SecureStorageKeys.pinCode);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _secureStorage.write(key: SecureStorageKeys.pinCode, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _secureStorage.read(key: SecureStorageKeys.pinCode);
    return stored != null && stored == pin;
  }

  Future<void> clearPin() async {
    await _secureStorage.delete(key: SecureStorageKeys.pinCode);
    await _secureStorage.delete(key: SecureStorageKeys.biometricEnabled);
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _secureStorage.read(key: SecureStorageKeys.biometricEnabled);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(key: SecureStorageKeys.biometricEnabled, value: enabled.toString());
  }

  /// Whether this device even has usable biometric hardware enrolled — the
  /// biometric toggle in Settings is hidden entirely if this is false.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Xác thực để mở khoá Sổ Thu Chi',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService(ref.watch(secureStorageProvider));
});
