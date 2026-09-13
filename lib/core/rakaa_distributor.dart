import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/sourate.dart';

const double _minLinesPerSlot = 5.0;

/// Lays already-chosen [RevisionUnit]s out into prayers' rakaas — steps 3-4
/// of the old monolithic `buildDayPlan`. See `CLAUDE.md` section "Règle du
/// plan quotidien", part D, for the spec this implements.
class RakaaDistributor {
  /// Distributes already-chosen units into the given prayers' rakaas. Pure:
  /// depends only on its arguments, reusable whether the units come from
  /// `RevisionEngine.buildDayUnits` (new flow) or from `ayah_facts` rows
  /// already validated at check-in (Phase 6 Sprint 2 — PlanScreen no longer
  /// generates its own plan, it distributes the one already confirmed).
  /// [learningUnit] (optional) — the verses the user wants to *learn* today:
  /// they occupy the very last recited rakaa of the day, revision filling the
  /// earlier ones. The revision budget is reduced by one rakaa for this,
  /// otherwise the last revision portion would simply be overwritten by
  /// learning instead of being redistributed.
  ///
  /// Returns the layout AND the units it could not place (`outside`), rule D
  /// of `CLAUDE.md`: only this function knows whether it subdivided (nothing
  /// is left out) or ran out of rakaas (the tail is shown apart). Re-deriving
  /// that outside by comparing values gets it wrong — a subdivided unit is
  /// never equal to the sub-ranges that replaced it.
  static ({List<PrayerPlan> plan, List<RevisionUnit> outside})
      distributeToRakaas({
    required List<RevisionUnit> units,
    required List<Prayer> prayersAlone,
    RevisionUnit? learningUnit,
  }) {
    final totalSuratRakaas =
        prayersAlone.fold(0, (sum, p) => sum + p.suratRakaas);
    final hasLearning = learningUnit != null && totalSuratRakaas > 0;
    final budget = totalSuratRakaas - (hasLearning ? 1 : 0);
    final pool = _UnitPool(_expandToRakaas(units, budget));

    // Countdown of remaining recited rakaas: the last one (recitedLeft == 0
    // after decrementing) is the learning one. Counting backwards avoids
    // having to locate "the last reciting prayer" upfront.
    int recitedLeft = totalSuratRakaas;
    final plan = <PrayerPlan>[];
    for (final prayer in prayersAlone) {
      pool.startPrayer();
      final rakaas = <RakaaAssignment>[];
      for (int r = 1; r <= prayer.rakaas; r++) {
        if (r > prayer.suratRakaas) {
          // Silent rakaa (beyond the recited-aloud count) — the only case
          // where a rakaa stays empty.
          rakaas.add(RakaaAssignment(rakaaNumber: r));
          continue;
        }
        recitedLeft--;
        if (hasLearning && recitedLeft == 0) {
          rakaas.add(RakaaAssignment(
              rakaaNumber: r, unit: learningUnit, isLearning: true));
          continue;
        }
        rakaas.add(RakaaAssignment(rakaaNumber: r, unit: pool.next()));
      }
      plan.add(PrayerPlan(prayer: prayer, rakaas: rakaas));
    }

    // Below the budget `_expandToRakaas` subdivides and pads, so every unit is
    // on screen — and the pool's leftovers would be sub-ranges, not the day's
    // units. Only a genuine shortage of rakaas leaves whole units unplaced.
    return (
      plan: plan,
      outside:
          units.length > budget ? pool.unconsumed : const <RevisionUnit>[],
    );
  }

  /// Subdivides units to fill [targetCount] rakaas.
  ///
  /// Rules:
  /// 1. A single verse, or a sub-unit under [_minLinesPerSlot] lines, is not
  ///    split further.
  /// 2. If expansion still leaves fewer units than rakaas, units repeat
  ///    cyclically rather than leaving a rakaa empty.
  static List<RevisionUnit> _expandToRakaas(
      List<RevisionUnit> units, int targetCount) {
    if (units.isEmpty || units.length >= targetCount) return units;

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

  /// Splits [unit] into [slots] contiguous verse ranges, or keeps it whole
  /// when splitting would not make sense (single verse, or under
  /// [_minLinesPerSlot] lines per resulting range).
  static List<RevisionUnit> _materialize(RevisionUnit unit, int slots) {
    final canSplit = slots > 1 &&
        unit.verseCount > 1 &&
        unit.estimatedLines / slots >= _minLinesPerSlot;
    if (!canSplit) return [unit];
    return _splitRange(unit.sourate, unit.verseStart, unit.verseEnd, slots);
  }

  /// Splits [sourate]'s [start]-[end] range into [count] contiguous
  /// sub-ranges (the last clamped to [end]).
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

  /// Repeats [units] cyclically up to [targetCount] — never an empty rakaa
  /// for lack of a fresh unit to propose.
  static List<RevisionUnit> _padCyclically(
      List<RevisionUnit> units, int targetCount) {
    if (units.isEmpty || units.length >= targetCount) return units;
    return List.generate(targetCount, (i) => units[i % units.length]);
  }
}

/// Distributes a list of already-expanded units (one per target rakaa)
/// rakaa by rakaa, honoring the "never the same range twice in one prayer"
/// rule (relaxed S6-B) at three priority levels:
/// 1. the next unit not yet consumed today and not already used in this
///    prayer;
/// 2. failing that, a unit already consumed elsewhere today but not yet in
///    this prayer;
/// 3. as a last resort, repeat — never an empty rakaa for this reason.
///
/// The pool itself owns the "already used in this prayer" set —
/// [startPrayer] resets it, [next] updates it — so no caller can break the
/// rule by forgetting to.
class _UnitPool {
  _UnitPool(List<RevisionUnit> units) : _units = units.toList();

  final List<RevisionUnit> _units;
  int _consumed = 0;
  Set<RevisionUnit> _usedInPrayer = {};

  /// Units no rakaa ever took — the day's content that did not fit.
  List<RevisionUnit> get unconsumed => _units.sublist(_consumed);

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
