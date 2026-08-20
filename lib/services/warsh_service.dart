import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:quran/quran.dart' as quran;

/// Texte arabe du Coran selon la riwaya Warsh (transmission de Nafi').
/// Numérotation des versets identique à l'édition Uthmani/Hafs déjà utilisée
/// dans l'app — seul le texte diffère.
/// Source : dataset ouvert fawazahmed0/quran-api (édition ara-quranwarsh).
class WarshService {
  static Map<String, dynamic>? _data;

  static Future<void> initialize() async {
    if (_data != null) return;
    final raw = await rootBundle.loadString('assets/quran/warsh.json');
    _data = jsonDecode(raw) as Map<String, dynamic>;
  }

  static String getVerse(int surahNumber, int verseNumber,
      {bool verseEndSymbol = false}) {
    final verses = _data?[surahNumber.toString()] as List<dynamic>?;
    if (verses == null || verseNumber < 1 || verseNumber > verses.length) {
      throw 'No verse found with given surahNumber and verseNumber.\n\n';
    }
    final text = verses[verseNumber - 1] as String;
    return text + (verseEndSymbol ? quran.getVerseEndSymbol(verseNumber) : '');
  }
}
