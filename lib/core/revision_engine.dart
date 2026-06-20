import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/sourate.dart';
import '../models/user_config.dart';

const int _pageLimitVerses = 20;

class RevisionEngine {
  /// Découpe les sourates en unités de révision (1 unité = 1 rakaa max)
  static List<RevisionUnit> buildUnits(List<Sourate> sourates) {
    final units = <RevisionUnit>[];
    for (final s in sourates) {
      if (s.verses <= _pageLimitVerses) {
        units.add(RevisionUnit(
          sourate: s,
          verseStart: 1,
          verseEnd: s.verses,
          isWhole: true,
        ));
      } else {
        final chunks = (s.verses / _pageLimitVerses).ceil();
        final chunkSize = (s.verses / chunks).ceil();
        for (int i = 0; i < chunks; i++) {
          final start = i * chunkSize + 1;
          final end = (start + chunkSize - 1).clamp(1, s.verses);
          units.add(RevisionUnit(
            sourate: s,
            verseStart: start,
            verseEnd: end,
            isWhole: false,
          ));
        }
      }
    }
    return units;
  }

  /// Calcule le nombre d'unités à couvrir aujourd'hui
  static int dailyTarget({
    required int cyclePosition,
    required int cycleTotal,
    required int daysRemaining,
  }) {
    final unitsLeft = cycleTotal - cyclePosition;
    if (unitsLeft <= 0 || daysRemaining <= 0) return cycleTotal;
    return (unitsLeft / daysRemaining).ceil();
  }

  /// Génère le plan du jour : distribue les unités dans les rakaas
  static DailySession buildDayPlan({
    required UserConfig config,
    required List<Prayer> prayersAlone,
    required int cyclePosition,
    required DateTime today,
  }) {
    final units = buildUnits(config.learnedSourates);
    final cycleTotal = units.length;

    final daysElapsed = today.difference(config.startDate).inDays;
    final daysRemaining = (config.revisionDays - daysElapsed).clamp(1, config.revisionDays);

    final totalRakaas = prayersAlone.fold(0, (sum, p) => sum + p.rakaas);

    final target = dailyTarget(
      cyclePosition: cyclePosition % cycleTotal,
      cycleTotal: cycleTotal,
      daysRemaining: daysRemaining,
    );

    final pos = cyclePosition % cycleTotal;
    final unitsToAssign = target.clamp(0, totalRakaas);
    final todayUnits = <RevisionUnit>[];
    for (int i = 0; i < unitsToAssign; i++) {
      todayUnits.add(units[(pos + i) % cycleTotal]);
    }

    // Distribue dans les prières
    final plan = <PrayerPlan>[];
    int unitIndex = 0;
    for (final prayer in prayersAlone) {
      final rakaas = <RakaaAssignment>[];
      for (int r = 1; r <= prayer.rakaas; r++) {
        if (unitIndex < todayUnits.length) {
          rakaas.add(RakaaAssignment(rakaaNumber: r, unit: todayUnits[unitIndex]));
          unitIndex++;
        } else {
          rakaas.add(RakaaAssignment(rakaaNumber: r));
        }
      }
      plan.add(PrayerPlan(prayer: prayer, rakaas: rakaas));
    }

    return DailySession(
      date: today,
      prayersAlone: prayersAlone,
      plan: plan,
      totalUnits: unitsToAssign,
      cyclePosition: pos,
      cycleTotal: cycleTotal,
      daysRemaining: daysRemaining,
    );
  }

  /// Avance le pointeur de cycle après une session complétée
  static int advanceCycle({
    required int currentPosition,
    required int unitsCompleted,
    required int cycleTotal,
  }) {
    return (currentPosition + unitsCompleted) % cycleTotal;
  }
}
