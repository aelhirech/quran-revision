import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/sourate.dart';
import '../models/user_config.dart';

/// Limite de mots par unité de révision (~1 page de Mushaf standard)
const int _wordLimit = 150;

class RevisionEngine {
  /// Découpe les sourates en unités de révision basées sur le nombre de mots.
  /// Une unité = ce qu'on peut réciter confortablement dans une rakaa.
  static List<RevisionUnit> buildUnits(List<Sourate> sourates) {
    final units = <RevisionUnit>[];
    for (final s in sourates) {
      if (s.words <= _wordLimit) {
        units.add(RevisionUnit(
          sourate: s,
          verseStart: 1,
          verseEnd: s.verses,
          isWhole: true,
        ));
      } else {
        final chunks = (s.words / _wordLimit).ceil();
        // Divise les versets en chunks proportionnels
        final versesPerChunk = (s.verses / chunks).ceil();
        for (int i = 0; i < chunks; i++) {
          final start = i * versesPerChunk + 1;
          final end = ((i + 1) * versesPerChunk).clamp(1, s.verses);
          if (start > s.verses) break;
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

  /// Génère le plan du jour : distribue les unités dans les rakaas où
  /// une sourate est récitée (suratRakaas), pas tous les rakaas.
  static DailySession buildDayPlan({
    required UserConfig config,
    required List<Prayer> prayersAlone,
    required int cyclePosition,
    required DateTime today,
  }) {
    final units = buildUnits(config.learnedSourates);
    final cycleTotal = units.length;

    final daysElapsed = today.difference(config.startDate).inDays;
    final daysRemaining =
        (config.revisionDays - daysElapsed).clamp(1, config.revisionDays);

    // Nombre de rakaas disponibles pour la révision (seulement les rakaas avec sourate)
    final totalSuratRakaas =
        prayersAlone.fold(0, (sum, p) => sum + p.suratRakaas);

    final target = dailyTarget(
      cyclePosition: cyclePosition % cycleTotal,
      cycleTotal: cycleTotal,
      daysRemaining: daysRemaining,
    );

    final pos = cyclePosition % cycleTotal;
    final unitsToAssign = target.clamp(0, cycleTotal);
    final baseUnits = <RevisionUnit>[];
    for (int i = 0; i < unitsToAssign; i++) {
      baseUnits.add(units[(pos + i) % cycleTotal]);
    }

    // Subdivise les unités pour remplir tous les suratRakaas disponibles
    final todayUnits = _expandToRakaas(baseUnits, totalSuratRakaas);

    // Distribue dans les prières — les unités vont dans les suratRakaas premiers rakaas
    final plan = <PrayerPlan>[];
    int unitIndex = 0;
    for (final prayer in prayersAlone) {
      final rakaas = <RakaaAssignment>[];
      for (int r = 1; r <= prayer.rakaas; r++) {
        final canHaveSurat = r <= prayer.suratRakaas;
        if (canHaveSurat && unitIndex < todayUnits.length) {
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
      totalUnits: baseUnits.length,
      cyclePosition: pos,
      cycleTotal: cycleTotal,
      daysRemaining: daysRemaining,
    );
  }

  /// Subdivise les unités pour remplir exactement [targetCount] rakaas.
  /// Si on a moins d'unités que de rakaas, chaque unité est re-découpée proportionnellement.
  static List<RevisionUnit> _expandToRakaas(
      List<RevisionUnit> units, int targetCount) {
    if (units.isEmpty || units.length >= targetCount) return units;

    final result = <RevisionUnit>[];
    int slotsLeft = targetCount;
    int unitsLeft = units.length;

    for (final unit in units) {
      // Nombre de rakaas allouées à cette unité (distribution équitable)
      final slots = (slotsLeft / unitsLeft).round().clamp(1, slotsLeft);
      slotsLeft -= slots;
      unitsLeft--;

      if (slots == 1 || unit.verseCount <= 1) {
        result.add(unit);
      } else {
        final versesPerSlot = (unit.verseCount / slots).ceil();
        for (int i = 0; i < slots; i++) {
          final start = unit.verseStart + i * versesPerSlot;
          if (start > unit.verseEnd) break;
          final end = (start + versesPerSlot - 1).clamp(unit.verseStart, unit.verseEnd);
          result.add(RevisionUnit(
            sourate: unit.sourate,
            verseStart: start,
            verseEnd: end,
            isWhole: false,
          ));
        }
      }
    }

    return result;
  }

  static int advanceCycle({
    required int currentPosition,
    required int unitsCompleted,
    required int cycleTotal,
  }) {
    return (currentPosition + unitsCompleted) % cycleTotal;
  }
}
