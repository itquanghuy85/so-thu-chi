/// Keys used to read/write values in [FlutterSecureStorage] across the app.
class SecureStorageKeys {
  SecureStorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String selectedWorkspaceId = 'selected_workspace_id';
  static const String pinCode = 'app_lock_pin';
  static const String biometricEnabled = 'app_lock_biometric_enabled';
  static const String visualStyle = 'app_visual_style';
  static const String onboardingSeen = 'onboarding_seen';
  static const String fcmToken = 'fcm_token_registered';
}
