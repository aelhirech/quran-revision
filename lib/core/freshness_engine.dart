// SRS léger — classe la "fraîcheur" d'une sourate/sélection depuis
// l'historique de révision au grain verset. Module pur : pas de Flutter,
// pas d'I/O.

enum FreshnessLevel {
  neverRevised, // aucun verset de la plage jamais révisé
  partiallyRecent, // au moins un verset révisé ≤30j ET au moins un qui ne l'est pas (jamais ou >30j)
  recent, // tous les versets de la plage révisés il y a ≤30j
  oneMonth, // aucun verset récent ; le plus récemment révisé l'a été il y a >30j
  threeMonths, // ... >90j
  sixMonths, // ... >180j
  oneYear, // ... >365j
}

class FreshnessEngine {
  static const int _recentAfterDays = 30;
  static const int _threeMonthsAfterDays = 90;
  static const int _sixMonthsAfterDays = 180;
  static const int _oneYearAfterDays = 365;

  /// Classifie la fraîcheur d'une plage de versets [verseStart]..[verseEnd]
  /// (bornes incluses, plage exacte de la sourate/sélection — jamais
  /// `1..sourate.verses`) à partir des dates de dernière révision par
  /// verset ([lastRevisionByAyah] : `ayah_id` → date, absence = jamais
  /// révisé). [today] toujours injecté (jamais `DateTime.now()` ici) pour
  /// rester testable.
  static FreshnessLevel computeForRange({
    required Map<int, DateTime> lastRevisionByAyah,
    required int verseStart,
    required int verseEnd,
    required DateTime today,
  }) {
    assert(verseEnd >= verseStart);
    final total = verseEnd - verseStart + 1;
    var recentCount = 0;
    DateTime? mostRecent;
    for (var ayah = verseStart; ayah <= verseEnd; ayah++) {
      final date = lastRevisionByAyah[ayah];
      if (date == null) continue;
      if (mostRecent == null || date.isAfter(mostRecent)) mostRecent = date;
      if (today.difference(date).inDays <= _recentAfterDays) recentCount++;
    }

    if (mostRecent == null) return FreshnessLevel.neverRevised;
    if (recentCount == total) return FreshnessLevel.recent;
    if (recentCount > 0) return FreshnessLevel.partiallyRecent;

    // Aucun verset récent, mais au moins un déjà révisé (mostRecent != null) :
    // palier basé sur la date la plus récente parmi les versets déjà
    // révisés (le moins pire, pas le pire).
    final days = today.difference(mostRecent).inDays;
    if (days > _oneYearAfterDays) return FreshnessLevel.oneYear;
    if (days > _sixMonthsAfterDays) return FreshnessLevel.sixMonths;
    if (days > _threeMonthsAfterDays) return FreshnessLevel.threeMonths;
    return FreshnessLevel.oneMonth;
  }
}
