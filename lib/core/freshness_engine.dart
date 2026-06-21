// SRS léger — calcule la "fraîcheur" d'une sourate depuis sa dernière révision.
// Module pur : pas de Flutter, pas d'I/O.

enum FreshnessLevel {
  hot,    // révisé récemment (< 7 jours)
  cold,   // commence à refroidir (7–13 jours)
  frozen, // à risque d'être oublié (14+ jours, ou jamais révisé)
}

class FreshnessEngine {
  static const int _coldAfterDays   = 7;
  static const int _frozenAfterDays = 14;

  /// Calcule le niveau de fraîcheur d'une sourate.
  /// [lastRevised] : null si jamais révisé → frozen d'office.
  /// [today] : injecté pour rester testable (jamais DateTime.now() ici).
  static FreshnessLevel compute(DateTime? lastRevised, DateTime today) {
    if (lastRevised == null) return FreshnessLevel.frozen;
    final days = today.difference(lastRevised).inDays;
    if (days < _coldAfterDays)   return FreshnessLevel.hot;
    if (days < _frozenAfterDays) return FreshnessLevel.cold;
    return FreshnessLevel.frozen;
  }

  /// Calcule la fraîcheur pour un ensemble de sourates en un seul passage.
  static Map<int, FreshnessLevel> computeAll(
    Map<int, DateTime> lastRevisionDates,
    DateTime today,
  ) {
    return {
      for (final entry in lastRevisionDates.entries)
        entry.key: compute(entry.value, today),
    };
  }
}
