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

  /// Calcule la fraîcheur pour un ensemble de clés (sourates, ou versets une
  /// fois la Phase 6 étendue au niveau verset) en un seul passage. Générique
  /// sur la clé : K=int pour une fraîcheur par sourate (usage actuel), tout
  /// autre type de clé (ex. un identifiant composite par verset) fonctionne
  /// à l'identique.
  static Map<K, FreshnessLevel> computeAll<K>(
    Map<K, DateTime> lastRevisionDates,
    DateTime today,
  ) {
    return {
      for (final entry in lastRevisionDates.entries)
        entry.key: compute(entry.value, today),
    };
  }
}
