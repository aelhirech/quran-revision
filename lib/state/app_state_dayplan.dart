part of 'app_state.dart';

// ─── Check-in/check-out ritual (Phase 6 Sprint 2) — building/editing the day
// plan ──────────────────────────────────────────────────────────────────
//
// The daily engine is the only source of the day plan: it writes proposed
// units directly into `ayah_facts` (see cadrage, "Moteur quotidien — source
// unique de vérité"). Check-in edits these rows, PlanScreen displays/spreads
// them across rakaas. Sealing (`checkOut`) and `reach` tracking live in
// `app_state_checkout.dart`.

extension AppStateDayPlan on AppState {
  RevisionUnit? _unitFor(DayFactGroup g) {
    final s = _sourateById(g.surahId);
    if (s == null) return null;
    return RevisionUnit(
      sourate: s,
      verseStart: g.verseStart,
      verseEnd: g.verseEnd,
      isWhole: g.verseStart == 1 && g.verseEnd == s.verses,
    );
  }

  /// Day plan units (pass `date`, defaults to `todayStr`) as validated at
  /// check-in — rebuilt from `ayah_facts`, never recomputed independently.
  Future<List<RevisionUnit>> dayUnits({String? date}) async {
    final groups = await AyahFactsRitual.dayFacts(date ?? todayStr, _riwaya);
    return groups.map(_unitFor).whereType<RevisionUnit>().toList();
  }

  /// Same as [dayUnits], plus each unit's per-verse `reach` status
  /// (`reachedVerses`) — this is the version CheckOutScreen consumes, at
  /// verse granularity (US-3 crit. 3).
  ///
  /// Persisted `reach` is read back rather than assumed "all done": the
  /// check-out shows everything as done BY DEFAULT — Backlog "Check-out :
  /// reach fait par défaut", 2026-09-04 — but that default only holds the
  /// first time. Since a sealed day can be reopened (Phase 9 Sprint 2), the
  /// screen has to start from what the user already declared, or a second
  /// close would silently re-credit what they had unchecked.
  Future<List<({RevisionUnit unit, Set<int> reachedVerses})>>
      dayUnitsWithStatus({String? date}) async {
    final groups = await AyahFactsRitual.dayFacts(date ?? todayStr, _riwaya);
    return [
      for (final g in groups)
        if (_unitFor(g) case final unit?)
          (unit: unit, reachedVerses: g.reachedVerses),
    ];
  }

  /// For [date]'s proposed units (defaults to today), which verses are
  /// "returning" — explicitly left undone at the check-out of a prior sealed
  /// day, now reproposed because their cycle group hasn't advanced past them
  /// — paired with the verse immediately preceding them in the user's
  /// current selection as a display-only context aid (US-3 crit. 4). `null`
  /// context means no valid predecessor to show (first verse of its
  /// selection). Consumed by the guided moment that proves the method (US-1
  /// sprint C) — this only surfaces the data, it writes nothing.
  Future<Map<(int, int), int?>> returningVersesContext({String? date}) async {
    final units = await dayUnits(date: date);
    final candidates = <(int, int)>{
      for (final u in units) for (final v in u.verses) (u.sourate.id, v),
    };
    final returning = await AyahFactsRitual.returningVerses(
        date ?? todayStr, _riwaya, candidates);
    final selections = _config?.selections ?? const [];
    return {
      for (final v in returning)
        v: RevisionEngine.contextVerseFor(v.$1, v.$2, selections),
    };
  }

  /// Has day [date] already been sealed? See [AyahFactsRitual.isDaySealed]
  /// — exposed so CheckOutScreen knows whether it's reopening a closed day
  /// or closing it for the first time.
  Future<bool> isDaySealed(String date) =>
      AyahFactsRitual.isDaySealed(date, _riwaya);

  /// Current cycle position/total, for display (HomeScreen banner, RecapScreen
  /// cycle card) — derived from the same [_selection] as the day plan
  /// (`DailySession`, PlanScreen), so the 3 screens stop each recomputing
  /// their own `RevisionEngine.buildDayUnits(...)` (a silent divergence
  /// source — see the 2026-09-01 TestFlight report on wrong récap numbers).
  ///
  /// Synchronous: a pure computation over `_config`/`_cyclePosition`, already
  /// in memory. Screens read it straight from `build` — a cached field
  /// filled by an `await` would stay stale right after a check-out that just
  /// advanced the cursor.
  DaySelection get daySelection => _config == null
      ? const DaySelection(groups: [], cycle: [], cyclePosition: 0)
      : _selection;

  /// Cycle progress in TRUE mushaf pages, for display — use this wherever a
  /// screen promises a page count to the user (`CycleProgressCard`, the
  /// Récap stat chip, PlanScreen's summary bar). `daySelection.cyclePosition`
  /// / `cycleTotal` count cycle ENTRIES, not always real pages (see
  /// `DaySelection.realPages`).
  ({int pos, int total}) get pagesProgress => pagesProgressOf(daySelection);

  /// Same counts, from a [DaySelection] the caller already holds. [_selection]
  /// rebuilds the whole cycle on every access, so a screen that needs both the
  /// page counts and something else off the selection (the home screen also
  /// asks [DaySelection.paginationUnavailable]) must hoist it once per frame
  /// rather than reach for two getters that each rebuild it.
  ({int pos, int total}) pagesProgressOf(DaySelection selection) =>
      selection.realPages(PageMetadataService.pageMetadataFor(_riwaya));

  /// Wraps `DaySelection.cycleDays` with this riwaya's page metadata — kept
  /// here so screens never import `PageMetadataService`/`RevisionEngine`
  /// directly (see [pagesProgressOf]).
  int cycleDaysFor(DaySelection selection, int pagesPerDay) => selection
      .cycleDays(pagesPerDay, PageMetadataService.pageMetadataFor(_riwaya));

  /// Preview (no write) of what the daily engine would propose if it ran
  /// now — used by the multi-day check-out ("also add today") to show a
  /// preview before sealing. Exposed here so screens never import
  /// `RevisionEngine` directly.
  List<RevisionUnit> get todayPreviewUnits => daySelection.units;

  /// Daily engine entry point — call on app open/resume (see ShellScreen).
  /// Gated on a pending day STRICTLY before today (see
  /// `AyahFactsRitual.pendingDate`): until it's sealed, no new plan is
  /// generated — otherwise `cyclePosition` wouldn't have advanced for that
  /// day yet, and the new plan would propose the same verses a second time.
  ///
  /// Since Phase 9, also proposes today's verses to **learn** (surah already
  /// in progress, `config.versesToLearnPerDay` verses) — check-in confirms
  /// or adjusts both proposals, it doesn't create them.
  Future<void> ensureDayPlan({bool notify = true}) async {
    if (_config == null) return;
    final today = todayStr;
    // Two independent reads, started together (like the block below) — this
    // is the app-open path.
    final pendingF = AyahFactsRitual.pendingDate(riwaya: _riwaya);
    final sealedF = AyahFactsRitual.isDaySealed(today, _riwaya);
    final sealedDateF = StorageService.loadSealedDate(_riwaya);
    _pendingDate = await pendingF;
    final sealed = await sealedF;
    final sealedDate = await sealedDateF;
    // A day with no revision row at all (every portion removed at check-in, or
    // nothing but learning) leaves nothing for `sealDay` to mark, hence the
    // stored date as a fallback — see `StorageService.saveSealedDate`.
    _closedDate = sealed || sealedDate == today ? today : null;
    if (_pendingDate == null) {
      // Independent reads started together rather than in series — this is
      // the app-open path (ShellScreen.initState).
      final existingF = AyahFactsRitual.dayFacts(today, _riwaya);
      final learnPlanF = AyahFactsLearning.learnPlanFor(today, _riwaya);
      final activePrayersF = StorageService.loadActivePrayers(_riwaya);
      // The day plan is only generated once a day — the learning proposal
      // is gated on that same moment, not merely on "no learn row today":
      // otherwise "I'm not learning anything today" (check-in) would be
      // silently undone on the next app open, re-proposing the same portion.
      // Known edge case: with no surah under revision, `proposeUnits` writes
      // nothing, so the day still looks new and the refusal gets re-proposed
      // on every open — harmless, no data consequence.
      if ((await existingF).isEmpty) {
        await AyahFactsRitual.proposeUnits(
            today, _riwaya, _selection.units);
        if (await learnPlanF == null) {
          final inProgress = await learningInProgress();
          if (inProgress != null) {
            await _proposeLearning(
                inProgress.sourate, _config!.versesToLearnPerDay,
                progress: inProgress);
          }
        }
      }
      // Resumes the in-progress session if the app restarted after a
      // check-in/PlanScreen start earlier the same day (prayers already
      // chosen).
      final activePrayers = await activePrayersF;
      if (activePrayers != null && activePrayers.isNotEmpty) {
        await buildTodaySession(activePrayers, notify: false);
      }
    }
    if (notify) _notify();
  }

  /// Check-in (and the "Rythme" row in Settings): adjusts the pages/day
  /// budget and regenerates today's revision proposal accordingly (rows
  /// already at `reach=1` are kept, see `AyahFactsRitual.clearDayProposal`).
  ///
  /// **Unless the day is already sealed**: since "Close my day" (Phase 9
  /// Sprint 2), today can be sealed while it's still today. Writing a fresh
  /// proposal (`checked_out = 0`) over it would reopen an already-counted
  /// day — it would go back to "pending" tomorrow, and its second check-out
  /// would advance the cycle a second time over content already credited.
  /// The new rhythm is persisted regardless: it applies to tomorrow's plan.
  Future<void> setPagesPerDay(int pagesPerDay) async {
    if (_config == null || _config!.pagesPerDay == pagesPerDay) return;
    _config = _config!.copyWith(pagesPerDay: pagesPerDay);
    await StorageService.saveConfig(_config!, _riwaya);
    if (!todayClosed) {
      final today = todayStr;
      await AyahFactsRitual.clearDayProposal(today, _riwaya);
      await AyahFactsRitual.proposeUnits(
          today, _riwaya, _selection.units);
      // A session already laid out across rakaas would carry units just
      // erased from the table — its checked boxes would revert with no
      // explanation. Close it, same as `saveConfig` does when the surah
      // selection changes.
      await clearTodaySession(notify: false);
    }
    _notify();
  }

  /// Closes the in-progress session ("redo plan", rhythm change, sealing) —
  /// single implementation of the `_todaySession` + `active_prayers` pair,
  /// which three callers otherwise each duplicated. [notify] `false` for
  /// callers chaining more writes before a single notify.
  Future<void> clearTodaySession({bool notify = true}) async {
    _todaySession = null;
    await StorageService.clearActivePrayers(_riwaya);
    if (notify) _notify();
  }

  /// Adds a surah/portion to the day plan from check-in.
  /// [date] defaults to today (check-in). Check-out passes it explicitly to
  /// declare a surah **revised in addition** that day: same write, the unit
  /// simply joins a past day's plan, where check-out's "done by default"
  /// will confirm it at sealing. Like any out-of-selection addition, it
  /// feeds history and freshness but doesn't advance `cyclePosition` beyond
  /// what the engine had proposed (see [checkOut]).
  Future<void> addToDayPlan(RevisionUnit unit, {String? date}) async {
    await AyahFactsRitual.proposeUnits(date ?? todayStr, _riwaya, [unit]);
    _notify();
  }

  /// Removes a surah/portion from the day plan from check-in.
  ///
  /// The range is not optional in practice: since the cycle became a page
  /// list, one day can hold two non-adjacent fragments of the same surah, and
  /// removing by surah alone would delete the other one too — with no way to
  /// get it back (re-adding writes the WHOLE surah).
  Future<void> removeFromDayPlan(int surahId,
      {int? verseStart, int? verseEnd}) async {
    await AyahFactsRitual.removeFromDayPlan(todayStr, _riwaya, surahId,
        verseStart: verseStart, verseEnd: verseEnd);
    _notify();
  }

  /// Extends a day plan surah's range by one verse (the "+" chip on the
  /// check-in detail screen).
  Future<void> extendDayPlanVerse(int surahId, int newVerse) async {
    final s = _sourateById(surahId);
    if (s == null) return;
    await AyahFactsRitual.proposeUnits(todayStr, _riwaya,
        [RevisionUnit(sourate: s, verseStart: newVerse, verseEnd: newVerse, isWhole: false)]);
    _notify();
  }

  /// Builds (or rebuilds) the day plan laid out across rakaas for the given
  /// prayers — distributes units already validated at check-in ([dayUnits]),
  /// doesn't regenerate them. Persists the prayer selection to survive an
  /// app restart before the session ends.
  Future<void> buildTodaySession(List<Prayer> prayersAlone,
      {bool notify = true}) async {
    if (_config == null || prayersAlone.isEmpty) return;
    // Two independent SQLite reads, started together rather than in series;
    // the cycle selection is a pure computation, done after so it doesn't
    // delay their start.
    final unitsF = dayUnits();
    final learningF = todayLearningUnit();
    final selection = _selection;
    final units = await unitsF;
    final layout = RakaaDistributor.distributeToRakaas(
      units: units,
      prayersAlone: prayersAlone,
      learningUnit: await learningF,
    );
    final pageMetadata = PageMetadataService.pageMetadataFor(_riwaya);
    // In TRUE pages (see `DaySelection.realPages`): the field already
    // documents "same unit as pagesToday", i.e. real pages, not cycle
    // entries (which can count more, see `buildCycle`).
    final pagesProgress = selection.realPages(pageMetadata);
    _todaySession = DailySession(
      date: DateTime.now(),
      prayersAlone: prayersAlone,
      plan: layout.plan,
      // Computed on the actually-kept units (`dayUnits()`, i.e. after
      // check-in edits), not on `selection`'s original proposal.
      pagesToday: RevisionEngine.pagesOf(units, pageMetadata),
      cyclePosition: pagesProgress.pos,
      cycleTotal: pagesProgress.total,
      outsidePrayers: layout.outside,
    );
    // `saveActivePrayers` = resume the in-progress session after a restart;
    // `saveLastSessionPrayers` = feeds "resume yesterday's prayers" at the
    // next check-in. Written here, when prayers are chosen, rather than at
    // session "completion" — since Phase 9 Sprint 2 there's no more session
    // completion, the day ends at check-out (see `PlanScreen.onCloturer`).
    await Future.wait([
      StorageService.saveActivePrayers(prayersAlone, _riwaya),
      StorageService.saveLastSessionPrayers(
          DateTime.now(), prayersAlone, _riwaya),
    ]);
    if (notify) _notify();
  }
}
