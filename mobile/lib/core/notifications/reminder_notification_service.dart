import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _reminderChannelId = 'daily_reminder_channel';

/// ID cố định cho 2 nhắc nhở hằng ngày (không dùng random để cancel được).
const morningReminderId = 8000;
const eveningReminderId = 8001;

/// Thông báo nhắc nhở cục bộ lúc 7:00 sáng và 22:00 tối.
/// Bấm vào thông báo → navigate đến màn hình tương ứng qua payload.
class ReminderNotificationService {
  final FlutterLocalNotificationsPlugin _plugin;

  ReminderNotificationService(this._plugin);

  static bool _tzReady = false;

  /// Khởi tạo timezone data một lần — gọi trước khi schedule bất kỳ nhắc nhở nào.
  static Future<void> _ensureTimezone() async {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fallback: giữ UTC nếu không lấy được timezone thiết bị
    }
    _tzReady = true;
  }

  /// Tạo notification channel cho Android (gọi trong PushNotificationService.initialize).
  static AndroidNotificationChannel get channel => const AndroidNotificationChannel(
        _reminderChannelId,
        'Nhắc nhở hằng ngày',
        description: 'Nhắc mở ca buổi sáng và chốt sổ buổi tối',
        importance: Importance.high,
      );

  /// Schedule hoặc hủy nhắc nhở dựa trên cài đặt người dùng.
  Future<void> applySettings({
    required bool morningEnabled,
    required bool eveningEnabled,
  }) async {
    if (morningEnabled) {
      await _scheduleMorning();
    } else {
      await _plugin.cancel(morningReminderId);
      dev.log('[Reminder] morning cancelled', name: 'ReminderSvc');
    }
    if (eveningEnabled) {
      await _scheduleEvening();
    } else {
      await _plugin.cancel(eveningReminderId);
      dev.log('[Reminder] evening cancelled', name: 'ReminderSvc');
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancel(morningReminderId);
    await _plugin.cancel(eveningReminderId);
  }

  // ---------------------------------------------------------------------------

  Future<void> _scheduleMorning() async {
    await _ensureTimezone();
    final at = _nextAt(7, 0);
    dev.log('[Reminder] scheduling morning at $at', name: 'ReminderSvc');
    await _plugin.zonedSchedule(
      morningReminderId,
      'Mở ca buổi sáng ☀️',
      'Chào buổi sáng! Hãy mở ca làm việc và kiểm tra số dư túi tiền đầu ngày.',
      at,
      _details(payload: jsonEncode({'type': 'morning_reminder'})),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleEvening() async {
    await _ensureTimezone();
    final at = _nextAt(22, 0);
    dev.log('[Reminder] scheduling evening at $at', name: 'ReminderSvc');
    await _plugin.zonedSchedule(
      eveningReminderId,
      'Chốt sổ cuối ngày 🌙',
      'Đã đến giờ chốt sổ! Ghi nhận thu chi và kiểm tra số dư cuối ngày.',
      at,
      _details(payload: jsonEncode({'type': 'evening_reminder'})),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Trả về TZDateTime tiếp theo khớp giờ [hour]:[minute] (hôm nay nếu chưa qua, mai nếu đã qua).
  tz.TZDateTime _nextAt(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  NotificationDetails _details({required String payload}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannelId,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_stat_notification',
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(
        // iOS cần exact scheduled permission riêng — không khả dụng khi build
        // debug trên simulator, chỉ hoạt động trên device thật.
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: Platform.isIOS ? InterruptionLevel.active : null,
      ),
    );
  }
}

final reminderNotificationServiceProvider = Provider<ReminderNotificationService>((ref) {
  throw UnimplementedError('Override this in PushNotificationService.initialize');
});
