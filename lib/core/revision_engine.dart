import 'dart:math';

import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';

/// ~1 page Mushaf Madinah (128 mots/page × ~1,17 pages par unité)
const int _wordLimit = 150;

/// Minimum de lignes Mushaf Madinah par rakaa pour qu'une subdivision ait du sens.
const double _minLinesPerSlot = 5.0;

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
        units.addAll(
            _splitRange(sel.sourate, sel.verseStart, sel.verseEnd, chunks));
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
    final pool = _UnitPool(_expandToRakaas(units, totalSuratRakaas));

    final plan = <PrayerPlan>[];
    for (final prayer in prayersAlone) {
      pool.startPrayer();
      final rakaas = <RakaaAssignment>[];
      for (int r = 1; r <= prayer.rakaas; r++) {
        if (r > prayer.suratRakaas) {
          // Rakaa silencieuse (au-delà du nombre de rakaas récitées à voix haute) —
          // c'est la seule situation où une rakaa reste vide.
          rakaas.add(RakaaAssignment(rakaaNumber: r));
          continue;
        }
        rakaas.add(RakaaAssignment(rakaaNumber: r, unit: pool.next()));
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
  /// 1. Un verset seul ou une sous-unité < [_minLinesPerSlot] lignes n'est pas subdivisé davantage.
  /// 2. Si après expansion on a encore moins d'unités que de rakaas,
  ///    les unités sont répétées cycliquement (plutôt que laisser des rakaas vides).
  static List<RevisionUnit> _expandToRakaas(
      List<RevisionUnit> units, int targetCount) {
    if (units.isEmpty || units.length >= targetCount) return units;

    // Répartit targetCount rakaas entre les unités, le plus également
    // possible, et matérialise chacune dans la foulée (une seule passe).
    final materialized = <RevisionUnit>[];
    int slotsLeft = targetCount;
    int unitsLeft = units.length;
    for (final unit in units) {
      final slots = (slotsLeft / unitsLeft).round().clamp(1, slotsLeft);
      slotsLeft -= slots;
      unitsLeft--;
      materialized.addAll(_materialize(unit, slots));
    }
    return _padCyclically(materialized, targetCount);
  }

  /// Découpe [unit] en [slots] plages de versets contiguës, ou la garde
  /// entière si la subdivision n'a pas de sens (verset unique, ou moins de
  /// [_minLinesPerSlot] lignes par plage résultante).
  static List<RevisionUnit> _materialize(RevisionUnit unit, int slots) {
    final canSplit = slots > 1 &&
        unit.verseCount > 1 &&
        unit.estimatedLines / slots >= _minLinesPerSlot;
    if (!canSplit) return [unit];
    return _splitRange(unit.sourate, unit.verseStart, unit.verseEnd, slots);
  }

  /// Découpe la plage [start]–[end] de [sourate] en [count] sous-plages
  /// contiguës (la dernière bornée à [end]) — logique partagée par
  /// [buildUnits] (découpage par limite de mots) et [_materialize]
  /// (subdivision en rakaas).
  static List<RevisionUnit> _splitRange(
      Sourate sourate, int start, int end, int count) {
    final versesPerPart = ((end - start + 1) / count).ceil();
    final result = <RevisionUnit>[];
    for (int i = 0; i < count; i++) {
      final s = start + i * versesPerPart;
      if (s > end) break;
      final e = (s + versesPerPart - 1).clamp(start, end);
      result.add(RevisionUnit(
        sourate: sourate,
        verseStart: s,
        verseEnd: e,
        isWhole: false,
      ));
    }
    return result;
  }

  /// Répète cycliquement [units] jusqu'à atteindre [targetCount] — jamais de
  /// rakaa vide faute d'unité fraîche à proposer (répétition cyclique).
  static List<RevisionUnit> _padCyclically(
      List<RevisionUnit> units, int targetCount) {
    if (units.isEmpty || units.length >= targetCount) return units;
    return List.generate(targetCount, (i) => units[i % units.length]);
  }

  static int advanceCycle({
    required int currentPosition,
    required int unitsCompleted,
    required int cycleTotal,
  }) {
    return (currentPosition + unitsCompleted) % cycleTotal;
  }

  /// Unités (échelle attendue par [advanceCycle]) et unités réellement
  /// couvertes par les [n] premières rakaas de [plan] (dans l'ordre) —
  /// utilisé pour la déclaration manuelle "une part fait" de `PlanScreen`, où
  /// l'utilisateur pense en rakaas récitées, pas en unités de cycle.
  static ({int units, List<RevisionUnit> coveredUnits}) coverageForFirstRakaas(
      List<PrayerPlan> plan, int n) {
    final seenLabels = <String>{};
    final coveredUnits = <RevisionUnit>[];
    int counted = 0;
    for (final pp in plan) {
      for (final r in pp.rakaas) {
        if (r.unit == null) continue;
        if (counted >= n) break;
        counted++;
        seenLabels.add(r.unit!.label);
        coveredUnits.add(r.unit!);
      }
      if (counted >= n) break;
    }
    return (units: seenLabels.length, coveredUnits: coveredUnits);
  }
}

/// Distribue une liste d'unités déjà expansées (une par rakaa cible) rakaa
/// par rakaa, en respectant la règle "pas deux fois la même plage dans une
/// même prière" (S6-B assouplie) à trois niveaux de priorité :
/// 1. la prochaine unité pas encore consommée aujourd'hui et pas déjà
///    utilisée dans cette prière ;
/// 2. à défaut, une unité déjà consommée ailleurs aujourd'hui mais pas
///    encore dans cette prière ;
/// 3. en dernier recours, on répète — jamais de rakaa vide pour cette raison.
///
/// Le pool possède lui-même l'ensemble "déjà utilisé dans cette prière" —
/// [startPrayer] le réinitialise, [next] le met à jour — pour qu'aucun
/// appelant ne puisse casser la règle en oubliant de le faire.
class _UnitPool {
  _UnitPool(List<RevisionUnit> units) : _units = units.toList();

  final List<RevisionUnit> _units;
  int _consumed = 0;
  Set<RevisionUnit> _usedInPrayer = {};

  void startPrayer() => _usedInPrayer = {};

  RevisionUnit? next() {
    if (_units.isEmpty) return null;

    for (int k = _consumed; k < _units.length; k++) {
      if (!_usedInPrayer.contains(_units[k])) {
        if (k != _consumed) {
          final tmp = _units[_consumed];
          _units[_consumed] = _units[k];
          _units[k] = tmp;
        }
        final unit = _units[_consumed++];
        _usedInPrayer.add(unit);
        return unit;
      }
    }
    for (final u in _units) {
      if (!_usedInPrayer.contains(u)) {
        _usedInPrayer.add(u);
        return u;
      }
    }
    final unit = _units.first;
    _usedInPrayer.add(unit);
    return unit;
  }
}
