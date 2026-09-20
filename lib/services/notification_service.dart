import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../core/strings.dart';
import 'storage_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Active les rappels : demande la permission OS, persiste le résultat
  /// réel (pas un optimiste `true`), planifie matin+soir+minuit seulement si
  /// accordée. Point d'entrée unique (onboarding + réglages) — retourne si
  /// la permission a été accordée, pour que l'appelant puisse réconcilier
  /// son état UI avec la réalité.
  static Future<bool> enable() async {
    final granted = await requestPermission();
    await StorageService.saveNotifEnabled(granted);
    if (granted) await rescheduleAll();
    return granted;
  }

  /// (Re)schedules the three reminders on the currently configured times
  /// (`StorageService`, US-1 sprint B for morning/evening — the midnight
  /// reminder is at a fixed hour, US-3 crit. 6). Single entry point shared
  /// by [enable] (first activation), `SettingsCard`'s time pickers, and
  /// `AppState.setLocale` (a reminder's text is baked in at scheduling time,
  /// so a language change must reschedule).
  static Future<void> rescheduleAll() async {
    final morningF = StorageService.loadMorningTime();
    final eveningF = StorageService.loadEveningTime();
    final morning = await morningF;
    final evening = await eveningF;
    await Future.wait([
      scheduleMorning(hour: morning.hour, minute: morning.minute),
      scheduleEvening(hour: evening.hour, minute: evening.minute),
      scheduleMidnight(),
    ]);
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
    // App mobile-only (iOS/Android) — le champ windows n'est là que parce que
    // le plugin exige un InitializationSettings valide pour toute plateforme
    // pour laquelle le support est compilé (dossier windows/ généré par
    // défaut), sinon `initialize()` lève sur desktop. Jamais utilisé en prod.
    const windows = WindowsInitializationSettings(
      appName: 'Quran Revision',
      appUserModelId: 'com.quranrevision.quranRevision',
      guid: '5a7b7078-2ab6-4255-914b-ac0bcc546697',
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios, windows: windows),
    );
    await _initializeTimeZone();
  }

  /// Loads the IANA database and points `tz.local` at the device's real
  /// timezone — required by `zonedSchedule` below, so "7am" means 7am for
  /// the user, not 7am UTC. Falls back to UTC on failure rather than
  /// leaving `tz.local` unset: the `timezone` package declares it `late`,
  /// with no default — every `_scheduleDaily` call reads it inside its own
  /// try/catch, so an unset `tz.local` wouldn't crash, but it WOULD make
  /// every single reminder (morning/evening/midnight) fail to schedule,
  /// silently, for the lifetime of the process. UTC is a wrong time, not no
  /// time — the lesser failure of the two.
  static Future<void> _initializeTimeZone() async {
    try {
      tz_data.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('Timezone init error: $e');
      tz.setLocalLocation(tz.UTC);
    }
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
    await _scheduleDaily(
      id: 1,
      title: S.notifMatinTitle,
      body: S.notifMatinBody,
      hour: hour,
      minute: minute,
      channelId: 'morning',
      channelName: 'Rappel matin',
    );
  }

  /// Planifie le bilan soir (heure configurable)
  static Future<void> scheduleEvening({int hour = 20, int minute = 30}) async {
    await _scheduleDaily(
      id: 2,
      title: S.notifSoirTitle,
      body: S.notifSoirBody,
      hour: hour,
      minute: minute,
      channelId: 'evening',
      channelName: 'Bilan soir',
    );
  }

  /// Schedules the invitation to close out at a fixed midnight hour (US-3
  /// crit. 6) — one more invitation, never a silent automatic sealing of the
  /// day (that stays always user-triggered, `AppState.checkOut`). Not
  /// configurable, unlike morning/evening — decided at scoping.
  static Future<void> scheduleMidnight() async {
    await _scheduleDaily(
      id: 3,
      title: S.notifMinuitTitle,
      body: S.notifMinuitBody,
      hour: 0,
      minute: 0,
      channelId: 'midnight',
      channelName: 'Rappel minuit',
    );
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll error: $e');
    }
  }

  /// Schedules a recurring notification at a fixed local hour, via
  /// `zonedSchedule` + `matchDateTimeComponents: time` — `periodicallyShow`
  /// (used before this sprint) plainly ignores `hour`/`minute`: it only
  /// repeats every 24h from the moment it's called, never at a chosen hour.
  /// A bug that stayed invisible for lack of any test on this service.
  static Future<void> _scheduleDaily({
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

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOf(hour, minute),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Notification schedule error: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
