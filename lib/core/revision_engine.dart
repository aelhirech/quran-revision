import 'dart:math';

import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';

/// ~1 page Mushaf Madinah (128 mots/page × ~1,17 pages par unité)
const int _wordLimit = 150;

/// Minimum de lignes Mushaf Madinah par rakaa pour qu'une subdivision ait du sens.
const double _minLinesPerSlot = 5.0;

/// Identité d'une unité pour la contrainte "pas deux fois la même plage
/// de versets dans une même prière" (S6-B assouplie : la sourate peut
/// revenir, tant que la plage exacte diffère).
String _unitKey(RevisionUnit u) =>
    '${u.sourate.id}_${u.verseStart}_${u.verseEnd}';

/// Résultat de [RevisionEngine.selectDayUnits] — quelles unités composent le
/// plan du jour, avant toute répartition en rakaas. Consommé à la fois par
/// [RevisionEngine.buildDayPlan] (répartition immédiate) et par le moteur
/// quotidien (Phase 6 Sprint 2, qui écrit ces unités dans `ayah_facts` sans
/// les répartir par prière).
class DaySelection {
  final List<RevisionUnit> units;
  final int cyclePosition; // position normalisée (mod cycleTotal)
  final int cycleTotal;
  final int daysRemaining;

  const DaySelection({
    required this.units,
    required this.cyclePosition,
    required this.cycleTotal,
    required this.daysRemaining,
  });
}

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

  /// Nombre d'unités (à partir de [pos], cycliquement) dont la somme des
  /// lignes Mushaf estimées atteint [targetLines] — mode "rythme par
  /// lignes/jour", alternative à [dailyTarget] qui se base sur les jours
  /// restants.
  static int _unitsForLines(
      List<RevisionUnit> units, int pos, int cycleTotal, int targetLines) {
    if (cycleTotal == 0) return 0;
    if (targetLines <= 0) return 1;
    double acc = 0;
    int count = 0;
    for (int i = 0; i < cycleTotal; i++) {
      acc += units[(pos + i) % cycleTotal].estimatedLines;
      count++;
      if (acc >= targetLines) break;
    }
    return count;
  }

  /// Détermine quelles unités composent le plan du jour (rythme par durée ou
  /// par lignes/jour) — sans les répartir en rakaas. Étapes 1-2 de l'ancien
  /// `buildDayPlan` monolithique, extraites pour être réutilisables par le
  /// moteur quotidien (Phase 6 Sprint 2) indépendamment de l'affichage
  /// prière-par-prière.
  static DaySelection selectDayUnits({
    required UserConfig config,
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
    // >= 1 : une config corrompue/personnalisée à 0 jour ne doit pas faire
    // planter clamp(1, effectiveDays) (nécessite lowerLimit <= upperLimit).
    final effectiveDays =
        (effectiveDaysOverride ?? config.effectiveDays(totalVerses)).clamp(1, 1 << 30);
    final daysRemaining = (effectiveDays - daysElapsed).clamp(1, effectiveDays);

    // Aucune sourate sélectionnée : rien à faire avancer dans le cycle
    // (dailyTarget/_unitsForLines savent déjà gérer cycleTotal == 0).
    final pos = cycleTotal == 0 ? 0 : cyclePosition % cycleTotal;
    final unitsToAssign = config.paceByLines
        ? _unitsForLines(units, pos, cycleTotal, config.targetLinesPerDay)
            .clamp(0, cycleTotal)
        : dailyTarget(
            cyclePosition: pos,
            cycleTotal: cycleTotal,
            daysRemaining: daysRemaining,
          ).clamp(0, cycleTotal);
    final baseUnits = <RevisionUnit>[];
    for (int i = 0; i < unitsToAssign; i++) {
      baseUnits.add(units[(pos + i) % cycleTotal]);
    }

    return DaySelection(
      units: baseUnits,
      cyclePosition: pos,
      cycleTotal: cycleTotal,
      daysRemaining: daysRemaining,
    );
  }

  /// Répartit des unités déjà choisies dans les rakaas des prières données —
  /// étapes 3-4 de l'ancien `buildDayPlan` monolithique. Pure : ne dépend que
  /// de ses arguments, réutilisable que les unités viennent de
  /// [selectDayUnits] (flux existant) ou des lignes `ayah_facts` déjà
  /// validées au check-in (Phase 6 Sprint 2 — PlanScreen ne génère plus son
  /// propre plan, il répartit celui déjà confirmé).
  static List<PrayerPlan> distributeToRakaas({
    required List<RevisionUnit> units,
    required List<Prayer> prayersAlone,
  }) {
    final totalSuratRakaas =
        prayersAlone.fold(0, (sum, p) => sum + p.suratRakaas);

    final expandedUnits = _expandToRakaas(units, totalSuratRakaas);
    // Mutable copy for no-repeat swap.
    final todayUnits = expandedUnits.toList();

    final plan = <PrayerPlan>[];
    int unitIndex = 0;
    for (final prayer in prayersAlone) {
      final rakaas = <RakaaAssignment>[];
      final usedInPrayer = <String>{};
      for (int r = 1; r <= prayer.rakaas; r++) {
        final canHaveSurat = r <= prayer.suratRakaas;
        if (!canHaveSurat) {
          // Rakaa silencieuse (au-delà du nombre de rakaas récitées à voix haute) —
          // c'est la seule situation où une rakaa reste vide.
          rakaas.add(RakaaAssignment(rakaaNumber: r));
          continue;
        }
        // 1. Cherche la prochaine unité non encore consommée aujourd'hui et pas
        //    déjà assignée dans cette prière (même exacte plage de versets).
        int found = -1;
        for (int k = unitIndex; k < todayUnits.length; k++) {
          if (!usedInPrayer.contains(_unitKey(todayUnits[k]))) {
            found = k;
            break;
          }
        }
        if (found != -1) {
          // Swap to bring the non-duplicate forward. This may reorder units
          // across prayers; within-prayer uniqueness takes priority over cycle order.
          if (found != unitIndex) {
            final tmp = todayUnits[unitIndex];
            todayUnits[unitIndex] = todayUnits[found];
            todayUnits[found] = tmp;
          }
          final unit = todayUnits[unitIndex];
          rakaas.add(RakaaAssignment(rakaaNumber: r, unit: unit));
          usedInPrayer.add(_unitKey(unit));
          unitIndex++;
          continue;
        }
        // 2. Plus rien de neuf à consommer : réutilise une unité déjà assignée
        //    ailleurs aujourd'hui mais pas encore dans cette prière — mieux
        //    qu'une rakaa vide, et ce n'est pas une répétition dans la prière.
        RevisionUnit? reuse;
        for (final u in todayUnits) {
          if (!usedInPrayer.contains(_unitKey(u))) {
            reuse = u;
            break;
          }
        }
        // 3. Dernier recours : tout a déjà été récité dans cette prière —
        //    on répète plutôt que de laisser la rakaa vide.
        reuse ??= todayUnits.isNotEmpty ? todayUnits.first : null;
        if (reuse != null) {
          rakaas.add(RakaaAssignment(rakaaNumber: r, unit: reuse));
          usedInPrayer.add(_unitKey(reuse));
        } else {
          rakaas.add(RakaaAssignment(rakaaNumber: r));
        }
      }
      plan.add(PrayerPlan(prayer: prayer, rakaas: rakaas));
    }

    return plan;
  }

  /// Construit le plan complet du jour (sélection + répartition en rakaas)
  /// en un seul appel — composition pure de [selectDayUnits] +
  /// [distributeToRakaas], sans effet de bord. Depuis Phase 6 Sprint 2, plus
  /// aucun appelant de l'app ne l'utilise directement (le moteur quotidien et
  /// PlanScreen appellent les deux étapes séparément, voir `AppState`) —
  /// conservée comme fonction pure testée (`test/core/revision_engine_test.dart`)
  /// plutôt que supprimée avec sa couverture de régression.
  static DailySession buildDayPlan({
    required UserConfig config,
    required List<Prayer> prayersAlone,
    required int cyclePosition,
    required DateTime today,
    int? effectiveDaysOverride,
  }) {
    final selection = selectDayUnits(
      config: config,
      cyclePosition: cyclePosition,
      today: today,
      effectiveDaysOverride: effectiveDaysOverride,
    );
    final plan = distributeToRakaas(
      units: selection.units,
      prayersAlone: prayersAlone,
    );
    return DailySession(
      date: today,
      prayersAlone: prayersAlone,
      plan: plan,
      totalUnits: selection.units.length,
      cyclePosition: selection.cyclePosition,
      cycleTotal: selection.cycleTotal,
      daysRemaining: selection.daysRemaining,
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
