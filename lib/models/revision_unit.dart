import 'sourate.dart';

class RevisionUnit {
  final Sourate sourate;
  final int verseStart;
  final int verseEnd;
  final bool isWhole;

  const RevisionUnit({
    required this.sourate,
    required this.verseStart,
    required this.verseEnd,
    required this.isWhole,
  });

  int get verseCount => verseEnd - verseStart + 1;

  /// Lignes estimées dans le Mushaf Madinah (~8,5 mots par ligne).
  double get estimatedLines =>
      (sourate.words * verseCount / sourate.verses) / 8.5;

  String get label {
    final name = '${sourate.nameAr} · ${sourate.nameFr}';
    if (isWhole) return name;
    return '$name (v.$verseStart–$verseEnd)';
  }
}
