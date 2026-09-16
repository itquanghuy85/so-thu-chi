import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../shared/providers/secure_storage_provider.dart';
import '../../auth/data/auth_repository.dart';

/// Backs "Cài PIN / Vân tay" (Mục 14). The PIN this device itself set is
/// stored directly in [FlutterSecureStorage] (Android Keystore / iOS
/// Keychain) for a fast local check — unchanged from before.
///
/// New: the PIN is also account-wide now (Mục — "hai máy cùng đăng nhập 1
/// tài khoản"), synced across every device on the account via the backend
/// (`AuthRepository.setPin`/`getPinStatus`). Only a bcrypt *hash* ever
/// travels over the network or sits in the database — never the plaintext
/// PIN, same treatment as the login password. A device that hasn't set its
/// own PIN yet but belongs to an account that has one caches that hash
/// locally (so app-lock still works fully offline, the one hard
/// requirement here) and verifies entries against it with
/// `BCrypt.checkpw`; the first correct entry also becomes this device's own
/// local PIN, so every later unlock is the fast local-only path again.
class AppLockService {
  final FlutterSecureStorage _secureStorage;
  final AuthRepository _authRepository;
  final LocalAuthentication _localAuth = LocalAuthentication();

  AppLockService(this._secureStorage, this._authRepository);

  /// Whether *this device* has its own locally-set PIN — the fast path.
  Future<bool> hasPin() async {
    final pin = await _secureStorage.read(key: SecureStorageKeys.pinCode);
    return pin != null && pin.isNotEmpty;
  }

  /// Whether app-lock should be required at all: this device's own PIN, or
  /// (fallback) the last-synced "this account has a PIN" flag from another
  /// device — see [syncFromServer].
  Future<bool> isLockRequired() async {
    if (await hasPin()) return true;
    final synced = await _secureStorage.read(key: SecureStorageKeys.syncedHasPin);
    return synced == 'true';
  }

  Future<void> setPin(String pin) async {
    await _secureStorage.write(key: SecureStorageKeys.pinCode, value: pin);
    try {
      await _authRepository.setPin(pin);
    } catch (_) {
      // Best-effort — this device still works with its own PIN even if the
      // push to sync it to other devices fails (e.g. offline); nothing here
      // blocks the local app-lock from working.
    }
  }

  /// Checks this device's own PIN first (no network needed); if this device
  /// has never had a PIN set but a hash was synced from another device
  /// (cached locally by [syncFromServer]), falls back to verifying against
  /// that hash and, on a match, adopts it as this device's own PIN so
  /// future unlocks skip straight to the fast local path.
  Future<bool> verifyPin(String pin) async {
    final stored = await _secureStorage.read(key: SecureStorageKeys.pinCode);
    if (stored != null && stored.isNotEmpty) {
      return stored == pin;
    }
    final syncedHash = await _secureStorage.read(key: SecureStorageKeys.syncedPinHash);
    if (syncedHash == null || syncedHash.isEmpty) return false;
    final matches = BCrypt.checkpw(pin, syncedHash);
    if (matches) {
      await _secureStorage.write(key: SecureStorageKeys.pinCode, value: pin);
    }
    return matches;
  }

  Future<void> clearPin() async {
    await _secureStorage.delete(key: SecureStorageKeys.pinCode);
    await _secureStorage.delete(key: SecureStorageKeys.biometricEnabled);
    await _secureStorage.delete(key: SecureStorageKeys.syncedPinHash);
    await _secureStorage.delete(key: SecureStorageKeys.syncedHasPin);
    await resetFailedPinAttempts();
    try {
      await _authRepository.clearPin();
    } catch (_) {
      // best-effort — see setPin's doc comment
    }
  }

  /// Bruteforce guard for the lock screen (Mục 14): after
  /// [maxPinAttempts] wrong entries the PIN pad is frozen for
  /// [pinLockoutDuration]. Count and lockout timestamp are persisted in
  /// secure storage so a restart doesn't reset the lockout.
  static const int maxPinAttempts = 5;
  static const Duration pinLockoutDuration = Duration(seconds: 30);

  Future<int> failedPinAttempts() async {
    final raw = await _secureStorage.read(key: SecureStorageKeys.failedPinAttempts);
    return int.tryParse(raw ?? '') ?? 0;
  }

  /// When the PIN pad is currently locked out; `null` if not locked out.
  Future<DateTime?> pinLockoutUntil() async {
    final raw = await _secureStorage.read(key: SecureStorageKeys.pinLockoutUntil);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Records one more wrong entry; starts the [pinLockoutDuration] freeze
  /// (and resets the counter) once [maxPinAttempts] is reached.
  Future<void> registerFailedPinAttempt() async {
    final attempts = await failedPinAttempts() + 1;
    if (attempts >= maxPinAttempts) {
      await _secureStorage.write(
        key: SecureStorageKeys.pinLockoutUntil,
        value: DateTime.now().add(pinLockoutDuration).toIso8601String(),
      );
      await _secureStorage.write(key: SecureStorageKeys.failedPinAttempts, value: '0');
    } else {
      await _secureStorage.write(key: SecureStorageKeys.failedPinAttempts, value: '$attempts');
    }
  }

  Future<void> resetFailedPinAttempts() async {
    await _secureStorage.delete(key: SecureStorageKeys.failedPinAttempts);
    await _secureStorage.delete(key: SecureStorageKeys.pinLockoutUntil);
  }

  /// Fetches the account's current PIN status from the server and caches
  /// it locally, so [isLockRequired]/[verifyPin] keep working offline
  /// afterward. Call opportunistically (app resume, Settings → Bảo mật) —
  /// never blocks anything if it fails.
  Future<void> syncFromServer() async {
    try {
      final status = await _authRepository.getPinStatus();
      await _secureStorage.write(key: SecureStorageKeys.syncedHasPin, value: status.hasPin.toString());
      if (status.pinHash != null) {
        await _secureStorage.write(key: SecureStorageKeys.syncedPinHash, value: status.pinHash!);
      } else {
        await _secureStorage.delete(key: SecureStorageKeys.syncedPinHash);
      }
    } catch (_) {
      // best-effort
    }
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
  /// Deliberately per-device, unlike the PIN: biometric unlock relies on
  /// this device's own enrolled fingerprints/face, which have no
  /// equivalent to sync to another device's different hardware.
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
  return AppLockService(ref.watch(secureStorageProvider), ref.watch(authRepositoryProvider));
});
