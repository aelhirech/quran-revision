import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // demandé plus tard
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  static Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  /// Planifie le rappel matin (heure configurable)
  static Future<void> scheduleMorning({int hour = 7, int minute = 0}) async {
    await _schedule(
      id: 1,
      title: '🕌 Révision du Coran',
      body: 'Planifie ta révision du jour',
      hour: hour,
      minute: minute,
      channelId: 'morning',
      channelName: 'Rappel matin',
    );
  }

  /// Planifie le bilan soir (heure configurable)
  static Future<void> scheduleEvening({int hour = 20, int minute = 30}) async {
    await _schedule(
      id: 2,
      title: '📖 Bilan du jour',
      body: 'As-tu complété ta révision ?',
      hour: hour,
      minute: minute,
      channelId: 'evening',
      channelName: 'Bilan soir',
    );
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll error: $e');
    }
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String channelId,
    required String channelName,
  }) async {
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );

      await _plugin.periodicallyShow(
        id,
        title,
        body,
        RepeatInterval.daily,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Notification schedule error: $e');
    }
  }
}
