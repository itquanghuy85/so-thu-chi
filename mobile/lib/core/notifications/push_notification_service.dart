import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app.dart';
import '../constants/secure_storage_keys.dart';
import '../../shared/providers/secure_storage_provider.dart';
import 'notifications_repository.dart';

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
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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

    FirebaseMessaging.onMessage.listen((message) => _showForegroundNotification(message));
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _navigate(ref, message.data));

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _navigate(ref, initialMessage.data);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) => _registerToken(ref, token));
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _registerToken(ref, token);
    }
  }

  Future<void> _registerToken(Ref ref, String token) async {
    final secureStorage = ref.read(secureStorageProvider);
    final lastRegistered = await secureStorage.read(key: SecureStorageKeys.fcmToken);
    if (lastRegistered == token) return;
    try {
      await ref.read(notificationsRepositoryProvider).registerToken(token);
      await secureStorage.write(key: SecureStorageKeys.fcmToken, value: token);
    } catch (e) {
      // Best-effort: a failed registration (e.g. offline right after login)
      // just means this device won't get pushes until the next successful
      // attempt — never block app startup over it.
      debugPrint('FCM token registration failed: $e');
    }
  }

  /// Called at logout so a shared/reused device stops receiving this
  /// account's pushes once signed out. Takes its dependencies directly
  /// (rather than a `Ref`) so it can be called from either a `Ref` or a
  /// `WidgetRef` call site — the two don't share a common supertype.
  Future<void> unregister({required NotificationsRepository repository, required FlutterSecureStorage secureStorage}) async {
    try {
      await repository.unregisterToken();
    } catch (_) {
      // best-effort
    }
    await secureStorage.delete(key: SecureStorageKeys.fcmToken);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
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
