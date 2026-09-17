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
  static const String failedPinAttempts = 'app_lock_failed_attempts';
  static const String pinLockoutUntil = 'app_lock_lockout_until';
  static const String visualStyle = 'app_visual_style';

  /// Ratio (0..1) of the draggable range where the floating "Trợ lý AI"
  /// button in the main shell was last dragged to.
  static const String aiFabTopRatio = 'ui_ai_fab_top_ratio';
  static const String onboardingSeen = 'onboarding_seen';
  static const String fcmToken = 'fcm_token_registered';

  static const String reminderMorningEnabled = 'reminder_morning_enabled';
  static const String reminderEveningEnabled = 'reminder_evening_enabled';

  /// Temporary — human-readable outcome of the last FCM registration
  /// attempt, shown in Settings so this can be diagnosed on-device without
  /// needing an Xcode/adb console. Remove once iOS push is confirmed
  /// working (see settings_screen.dart's "Chẩn đoán thông báo" tile).
  static const String fcmDebugStatus = 'fcm_debug_status';
}
