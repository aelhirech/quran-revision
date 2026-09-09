import 'dart:math' as math;

import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';

/// One day of the cycle, before any rakaa layout.
///
/// See `CLAUDE.md` section "Règle du plan quotidien" — that pseudo-code is the
/// spec, this file implements it.
class DaySelection {
  /// The pages proposed for today. One entry usually = one real mushaf page,
  /// holding every selected fragment that fills it entirely — EXCEPT a surah
  /// straddling a page boundary, whose fragment there never merges with a
  /// neighbour, and so gets an entry of its own (see `buildCycle`).
  final List<List<RevisionUnit>> groups;

  /// The whole cycle [groups] was taken from. Carried along so the check-out
  /// walks the very list the day plan came from, instead of rebuilding it and
  /// risking a second, silently different derivation of the same state.
  final List<List<RevisionUnit>> cycle;

  /// Index of the next page to revise. Counted in PAGES, never in surahs: a
  /// surah larger than the daily budget must be resumable at page 2 tomorrow.
  final int cyclePosition;

  const DaySelection({
    required this.groups,
    required this.cycle,
    required this.cyclePosition,
  });

  /// How many cycle entries the whole selection spans — usually, but not
  /// always, the count of distinct real mushaf pages (see [groups]).
  int get cycleTotal => cycle.length;

  /// Progress in TRUE distinct mushaf pages — as opposed to
  /// [cyclePosition]/[cycleTotal], which count cycle ENTRIES, sometimes more
  /// numerous than real pages (a surah straddling a page it shares with a
  /// fully-fitting neighbour costs 2 entries for 1 physical page, see
  /// [buildCycle]). Screens that literally promise a page count to the user
  /// (`CycleProgressCard`, the Récap stat chip, `PlanScreen`'s summary bar)
  /// must use this instead of the raw fields.
  ///
  /// A real page counts as covered only once EVERY entry touching it has
  /// been passed — simply deduping page numbers over a prefix of [cycle]
  /// (an earlier version of this method did that) let a small straddling
  /// fragment mark the WHOLE shared page done the moment it alone was
  /// completed, well before its unrelated, not-yet-due neighbour on that
  /// same page (found in review: Al-Inshiqaq's last verse, sharing page 590
  /// with Al-Buruj — a full 22-verse surah — made the pair read "100%" right
  /// after Al-Inshiqaq alone was finished).
  ({int pos, int total}) realPages(Map<int, Map<int, int>> pageMetadata) {
    // Per real page, the index of the LAST cycle entry that touches it —
    // that page is only fully covered once the cursor has passed it too.
    //
    // One lookup per UNIT, not per verse: `buildCycle` only ever puts a
    // (start, end) range in a single entry when every verse in it shares one
    // real page (see its "min..max is exact" comment) — so `verseStart`
    // alone already names that page, and this stays cheap even on a full
    // Quran selection, unlike the equivalent scan over every raw verse.
    final lastEntryOfPage = <int, int>{};
    for (var i = 0; i < cycle.length; i++) {
      for (final unit in cycle[i]) {
        final page = pageMetadata[unit.sourate.id]?[unit.verseStart];
        if (page == null) continue;
        final known = lastEntryOfPage[page];
        if (known == null || i > known) lastEntryOfPage[page] = i;
      }
    }
    final covered =
        lastEntryOfPage.values.where((last) => last < cyclePosition).length;
    return (pos: covered, total: lastEntryOfPage.length);
  }

  /// Flattened view, for consumers that do not care about the page boundary
  /// (writing the proposal into `ayah_facts`, rakaa layout, check-out preview).
  List<RevisionUnit> get units => [for (final g in groups) ...g];
}

const double _minLinesPerSlot = 5.0;

class RevisionEngine {
  /// Number of distinct mushaf pages covered by [units] over their exact verse
  /// range. Counts page numbers, not (surah, page) pairs: several short surahs
  /// sharing one physical page cost one page, which is what the daily budget
  /// spends on them.
  static int pagesOf(
    Iterable<RevisionUnit> units,
    Map<int, Map<int, int>> pageMetadata,
  ) {
    final pages = <int>{};
    for (final unit in units) {
      final surahPages = pageMetadata[unit.sourate.id];
      if (surahPages == null) continue;
      for (int v = unit.verseStart; v <= unit.verseEnd; v++) {
        final page = surahPages[v];
        if (page != null) pages.add(page);
      }
    }
    return pages.length;
  }

  /// Deterministic per-surah shuffle rank — same seed and same surah give the
  /// same rank whatever else the selection holds.
  static int _shuffleKey(int seed, int surahId) =>
      math.Random(seed + surahId).nextInt(1 << 31);

  /// The whole cycle, as an ordered list of mushaf pages — each entry holding
  /// every selected fragment sitting on that page.
  ///
  /// Pure and deterministic: [pageMetadata] is injected, `lib/core/` does no
  /// I/O. Shuffling happens at SURAH level only, so a surah's pages always
  /// stay in mushaf order; a page shared by several selected surahs collapses
  /// into a single entry **only when every one of them fits entirely on that
  /// page** — pages are a mnemonic aid, revision happens surah by surah.
  ///
  /// A surah that only partly lands on a shared page (its selection spans
  /// several pages) never joins that page's shared entry: it would borrow the
  /// shared entry's rank — the MIN across everyone on it — and a neighbour
  /// shuffled earlier could then pull the surah's tail ahead of its own
  /// beginning, splitting it across two non-adjacent points of the cycle
  /// (found in production: Al-Inshiqaq's last verse, sharing a page with
  /// Al-Buruj, was proposed on its own while the rest of Al-Inshiqaq sat
  /// elsewhere in the cycle). Such a fragment gets its own private entry
  /// instead — see `_privatePageKey`.
  ///
  /// A selection whose surah has no pagination metadata is skipped — callers
  /// that can surface it should, rather than silently proposing nothing.
  static List<List<RevisionUnit>> buildCycle({
    required UserConfig config,
    required Map<int, Map<int, int>> pageMetadata,
  }) {
    final order = List<SourateSelection>.from(config.selections);
    if (config.shuffleEnabled) {
      // Sorted on a per-surah key rather than shuffled as a list: a
      // Fisher-Yates pass over n+1 elements shares nothing with the pass over
      // n, so adding one surah (`handOffLearnedSurahs`) reordered every other
      // one while `cyclePosition` stayed put — pages skipped, pages repeated.
      final seed = config.startDate.millisecondsSinceEpoch;
      order.sort((a, b) {
        final byKey = _shuffleKey(seed, a.sourate.id)
            .compareTo(_shuffleKey(seed, b.sourate.id));
        return byKey != 0 ? byKey : a.sourate.id.compareTo(b.sourate.id);
      });
    }

    // Keyed by real page number when a fragment fills its page entirely, or
    // by `_privatePageKey` otherwise — an "entry" is not always a real page,
    // see [DaySelection.groups].
    final fragmentsByEntry = <int, List<RevisionUnit>>{};
    final rankByEntry = <int, int>{};

    for (int rank = 0; rank < order.length; rank++) {
      final selection = order[rank];
      final surahPages = pageMetadata[selection.sourate.id];
      if (surahPages == null || surahPages.isEmpty) continue;

      // Only the verses the user actually selected. Reading the whole surah
      // here is what used to answer "v.1-5" to a request for "v.255-260".
      final versesByPage = <int, List<int>>{};
      for (int v = selection.verseStart; v <= selection.verseEnd; v++) {
        final page = surahPages[v];
        if (page != null) versesByPage.putIfAbsent(page, () => []).add(v);
      }

      // The whole selection fits on one page only when this surah touches a
      // single page in total — not per fragment, since a fragment is by
      // definition confined to its own page.
      final wholeOnOnePage = versesByPage.length == 1;

      versesByPage.forEach((page, verses) {
        // Verses of one surah on one page are contiguous, so min..max is exact.
        final start = verses.reduce(math.min);
        final end = verses.reduce(math.max);
        final key = wholeOnOnePage
            ? page
            : _privatePageKey(page, selection.sourate.id);
        fragmentsByEntry.putIfAbsent(key, () => []).add(RevisionUnit(
              sourate: selection.sourate,
              verseStart: start,
              verseEnd: end,
              isWhole: start == 1 && end == selection.sourate.verses,
            ));
        final known = rankByEntry[key];
        if (known == null || rank < known) rankByEntry[key] = rank;
      });
    }

    final entries = fragmentsByEntry.keys.toList()
      ..sort((a, b) {
        // Surah order first (shuffled or not), then mushaf order inside a surah.
        final byRank = rankByEntry[a]!.compareTo(rankByEntry[b]!);
        return byRank != 0 ? byRank : a.compareTo(b);
      });

    return [for (final key in entries) fragmentsByEntry[key]!];
  }

  /// Group key for a fragment that does NOT fill its whole page — exclusive
  /// to (surah, page) so it can never collide with a real page number nor
  /// with another surah's own private fragment. Plain arithmetic rather than
  /// a composite (page, surahId) key type: both bounds it relies on are
  /// Quran-structural constants, not runtime data that could grow —
  /// `page * 1000` alone already exceeds any real mushaf page count (604 on
  /// both riwayat, and the Quran will not gain more), and `surahId` is
  /// always one of exactly 114 fixed surahs, forever < 1000. Stays monotonic
  /// in [page] so a surah's own several private fragments keep mushaf order
  /// relative to each other under the (rank, key) sort above — they all
  /// carry the SAME rank (only this surah ever writes to its own private
  /// keys), so that sort falls through to this key as the tiebreak.
  static int _privatePageKey(int page, int surahId) => page * 1000 + surahId;

  /// The pages to propose today: [UserConfig.pagesPerDay] consecutive entries
  /// of [buildCycle], starting at [cyclePosition] and wrapping.
  ///
  /// Never returns more entries than the cycle holds, so no page is proposed
  /// twice before the cycle has wrapped.
  static DaySelection buildDayUnits({
    required UserConfig config,
    required int cyclePosition,
    required Map<int, Map<int, int>> pageMetadata,
  }) {
    final cycle = buildCycle(config: config, pageMetadata: pageMetadata);
    if (cycle.isEmpty) {
      return const DaySelection(groups: [], cycle: [], cyclePosition: 0);
    }
    final total = cycle.length;
    final pos = cyclePosition % total;
    final take = math.min(config.pagesPerDay, total);
    return DaySelection(
      groups: [for (int i = 0; i < take; i++) cycle[(pos + i) % total]],
      cycle: cycle,
      cyclePosition: pos,
    );
  }

  /// Répartit des unités déjà choisies dans les rakaas des prières données —
  /// étapes 3-4 de l'ancien `buildDayPlan` monolithique. Pure : ne dépend que
  /// de ses arguments, réutilisable que les unités viennent de
  /// [buildDayUnits] (nouveau flux) ou des lignes `ayah_facts` déjà
  /// validées au check-in (Phase 6 Sprint 2 — PlanScreen ne génère plus son
  /// propre plan, il répartit celui déjà confirmé).
  /// [learningUnit] (optionnel) — les versets que l'utilisateur veut
  /// *apprendre* aujourd'hui : ils occupent la toute dernière rakaa récitée
  /// de la journée, la révision se répartissant sur les précédentes. Le
  /// budget de rakaas laissé à la révision est donc réduit d'une unité, sans
  /// quoi la dernière portion de révision serait simplement écrasée par
  /// l'apprentissage au lieu d'être redistribuée.
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

    // Décompte des rakaas récitées restantes : la dernière (recitedLeft == 0
    // après décrément) est celle de l'apprentissage. Compter à rebours évite
    // d'avoir à retrouver "la dernière prière qui récite" en amont.
    int recitedLeft = totalSuratRakaas;
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
