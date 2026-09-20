part of 'app_state.dart';

// ─── Check-in/check-out ritual (Phase 6 Sprint 2) — `reach` tracking and
// sealing ───────────────────────────────────────────────────────────────
//
// Building/editing the day plan lives in `app_state_dayplan.dart`. This file
// covers what checks/unchecks a unit, and what seals the day and advances
// the cycle.

extension AppStateCheckOut on AppState {
  /// Batch-marks `reach` (default `true`) for [units] — either a completed
  /// PlanScreen round (implicit date: today, `reach` always true), or a
  /// CheckOutScreen seal (explicit [date]): `reach: true` confirms "done by
  /// default", `reach: false` explicitly undoes a unit already at
  /// `reach=1` (e.g. checked by mistake earlier in PlanScreen) — see
  /// CLAUDE.md § "Modèle de données central": undoing progress resets
  /// `reach` to 0, never a plain no-op. Never advances `cyclePosition`
  /// itself (see [checkOut]); no `notifyListeners` here, left to callers
  /// that chain further writes before a single notify for the whole
  /// operation.
  Future<void> markUnitsReached(List<RevisionUnit> units,
      {String? date, bool reach = true}) async {
    await AyahFactsRitual.setReachForUnits(date ?? todayStr, _riwaya, units, reach);
  }

  /// Like [markUnitsReached], but verse by verse rather than a whole range —
  /// check-out now confirms each verse individually (US-3 crit. 3, revision
  /// and learning alike: a single gesture, unchecking one specific verse).
  Future<void> markVersesReached(
      String date, int surahId, List<int> ayahIds, bool reach) async {
    await AyahFactsRitual.setReachForVerses(date, _riwaya, surahId, ayahIds, reach,
        type: AyahFactType.revise);
  }

  /// Toggles "done/not done" for a PlanScreen rakaa — replaces the old
  /// in-memory/SharedPreferences state (`_checkedRakaas`) with a direct
  /// write into `ayah_facts` for today (see [setUnitReach] for an
  /// arbitrary date). If [unit] is assigned to several rakaas of the round
  /// (content shortage, cf. `RevisionEngine._padCyclically`), checking one
  /// automatically checks the others — `reach` is a per-verse/per-day
  /// truth, not per-rakaa, by design.
  /// [learning] targets the learning rakaa (`type='learn'` rows) instead of
  /// revision — same gesture ("I did this rakaa") on both content types.
  Future<void> toggleTodayUnitReach(RevisionUnit unit, bool reach,
      {bool learning = false}) async {
    if (!learning) return setUnitReach(todayStr, unit, reach);
    // The portion being learned isn't necessarily contiguous (a middle verse
    // may have been learned ahead, or un-learned): write the exact list of
    // proposed verses, not the `BETWEEN` range, which would include verses
    // with no row in the database.
    final plan = await learningPlanFor(todayStr);
    if (plan == null) return;
    await markLearnVerses(todayStr, plan.sourate.id, plan.ayahIds, reach);
    _notify();
  }

  /// Today's `reach` status for each unique unit in [units] — a single
  /// query ([AyahFactsRitual.reachedVersesToday]), with the exact per-range
  /// result recomputed in Dart (not per-surah like [dayUnitsWithStatus],
  /// which would wrongly merge two distinct ranges of the same surah
  /// assigned to different rakaas). Consumed by PlanScreen for each
  /// rakaa's "checked" state.
  Future<Map<RevisionUnit, bool>> reachStatusFor(Iterable<RevisionUnit> units,
      {bool learning = false}) async {
    final reachedByVerse = await AyahFactsRitual.reachedVersesToday(
        todayStr, _riwaya,
        type: learning ? AyahFactType.learn : AyahFactType.revise);
    // For learning, the truth is the list of verses actually proposed — not
    // the whole range: a portion with gaps ([2, 4, 5]) would otherwise never
    // be considered done, since verse 3 has no row to set to `reach = 1`.
    final learnVerses =
        learning ? (await learningPlanFor(todayStr))?.ayahIds : null;
    bool isReached(RevisionUnit unit) {
      final verses = learnVerses ??
          List.generate(unit.verseCount, (i) => unit.verseStart + i);
      return verses.isNotEmpty &&
          verses.every(
              (v) => reachedByVerse[unit.sourate.id]?.contains(v) ?? false);
    }

    return {for (final unit in units.toSet()) unit: isReached(unit)};
  }

  /// Toggles "done/not done" for a surah/portion of the check-out — or, if
  /// [learning], for a portion being learned (`type='learn'`).
  Future<void> setUnitReach(String date, RevisionUnit unit, bool reach,
      {bool learning = false}) async {
    await AyahFactsRitual.setReach(date, _riwaya, unit.sourate.id,
        unit.verseStart, unit.verseEnd, reach,
        type: learning ? AyahFactType.learn : AyahFactType.revise);
    _notify();
  }

  /// How many cycle PAGES day [date] actually completed, starting from
  /// `selection.cyclePosition` — this is what advances the cursor (the full
  /// business rule lives on [checkOut] and in `CLAUDE.md`).
  ///
  /// Counting does not stop at what the engine had proposed: it carries on
  /// into the NEXT pages of the cycle, so declaring extra work moves the
  /// cursor. A page beyond the proposal only counts if the user actually
  /// declared it that day, otherwise the cursor would skip never-revised
  /// content.
  Future<int> _completedPagesFor(String date, DaySelection selection) async {
    // The very cycle the day plan came from, not a second `buildCycle` pass:
    // rebuilding it here walked a list that nothing guaranteed identical to
    // the one that produced `selection.cyclePosition`.
    final cycle = selection.cycle;
    final proposedCount = selection.groups.length;
    int pagesCompleted = 0;
    for (int step = 0; step < cycle.length; step++) {
      final group = cycle[(selection.cyclePosition + step) % cycle.length];
      bool anyExists = false;
      for (final unit in group) {
        final status = await AyahFactsRitual.rangeStatus(
            date, _riwaya, unit.sourate.id, unit.verseStart, unit.verseEnd);
        if (!status.exists) continue; // removed at check-in — not blocking
        anyExists = true;
        // Unit present but not done: this group, and everything after, blocks.
        if (!status.reached) return pagesCompleted;
      }
      if (!anyExists) {
        // No row for this group. Within the day's proposal, that's a
        // check-in removal: neither counted nor blocking. Beyond it, it's
        // simply content not done: the cycle stops there.
        if (step < proposedCount) continue;
        return pagesCompleted;
      }
      pagesCompleted++;
    }
    return pagesCompleted;
  }

  /// Seals day [date] (check-out): locks its rows and advances the cycle
  /// once for the whole day, based on the engine-proposed GROUPS that
  /// actually reached `reach=1` (in order — same logic as PlanScreen's
  /// historical partial declaration: an out-of-selection addition at
  /// check-in feeds history/freshness but does not advance `cyclePosition`
  /// beyond what the engine originally proposed that day — the cadrage
  /// hasn't settled a more precise rule for out-of-cycle additions, see
  /// CHANGELOG). `cyclePosition` advances by completed GROUP
  /// (`DaySelection.groups`), not by individual unit: several short surahs
  /// sharing the same real mushaf page form a single group/cycle position
  /// (see "grouping by shared page" cadrage, 2026-09-05) — counting them one
  /// by one would desync `cyclePosition` from `cycleTotal` (which counts
  /// groups).
  ///
  /// That grouping only holds when a surah fits ENTIRELY on the shared page —
  /// one that only spills onto it forms its own cycle position instead, never
  /// merged with a neighbour that does fit whole (see `RevisionEngine.
  /// buildCycle`, `CLAUDE.md` § "Règle du plan quotidien" part A; fixed
  /// 2026-09-08).
  ///
  /// Within a group, a unit fully removed at check-in ([removeFromDayPlan])
  /// no longer has any row in the database: it is ignored (neither counted
  /// nor blocking) — only a unit that is *present* but not done blocks the
  /// group (and stops the count of subsequent groups), otherwise it would
  /// wrongly break the count of subsequent, genuinely completed groups (bug
  /// found in code review). A group whose units were ALL removed is itself
  /// ignored (neither counted nor blocking), for the same reason.
  ///
  /// **Idempotent on the cycle** (Phase 9 Sprint 2): re-sealing an
  /// already-sealed day rewrites corrected `reach` values but no longer
  /// advances `cyclePosition` — see the comment in the body. Returns `true`
  /// if the cycle just wrapped (milestone to show on screen).
  Future<bool> checkOut(String date) async {
    if (_config == null) return false;
    // Engine pass (pure CPU) and SQLite read are independent — started
    // together instead of in series.
    final sealedF = AyahFactsRitual.isDaySealed(date, _riwaya);
    final selection = _selection;
    // An already-sealed day can be re-sealed: "Seal my day" (Phase 9
    // Sprint 2) doesn't prevent running another round afterward, and the
    // following check-out would seal the same day a second time. `reach`
    // corrections keep writing normally, but the cycle must only advance
    // once per day — otherwise the cursor would skip never-revised content,
    // exactly what [_completedPagesFor]'s guard is meant to prevent.
    final pagesCompleted =
        await sealedF ? 0 : await _completedPagesFor(date, selection);
    final cycleWraps = pagesCompleted > 0 &&
        selection.cycleTotal > 0 &&
        (_cyclePosition + pagesCompleted) >= selection.cycleTotal;
    _pendingDate = null;
    // Only when it IS today: a catch-up check-out on an older day would
    // otherwise overwrite the flag and make an already-sealed today look
    // open again, re-arming the very guards that flag protects.
    if (date == todayStr) _closedDate = date;
    // Independent writes (ayah_facts table, prefs, cycle) — fired in
    // parallel instead of in series.
    await Future.wait([
      AyahFactsRitual.sealDay(date, _riwaya),
      StorageService.saveSealedDate(date, _riwaya),
      refreshFreshness(notify: false),
      clearTodaySession(notify: false),
      advanceCycle(pagesCompleted, selection.cycleTotal, notify: false),
    ]);
    // Only after sealing: a surah whose last verse was just confirmed
    // learned joins revision (see [handOffLearnedSurahs]).
    await handOffLearnedSurahs(notify: false);
    _notify(); // the only notify of the whole operation
    return cycleWraps;
  }
}
