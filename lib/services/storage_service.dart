import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer.dart';
import '../models/riwaya.dart';
import '../models/user_config.dart';
import 'riwaya_key.dart';

class StorageService {
  static const _keyConfig = 'user_config';
  static const _keyCyclePosition = 'cycle_position';
  static const _keyLocale = 'locale';
  static const _keyNotifEnabled = 'notif_enabled';
  static const _keyPauseDates = 'pause_dates';
  static const _keyRiwaya = 'riwaya';
  static const _keyCheckedRakaas = 'today_checked_rakaas';
  static const _keyTourSeen = 'onboarding_tour_seen';
  static const _keyLastSessionPrayers = 'last_session_prayers';
  static const _keyActivePrayers = 'active_round_prayers';

  /// Hafs et Warsh sont deux parcours indépendants (config, cycle, pauses,
  /// cases cochées) — ces clés sont donc préfixées par riwaya. Langue/riwaya-
  /// active/notifications/tour-vu restent des préférences globales, non
  /// préfixées. Depuis Phase 6 Sprint 2, le plan du jour n'est plus persisté
  /// ici (`previewSession`/`todaySession` ont disparu) — les lignes
  /// `ayah_facts` du jour en sont la seule source, voir `AyahFactsService`.
  static String _track(String base, Riwaya riwaya) => riwayaKey(base, riwaya);

  static Future<void> saveConfig(UserConfig config, Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_track(_keyConfig, riwaya), jsonEncode(config.toJson()));
  }

  static Future<UserConfig?> loadConfig(Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_track(_keyConfig, riwaya));
    if (raw == null) return null;
    try {
      return UserConfig.fromJson(jsonDecode(raw));
    } catch (_) {
      // Config corrompue (ex. après une refonte de quran_data.dart) : mieux
      // vaut renvoyer l'utilisateur à l'onboarding qu'un crash au démarrage.
      return null;
    }
  }

  static Future<void> saveCyclePosition(int position, Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_track(_keyCyclePosition, riwaya), position);
  }

  static Future<int> loadCyclePosition(Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_track(_keyCyclePosition, riwaya)) ?? 0;
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

  /// Prières de la manche en cours (choisies dans HomeScreen, pas encore
  /// clôturée) — permet de reconstruire `AppState.todaySession` (dérivé de
  /// `ayah_facts`, plus persisté comme objet) si l'app redémarre avant la
  /// fin de la manche, sans perdre la sélection de prières (Phase 6 Sprint
  /// 2 ; remplace l'ancien `previewSession`/`todaySession`, voir cadrage).
  /// Même garde de fraîcheur par date que [loadCheckedRakaas].
  static Future<void> saveActivePrayers(
      List<Prayer> prayers, Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_track(_keyActivePrayers, riwaya), jsonEncode({
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'prayers': prayers.map((p) => p.name).toList(),
    }));
  }

  static Future<List<Prayer>?> loadActivePrayers(Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_track(_keyActivePrayers, riwaya));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (decoded['date'] != today) {
        await clearActivePrayers(riwaya);
        return null;
      }
      return (decoded['prayers'] as List)
          .map((name) {
            try {
              return Prayer.values.byName(name as String);
            } catch (_) {
              return null;
            }
          })
          .whereType<Prayer>()
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearActivePrayers(Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_track(_keyActivePrayers, riwaya));
  }

  /// Rakaas cochées dans la session du jour, par index de prière — permet de
  /// survivre à un redémarrage de l'app sans perdre la progression déjà cochée.
  /// La date est stockée à côté : si elle ne correspond plus à aujourd'hui
  /// (session jamais explicitement clôturée puis minuit passé), le chargement
  /// la traite comme absente et purge la clé — même logique que
  /// [loadActivePrayers].
  static Future<void> saveCheckedRakaas(
      Map<int, Set<int>> checked, Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = checked.map((k, v) => MapEntry(k.toString(), v.toList()));
    await prefs.setString(_track(_keyCheckedRakaas, riwaya), jsonEncode({
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'checked': encoded,
    }));
  }

  static Future<Map<int, Set<int>>> loadCheckedRakaas(Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _track(_keyCheckedRakaas, riwaya);
    final raw = prefs.getString(key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (decoded['date'] != today) {
        await clearCheckedRakaas(riwaya);
        return {};
      }
      final checked = decoded['checked'] as Map<String, dynamic>;
      return checked.map((k, v) =>
          MapEntry(int.parse(k), (v as List).cast<int>().toSet()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> clearCheckedRakaas(Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_track(_keyCheckedRakaas, riwaya));
  }

  /// Dernière sélection de prières d'une session complétée normalement (pas
  /// la saisie manuelle) — permet à `HomeScreen` de proposer "reprendre les
  /// prières d'hier". Ne vient plus de l'historique de révision (Phase 6,
  /// `ayah_facts` n'a pas de notion de prière, une table de faits par verset
  /// n'a pas à en porter une) : petite persistance UI dédiée, à part.
  static Future<void> saveLastSessionPrayers(
      DateTime date, List<Prayer> prayers, Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_track(_keyLastSessionPrayers, riwaya), jsonEncode({
      'date': date.toIso8601String().substring(0, 10),
      'prayers': prayers.map((p) => p.name).toList(),
    }));
  }

  static Future<({DateTime date, List<Prayer> prayers})?> loadLastSessionPrayers(
      Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_track(_keyLastSessionPrayers, riwaya));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final prayers = (decoded['prayers'] as List)
          .map((name) {
            try {
              return Prayer.values.byName(name as String);
            } catch (_) {
              return null;
            }
          })
          .whereType<Prayer>()
          .toList();
      return (date: DateTime.parse(decoded['date'] as String), prayers: prayers);
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePauseDates(Set<String> dates, Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_track(_keyPauseDates, riwaya), dates.toList());
  }

  static Future<Set<String>> loadPauseDates(Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_track(_keyPauseDates, riwaya)) ?? []).toSet();
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
  /// sessions, pauses) du parcours [riwaya] — pas l'autre parcours, ni les
  /// préférences d'app (langue, riwaya active, notifications, tour vu), que
  /// "Réinitialiser" dans le profil ne doit pas toucher.
  static Future<void> clearConfigOnly(Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_track(_keyConfig, riwaya)),
      prefs.remove(_track(_keyCyclePosition, riwaya)),
      prefs.remove(_track(_keyPauseDates, riwaya)),
      prefs.remove(_track(_keyCheckedRakaas, riwaya)),
      prefs.remove(_track(_keyLastSessionPrayers, riwaya)),
      prefs.remove(_track(_keyActivePrayers, riwaya)),
    ]);
  }

  /// Migration one-shot pour les installations existantes : avant l'ajout des
  /// parcours par riwaya, ces clés étaient globales et implicitement
  /// Hafs (Warsh n'était qu'un affichage alternatif du même texte). On les
  /// renomme donc telles quelles vers le parcours Hafs. Idempotent : les
  /// anciennes clés n'existent plus après le premier passage.
  static Future<void> migrateLegacyTrackData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyConfig)) {
      await prefs.setString(
          _track(_keyConfig, Riwaya.hafs), prefs.getString(_keyConfig)!);
      await prefs.remove(_keyConfig);
    }
    if (prefs.containsKey(_keyCyclePosition)) {
      await prefs.setInt(_track(_keyCyclePosition, Riwaya.hafs),
          prefs.getInt(_keyCyclePosition)!);
      await prefs.remove(_keyCyclePosition);
    }
    if (prefs.containsKey(_keyPauseDates)) {
      await prefs.setStringList(_track(_keyPauseDates, Riwaya.hafs),
          prefs.getStringList(_keyPauseDates)!);
      await prefs.remove(_keyPauseDates);
    }
    if (prefs.containsKey(_keyCheckedRakaas)) {
      await prefs.setString(_track(_keyCheckedRakaas, Riwaya.hafs),
          prefs.getString(_keyCheckedRakaas)!);
      await prefs.remove(_keyCheckedRakaas);
    }
  }
}
