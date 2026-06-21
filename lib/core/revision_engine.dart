import 'dart:math';

import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';

/// ~1 page Mushaf Madinah (128 mots/page × ~1,17 pages par unité)
const int _wordLimit = 150;

/// Minimum de lignes Mushaf Madinah par rakaa pour qu'une subdivision ait du sens.
const double _minLinesPerSlot = 3.0;

class RevisionEngine {
  static List<RevisionUnit> buildUnits(List<SourateSelection> selections) {
    final units = <RevisionUnit>[];
    for (final sel in selections) {
      final rangeWords = sel.estimatedWords;
      if (rangeWords <= _wordLimit) {
        units.add(RevisionUnit(
          sourate: sel.sourate,
          verseStart: sel.verseStart,
          verseEnd: sel.verseEnd,
          isWhole: sel.isWhole,
        ));
      } else {
        final chunks = (rangeWords / _wordLimit).ceil();
        final versesPerChunk = (sel.verseCount / chunks).ceil();
        for (int i = 0; i < chunks; i++) {
          final start = sel.verseStart + i * versesPerChunk;
          final end = (start + versesPerChunk - 1).clamp(sel.verseStart, sel.verseEnd);
          if (start > sel.verseEnd) break;
          units.add(RevisionUnit(
            sourate: sel.sourate,
            verseStart: start,
            verseEnd: end,
            isWhole: false,
          ));
        }
      }
    }
    return units;
  }

  static int dailyTarget({
    required int cyclePosition,
    required int cycleTotal,
    required int daysRemaining,
  }) {
    final unitsLeft = cycleTotal - cyclePosition;
    if (unitsLeft <= 0 || daysRemaining <= 0) return cycleTotal;
    return (unitsLeft / daysRemaining).ceil();
  }

  static DailySession buildDayPlan({
    required UserConfig config,
    required List<Prayer> prayersAlone,
    required int cyclePosition,
    required DateTime today,
    int? effectiveDaysOverride,
  }) {
    final rawUnits = buildUnits(config.selections);
    final units = config.shuffleEnabled
        ? ([...rawUnits]..shuffle(Random(config.startDate.millisecondsSinceEpoch)))
        : rawUnits;
    final cycleTotal = units.length;

    final totalVerses = config.totalSelectedVerses;
    final daysElapsed = today.difference(config.startDate).inDays;
    final effectiveDays = effectiveDaysOverride ?? config.effectiveDays(totalVerses);
    final daysRemaining = (effectiveDays - daysElapsed).clamp(1, effectiveDays);

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

    final expandedUnits = _expandToRakaas(baseUnits, totalSuratRakaas);
    // Mutable copy for no-repeat swap.
    final todayUnits = expandedUnits.toList();

    final plan = <PrayerPlan>[];
    int unitIndex = 0;
    for (final prayer in prayersAlone) {
      final rakaas = <RakaaAssignment>[];
      final usedInPrayer = <int>{};
      for (int r = 1; r <= prayer.rakaas; r++) {
        final canHaveSurat = r <= prayer.suratRakaas;
        if (!canHaveSurat || unitIndex >= todayUnits.length) {
          rakaas.add(RakaaAssignment(rakaaNumber: r));
          continue;
        }
        // Find the earliest remaining unit whose sourate isn't already in this prayer.
        int found = -1;
        for (int k = unitIndex; k < todayUnits.length; k++) {
          if (!usedInPrayer.contains(todayUnits[k].sourate.id)) {
            found = k;
            break;
          }
        }
        if (found == -1) {
          // All remaining units duplicate a sourate already used — leave empty.
          rakaas.add(RakaaAssignment(rakaaNumber: r));
        } else {
          // Swap to bring the non-duplicate forward. This may reorder units
          // across prayers; within-prayer uniqueness takes priority over cycle order.
          if (found != unitIndex) {
            final tmp = todayUnits[unitIndex];
            todayUnits[unitIndex] = todayUnits[found];
            todayUnits[found] = tmp;
          }
          final unit = todayUnits[unitIndex];
          rakaas.add(RakaaAssignment(rakaaNumber: r, unit: unit));
          usedInPrayer.add(unit.sourate.id);
          unitIndex++;
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

  /// Subdivise les unités pour remplir [targetCount] rakaas.
  ///
  /// Règles :
  /// 1. Un verset seul ou une sous-unité < 3 lignes n'est pas subdivisé davantage.
  /// 2. Si après expansion on a encore moins d'unités que de rakaas,
  ///    les unités sont répétées cycliquement (plutôt que laisser des rakaas vides).
  static List<RevisionUnit> _expandToRakaas(
      List<RevisionUnit> units, int targetCount) {
    if (units.isEmpty || units.length >= targetCount) return units;

    final result = <RevisionUnit>[];
    int slotsLeft = targetCount;
    int unitsLeft = units.length;

    for (final unit in units) {
      final slots = (slotsLeft / unitsLeft).round().clamp(1, slotsLeft);
      slotsLeft -= slots;
      unitsLeft--;

      final canSplit = slots > 1 &&
          unit.verseCount > 1 &&
          unit.estimatedLines / slots >= _minLinesPerSlot;

      if (!canSplit) {
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

    // Répétition cyclique si le nombre de rakaas dépasse les unités disponibles.
    if (result.isNotEmpty && result.length < targetCount) {
      final base = [...result];
      while (result.length < targetCount) {
        result.add(base[result.length % base.length]);
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
