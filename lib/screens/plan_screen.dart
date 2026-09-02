import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_rules.dart';
import '../core/freshness_engine.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../services/ayah_facts_service.dart';
import '../services/verse_service.dart';
import '../state/app_state.dart';
import '../widgets/arabic_verse_text.dart';
import '../widgets/prayer_plan_card.dart';
import '../widgets/primary_cta_button.dart';

/// Répartition en rakaas d'un plan déjà validé au check-in (Phase 6 Sprint
/// 2, voir cadrage "Moteur quotidien") — checklist active uniquement,
/// l'ancien mode "aperçu avant engagement" a disparu : le check-in en tient
/// désormais lieu (`CheckInScreen`).
class PlanScreen extends StatefulWidget {
  final DailySession session;
  final Future<void> Function(int unitsCompleted, List<RevisionUnit> coveredUnits)? onComplete;
  final VoidCallback? onChangePlan;
  final FreshnessLevel? Function(int sourateId)? freshnessOf;

  const PlanScreen({
    super.key,
    required this.session,
    this.onComplete,
    this.onChangePlan,
    this.freshnessOf,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  // Chargé une fois puis tenu à jour localement par [_toggle] — pas de
  // `context.watch`, donc pas réactif à une écriture `ayah_facts` faite
  // ailleurs pour aujourd'hui. Sûr aujourd'hui car DayPlanTab n'affiche
  // jamais PlanScreen en même temps qu'un autre écran écrivant `reach`
  // (CheckOutScreen ne s'ouvre que sur un jour STRICTEMENT antérieur —
  // `AyahFactsService.pendingDate` — jamais aujourd'hui ; HomeScreen n'est
  // affiché que quand `todaySession == null`, donc jamais en même temps que
  // PlanScreen) — à revoir si un futur écran gagne la capacité d'écrire
  // `reach` pour aujourd'hui pendant que PlanScreen reste monté.
  Map<RevisionUnit, bool>? _reached;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reached =
        await context.read<AppState>().reachStatusFor(_allCoveredUnits);
    if (!mounted) return;
    setState(() => _reached = reached);
  }

  Map<int, Set<int>> _checkedByPrayer() {
    final reached = _reached ?? const {};
    final result = <int, Set<int>>{};
    for (int pi = 0; pi < widget.session.plan.length; pi++) {
      final pp = widget.session.plan[pi];
      result[pi] = {
        for (final r in pp.rakaas)
          if (r.unit != null && reached[r.unit] == true) r.rakaaNumber,
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

  /// Toutes les unités couvertes par le plan du jour (déclaration "tout fait")
  /// — plages verseStart/verseEnd précises, nécessaires pour écrire des
  /// faits par verset dans `ayah_facts` (Phase 6).
  List<RevisionUnit> get _allCoveredUnits => [
        for (final pp in widget.session.plan)
          for (final r in pp.rakaas)
            if (r.unit != null) r.unit!,
      ];

  /// Unités (échelle attendue par `advanceCycle`) et unités réellement
  /// couvertes par les [n] premières rakaas du plan (dans l'ordre) — utilisé
  /// pour la déclaration manuelle "une part fait", où l'utilisateur pense en
  /// rakaas récitées, pas en unités de cycle.
  ({int units, List<RevisionUnit> coveredUnits}) _coverageForFirstRakaas(int n) {
    final seenLabels = <String>{};
    final coveredUnits = <RevisionUnit>[];
    int counted = 0;
    for (final pp in widget.session.plan) {
      for (final r in pp.rakaas) {
        if (r.unit == null) continue;
        if (counted >= n) break;
        counted++;
        seenLabels.add(r.unit!.label);
        coveredUnits.add(r.unit!);
      }
      if (counted >= n) break;
    }
    return (units: seenLabels.length, coveredUnits: coveredUnits);
  }

  Future<void> _confirmChangePlan(BuildContext context) async {
    // Commitment modal — l'utilisateur doit déclarer ce qu'il a fait.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommitmentSheet(
        totalRakaas: _totalRakaasWithUnit,
        onToutFait: () async {
          Navigator.pop(context);
          if (mounted) {
            await widget.onComplete!(widget.session.totalUnits, _allCoveredUnits);
          }
        },
        onPartFait: (n) async {
          Navigator.pop(context);
          final coverage = _coverageForFirstRakaas(n);
          if (mounted) {
            await widget.onComplete!(coverage.units, coverage.coveredUnits);
          }
        },
        onRienFait: () {
          Navigator.pop(context);
          widget.onChangePlan?.call();
        },
      ),
    );
  }

  Future<void> _toggle(int prayerIndex, int rakaaNumber) async {
    final pp = widget.session.plan[prayerIndex];
    final unit = pp.rakaas.firstWhere((r) => r.rakaaNumber == rakaaNumber).unit;
    if (unit == null) return;
    final newReach = !((_reached ?? const {})[unit] ?? false);
    final appState = context.read<AppState>();
    // Coche affichée avant l'écriture disque (comme l'ancien
    // `toggleChecked`) pour que le tap reste instantané — `setReach` est une
    // affectation directe (pas de lecture-modification), la valeur locale
    // est donc déjà celle qui sera écrite.
    setState(() => _reached = {...?_reached, unit: newReach});
    await appState.toggleTodayUnitReach(unit, newReach);
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
    final checkedByPrayer = _checkedByPrayer();
    final allDone = _allDoneOf(checkedByPrayer);
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
                  icon: const Icon(Icons.tune),
                  tooltip: S.modifierPlan,
                  onPressed: () => _confirmChangePlan(context),
                ),
              IconButton(
                icon: const Icon(Icons.mosque_outlined),
                tooltip: S.focusMosquee,
                onPressed: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => _FocusMosqueeScreen(session: widget.session),
                  ),
                ),
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
          SliverToBoxAdapter(child: _summaryBar(cs)),
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
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 56,
            child: _completionButton(allDone, checkedCount),
          ),
        ),
      ),
    );
  }

  Future<void> _showCompletionSummary() async {
    final state = context.read<AppState>();
    // +1 anticipe la session d'aujourd'hui, pas encore enregistrée à ce stade.
    final streakFuture = AyahFactsService.currentStreak(
            pauseDates: state.pauseDates, riwaya: state.riwaya)
        .then((s) => s + 1);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompletionCelebrationSheet(
        session: widget.session,
        streakFuture: streakFuture,
      ),
    );
    if (mounted) {
      await widget.onComplete!(widget.session.totalUnits, _allCoveredUnits);
    }
  }

  Widget _completionButton(bool allDone, int checkedCount) {
    final button = PrimaryCtaButton(
      onPressed: allDone ? _showCompletionSummary : null,
      icon: allDone ? Icons.check_circle : Icons.check_circle_outline,
      label: allDone
          ? S.revisionComplete
          : '$checkedCount / $_totalRakaasWithUnit ${S.rakaasLabel}',
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

  Widget _summaryBar(ColorScheme cs) {
    final session = widget.session;
    final isOnTrack = session.isOnTrack;
    final palette = context.palette;
    final cycleEnd =
        (session.cyclePosition + session.totalUnits).clamp(0, session.cycleTotal);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.unitesRakaas(session.totalUnits, session.totalRakaas),
                style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              Text(
                isOnTrack ? S.dansLesTemps : S.prendsAvance,
                style: TextStyle(
                  color: isOnTrack ? palette.primary : cs.tertiary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${S.cycleEnCours} : $cycleEnd / ${session.cycleTotal}',
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: session.cycleTotal == 0
                        ? 0
                        : cycleEnd / session.cycleTotal,
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

// ─── Écran waouh (gamification) ───────────────────────────────────────────────

class _CompletionCelebrationSheet extends StatelessWidget {
  final DailySession session;
  final Future<int> streakFuture;

  const _CompletionCelebrationSheet({
    required this.session,
    required this.streakFuture,
  });

  List<RevisionUnit> _unitsForPrayer(PrayerPlan pp) {
    final seen = <String>{};
    final result = <RevisionUnit>[];
    for (final r in pp.rakaas) {
      if (r.unit != null && seen.add(r.unit!.label)) {
        result.add(r.unit!);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Animation célébration
          const Text('✨', style: TextStyle(fontSize: 52))
              .animate()
              .scale(
                  begin: const Offset(0.3, 0.3),
                  duration: 600.ms,
                  curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 800.ms),
          const SizedBox(height: 12),
          Text(S.waouhIslamic,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: context.palette.primary)),
          const SizedBox(height: 4),
          Text(S.waouhSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          // Streak
          FutureBuilder<int>(
            future: streakFuture,
            builder: (_, snap) {
              if (!snap.hasData) return const SizedBox(height: 40);
              final streak = snap.data!;
              return _StreakBadge(streak: streak)
                  .animate()
                  .fadeIn(delay: 300.ms)
                  .slideY(begin: 0.2);
            },
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          // Résumé session
          ...session.plan.map((pp) => _prayerRow(cs, pp)),
          const SizedBox(height: 20),
          PrimaryCtaButton(
            label: S.terminer,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.15, duration: 350.ms, curve: Curves.easeOut);
  }

  Widget _prayerRow(ColorScheme cs, PrayerPlan pp) {
    final units = _unitsForPrayer(pp);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.mosque_outlined,
                size: 16, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pp.prayer.nameFr,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: cs.onSurface)),
                Text(
                  units.isEmpty
                      ? S.alFatihaSeul
                      : units.map((u) => u.label).join(' · '),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    String message;
    if (streak == 1) {
      message = S.premierJour;
    } else if (AppRules.streakMilestones.contains(streak)) {
      message = S.nouveauPalier;
    } else {
      message = S.streakJours(streak);
    }

    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary)),
              Text(S.streakLabel,
                  style: TextStyle(fontSize: 11, color: palette.goldDark)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Commitment modal ─────────────────────────────────────────────────────────

class _CommitmentSheet extends StatefulWidget {
  final int totalRakaas;
  final Future<void> Function() onToutFait;
  final Future<void> Function(int n) onPartFait;
  final VoidCallback onRienFait;

  const _CommitmentSheet({
    required this.totalRakaas,
    required this.onToutFait,
    required this.onPartFait,
    required this.onRienFait,
  });

  @override
  State<_CommitmentSheet> createState() => _CommitmentSheetState();
}

class _CommitmentSheetState extends State<_CommitmentSheet> {
  int _partialN = 1;
  bool _showPartial = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(S.engagementTitre,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          const SizedBox(height: 20),
          if (!_showPartial) ...[
            PrimaryCtaButton(
              height: 50,
              icon: Icons.check_circle_outline,
              label: S.toutFait,
              onPressed: widget.onToutFait,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _showPartial = true;
                // clamp(1, totalRakaas) exigerait totalRakaas >= 1 : un plan
                // sans aucune unité assignée (aucune sourate sélectionnée,
                // cf. RevisionEngine) donnerait un intervalle 1..0 invalide.
                final maxRakaas = widget.totalRakaas > 0 ? widget.totalRakaas : 1;
                _partialN = (widget.totalRakaas * AppRules.defaultPartialFraction)
                    .round()
                    .clamp(1, maxRakaas);
              }),
              icon: const Icon(Icons.remove_circle_outline),
              label: Text(S.unePart,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: widget.onRienFait,
              icon: Icon(Icons.cancel_outlined, color: cs.error),
              label: Text(S.rienFait,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.error)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ] else ...[
            Text(S.combienRakaas,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: _partialN > 1
                      ? () => setState(() => _partialN--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('$_partialN',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface)),
                ),
                IconButton.filled(
                  onPressed: _partialN < widget.totalRakaas
                      ? () => setState(() => _partialN++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => widget.onPartFait(_partialN),
              child: Text(S.valider,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _showPartial = false),
              child: Text(S.annuler),
            ),
          ],
        ],
      ),
    ).animate().slideY(begin: 0.2, duration: 300.ms, curve: Curves.easeOut);
  }
}

// ─── Mode focus mosquée ───────────────────────────────────────────────────────

class _FocusMosqueeScreen extends StatelessWidget {
  final DailySession session;
  const _FocusMosqueeScreen({required this.session});

  List<RevisionUnit> get _uniqueUnits {
    final seen = <String>{};
    final result = <RevisionUnit>[];
    for (final pp in session.plan) {
      for (final r in pp.rakaas) {
        if (r.unit != null && seen.add(r.unit!.label)) {
          result.add(r.unit!);
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final units = _uniqueUnits;
    final riwaya = context.watch<AppState>().riwaya;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1410),
      body: SafeArea(
        child: Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              itemCount: units.length,
              separatorBuilder: (_, _) => Divider(
                  color: Colors.white.withValues(alpha: 0.12),
                  height: 32),
              itemBuilder: (_, i) {
                final unit = units[i];
                final verses = VerseService.versesForUnit(unit, riwaya: riwaya);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      unit.sourate.nameAr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 14),
                    ArabicVerseText(
                      text: verses.join('  '),
                      fontSize: 24,
                      height: 2.2,
                      color: const Color(0xFFF2F7F3),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(S.quitterFocus),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF86E0A8),
                    foregroundColor: const Color(0xFF0E1410),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
