import 'package:flutter/foundation.dart';
import '../core/freshness_engine.dart';
import '../core/quran_data.dart';
import '../core/rakaa_distributor.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../models/ayah_fact.dart';
import '../models/daily_session.dart';
import '../models/learning_progress.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/riwaya.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';
import '../services/ayah_facts_service.dart';
import '../services/hafs_service.dart';
import '../services/notification_service.dart';
import '../services/page_metadata_service.dart';
import '../services/storage_service.dart';
import '../services/warsh_service.dart';

part 'app_state_dayplan.dart';
part 'app_state_checkout.dart';
part 'app_state_learning.dart';

class AppState extends ChangeNotifier {
  UserConfig? _config;
  int _cyclePosition;
  DailySession? _todaySession;
  // Date (YYYY-MM-DD) of the oldest not-yet-sealed revision day, or null —
  // see `ensureDayPlan`. While non-null, the daily engine won't generate a
  // new plan (see Phase 6 cadrage, "daily engine — single source of truth").
  String? _pendingDate;
  // Date (YYYY-MM-DD) known to be sealed — NOT a bool: a bool would stay
  // true past midnight with the app still resident, showing "Day closed"
  // with a dead-end CTA on a brand new day, no way out short of killing
  // the app.
  String? _closedDate;
  Set<String> _pauseDates;
  String _locale;
  Riwaya _riwaya;
  final bool warshAvailable;
  bool _hasSeenTour;
  // Ids of the real-gesture guided steps completed so far (US-1 sprint B) —
  // filled once at boot (see `main.dart`), never reloaded in `_loadTrackState`:
  // the guided accompaniment is global, it must not replay on a riwaya
  // switch. Kept in the class body (not an extension) for the same reason as
  // `_hasSeenTour` — an `extension on AppState` cannot carry a field.
  Set<String> _guideDone;
  List<Sourate> _sourates;
  // Last revision date per verse (surahId → ayahId → date), finest grain
  // available — see `refreshFreshness`/`freshnessFor`. FreshnessEngine.
  // computeForRange buckets on demand over the exact requested range (whole
  // surah or partial selection), not a precomputed per-surah map: the range
  // varies by caller (RecapCard = selection, PlanScreen/check-in = today's
  // unit, possibly subdivided).
  Map<int, Map<int, DateTime>> _lastRevisionByAyah = {};

  AppState(
    this._config, {
    String locale = 'fr',
    Riwaya riwaya = Riwaya.hafs,
    this.warshAvailable = true,
    bool initialHasSeenTour = false,
    Set<String> initialGuideDone = const {},
    int initialCyclePosition = 0,
    Set<String> initialPauseDates = const {},
  })  : _locale = locale,
        // `riwaya` must stay a public named arg for callers — `this._riwaya`
        // would make the constructor arg private.
        // ignore: prefer_initializing_formals
        _riwaya = riwaya,
        _hasSeenTour = initialHasSeenTour,
        _guideDone = Set.from(initialGuideDone),
        _sourates = _souratesFor(riwaya),
        _cyclePosition = initialCyclePosition,
        _pauseDates = Set.from(initialPauseDates) {
    S.locale = locale;
  }

  static List<Sourate> _souratesFor(Riwaya riwaya) => buildSourates(
        verseCounts:
            riwaya == Riwaya.warsh ? WarshService.verseCounts : HafsService.verseCounts,
        wordCounts:
            riwaya == Riwaya.warsh ? WarshService.wordCounts : HafsService.wordCounts,
      );

  /// `notifyListeners()` is `@protected` (only callable from instance members
  /// of a `ChangeNotifier` subclass) — the domain extensions in
  /// `app_state_*.dart` are not instance members, so they call this instead.
  ///
  /// The ONLY call site of `notifyListeners()` in the whole library: the class
  /// body used to call it directly while the extensions called `_notify()`,
  /// which left the rule "one notify per logical operation" (`CLAUDE.md`)
  /// spread over two greps instead of one.
  void _notify() => notifyListeners();

  Sourate? _sourateById(int id) {
    for (final s in _sourates) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Today's selection, pure (no writes).
  ///
  /// The cycle does not depend on the date at all: it is a pure function of
  /// the selection, the pace and the cursor. Every caller
  /// (`ensureDayPlan`, `buildTodaySession`, `checkOut`, `daySelection`,
  /// `todayPreviewUnits`) reads it here so the day plan, the check-out and the
  /// KPIs can never diverge.
  DaySelection get _selection => RevisionEngine.buildDayUnits(
        config: _config!,
        cyclePosition: _cyclePosition,
        pageMetadata: PageMetadataService.pageMetadataFor(_riwaya),
      );

  UserConfig? get config => _config;
  int get cyclePosition => _cyclePosition;
  DailySession? get todaySession => _todaySession;
  String? get pendingDate => _pendingDate;
  Set<String> get pauseDates => Set.unmodifiable(_pauseDates);
  String get locale => _locale;
  Riwaya get riwaya => _riwaya;
  bool get hasSeenTour => _hasSeenTour;

  Future<void> markTourSeen() async {
    if (_hasSeenTour) return;
    _hasSeenTour = true;
    await StorageService.setTourSeen();
    _notify();
  }

  /// Has the real-gesture guided step [id] already happened (US-1 sprint B)?
  /// Synchronous, unlike the old per-hook flags it replaces: [_guideDone] is
  /// filled once at boot, so a screen reads it straight from `build` instead
  /// of an async `initState` load that risked flashing the "not guided yet"
  /// state for a frame.
  bool guideDone(String id) => _guideDone.contains(id);

  /// Marks guided step [id] as done — called only from the real gesture it
  /// accompanies (a check-in validated, a verse sheet actually opened, a
  /// check-out sealed, a step's own action button), never from a banner
  /// being merely displayed or dismissed. No-op if already done, so callers
  /// don't need to guard against re-marking on every tap.
  Future<void> markGuideDone(String id) async {
    if (_guideDone.contains(id)) return;
    _guideDone = {..._guideDone, id};
    await StorageService.saveGuideDone(_guideDone);
    _notify();
  }
  /// Sourates for the active track, with verse/word counts correct for the
  /// active riwaya (Hafs 6236 verses total, Warsh 6214 — per-surah counts
  /// differ accordingly). Use this instead of `quran_data.dart`'s raw data
  /// wherever a surah list is needed.
  List<Sourate> get sourates => _sourates;
  /// Has today already been sealed? Since "Seal my day" seals the current
  /// day without waiting for tomorrow (Phase 9 Sprint 2), the home screen
  /// needs to know — otherwise it would re-invite the user to "light up" an
  /// already-closed day. Derived from `ayah_facts` (`checked_out`), never
  /// kept in parallel, and compared against today's date so a date change
  /// invalidates it automatically.
  bool get todayClosed => _closedDate == todayStr;

  /// Freshness level of a surah/selection over its exact verse range
  /// [verseStart]..[verseEnd] (not `1..sourate.verses`) — see
  /// `FreshnessEngine.computeForRange`.
  FreshnessLevel freshnessFor(int sourateId, int verseStart, int verseEnd) =>
      FreshnessEngine.computeForRange(
        lastRevisionByAyah: _lastRevisionByAyah[sourateId] ?? const {},
        verseStart: verseStart,
        verseEnd: verseEnd,
        today: DateTime.now(),
      );

  /// Today's date as `YYYY-MM-DD` — key of all of today's `ayah_facts` rows.
  /// Public since Phase 9 Sprint 2: `DayPlanTab` needs it to push check-out
  /// onto today, and recomputing it in the UI would recreate a second
  /// source of truth.
  String get todayStr =>
      DateTime.now().toIso8601String().substring(0, 10);

  bool get isPausedToday => _pauseDates.contains(todayStr);

  Future<void> togglePauseToday() async {
    final today = todayStr;
    if (_pauseDates.contains(today)) {
      _pauseDates.remove(today);
    } else {
      _pauseDates.add(today);
    }
    await StorageService.savePauseDates(_pauseDates, _riwaya);
    _notify();
  }

  Future<void> setLocale(String locale) async {
    _locale = locale;
    S.locale = locale;
    await StorageService.saveLocale(locale);
    // Reminder text is baked in at scheduling time, so an already-scheduled
    // reminder would keep the language it was created in forever. Rescheduling
    // overwrites ids 1, 2 and 3 (morning/evening/midnight), so it is idempotent.
    if (await StorageService.loadNotifEnabled()) {
      await NotificationService.rescheduleAll();
    }
    _notify();
  }

  /// Switches the active track (Hafs <-> Warsh). Each riwaya is an
  /// independent track (separate config, cycle, day plan, progress,
  /// history) — nothing is translated from one track to the other. If the
  /// target track was never configured, `config` becomes `null` again and
  /// the app naturally falls back to onboarding (see main.dart). Returns
  /// `false` without changing anything if the requested riwaya couldn't be
  /// loaded at startup (Warsh text unavailable) — avoids crashing on
  /// `WarshService.verseCounts` while building the surah list.
  Future<bool> setRiwaya(Riwaya riwaya) async {
    if (riwaya == _riwaya) return true;
    if (riwaya == Riwaya.warsh && !warshAvailable) return false;
    _riwaya = riwaya;
    await StorageService.saveRiwaya(riwaya);
    await _loadTrackState();
    _notify();
    return true;
  }

  Future<void> _loadTrackState() async {
    // Independent reads kicked off in parallel — one round-trip instead of
    // several in series (same pattern as boot, main.dart).
    final configF = StorageService.loadConfig(_riwaya);
    final cyclePositionF = StorageService.loadCyclePosition(_riwaya);
    final pauseDatesF = StorageService.loadPauseDates(_riwaya);
    _config = await configF;
    _cyclePosition = await cyclePositionF;
    _pauseDates = await pauseDatesF;
    _sourates = _souratesFor(_riwaya);
    _todaySession = null;
    _pendingDate = null;
    // `ensureDayPlan` returns early when the track has no config, so it
    // would leave a stale closed-day flag from the previous riwaya.
    _closedDate = null;
    await refreshFreshness(notify: false);
    await ensureDayPlan(notify: false);
  }

  /// Only resets the cycle when the selected surahs actually changed — a
  /// mere pace adjustment (duration, lines/day) must not erase progress or
  /// the current day plan.
  ///
  /// Returns `false` (config left untouched) if the selection changes while
  /// an older day is still pending check-out ([pendingDate]): that day's
  /// `ayah_facts` rows were proposed from the CURRENT cycle, and sealing it
  /// reads `_selection` fresh from `_config` (see `checkOut`) — a selection
  /// change here (plus the `cyclePosition` reset below) would seal it against
  /// a cycle its own proposal never came from. A pace-only change is exempt
  /// ([setPagesPerDay] already guards its own, narrower risk on `todayClosed`
  /// instead of `pendingDate`: today's plan can still be re-proposed, an
  /// older pending day never touches `_selection` again once sealed).
  Future<bool> saveConfig(UserConfig config) async {
    final selectionsChanged =
        _config == null || !_sameSelections(_config!.selections, config.selections);
    if (selectionsChanged && _pendingDate != null) return false;
    _config = config;
    await StorageService.saveConfig(config, _riwaya);
    if (selectionsChanged) {
      _cyclePosition = 0;
      _todaySession = null;
      await StorageService.saveCyclePosition(0, _riwaya);
    }
    _notify();
    return true;
  }

  bool _sameSelections(List<SourateSelection> a, List<SourateSelection> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  /// Advances `cyclePosition` — delegates the calculation to
  /// `RevisionEngine`, the single source of truth for progress. Since
  /// Phase 6 Sprint 2, only called by [checkOut] (once per sealed day), no
  /// longer on every PlanScreen round.
  Future<void> advanceCycle(int unitsCompleted, int cycleTotal,
      {bool notify = true}) async {
    if (cycleTotal == 0) return;
    _cyclePosition = RevisionEngine.advanceCycle(
      currentPosition: _cyclePosition,
      unitsCompleted: unitsCompleted,
      cycleTotal: cycleTotal,
    );
    await StorageService.saveCyclePosition(_cyclePosition, _riwaya);
    if (notify) _notify();
  }

  /// Reloads last revision dates per verse from history — see
  /// [freshnessFor]. Called when a session starts and after each completed
  /// session.
  Future<void> refreshFreshness({bool notify = true}) async {
    _lastRevisionByAyah = await AyahFactsService.lastRevisionDatesPerVerse(riwaya: _riwaya);
    if (notify) _notify();
  }

  /// Toggling the shuffle rebuilds the cycle in a completely different order,
  /// so the cursor no longer designates the page it used to — it restarts,
  /// exactly like [saveConfig] does when the selection changes.
  ///
  /// Returns `false` (config left untouched) under the same [pendingDate]
  /// guard as [saveConfig]: `buildCycle` reorders on `shuffleEnabled` just as
  /// it does on `selections`, so flipping this mid-pending-day would corrupt
  /// that day's seal the same way an unguarded selection change would.
  Future<bool> setShuffleEnabled(bool enabled) async {
    if (_config == null || _config!.shuffleEnabled == enabled) return true;
    if (_pendingDate != null) return false;
    _config = _config!.copyWith(shuffleEnabled: enabled);
    _cyclePosition = 0;
    _todaySession = null;
    await StorageService.saveConfig(_config!, _riwaya);
    await StorageService.saveCyclePosition(0, _riwaya);
    _notify();
    return true;
  }

  Future<void> clearConfig() async {
    _closedDate = null;
    _config = null;
    _cyclePosition = 0;
    _todaySession = null;
    _pendingDate = null;
    _pauseDates = {};
    await StorageService.clearConfigOnly(_riwaya);
    _notify();
  }
}
