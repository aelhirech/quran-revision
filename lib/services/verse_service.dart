import 'package:quran/quran.dart' as quran;
import '../models/revision_unit.dart';
import '../models/riwaya.dart';
import 'warsh_service.dart';

class VerseService {
  /// Retourne les versets arabes d'une unité de révision, dans la riwaya
  /// demandée. La numérotation des versets est identique entre Hafs et
  /// Warsh — seul le texte affiché change.
  static List<String> versesForUnit(RevisionUnit unit,
      {Riwaya riwaya = Riwaya.hafs}) {
    final surahId = unit.sourate.id;
    final result = <String>[];
    for (int v = unit.verseStart; v <= unit.verseEnd; v++) {
      result.add(getVerse(surahId, v, riwaya: riwaya));
    }
    return result;
  }

  static String getVerse(int surahId, int verseNumber,
      {Riwaya riwaya = Riwaya.hafs}) {
    return riwaya == Riwaya.warsh
        ? WarshService.getVerse(surahId, verseNumber, verseEndSymbol: true)
        : quran.getVerse(surahId, verseNumber, verseEndSymbol: true);
  }

  /// Nombre total de versets d'une sourate selon le package Tanzil.
  static int verseCount(int surahId) => quran.getVerseCount(surahId);

  /// Nom arabe d'une sourate — identique entre Hafs et Warsh.
  static String surahNameArabic(int surahId) => quran.getSurahNameArabic(surahId);
}
