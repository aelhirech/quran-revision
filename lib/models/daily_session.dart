import 'prayer.dart';
import 'revision_unit.dart';

class RakaaAssignment {
  final int rakaaNumber;
  final RevisionUnit? unit; // null = Al-Fatiha uniquement

  const RakaaAssignment({required this.rakaaNumber, this.unit});
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
