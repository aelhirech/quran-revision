import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Numéro de Hizb (1-60) où commence chaque sourate — source QUL
/// (metadata/quran-metadata-hizb.json), donnée authoritative issue du
/// Mushaf officiel. Remplace l'ancienne estimation par position cumulative.
/// Convention de Hizb : identique quelle que soit la riwaya active (c'est
/// une convention d'impression de Mushaf, pas une donnée par riwaya).
class HizbMetadataService {
  static Map<int, int>? _surahStartHizb;

  static Future<void> initialize() async {
    if (_surahStartHizb != null) return;
    final raw = await rootBundle.loadString(
      'assets/quran/metadata/quran-metadata-hizb.json',
    );
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final result = <int, int>{};
    final hizbNumbers = data.keys.map(int.parse).toList()..sort();
    for (final hizbNumber in hizbNumbers) {
      final entry = data[hizbNumber.toString()] as Map<String, dynamic>;
      final verseMapping = entry['verse_mapping'] as Map<String, dynamic>;
      for (final surahIdStr in verseMapping.keys) {
        final surahId = int.parse(surahIdStr);
        if (result.containsKey(surahId)) continue;
        final range = verseMapping[surahIdStr] as String;
        final start = int.parse(range.split('-').first);
        if (start == 1) result[surahId] = hizbNumber;
      }
    }
    _surahStartHizb = result;
  }

  /// Purement cosmétique (regroupement optionnel dans l'onboarding) — si le
  /// chargement a échoué ou n'a pas encore eu lieu, retourne une map vide
  /// plutôt que de planter (le "groupement par Hizb" retombe alors sur
  /// aucun regroupement, sans casser le reste de l'app).
  static Map<int, int> get surahStartHizb => _surahStartHizb ?? const {};
}
