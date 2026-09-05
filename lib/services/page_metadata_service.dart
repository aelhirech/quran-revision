import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/riwaya.dart';

/// Numéro de page mushaf (absolu, ex. 601) où se trouve chaque ayah — source
/// QUL/quranpedia, une entrée par riwaya (Hafs et Warsh n'ont pas la même
/// pagination). Chargée une fois via `rootBundle` (asset bundlé dans l'app,
/// contrairement à un chemin `dart:io` qui ne résout pas les assets sur un
/// vrai appareil) et mise en cache en mémoire pour le reste de la session —
/// `RevisionEngine.buildDayUnits` y fait appel à chaque check-in/check-out,
/// pas seulement au démarrage.
class PageMetadataService {
  static final Map<Riwaya, Map<int, Map<int, int>>> _cache = {};

  static Future<void> initialize() async {
    if (_cache.isNotEmpty) return;
    for (final riwaya in Riwaya.values) {
      _cache[riwaya] = await _load(riwaya);
    }
  }

  static Future<Map<int, Map<int, int>>> _load(Riwaya riwaya) async {
    final filename = riwaya == Riwaya.hafs
        ? 'assets/quran/metadata/quran-metadata-page-hafs.json'
        : 'assets/quran/metadata/quran-metadata-page-warsh.json';
    final raw = await rootBundle.loadString(filename);
    final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
    final result = <int, Map<int, int>>{};
    jsonMap.forEach((surahKey, ayahMapDynamic) {
      final ayahMap = ayahMapDynamic as Map<String, dynamic>;
      result[int.parse(surahKey)] = {
        for (final entry in ayahMap.entries) int.parse(entry.key): entry.value as int,
      };
    });
    return result;
  }

  /// Retourne `{}` si jamais initialisé — ne devrait pas arriver en usage
  /// normal (voir `main.dart`), mais évite un crash plutôt qu'une exception
  /// non gérée si un appelant (test, écran) oublie l'initialisation.
  static Map<int, Map<int, int>> pageMetadataFor(Riwaya riwaya) =>
      _cache[riwaya] ?? const {};
}
