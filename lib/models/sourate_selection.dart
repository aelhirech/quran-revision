import 'sourate.dart';

/// Représente la portion d'une sourate que l'utilisateur a mémorisée.
/// isWhole = true si toute la sourate est sélectionnée.
class SourateSelection {
  final Sourate sourate;
  final int verseStart;
  final int verseEnd;

  const SourateSelection({
    required this.sourate,
    required this.verseStart,
    required this.verseEnd,
  });

  /// Sélectionne toute la sourate.
  SourateSelection.whole(Sourate s)
      : sourate = s,
        verseStart = 1,
        verseEnd = s.verses;

  bool get isWhole => verseStart == 1 && verseEnd == sourate.verses;
  int get verseCount => verseEnd - verseStart + 1;

  /// Nombre de mots approximatif pour la plage sélectionnée.
  int get estimatedWords =>
      (sourate.words * verseCount / sourate.verses).round().clamp(1, sourate.words);

  String get rangeLabel => isWhole ? '' : ' (v.$verseStart–$verseEnd)';

  /// Same range of the same surah is the same selection, regardless of the
  /// `Sourate` instance's other fields — mirrors `RevisionUnit.==`.
  @override
  bool operator ==(Object other) =>
      other is SourateSelection &&
      other.sourate.id == sourate.id &&
      other.verseStart == verseStart &&
      other.verseEnd == verseEnd;

  @override
  int get hashCode => Object.hash(sourate.id, verseStart, verseEnd);

  Map<String, dynamic> toJson() => {
        'sourate': sourate.toJson(),
        'verseStart': verseStart,
        'verseEnd': verseEnd,
      };

  factory SourateSelection.fromJson(Map<String, dynamic> j) {
    final s = Sourate.fromJson(j['sourate'] as Map<String, dynamic>);
    return SourateSelection(
      sourate: s,
      verseStart: j['verseStart'] as int? ?? 1,
      verseEnd: j['verseEnd'] as int? ?? s.verses,
    );
  }
}
