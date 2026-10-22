part of 'app_state.dart';

// ─── Check-in/check-out ritual (Phase 6 Sprint 2) — building/editing the day
// plan ──────────────────────────────────────────────────────────────────
//
// The day plan lives in `ayah_facts` (see cadrage, "Moteur quotidien — source
// unique de vérité"), but only once the check-in is validated
// (`commitCheckIn`): until then the user hasn't started the day and nothing
// is written. PlanScreen displays/spreads the rows across rakaas. Sealing
// (`checkOut`) and `reach` tracking live in `app_state_checkout.dart`.

extension AppStateDayPlan on AppState {
  RevisionUnit? _unitFor(DayFactGroup g) {
    final s = sourateById(g.surahId);
    if (s == null) return null;
    return RevisionUnit.spanning(s, g.verseStart, g.verseEnd);
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
    final returning =
        await AyahFactsRitual.returningVerses(date ?? todayStr, _riwaya);
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

  /// Round duration in days at the current pace (`DaySelection.cycleDays`),
  /// or `null` if nothing is selected — the close-out's "look ahead" (US-1
  /// crit. 5, US-14). Takes the hoisted selection, like [pagesProgressOf].
  int? roundDaysOf(DaySelection selection) => selection.cycleTotal == 0
      ? null
      : selection.cycleDays(_config?.pagesPerDay ?? 0,
          PageMetadataService.pageMetadataFor(_riwaya));

  /// Preview (no write) of what the daily engine proposes for today — the
  /// check-in's starting point. Exposed here so screens never import
  /// `RevisionEngine` directly.
  List<RevisionUnit> get todayPreviewUnits => daySelection.units;

  /// Daily engine entry point — call on app open/resume (see ShellScreen).
  /// Gated on a pending day STRICTLY before today (see
  /// `AyahFactsRitual.pendingDate`): until it's sealed, the day can't start —
  /// otherwise `cyclePosition` wouldn't have advanced for that day yet, and
  /// the new plan would propose the same verses a second time.
  ///
  /// **Writes no plan**: today's rows only appear when the check-in is
  /// validated ([commitCheckIn]). A day whose button was never pressed leaves
  /// no row, hence no catch-up check-out the next day.
  Future<void> ensureDayPlan({bool notify = true}) async {
    if (_config == null) return;
    final today = todayStr;
    // Two independent reads, started together — this is the app-open path.
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
      // Resumes the in-progress session if the app restarted after a
      // check-in/PlanScreen start earlier the same day (prayers already
      // chosen).
      final activePrayers = await StorageService.loadActivePrayers(_riwaya);
      // `[]` is a validated round without prayers (US-27 crit. 6), not absence.
      if (activePrayers != null) {
        await buildTodaySession(activePrayers, notify: false);
      }
    }
    if (notify) _notify();
  }

  /// Starting point of the check-in: today's rows when the day was already
  /// started (re-opened after "redo plan"), otherwise what the engine proposes
  /// — revision and the next block of the surah being learned — computed in
  /// memory, nothing written. Learning's default is only proposed for a day
  /// with no row at all, so "I'm not learning anything today" survives a
  /// re-opening.
  Future<CheckInDraft> checkInStart() async {
    final unitsF = dayUnits();
    final planF = learningPlanFor(todayStr);
    final units = await unitsF;
    final plan = await planF;
    if (units.isNotEmpty || plan != null) {
      return CheckInDraft(
        units: units,
        learning: plan == null
            ? null
            : (
                progress: await _learningProgressOf(plan.sourate),
                ayahIds: plan.ayahIds
              ),
      );
    }
    final inProgress = await learningInProgress();
    final block =
        inProgress?.nextBlock(_config?.versesToLearnPerDay ?? 0) ?? const <int>[];
    return CheckInDraft(
      units: todayPreviewUnits,
      learning: inProgress == null || block.isEmpty
          ? null
          : (progress: inProgress, ayahIds: block),
    );
  }

  /// Validating the check-in: the only moment today's plan is written to
  /// `ayah_facts`. Proposed rows (`reach = 0`) are cleared then the draft is
  /// proposed: what the user removed stays gone, while a row already at
  /// `reach = 1` is never touched (`proposeUnits` ignores conflicts).
  Future<void> commitCheckIn(CheckInDraft draft) async {
    if (_config == null) return;
    await AyahFactsRitual.clearDayProposal(todayStr, _riwaya);
    await AyahFactsRitual.proposeUnits(todayStr, _riwaya, draft.units);
    final learning = draft.learning;
    await setLearningForToday(
        learning?.progress.sourate, _config!.versesToLearnPerDay,
        ayahIds: learning?.ayahIds, notify: false);
    _notify();
  }

  /// Check-in (and the "Rythme" row in Settings): adjusts the pages/day
  /// budget and, when today's plan already exists, regenerates its revision
  /// proposal accordingly (rows already at `reach=1` are kept, see
  /// `AyahFactsRitual.clearDayProposal`). A day not started has no rows to
  /// regenerate, and the check-in passes [rewriteProposal] `false` because it
  /// rebuilds its in-memory draft itself.
  ///
  /// **Unless the day is already sealed**: since "Close my day" (Phase 9
  /// Sprint 2), today can be sealed while it's still today. Writing a fresh
  /// proposal (`checked_out = 0`) over it would reopen an already-counted
  /// day — it would go back to "pending" tomorrow, and its second check-out
  /// would advance the cycle a second time over content already credited.
  /// The new rhythm is persisted regardless: it applies to tomorrow's plan.
  Future<void> setPagesPerDay(int pagesPerDay,
      {bool rewriteProposal = true}) async {
    if (_config == null || _config!.pagesPerDay == pagesPerDay) return;
    _config = _config!.copyWith(pagesPerDay: pagesPerDay);
    await StorageService.saveConfig(_config!, _riwaya);
    final today = todayStr;
    if (rewriteProposal &&
        !todayClosed &&
        (await AyahFactsRitual.dayFacts(today, _riwaya)).isNotEmpty) {
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

  /// The user's selections that can still be added to a day plan, in mushaf
  /// order: every surah of the revision selection except those in [present].
  /// A catch-up reads today's selection, not the one of that past day.
  List<SourateSelection> addableSelections(Set<int> present) {
    final addable = (_config?.selections ?? const <SourateSelection>[])
        .where((sel) => !present.contains(sel.sourate.id))
        .toList();
    addable.sort((a, b) => a.sourate.id.compareTo(b.sourate.id));
    return addable;
  }

  /// Adds a surah/portion to the plan of [date]. Check-out uses it to
  /// declare a surah **revised in addition** that day: same write, the unit
  /// simply joins a past day's plan, where check-out's "done by default"
  /// will confirm it at sealing. The surah always belongs to the selection,
  /// so declaring it can advance `cyclePosition` beyond what the engine had
  /// proposed ("do more", see [checkOut]).
  Future<void> addToDayPlan(RevisionUnit unit, String date) async {
    await AyahFactsRitual.proposeUnits(date, _riwaya, [unit]);
    _notify();
  }

  /// Builds (or rebuilds) the day plan laid out across rakaas for the given
  /// prayers — distributes units already validated at check-in ([dayUnits]),
  /// doesn't regenerate them. Persists the prayer selection to survive an
  /// app restart before the session ends.
  Future<void> buildTodaySession(List<Prayer> prayersAlone,
      {bool notify = true}) async {
    if (_config == null) return;
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
      outsideLearning: layout.outsideLearning,
    );
    // `saveActivePrayers` = resume the in-progress session after a restart;
    // `saveLastSessionPrayers` = feeds "resume yesterday's prayers" at the
    // next check-in. Written here, when prayers are chosen, rather than at
    // session "completion" — since Phase 9 Sprint 2 there's no more session
    // completion, the day ends at check-out (see `PlanScreen.onCloturer`).
    // An empty choice must not erase "yesterday's prayers" for the next day.
    await Future.wait([
      StorageService.saveActivePrayers(prayersAlone, _riwaya),
      if (prayersAlone.isNotEmpty)
        StorageService.saveLastSessionPrayers(
            DateTime.now(), prayersAlone, _riwaya),
    ]);
    if (notify) _notify();
  }
}
