import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Chargement + comptage (versets/mots par sourate) d'un asset de texte
/// coranique au format `{"surah:ayah": {"surah":.., "ayah":.., "text":..}}`.
/// Partagé par HafsService et WarshService — seul l'asset chargé diffère.
class QuranTextAsset {
  final String assetPath;
  Map<String, dynamic>? _data;
  Map<int, int>? _verseCounts;
  Map<int, int>? _wordCounts;

  QuranTextAsset(this.assetPath);

  Future<void> initialize() async {
    if (_data != null) return;
    final raw = await rootBundle.loadString(assetPath);
    _data = jsonDecode(raw) as Map<String, dynamic>;
    _computeCounts();
  }

  void _computeCounts() {
    final verseCounts = <int, int>{};
    final wordCounts = <int, int>{};
    final wordSplitter = RegExp(r'\s+');
    for (final v in _data!.values) {
      final entry = v as Map<String, dynamic>;
      final surah = entry['surah'] as int;
      final text = entry['text'] as String;
      final words =
          text.trim().isEmpty ? 0 : text.trim().split(wordSplitter).length;
      verseCounts[surah] = (verseCounts[surah] ?? 0) + 1;
      wordCounts[surah] = (wordCounts[surah] ?? 0) + words;
    }
    _verseCounts = verseCounts;
    _wordCounts = wordCounts;
  }

  String getVerse(int surahNumber, int verseNumber) {
    final entry = _data?['$surahNumber:$verseNumber'] as Map<String, dynamic>?;
    if (entry == null) {
      throw 'No verse found with given surahNumber and verseNumber.\n\n';
    }
    return entry['text'] as String;
  }

  Map<int, int> get verseCounts => _verseCounts!;
  Map<int, int> get wordCounts => _wordCounts!;
}
