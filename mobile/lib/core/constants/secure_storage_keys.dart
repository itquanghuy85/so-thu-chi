/// Keys used to read/write values in [FlutterSecureStorage] across the app.
class SecureStorageKeys {
  SecureStorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String selectedWorkspaceId = 'selected_workspace_id';
  static const String pinCode = 'app_lock_pin';
  static const String biometricEnabled = 'app_lock_biometric_enabled';
}
