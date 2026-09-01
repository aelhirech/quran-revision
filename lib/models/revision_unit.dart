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

  /// Deux unités qui portent exactement la même plage de versets de la même
  /// sourate représentent le même contenu à réviser, quelle que soit la façon
  /// dont chacune a été produite (`isWhole` n'entre donc pas en jeu — c'est
  /// une info sur l'origine de la plage, pas sur son contenu). Utilisé par
  /// `RevisionEngine` pour la règle "pas deux fois la même plage dans une
  /// même prière" (S6-B).
  @override
  bool operator ==(Object other) =>
      other is RevisionUnit &&
      other.sourate.id == sourate.id &&
      other.verseStart == verseStart &&
      other.verseEnd == verseEnd;

  @override
  int get hashCode => Object.hash(sourate.id, verseStart, verseEnd);
}
