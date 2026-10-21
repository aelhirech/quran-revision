part of 'app_state.dart';

// ─── Today's learning (Phase 9) ──────────────────────────────────────────
//
// Same model as revision: verses to learn are dated `ayah_facts` rows
// (`type='learn'`, `reach=0` targeted → `reach=1` acquired), never state
// held in parallel. The day plan's last rakaa recites them, check-out
// confirms which are actually acquired.

extension AppStateLearning on AppState {
  /// Surahs whose memorization is started but not finished — rebuilt from
  /// `ayah_facts` (`type='learn'`).
  Future<List<LearningProgress>> learningProgressList() async =>
      AyahFactsLearning.loadMainLearningProgress(
          riwaya: _riwaya, sourates: _sourates);

  /// Surah currently being learned, or `null`. Only one at a time in
  /// practice (check-in starts one), but switching surah mid-way leaves
  /// several unfinished: keep the **most recently started** one, the one
  /// the user is working on today — not whatever SQLite returns first,
  /// whose order means nothing.
  Future<LearningProgress?> learningInProgress() async {
    LearningProgress? latest;
    for (final p in await learningProgressList()) {
      if (p.isComplete) continue;
      if (latest == null || p.startDate.isAfter(latest.startDate)) latest = p;
    }
    return latest;
  }

  Future<LearningProgress> _learningProgressOf(Sourate sourate) async =>
      LearningProgress(
        sourate: sourate,
        learnedVerses: await AyahFactsLearning.learnedVersesForSourate(
            riwaya: _riwaya, surahId: sourate.id),
        startDate: DateTime.now(),
      );

  /// [count] also becomes the new default proposed on following days
  /// (`UserConfig.versesToLearnPerDay`). Returns whether it changed.
  Future<bool> _saveVersesToLearn(int count) async {
    if (_config == null || count == _config!.versesToLearnPerDay) return false;
    _config = _config!.copyWith(versesToLearnPerDay: count);
    await StorageService.saveConfig(_config!, _riwaya);
    return true;
  }

  /// Check-in: the learning part of the draft for [sourate] and [count] —
  /// the next [count] not-yet-acquired verses (`LearningProgress.nextBlock`),
  /// nothing written to `ayah_facts` until [commitCheckIn]. `null` for no
  /// surah, or one with nothing left to learn.
  Future<LearningDraft?> learningDraftFor(
      Sourate? sourate, int count) async {
    if (await _saveVersesToLearn(count)) _notify();
    if (sourate == null) return null;
    final progress = await _learningProgressOf(sourate);
    final ayahIds = progress.nextBlock(count);
    return ayahIds.isEmpty ? null : (progress: progress, ayahIds: ayahIds);
  }

  /// Portion to learn today (day plan's last rakaa), or `null` if the user
  /// isn't learning anything right now. **Derived on demand**, never cached
  /// in a field: that's exactly the state parallel to `ayah_facts` CLAUDE.md
  /// forbids (the `_checkedRakaas` precedent) — a cache would need
  /// refreshing by all 4 writers of `learn` rows, including
  /// `deleteLearnFacts` called from the Récap screen.
  Future<RevisionUnit?> todayLearningUnit() async {
    final plan = await learningPlanFor(todayStr);
    if (plan == null) return null;
    // `learnPlanFor` sorts by `ayah_id`, so first/last are indeed min/max.
    return RevisionUnit.spanning(
        plan.sourate, plan.ayahIds.first, plan.ayahIds.last);
  }

  /// Writes today's learning portion — called by [commitCheckIn]. [sourate]
  /// `null` = learn nothing today. [ayahIds] is the portion the user saw in
  /// the check-in; without it, the next [count] verses of [sourate].
  Future<void> setLearningForToday(Sourate? sourate, int count,
      {List<int>? ayahIds, bool notify = true}) async {
    if (_config == null) return;
    await _saveVersesToLearn(count);
    // Only rows still at `reach=0` are cleared — a verse already acquired
    // today doesn't disappear just because the portion is adjusted.
    await AyahFactsRitual.clearDayProposal(todayStr, _riwaya,
        type: AyahFactType.learn);
    if (sourate != null) {
      final block =
          ayahIds ?? (await _learningProgressOf(sourate)).nextBlock(count);
      await AyahFactsLearning.proposeLearnVerses(
          todayStr, _riwaya, sourate.id, block);
    }
    if (notify) _notify();
  }

  /// Check-out: declare one verse **learned in addition** on day [date] —
  /// adds the next not-yet-acquired verse of the surah being learned to
  /// that day's portion. No-op if there's no portion that day, or the surah
  /// is already fully memorized.
  Future<void> extendLearningForDate(String date) async {
    final plan = await learningPlanFor(date);
    if (plan == null) return;
    final learned = await AyahFactsLearning.learnedVersesForSourate(
        riwaya: _riwaya, surahId: plan.sourate.id);
    final taken = {...learned, ...plan.ayahIds};
    for (int v = 1; v <= plan.sourate.verses; v++) {
      if (taken.contains(v)) continue;
      await AyahFactsLearning.proposeLearnVerses(
          date, _riwaya, plan.sourate.id, [v]);
      break;
    }
    _notify();
  }

  /// Portion proposed to learn on day [date] (check-out of a pending day, or
  /// today via [todayLearningUnit]), resolved to a `Sourate` — `null` if the
  /// user wasn't learning anything that day. Verses are returned as-is (a
  /// list, not a range): a day's portion isn't necessarily contiguous if a
  /// middle verse was learned ahead of time. `reachedVerses` is surfaced so
  /// that checking out an ALREADY sealed day can restart from the exceptions
  /// declared the first time, instead of re-checking everything by default
  /// (see [dayUnitsWithStatus]).
  Future<({Sourate sourate, List<int> ayahIds, Set<int> reachedVerses})?>
      learningPlanFor(String date) async {
    final plan = await AyahFactsLearning.learnPlanFor(date, _riwaya);
    final sourate = plan == null ? null : sourateById(plan.surahId);
    if (plan == null || sourate == null || plan.ayahIds.isEmpty) return null;
    return (
      sourate: sourate,
      ayahIds: plan.ayahIds,
      reachedVerses: plan.reachedVerses,
    );
  }

  /// Confirms (or undoes) acquisition of verses learned on day [date] —
  /// check-out, in two batches (learned / still in progress). Undoing
  /// writes `reach = 0` explicitly rather than skipping: the row may already
  /// be at 1 (learning rakaa checked in PlanScreen) — see CLAUDE.md
  /// § "Modèle de données central" (central data model).
  Future<void> markLearnVerses(
      String date, int surahId, List<int> ayahIds, bool learned) async {
    await AyahFactsRitual.setReachForVerses(
        date, _riwaya, surahId, ayahIds, learned,
        type: AyahFactType.learn);
  }

  /// Verses of [surahId] acquired on the last learning day before [date] —
  /// what the check-out offers to withdraw (US-12).
  Future<List<int>> lastLearnedBlock(int surahId, String date) =>
      AyahFactsLearning.lastLearnedBlock(surahId, date, _riwaya);

  /// Withdraws verses learned on a previous day: they go back to "to learn"
  /// and the surah stays in progress (rows downgraded, never deleted).
  Future<void> unlearnVerses(int surahId, Iterable<int> ayahIds) =>
      AyahFactsLearning.unlearnVerses(surahId, ayahIds.toList(), _riwaya);

  /// Any fully memorized surah automatically switches to the revision
  /// selection and leaves learning — "once a surah's learning is finished
  /// it becomes revision" (Phase 9 cadrage). Replaces the old manual "Add
  /// to revision" button on the Learn tab (removed). Returns the surahs
  /// that just switched, so the caller can inform the user. Called at
  /// check-out (with `notify: false`, since the caller notifies once for
  /// the whole operation).
  ///
  /// The surah joins `selections` **without** going through [saveConfig],
  /// which would reset `cyclePosition` to 0: a freshly memorized surah is
  /// added to the current cycle, it doesn't invalidate the position already
  /// reached in the others.
  Future<List<Sourate>> handOffLearnedSurahs({bool notify = true}) async {
    if (_config == null) return const [];
    final handed = <Sourate>[];
    for (final p in await learningProgressList()) {
      // Already switched over at a previous check-out: neither re-added nor
      // re-reported. This check — not deleting the `learn` facts — is what
      // makes the switch idempotent: those facts are the memorization trail
      // feeding "Memorized surahs" (Récap, Settings); deleting them would
      // reset that counter to 0 forever.
      if (!p.isComplete ||
          _config!.selections.any((s) => s.sourate.id == p.sourate.id)) {
        continue;
      }
      _config = _config!.copyWith(
          selections: [..._config!.selections, SourateSelection.whole(p.sourate)]);
      await StorageService.saveConfig(_config!, _riwaya);
      handed.add(p.sourate);
    }
    if (notify && handed.isNotEmpty) _notify();
    return handed;
  }
}
