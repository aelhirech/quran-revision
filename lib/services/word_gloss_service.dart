import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/riwaya.dart';

/// Word-by-word French meanings (CoranMot, Dr Usama Nonnenmacher), bundled
/// unmodified: one `sura<TAB>ayah<TAB>word<TAB>meaning` line per word, in
/// reading order. Hafs numbering only.
class WordGlossService {
  static const _asset = 'assets/quran/wbw/fr.coranmot.tsv';

  static Map<(int, int), List<String>>? _byVerse;

  static bool availableFor(String locale, Riwaya riwaya) =>
      locale == 'fr' && riwaya == Riwaya.hafs;

  static Future<void> load() async {
    if (_byVerse != null) return;
    final raw = await rootBundle.loadString(_asset);
    final byVerse = <(int, int), List<String>>{};
    for (final line in const LineSplitter().convert(raw)) {
      final fields = line.split('\t');
      byVerse
          .putIfAbsent((int.parse(fields[0]), int.parse(fields[1])), () => [])
          .add(fields[3]);
    }
    _byVerse = byVerse;
  }

  /// The meanings of a verse's words, in order; `null` until [load] is done.
  static List<String>? glosses(int surahId, int ayahId) =>
      _byVerse?[(surahId, ayahId)];
}
