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
  final int totalUnits;
  final int cyclePosition;
  final int cycleTotal;

  const DailySession({
    required this.date,
    required this.prayersAlone,
    required this.plan,
    required this.totalUnits,
    required this.cyclePosition,
    required this.cycleTotal,
  });

  int get totalRakaas =>
      prayersAlone.fold(0, (sum, p) => sum + p.rakaas);

  double get cycleProgress => cycleTotal == 0 ? 0 : cyclePosition / cycleTotal;
}
