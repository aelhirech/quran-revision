import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'storage_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Active les rappels : demande la permission OS, persiste le résultat
  /// réel (pas un optimiste `true`), planifie matin+soir seulement si
  /// accordée. Point d'entrée unique (onboarding + réglages) — retourne si
  /// la permission a été accordée, pour que l'appelant puisse réconcilier
  /// son état UI avec la réalité.
  static Future<bool> enable() async {
    final granted = await requestPermission();
    await StorageService.saveNotifEnabled(granted);
    if (granted) {
      await Future.wait([scheduleMorning(), scheduleEvening()]);
    }
    return granted;
  }

  /// Désactive les rappels : persiste explicitement `false` (pas de valeur
  /// par défaut fantôme) et annule les notifications planifiées.
  static Future<void> disable() async {
    await StorageService.saveNotifEnabled(false);
    await cancelAll();
  }

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // demandé plus tard
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
  }

  static Future<bool> requestPermission() async {
    try {
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
    } catch (e) {
      debugPrint('requestPermission error: $e');
      return false;
    }
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
        id: id,
        title: title,
        body: body,
        repeatInterval: RepeatInterval.daily,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Notification schedule error: $e');
    }
  }
}
