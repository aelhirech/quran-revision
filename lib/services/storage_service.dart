import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_session.dart';
import '../models/riwaya.dart';
import '../models/user_config.dart';

class StorageService {
  static const _keyConfig = 'user_config';
  static const _keyCyclePosition = 'cycle_position';
  static const _keyLocale = 'locale';
  static const _keyNotifEnabled = 'notif_enabled';
  static const _keyPreviewSession = 'preview_session';
  static const _keyTodaySession = 'today_session';
  static const _keyPauseDates = 'pause_dates';
  static const _keyRiwaya = 'riwaya';
  static const _keyCheckedRakaas = 'today_checked_rakaas';
  static const _keyTourSeen = 'onboarding_tour_seen';

  static Future<void> saveConfig(UserConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyConfig, jsonEncode(config.toJson()));
  }

  static Future<UserConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyConfig);
    if (raw == null) return null;
    try {
      return UserConfig.fromJson(jsonDecode(raw));
    } catch (_) {
      // Config corrompue (ex. après une refonte de quran_data.dart) : mieux
      // vaut renvoyer l'utilisateur à l'onboarding qu'un crash au démarrage.
      return null;
    }
  }

  static Future<void> saveCyclePosition(int position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCyclePosition, position);
  }

  static Future<int> loadCyclePosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCyclePosition) ?? 0;
  }

  static Future<void> saveLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale);
  }

  static Future<String> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocale) ?? 'fr';
  }

  static Future<void> saveNotifEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifEnabled, enabled);
  }

  static Future<bool> loadNotifEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifEnabled) ?? true;
  }

  static Future<void> savePreviewSession(DailySession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPreviewSession, jsonEncode(session.toJson()));
  }

  static Future<DailySession?> loadPreviewSession() async {
    final prefs = await SharedPreferences.getInstance();
    return _sessionOrNullIfStale(prefs.getString(_keyPreviewSession));
  }

  static Future<void> clearPreviewSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPreviewSession);
  }

  static Future<void> saveTodaySession(DailySession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTodaySession, jsonEncode(session.toJson()));
  }

  static Future<DailySession?> loadTodaySession() async {
    final prefs = await SharedPreferences.getInstance();
    return _sessionOrNullIfStale(prefs.getString(_keyTodaySession));
  }

  static DailySession? _sessionOrNullIfStale(String? raw) {
    if (raw == null) return null;
    try {
      final session = DailySession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final today = DateTime.now();
      final sameDay = session.date.year == today.year &&
          session.date.month == today.month &&
          session.date.day == today.day;
      return sameDay ? session : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearTodaySession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTodaySession);
  }

  /// Rakaas cochées dans la session du jour, par index de prière — permet de
  /// survivre à un redémarrage de l'app sans perdre la progression déjà cochée.
  /// La date est stockée à côté : si elle ne correspond plus à aujourd'hui
  /// (session jamais explicitement clôturée puis minuit passé), le chargement
  /// la traite comme absente et purge la clé — même logique que
  /// [_sessionOrNullIfStale] pour [loadTodaySession].
  static Future<void> saveCheckedRakaas(Map<int, Set<int>> checked) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = checked.map((k, v) => MapEntry(k.toString(), v.toList()));
    await prefs.setString(_keyCheckedRakaas, jsonEncode({
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'checked': encoded,
    }));
  }

  static Future<Map<int, Set<int>>> loadCheckedRakaas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCheckedRakaas);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (decoded['date'] != today) {
        await clearCheckedRakaas();
        return {};
      }
      final checked = decoded['checked'] as Map<String, dynamic>;
      return checked.map((k, v) =>
          MapEntry(int.parse(k), (v as List).cast<int>().toSet()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> clearCheckedRakaas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCheckedRakaas);
  }

  static Future<void> savePauseDates(Set<String> dates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyPauseDates, dates.toList());
  }

  static Future<Set<String>> loadPauseDates() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_keyPauseDates) ?? []).toSet();
  }

  static Future<void> saveRiwaya(Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRiwaya, riwaya.name);
  }

  static Future<Riwaya> loadRiwaya() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRiwaya);
    return Riwaya.values.firstWhere((r) => r.name == raw,
        orElse: () => Riwaya.hafs);
  }

  static Future<bool> hasSeenTour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTourSeen) ?? false;
  }

  static Future<void> setTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTourSeen, true);
  }

  /// Réinitialise uniquement la configuration de révision (sourates, cycle,
  /// sessions, pauses) — pas les préférences d'app (langue, riwaya,
  /// notifications, tour vu), que "Réinitialiser" dans le profil ne doit pas
  /// toucher.
  static Future<void> clearConfigOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyConfig),
      prefs.remove(_keyCyclePosition),
      prefs.remove(_keyPreviewSession),
      prefs.remove(_keyTodaySession),
      prefs.remove(_keyPauseDates),
      prefs.remove(_keyCheckedRakaas),
    ]);
  }
}
