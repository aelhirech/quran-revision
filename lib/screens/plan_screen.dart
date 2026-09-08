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
import '../widgets/prayer_plan_card.dart';
import '../widgets/primary_cta_button.dart';

/// Répartition en rakaas d'un plan déjà validé au check-in (Phase 6 Sprint
/// 2, voir cadrage "Moteur quotidien") — checklist active uniquement,
/// l'ancien mode "aperçu avant engagement" a disparu : le check-in en tient
/// désormais lieu (`CheckInScreen`).
class PlanScreen extends StatefulWidget {
  final DailySession session;

  /// « Clôturer ma journée » — ouvre le check-out du jour (voir `DayPlanTab`).
  /// Depuis la Phase 9 Sprint 2, c'est la seule sortie normale de l'écran :
  /// l'ancien `onComplete` (déclaration "tout fait / une part / rien fait" +
  /// écran de célébration) a disparu, ce que l'utilisateur a réellement fait
  /// se confirme au check-out et nulle part ailleurs.
  final VoidCallback onCloturer;

  /// « Refaire le plan » — abandonne la répartition en cours et revient à
  /// l'accueil pour un nouveau check-in.
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

  /// Statut de la rakaa d'apprentissage, tenu à part de [_reached] : ses
  /// faits vivent sous `type='learn'` dans `ayah_facts`, et deux plages
  /// identiques (même sourate, mêmes versets) n'auraient sinon qu'une seule
  /// entrée dans une Map clée par `RevisionUnit`.
  bool _learningReached = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Rakaa d'apprentissage du jour (la dernière récitée), s'il y en a une.
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
    // Deux lectures indépendantes (révision / apprentissage) démarrées en
    // parallèle plutôt qu'en série.
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

  /// Toutes les unités de **révision** couvertes par le plan du jour
  /// (déclaration "tout fait") — plages verseStart/verseEnd précises,
  /// nécessaires pour écrire des faits par verset dans `ayah_facts` (Phase
  /// 6). La rakaa d'apprentissage en est exclue : elle ne fait pas avancer
  /// le cycle et se confirme au check-out (Phase 9).
  List<RevisionUnit> get _allCoveredUnits => [
        for (final pp in widget.session.plan)
          for (final r in pp.rakaas)
            if (r.unit != null && !r.isLearning) r.unit!,
      ];

  /// « Refaire le plan » — remplace l'ancien volet non-fermable « Tout fait /
  /// Une part / Rien fait » (Phase 9 Sprint 2). Faire déclarer ici ce qui a
  /// été révisé faisait doublon avec le check-out, seul endroit qui scelle la
  /// journée et fait avancer le cycle ; il ne reste donc que le geste « je
  /// veux une autre répartition », derrière une confirmation parce qu'il
  /// renvoie à l'accueil. Les rakaas déjà cochées restent écrites dans
  /// `ayah_facts` : rien n'est perdu, seule la répartition en rakaas l'est.
  Future<void> _confirmRefairePlan() async {
    final confirmed = await confirmDialog(
      context,
      title: S.refairePlan,
      message: S.refairePlanConfirm,
      confirmLabel: S.refairePlan,
    );
    if (confirmed) widget.onChangePlan?.call();
  }

  Future<void> _toggle(int prayerIndex, int rakaaNumber) async {
    final pp = widget.session.plan[prayerIndex];
    final assignment = pp.rakaas.firstWhere((r) => r.rakaaNumber == rakaaNumber);
    final unit = assignment.unit;
    if (unit == null) return;
    final newReach = !_isReached(assignment);
    final appState = context.read<AppState>();
    // Coche affichée avant l'écriture disque (comme l'ancien
    // `toggleChecked`) pour que le tap reste instantané — `setReach` est une
    // affectation directe (pas de lecture-modification), la valeur locale
    // est donc déjà celle qui sera écrite.
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

  /// « Clôturer ma journée » — **toujours actif** (cadrage 2026-09-07) : le
  /// check-out est précisément l'endroit où l'on corrige ce qui n'a pas été
  /// fait comme ce qui l'a été en plus, le verrouiller tant que toutes les
  /// rakaas ne sont pas cochées obligerait à cocher faux pour pouvoir
  /// clôturer sa journée. L'animation de célébration ne se déclenche, elle,
  /// que quand tout est effectivement coché.
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

  /// Bandeau de résumé — en **pages réelles** depuis la Phase 9 Sprint 2, la
  /// même unité que le rythme réglé. Lit `pagesPosition`/`pagesTotal` du
  /// `DailySession` au lieu de reprojeter localement une fin de cycle : cet
  /// écran était le dernier des trois (avec Accueil et Récap) à refaire
  /// l'arithmétique de cycle dans son coin — dette §8.5 de la doc technique.
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
                '${S.cycleEnCours} : ${session.pagesPosition} / ${session.pagesTotal}',
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: session.pagesTotal == 0
                        ? 0
                        : session.pagesPosition / session.pagesTotal,
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
