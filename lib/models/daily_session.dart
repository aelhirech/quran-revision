import 'prayer.dart';
import 'revision_unit.dart';

class RakaaAssignment {
  final int rakaaNumber;
  final RevisionUnit? unit; // null = Al-Fatiha uniquement

  /// `true` si [unit] est la portion à *apprendre* aujourd'hui, pas une
  /// portion à réviser — la toute dernière rakaa récitée de la journée (voir
  /// `RevisionEngine.distributeToRakaas`). Les deux se distinguent à
  /// l'affichage (PlanScreen) et à l'écriture (`ayah_facts.type`), d'où le
  /// drapeau porté par l'assignation plutôt que déduit par l'appelant.
  final bool isLearning;

  const RakaaAssignment({
    required this.rakaaNumber,
    this.unit,
    this.isLearning = false,
  });
}

class PrayerPlan {
  final Prayer prayer;
  final List<RakaaAssignment> rakaas;

  const PrayerPlan({required this.prayer, required this.rakaas});
}

class DailySession {
  final DateTime date;
  final List<Prayer> prayersAlone;
  final List<PrayerPlan> plan;

  /// Pages réelles du mushaf couvertes par le plan de ce jour, et progression
  /// du cycle dans cette même unité (Phase 9 Sprint 2) — le rythme se règle
  /// en pages/jour, tous les compteurs affichés parlent donc de pages plutôt
  /// que d'« unités », un grain interne au moteur. [pagesToday] est calculé
  /// sur les unités réellement retenues pour la journée (donc après édition
  /// au check-in), pas sur la proposition d'origine.
  final int pagesToday;
  final int pagesPosition;
  final int pagesTotal;

  const DailySession({
    required this.date,
    required this.prayersAlone,
    required this.plan,
    required this.pagesToday,
    required this.pagesPosition,
    required this.pagesTotal,
  });

  int get totalRakaas =>
      prayersAlone.fold(0, (sum, p) => sum + p.rakaas);
}
