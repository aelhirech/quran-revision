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

  /// Surahs whose last verse was first acquired on [date] join the revision
  /// selection whole (replacing any partial range) and leave learning.
  /// Returns them, for the check-out announcement.
  ///
  /// Keyed on the completion date, not on "complete and not whole yet", so
  /// it happens once: a range narrowed or a surah removed later is the
  /// user's choice and is never undone on another day.
  ///
  /// Bypasses [saveConfig], which resets `cyclePosition` to 0. The cursor is
  /// an entry index of `buildCycle` and the widened surah can sort before it
  /// (shuffle), so it is re-anchored on the verse it pointed to instead.
  Future<List<Sourate>> handOffLearnedSurahs({
    required String date,
    bool notify = true,
  }) async {
    if (_config == null) return const [];
    final completed = await AyahFactsLearning.surahsCompletedOn(date, _riwaya);
    final handed = <Sourate>[];
    for (final MapEntry(key: surahId, value: learned) in completed.entries) {
      final sourate = sourateById(surahId);
      if (sourate == null || learned < sourate.verses) continue;
      final alreadyWhole = _config!.selections.any(
        (s) => s.sourate.id == surahId && s.isWhole,
      );
      if (!alreadyWhole) handed.add(sourate);
    }
    if (handed.isEmpty) return const [];

    final before = _selection;
    _config = _config!.copyWith(selections: _widenedSelections(handed));
    await StorageService.saveConfig(_config!, _riwaya);

    final anchored = reanchorCursor(
      before.cycle,
      before.cyclePosition,
      _selection.cycle,
    );
    if (anchored == null && before.cycle.isNotEmpty) {
      debugPrint(
        '[AppState] handOffLearnedSurahs: cursor $_cyclePosition '
        'not found in the widened cycle, position kept as is',
      );
    }
    _cyclePosition = anchored ?? _cyclePosition;
    await StorageService.saveCyclePosition(_cyclePosition, _riwaya);

    if (notify) _notify();
    return handed;
  }

  /// Current selections with each of [sourates] made whole, at the place of
  /// its first range (duplicates dropped), or appended if it had none.
  List<SourateSelection> _widenedSelections(List<Sourate> sourates) {
    final selections = [..._config!.selections];
    for (final sourate in sourates) {
      final first = selections.indexWhere((s) => s.sourate.id == sourate.id);
      selections.removeWhere((s) => s.sourate.id == sourate.id);
      selections.insert(
        first == -1 ? selections.length : first,
        SourateSelection.whole(sourate),
      );
    }
    return selections;
  }
}
