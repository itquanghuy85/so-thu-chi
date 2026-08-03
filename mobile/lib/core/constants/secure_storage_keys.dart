/// Keys used to read/write values in [FlutterSecureStorage] across the app.
class SecureStorageKeys {
  SecureStorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String selectedWorkspaceId = 'selected_workspace_id';
  static const String pinCode = 'app_lock_pin';
  static const String biometricEnabled = 'app_lock_biometric_enabled';
  static const String syncedPinHash = 'app_lock_synced_pin_hash';
  static const String syncedHasPin = 'app_lock_synced_has_pin';
  static const String visualStyle = 'app_visual_style';
  static const String onboardingSeen = 'onboarding_seen';
  static const String fcmToken = 'fcm_token_registered';

  /// Temporary — human-readable outcome of the last FCM registration
  /// attempt, shown in Settings so this can be diagnosed on-device without
  /// needing an Xcode/adb console. Remove once iOS push is confirmed
  /// working (see settings_screen.dart's "Chẩn đoán thông báo" tile).
  static const String fcmDebugStatus = 'fcm_debug_status';
}
