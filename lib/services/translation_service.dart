import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Verse translations shown under the Arabic text (Hafs numbering only).
/// Files are the Tanzil editions, bundled unmodified: one
/// `surah|ayah|text` line per verse, then a `#` comment block.
class TranslationService {
  static const _assets = {
    'fr': 'assets/quran/translations/fr.hamidullah.txt',
    'en': 'assets/quran/translations/en.sahih.txt',
  };

  static final Map<String, Map<(int, int), String>> _byLocale = {};

  static Future<void> load(String locale) async {
    if (_byLocale.containsKey(locale)) return;
    final raw = await rootBundle.loadString(_assets[locale]!);
    final verses = <(int, int), String>{};
    final startsWithDigit = RegExp(r'^\d');
    for (final line in const LineSplitter().convert(raw)) {
      if (!startsWithDigit.hasMatch(line)) continue;
      final surahEnd = line.indexOf('|');
      final ayahEnd = line.indexOf('|', surahEnd + 1);
      final surahId = int.parse(line.substring(0, surahEnd));
      final ayahId = int.parse(line.substring(surahEnd + 1, ayahEnd));
      verses[(surahId, ayahId)] = line.substring(ayahEnd + 1);
    }
    _byLocale[locale] = verses;
  }

  static String? verse(String locale, int surahId, int ayahId) =>
      _byLocale[locale]?[(surahId, ayahId)];
}
