import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Sourates qui commencent par la Bismillah (toutes sauf At-Tawbah, et sauf
/// Al-Fatiha où la Bismillah est le verset 1 lui-même, pas une ligne
/// séparée) — source QUL (metadata/quran-metadata-surah-name.json), champ
/// `bismillah_pre`, bundlée depuis le Sprint 8 mais jamais lue jusqu'ici
/// (voir docs/CHANGELOG.md, section "Bismillah (décidé)").
class SurahMetadataService {
  static Map<int, bool>? _bismillahPre;

  static Future<void> initialize() async {
    if (_bismillahPre != null) return;
    final raw = await rootBundle.loadString(
      'assets/quran/metadata/quran-metadata-surah-name.json',
    );
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _bismillahPre = {
      for (final entry in data.entries)
        int.parse(entry.key): entry.value['bismillah_pre'] as bool,
    };
  }

  /// Purement cosmétique (affichage de la Bismillah) — si le chargement a
  /// échoué ou n'a pas encore eu lieu, retourne `false` plutôt que de
  /// planter (pas de Bismillah affichée, sans casser le reste de l'app).
  static bool bismillahPre(int surahId) => _bismillahPre?[surahId] ?? false;
}
