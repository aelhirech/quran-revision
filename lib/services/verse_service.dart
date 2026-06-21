import 'package:quran/quran.dart' as quran;
import '../models/revision_unit.dart';

class VerseService {
  /// Retourne les versets arabes d'une unité de révision.
  /// [unit.verseStart] et [unit.verseEnd] sont les bornes inclusives.
  static List<String> versesForUnit(RevisionUnit unit) {
    final surahId = unit.sourate.id;
    final result = <String>[];
    for (int v = unit.verseStart; v <= unit.verseEnd; v++) {
      result.add(quran.getVerse(surahId, v, verseEndSymbol: true));
    }
    return result;
  }

  /// Nombre total de versets d'une sourate selon le package Tanzil.
  static int verseCount(int surahId) => quran.getVerseCount(surahId);
}
