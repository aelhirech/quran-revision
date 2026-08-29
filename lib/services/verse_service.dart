import '../models/revision_unit.dart';
import '../models/riwaya.dart';
import 'hafs_service.dart';
import 'warsh_service.dart';

const _arabicIndicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

class VerseService {
  /// Retourne les versets arabes d'une unité de révision, dans la riwaya
  /// demandée. Hafs et Warsh ont chacun leur propre numérotation native
  /// (6236 vs 6214 versets) — `unit` doit déjà avoir été construite dans la
  /// riwaya passée en paramètre.
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
      {Riwaya riwaya = Riwaya.hafs, bool verseEndSymbol = true}) {
    final text = riwaya == Riwaya.warsh
        ? WarshService.getVerse(surahId, verseNumber)
        : HafsService.getVerse(surahId, verseNumber);
    if (!verseEndSymbol) return text;
    return '$text ${_arabicIndicNumeral(verseNumber)}';
  }

  static String _arabicIndicNumeral(int n) =>
      n.toString().split('').map((d) => _arabicIndicDigits[int.parse(d)]).join();

  /// Nombre total de versets d'une sourate, selon la riwaya (Hafs 6236,
  /// Warsh 6214 au total — les comptes par sourate diffèrent en conséquence).
  static int verseCount(int surahId, Riwaya riwaya) =>
      (riwaya == Riwaya.warsh ? WarshService.verseCounts : HafsService.verseCounts)[
          surahId]!;

  /// Nombre de mots approximatif d'une sourate, selon la riwaya.
  static int wordCount(int surahId, Riwaya riwaya) =>
      (riwaya == Riwaya.warsh ? WarshService.wordCounts : HafsService.wordCounts)[
          surahId]!;
}
