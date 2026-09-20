import 'dart:math' as math;

import '../models/revision_unit.dart';
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

  /// How many days one full pass over the selection takes at [pagesPerDay].
  ///
  /// Deliberately counts CYCLE ENTRIES, not the real pages of [realPages]:
  /// `buildDayUnits` hands out `pagesPerDay` *entries* per day, and a surah
  /// straddling a page it shares with a fully-fitting neighbour costs 2
  /// entries for 1 physical page. Dividing real pages would promise a
  /// shorter round than the one actually walked — unacceptable for a number
  /// the UI phrases as a guarantee ("no surah waits more than N days").
  int cycleDays(int pagesPerDay) =>
      pagesPerDay <= 0 ? 0 : (cycleTotal / pagesPerDay).ceil();

  /// True when surahs are selected yet nothing entered the cycle — the only
  /// possible cause is that the mushaf pagination failed to load, since
  /// `buildCycle` drops any portion it cannot resolve to a real page.
  ///
  /// Lives here rather than in each screen: the home screen and the
  /// onboarding day-1 step both have to decide whether to warn, and two
  /// hand-written formulations of the same rule are exactly the silent
  /// divergence that produced the 2026-09-01 wrong-récap report.
  bool paginationUnavailable(bool hasSelections) =>
      hasSelections && cycleTotal == 0;

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

  /// The verse immediately preceding [ayahId] within its own range in
  /// [selections] — the display-only memory aid for a verse that reappears
  /// after being explicitly left undone at check-out (US-3 crit. 4), never
  /// itself proposed or credited. `null` when [ayahId] is the very first
  /// verse of its selection: showing a verse outside the range the user
  /// chose is never allowed (`CLAUDE.md` § "Règle du plan quotidien", E.3),
  /// so there is no valid predecessor to offer. Also `null` if [surahId]/
  /// [ayahId] is not part of any current selection at all (the user removed
  /// it since the verse was left undone).
  static int? contextVerseFor(
    int surahId,
    int ayahId,
    List<SourateSelection> selections,
  ) {
    for (final sel in selections) {
      if (sel.sourate.id != surahId) continue;
      if (ayahId < sel.verseStart || ayahId > sel.verseEnd) continue;
      return ayahId > sel.verseStart ? ayahId - 1 : null;
    }
    return null;
  }

  static int advanceCycle({
    required int currentPosition,
    required int unitsCompleted,
    required int cycleTotal,
  }) {
    return (currentPosition + unitsCompleted) % cycleTotal;
  }
}
