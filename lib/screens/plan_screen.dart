import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/freshness_engine.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../models/revision_unit.dart';
import '../state/app_state.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/outside_prayers_block.dart';
import '../widgets/prayer_plan_card.dart';
import '../widgets/primary_cta_button.dart';

/// Rakaa layout of a plan already validated at check-in (Phase 6 Sprint 2,
/// see "Moteur quotidien" scoping) — active checklist only, the old
/// "preview before committing" mode is gone: check-in now stands in for it
/// (`CheckInScreen`).
class PlanScreen extends StatefulWidget {
  final DailySession session;

  /// "Close my day" — opens today's check-out (see `DayPlanTab`). Since
  /// Phase 9 Sprint 2, this is the screen's only normal exit: the old
  /// `onComplete` (declaring "all done / partly done / nothing done" + a
  /// celebration screen) is gone — what the user actually did is confirmed
  /// at check-out, and nowhere else.
  final VoidCallback onCloturer;

  /// "Redo the plan" — discards the current layout and returns to the home
  /// screen for a new check-in.
  final VoidCallback? onChangePlan;
  final FreshnessLevel Function(int sourateId, int verseStart, int verseEnd)? freshnessOf;

  const PlanScreen({
    super.key,
    required this.session,
    required this.onCloturer,
    this.onChangePlan,
    this.freshnessOf,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  // Loaded once, then kept up to date locally by [_toggle] — no
  // `context.watch`, so this is not reactive to an `ayah_facts` write made
  // elsewhere for today. Only one screen can write `reach` over a PlanScreen
  // left mounted: today's check-out, triggered by "Close my day".
  // `DayPlanTab._closeDay` rebuilds the round on return, which remounts a
  // new `DailySession`, a new `ValueKey`, and a fresh `_load()`. Revisit if
  // another screen gains that ability.
  Map<RevisionUnit, bool>? _reached;

  /// Status of the learning rakaa, kept apart from [_reached]: its facts
  /// live under `type='learn'` in `ayah_facts`, and two identical ranges
  /// (same surah, same verses) would otherwise collapse to a single entry in
  /// a Map keyed by `RevisionUnit`.
  bool _learningReached = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Today's learning rakaa (the last recited one), if there is one.
  RevisionUnit? get _learningUnit {
    for (final pp in widget.session.plan) {
      for (final r in pp.rakaas) {
        if (r.isLearning && r.unit != null) return r.unit;
      }
    }
    return null;
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final learningUnit = _learningUnit;
    // Two independent reads (revision / learning) started in parallel
    // rather than sequentially.
    final reachedF = state.reachStatusFor(_allCoveredUnits);
    final learningF = learningUnit == null
        ? Future.value(const <RevisionUnit, bool>{})
        : state.reachStatusFor([learningUnit], learning: true);
    final reached = await reachedF;
    final learning = await learningF;
    if (!mounted) return;
    setState(() {
      _reached = reached;
      _learningReached = learning[learningUnit] ?? false;
    });
  }

  bool _isReached(RakaaAssignment r) =>
      r.isLearning ? _learningReached : (_reached ?? const {})[r.unit] == true;

  Map<int, Set<int>> _checkedByPrayer() {
    final result = <int, Set<int>>{};
    for (int pi = 0; pi < widget.session.plan.length; pi++) {
      final pp = widget.session.plan[pi];
      result[pi] = {
        for (final r in pp.rakaas)
          if (r.unit != null && _isReached(r)) r.rakaaNumber,
      };
    }
    return result;
  }

  bool _allDoneOf(Map<int, Set<int>> checkedByPrayer) {
    for (int pi = 0; pi < widget.session.plan.length; pi++) {
      final pp = widget.session.plan[pi];
      final checked = checkedByPrayer[pi] ?? {};
      for (final r in pp.rakaas) {
        if (r.unit != null && !checked.contains(r.rakaaNumber)) return false;
      }
    }
    return true;
  }

  int get _totalRakaasWithUnit {
    int count = 0;
    for (final pp in widget.session.plan) {
      count += pp.rakaas.where((r) => r.unit != null).length;
    }
    return count;
  }

  int _checkedCountOf(Map<int, Set<int>> checkedByPrayer) =>
      checkedByPrayer.values.fold(0, (sum, s) => sum + s.length);

  /// All **revision** units covered by the day's plan (the "all done"
  /// declaration) — precise verseStart/verseEnd ranges, needed to write
  /// per-verse facts into `ayah_facts` (Phase 6). The learning rakaa is
  /// excluded: it does not advance the cycle and is confirmed at check-out
  /// (Phase 9).
  List<RevisionUnit> get _allCoveredUnits => [
        for (final pp in widget.session.plan)
          for (final r in pp.rakaas)
            if (r.unit != null && !r.isLearning) r.unit!,
      ];

  /// "Redo the plan" — replaces the old non-dismissable "All done / Partly
  /// done / Nothing done" panel (Phase 9 Sprint 2). Having the user declare
  /// what was revised here duplicated check-out, the only place that seals
  /// the day and advances the cycle; so all that remains is the "I want a
  /// different layout" gesture, behind a confirmation because it returns to
  /// the home screen. Rakaas already checked stay written in `ayah_facts`:
  /// nothing is lost, only the rakaa layout is.
  Future<void> _confirmRefairePlan() async {
    final confirmed = await confirmDialog(
      context,
      title: S.refairePlan,
      message: S.refairePlanConfirm,
      confirmLabel: S.refairePlan,
    );
    if (!mounted || !confirmed) return;
    widget.onChangePlan?.call();
  }

  Future<void> _toggle(int prayerIndex, int rakaaNumber) async {
    final pp = widget.session.plan[prayerIndex];
    final assignment = pp.rakaas.firstWhere((r) => r.rakaaNumber == rakaaNumber);
    final unit = assignment.unit;
    if (unit == null) return;
    final newReach = !_isReached(assignment);
    final appState = context.read<AppState>();
    // Checkbox shown before the disk write (like the old `toggleChecked`)
    // so the tap stays instant — `setReach` is a direct assignment (no
    // read-modify), so the local value is already what gets written.
    setState(() {
      if (assignment.isLearning) {
        _learningReached = newReach;
      } else {
        _reached = {...?_reached, unit: newReach};
      }
    });
    await appState.toggleTodayUnitReach(unit, newReach,
        learning: assignment.isLearning);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_reached == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final palette = context.palette;
    final checkedByPrayer = _checkedByPrayer();
    // Content that did not fit in the prayers is still today's content:
    // as long as any remains, the day is not "all done", even if every
    // rakaa is checked.
    final allDone = _allDoneOf(checkedByPrayer) &&
        widget.session.outsidePrayers.isEmpty;
    final checkedCount = _checkedCountOf(checkedByPrayer);
    final progress = _totalRakaasWithUnit == 0
        ? 1.0
        : checkedCount / _totalRakaasWithUnit;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(S.revisionEnCours),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            pinned: true,
            actions: [
              if (widget.onChangePlan != null)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: S.refairePlan,
                  onPressed: _confirmRefairePlan,
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: ClipRRect(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.primary,
                  minHeight: 4,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _summaryBar()),
          SliverToBoxAdapter(
              child: OutsidePrayersBlock(units: widget.session.outsidePrayers)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final pp = widget.session.plan[i];
                  return PrayerPlanCard(
                    prayerIndex: i,
                    pp: pp,
                    checked: checkedByPrayer[i] ?? {},
                    onToggle: (rakaa) => _toggle(i, rakaa),
                    freshnessOf: widget.freshnessOf,
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: i * 80))
                      .slideY(begin: 0.06);
                },
                childCount: widget.session.plan.length,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$checkedCount / $_totalRakaasWithUnit ${S.rakaasLabel}',
                  style: TextStyle(fontSize: 12, color: palette.textMuted)),
              const SizedBox(height: 8),
              SizedBox(height: 56, child: _completionButton(allDone)),
            ],
          ),
        ),
      ),
    );
  }

  /// "Close my day" — **always active** (2026-09-07 scoping decision):
  /// check-out is precisely the place to correct what wasn't done as well as
  /// what was done extra; locking it until every rakaa is checked would
  /// force a false check just to close the day. The celebration animation,
  /// though, only fires once everything is actually checked.
  Widget _completionButton(bool allDone) {
    final button = PrimaryCtaButton(
      onPressed: widget.onCloturer,
      icon: allDone ? Icons.check_circle : Icons.nightlight_outlined,
      label: S.cloturerMaJournee,
    );

    if (!allDone) return button;

    return button
        .animate(key: const ValueKey('done'))
        .scale(
            begin: const Offset(0.92, 0.92),
            end: const Offset(1, 1),
            duration: 350.ms,
            curve: Curves.elasticOut)
        .shimmer(
            duration: 900.ms,
            color: Colors.white.withValues(alpha: 0.4),
            delay: 100.ms);
  }

  /// Summary bar — in **real pages** since Phase 9 Sprint 2, the same unit
  /// as the configured pace. Reads `cyclePosition`/`cycleTotal` off the
  /// `DailySession` instead of re-deriving cycle progress locally: this
  /// screen was the last of the three (with Home and Récap) still doing its
  /// own cycle arithmetic — tech debt §8.5 of the tech doc.
  Widget _summaryBar() {
    final session = widget.session;
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: 0.07),
        border: Border.all(color: palette.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.pagesRakaas(session.pagesToday, session.totalRakaas),
            style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${S.cycleEnCours} : ${session.cyclePosition} / ${session.cycleTotal}',
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: session.cycleTotal == 0
                        ? 0
                        : session.cyclePosition / session.cycleTotal,
                    minHeight: 3,
                    backgroundColor: palette.textPrimary.withValues(alpha: 0.1),
                    color: palette.gold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
