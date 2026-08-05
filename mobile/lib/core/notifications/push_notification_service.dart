import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app.dart';
import '../constants/secure_storage_keys.dart';
import '../../shared/providers/secure_storage_provider.dart';
import 'notifications_repository.dart';
import 'reminder_notification_service.dart';

const _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Thông báo Sổ Thu Chi',
  description: 'Thông báo giao dịch, ngân sách và giao dịch định kỳ',
  importance: Importance.high,
);

/// Runs in a separate background isolate when a push arrives while the app
/// is backgrounded/terminated. Android/iOS already auto-display the system
/// notification for a `notification`-payload message (which is all the
/// backend ever sends — see NotificationsService.notifyWorkspace), so this
/// handler is intentionally a near-no-op; it just has to exist and
/// initialize Firebase for the isolate, per the firebase_messaging contract.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Push notifications (Mục — "Thông báo đẩy"): registers this device's FCM
/// token with the backend, shows a heads-up notification while the app is
/// in the foreground (the OS suppresses the system tray banner in that
/// case), and routes a notification tap to the relevant screen.
class PushNotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize(Ref ref) async {
    if (_initialized) return;
    _initialized = true;

    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    await _localNotifications.initialize(
      const InitializationSettings(
        // ic_stat_notification là white monochrome drawable — bắt buộc Android 5+.
        android: AndroidInitializationSettings('ic_stat_notification'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        _navigate(ref, jsonDecode(payload) as Map<String, dynamic>);
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(ReminderNotificationService.channel);

    // Schedule daily reminders theo cài đặt người dùng (default: bật).
    final morningOn = await ref.read(secureStorageProvider).read(key: SecureStorageKeys.reminderMorningEnabled) != 'false';
    final eveningOn = await ref.read(secureStorageProvider).read(key: SecureStorageKeys.reminderEveningEnabled) != 'false';
    await ReminderNotificationService(_localNotifications).applySettings(
      morningEnabled: morningOn,
      eveningEnabled: eveningOn,
    );

    FirebaseMessaging.onMessage.listen((message) => _showForegroundNotification(message));
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _navigate(ref, message.data));

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _navigate(ref, initialMessage.data);
    }

    final repository = ref.read(notificationsRepositoryProvider);
    final secureStorage = ref.read(secureStorageProvider);
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => _registerToken(repository: repository, secureStorage: secureStorage, token: token),
    );
    await _fetchAndRegister(repository: repository, secureStorage: secureStorage);
  }

  /// Re-runs the fetch-token → register-with-backend flow unconditionally
  /// (bypassing the "unchanged token" skip in [_registerToken]) — used by
  /// the temporary "Chẩn đoán thông báo" tile in Settings so the outcome
  /// can be checked on-device. Takes explicit dependencies rather than a
  /// `Ref`/`WidgetRef` — see [unregister]'s doc comment for why.
  Future<void> debugForceReRegister({
    required NotificationsRepository repository,
    required FlutterSecureStorage secureStorage,
  }) =>
      _fetchAndRegister(repository: repository, secureStorage: secureStorage, force: true);

  Future<void> _fetchAndRegister({
    required NotificationsRepository repository,
    required FlutterSecureStorage secureStorage,
    bool force = false,
  }) async {
    try {
      // iOS/macOS only: the FCM token can't be minted until the native APNs
      // device token has actually arrived — an async round-trip through
      // Apple's push service that hasn't necessarily finished by the time
      // this runs right after app launch. Calling getToken() before that
      // lands fails with "apns-token-not-set" (a documented, one-time
      // per-cold-start race, not a broken setup) — so wait for it first.
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        var apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        var attempts = 0;
        while (apnsToken == null && attempts < 10) {
          await Future.delayed(const Duration(seconds: 1));
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          attempts++;
        }
        if (apnsToken == null) {
          await secureStorage.write(
            key: SecureStorageKeys.fcmDebugStatus,
            value:
                'APNS token vẫn null sau ${attempts}s chờ lúc ${DateTime.now()} — thiết bị chưa đăng ký nhận push với Apple thành công (kiểm tra lại Push Notifications capability/provisioning profile trong Xcode).',
          );
          return;
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        await secureStorage.write(
          key: SecureStorageKeys.fcmDebugStatus,
          value: 'getToken() trả về null lúc ${DateTime.now()} — thiết bị chưa nhận được token nào từ Firebase/APNs.',
        );
        return;
      }
      await _registerToken(repository: repository, secureStorage: secureStorage, token: token, force: force);
    } catch (e) {
      await secureStorage.write(
        key: SecureStorageKeys.fcmDebugStatus,
        value: 'getToken() báo lỗi lúc ${DateTime.now()}: $e',
      );
    }
  }

  Future<void> _registerToken({
    required NotificationsRepository repository,
    required FlutterSecureStorage secureStorage,
    required String token,
    bool force = false,
  }) async {
    final lastRegistered = await secureStorage.read(key: SecureStorageKeys.fcmToken);
    if (!force && lastRegistered == token) {
      await secureStorage.write(
        key: SecureStorageKeys.fcmDebugStatus,
        value: 'OK (không đổi) lúc ${DateTime.now()} — token ...${token.substring(token.length - 8)}',
      );
      return;
    }
    try {
      await repository.registerToken(token);
      await secureStorage.write(key: SecureStorageKeys.fcmToken, value: token);
      await secureStorage.write(
        key: SecureStorageKeys.fcmDebugStatus,
        value: 'Đăng ký THÀNH CÔNG lúc ${DateTime.now()} — token ...${token.substring(token.length - 8)}',
      );
    } catch (e) {
      // Best-effort: a failed registration (e.g. offline right after login)
      // just means this device won't get pushes until the next successful
      // attempt — never block app startup over it.
      await secureStorage.write(
        key: SecureStorageKeys.fcmDebugStatus,
        value: 'Đăng ký THẤT BẠI lúc ${DateTime.now()}: $e',
      );
      debugPrint('FCM token registration failed: $e');
    }
  }

  /// Called at logout so a shared/reused device stops receiving this
  /// account's pushes once signed out. Takes its dependencies directly
  /// (rather than a `Ref`) so it can be called from either a `Ref` or a
  /// `WidgetRef` call site — the two don't share a common supertype.
  Future<void> unregister({required NotificationsRepository repository, required FlutterSecureStorage secureStorage}) async {
    final token = await secureStorage.read(key: SecureStorageKeys.fcmToken);
    if (token != null && token.isNotEmpty) {
      try {
        await repository.unregisterToken(token);
      } catch (_) {
        // best-effort
      }
    }
    await secureStorage.delete(key: SecureStorageKeys.fcmToken);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    // Unique ID per notification avoids later ones silently replacing earlier
    // ones that share the same hashCode.
    final id = DateTime.now().millisecondsSinceEpoch % 0x7FFFFFFF;
    await _localNotifications.show(
      id,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          // Monochrome drawable required on Android 5+ for notification icons.
          icon: '@drawable/ic_stat_notification',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _navigate(Ref ref, Map<String, dynamic> data) {
    final router = ref.read(goRouterProvider);
    switch (data['type']) {
      case 'transaction_created':
      case 'recurring_run':
        router.go('/transactions');
        break;
      case 'budget_over_limit':
        router.go('/budgets');
        break;
      case 'morning_reminder':
        router.go('/shift');
        break;
      case 'evening_reminder':
        router.go('/daily-closing');
        break;
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) => PushNotificationService());

/// Side-effect-only provider (same pattern as `autoFlushOnReconnectProvider`)
/// — watched once from `MainShellScreen`, which only renders once the user
/// is authenticated and has a workspace selected, so token registration
/// always has a valid session to attach to.
final pushNotificationInitProvider = Provider<void>((ref) {
  ref.read(pushNotificationServiceProvider).initialize(ref);
});
