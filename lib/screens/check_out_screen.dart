import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';
import '../models/revision_unit.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../state/app_state.dart';
import '../widgets/check_hero.dart';
import '../widgets/cycle_milestone_dialog.dart';
import '../widgets/guide_step.dart';
import '../widgets/outlined_action_button.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/sourate_picker_sheet.dart';
import '../widgets/step_dots.dart';
import '../widgets/verse_chip.dart';
import '../widgets/verse_range_picker.dart';
import '../widgets/verse_toggle_chips.dart';
import 'check_out_row.dart';

part 'check_out_sections.dart';

/// Popup de rattrapage : scelle un jour de révision non encore clôturé
/// (`checked_out = 0`) — c'est le seul moment où `cyclePosition` avance
/// (voir `AppState.checkOut`). Tant qu'un jour est en attente, aucun nouveau
/// check-in n'est proposé (voir cadrage Phase 6, gating du moteur quotidien).
///
/// Écran à SECTIONS simultanées (révision + volet apprentissage, plus une
/// deuxième partie optionnelle pour le rattrapage multi-jours), pas un
/// wizard séquentiel : le découpage en fichiers suit cette logique
/// (contrôleur ici, sections "ajouter en plus"/apprentissage/partie 2 dans
/// `check_out_sections.dart` via `part`/`part of`, ligne de liste et
/// sous-écran de détail dans leurs propres fichiers) plutôt que le pattern
/// "une page par étape" de l'onboarding.
class CheckOutScreen extends StatefulWidget {
  final String date; // YYYY-MM-DD, jour en attente à clôturer
  const CheckOutScreen({super.key, required this.date});

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> {
  List<({RevisionUnit unit, Set<int> reachedVerses})>? _items;
  // Verses unchecked by the user (exceptions), identified by
  // (surahId, ayahId) — everything else is "done" by default, written to
  // the DB only at close ([_close]). Verse granularity (US-3 crit. 3):
  // replaces the old whole-surah/portion unchecking, unified with the same
  // gesture already used on the learning side (`_notLearned`). Prefilled
  // from the persisted `reach` when the day is ALREADY sealed: reopening a
  // close-out has to resume from what was declared, not recheck everything
  // (see [_load]).
  final Set<(int, int)> _uncheckedVerses = {};
  // Portion à apprendre proposée ce jour-là (Phase 9), et les versets que
  // l'utilisateur déclare NE PAS avoir acquis — même patron d'exception que
  // `_unchecked` côté révision : tout est "appris" par défaut, décocher
  // signale un verset à continuer d'apprendre (il sera reproposé).
  ({Sourate sourate, List<int> ayahIds, Set<int> reachedVerses})? _learnPlan;
  // Guide's "look ahead" (crit. 5): full progress of the surah being
  // learned, for `LearningProgress.daysToFinish` — distinct from
  // [_learnPlan], which only carries THIS day's proposed portion.
  LearningProgress? _learningProgress;
  final Set<int> _notLearned = {};
  int _step = 1;
  // Les exceptions persistées n'ont été reprises qu'une fois (voir [_load]).
  bool _prefilled = false;
  bool _addToday = false;
  bool _sealing = false;

  // `setState` is `@protected`, not callable from `_CheckOutSections` (an
  // extension, not a State subclass member despite sharing this library) —
  // this forwards it instead of scattering `// ignore:` comments there.
  void _setState(VoidCallback fn) => setState(fn);

  /// Calculé une fois : `DateTime.parse` sur une date locale résout le
  /// fuseau horaire, de loin la primitive la plus chère de cet écran, et les
  /// libellés le relisaient une dizaine de fois par build.
  late final int _gapDays =
      DateTime.now().difference(DateTime.parse(widget.date)).inDays;

  bool get _isMultiDay => _gapDays > 1;

  /// Clôture du jour courant (« Clôturer ma journée », Phase 9 Sprint 2) par
  /// opposition au rattrapage d'un jour passé : même écran, même mécanique de
  /// scellement — seuls les libellés changent, parler d'« hier » à quelqu'un
  /// qui clôture le soir même serait faux.
  bool get _isToday => _gapDays == 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final itemsF = state.dayUnitsWithStatus(date: widget.date);
    final learnF = state.learningPlanFor(widget.date);
    final sealedF = state.isDaySealed(widget.date);
    final learningProgressF =
        state.guideDone('checkout_done') ? null : state.learningInProgress();
    final items = await itemsF;
    final learn = await learnF;
    final sealed = await sealedF;
    if (learningProgressF != null) _learningProgress = await learningProgressF;
    if (!mounted) return;
    setState(() {
      _items = items;
      _learnPlan = learn;
      // "Tout fait par défaut" ne vaut que pour une PREMIÈRE clôture. Sur une
      // journée déjà scellée, repartir de zéro effacerait en silence les
      // exceptions déjà déclarées dès que l'utilisateur re-clôture. Une seule
      // fois : `_load` est rejoué au retour de l'écran détail, et réappliquer
      // la base écraserait ce que l'utilisateur vient de recocher.
      if (sealed && !_prefilled) {
        _prefilled = true;
        for (final it in items) {
          for (final v in it.unit.verses) {
            if (!it.reachedVerses.contains(v)) {
              _uncheckedVerses.add((it.unit.sourate.id, v));
            }
          }
        }
        if (learn != null) {
          _notLearned.addAll(
              learn.ayahIds.where((v) => !learn.reachedVerses.contains(v)));
        }
      }
    });
  }

  void _toggleVerse(int surahId, int ayahId) {
    setState(() {
      final key = (surahId, ayahId);
      if (!_uncheckedVerses.add(key)) _uncheckedVerses.remove(key);
    });
  }

  Future<void> _close() async {
    if (_sealing) return;
    setState(() => _sealing = true);
    try {
      final state = context.read<AppState>();
      // Le check-out est "fait par défaut" : les versets restés cochés sont
      // confirmés reach=1. Les exceptions décochées repassent explicitement à
      // reach=0 — nécessaire même si `proposeUnits` les a déjà écrites à 0,
      // car un verset peut avoir reach=1 depuis plus tôt dans la journée
      // (rakaa cochée dans PlanScreen avant que le jour ne devienne "en
      // attente") : annuler une progression doit repasser reach à 0, jamais
      // rester un no-op silencieux (voir CLAUDE.md § « Modèle de données
      // centrale »). Granularité verset (US-3 crit. 3) : groupé par sourate
      // pour tenir en un aller-retour SQLite par sourate/statut plutôt qu'un
      // par verset.
      final checkedBySurah = <int, List<int>>{};
      final uncheckedBySurah = <int, List<int>>{};
      for (final it in _items!) {
        final surahId = it.unit.sourate.id;
        for (final v in it.unit.verses) {
          final bucket =
              _uncheckedVerses.contains((surahId, v)) ? uncheckedBySurah : checkedBySurah;
          bucket.putIfAbsent(surahId, () => []).add(v);
        }
      }
      // Même patron pour la portion à apprendre : les versets restés cochés
      // sont confirmés acquis, ceux décochés repassent explicitement à
      // `reach = 0` (ils seront reproposés) plutôt que de rester tels quels.
      final learn = _learnPlan;
      await Future.wait([
        for (final entry in checkedBySurah.entries)
          state.markVersesReached(widget.date, entry.key, entry.value, true),
        for (final entry in uncheckedBySurah.entries)
          state.markVersesReached(widget.date, entry.key, entry.value, false),
        if (learn != null) ...[
          state.markLearnVerses(
              widget.date,
              learn.sourate.id,
              [for (final v in learn.ayahIds) if (!_notLearned.contains(v)) v],
              true),
          state.markLearnVerses(
              widget.date, learn.sourate.id, _notLearned.toList(), false),
        ],
      ]);
      final cycleWrapped = await state.checkOut(widget.date);
      // Marked AFTER the real sealing, never on the guide's display or a
      // plain tap — see CLAUDE.md § "Modèle de données central" and the
      // guide rule (CHANGELOG, US-1 sprint B).
      await state.markGuideDone('checkout_done');
      // Le jour en attente est scellé. Écart d'1 jour : pas de choix
      // proposé, on enchaîne directement sur aujourd'hui comme avant.
      // Écart multi-jours (Partie 2) : ne propose aujourd'hui que si
      // l'utilisateur l'a explicitement demandé via le toggle — sinon
      // "Terminer sans aujourd'hui" doit vraiment différer, pas générer le
      // plan quand même à la ligne suivante (bug trouvé en revue de code).
      if (!_isMultiDay || _addToday) await state.ensureDayPlan();
      if (!mounted) return;
      if (cycleWrapped) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const CycleMilestoneDialog(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sealing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final palette = context.palette;
    final items = _items;
    final showPart2 = _isMultiDay && _step == 2;

    return PopScope(
      canPop: !_sealing,
      child: Scaffold(
        backgroundColor: palette.cream,
        body: items == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    _hero(palette, showPart2),
                    if (!state.guideDone('checkout_done')) _guideStep(state),
                    Expanded(
                      child: showPart2
                          ? _part2Body(palette)
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              children: [
                                for (final it in items)
                                  CheckOutRow(
                                    unit: it.unit,
                                    uncheckedVerses: {
                                      for (final v in it.unit.verses)
                                        if (_uncheckedVerses
                                            .contains((it.unit.sourate.id, v)))
                                          v,
                                    },
                                    onToggleVerse: (v) =>
                                        _toggleVerse(it.unit.sourate.id, v),
                                  ),
                                const SizedBox(height: 14),
                                OutlinedActionButton(
                                    icon: Icons.add,
                                    label: S.checkOutReviseEnPlus,
                                    onTap: _addRevisedSourate),
                                ..._learnSection(palette),
                              ],
                            ),
                    ),
                    _ctaBar(palette, showPart2),
                  ],
                ),
              ),
      ),
    );
  }

  /// "Look ahead" of the first check-out (US-1 crit. 5): the cycle's round
  /// duration (`DaySelection.cycleDays`, reused from sprint A) and, if a
  /// surah is being memorized, its conditional deadline
  /// (`LearningProgress.daysToFinish`). Generic fallback if neither applies
  /// (empty selection, or no learning in progress).
  Widget _guideStep(AppState state) {
    final cycleTotal = state.daySelection.cycleTotal;
    final pagesPerDay = state.config?.pagesPerDay ?? 0;
    final cycleDays =
        cycleTotal > 0 ? state.daySelection.cycleDays(pagesPerDay) : null;
    final learningDays = _learningProgress
        ?.daysToFinish(state.config?.versesToLearnPerDay ?? 0);
    final body = [
      if (cycleDays != null) S.guideCheckoutCycleBody(cycleDays),
      if (learningDays != null && learningDays > 0)
        S.guideCheckoutLearningBody(learningDays),
    ].join(' ');
    return GuideStep(
      icon: Icons.nightlight_outlined,
      title: S.guideCheckoutTitle,
      body: body.isEmpty ? S.guideCheckoutBody : body,
    );
  }

  Widget _hero(AppPalette palette, bool showPart2) {
    // Titre et badge suivent la même cascade : un seul choix plutôt que deux
    // ternaires jumeaux à garder synchronisés quand un cas s'ajoute.
    final (title, badge) = showPart2
        ? (S.checkOutTitreAujourdhui, S.checkOutPartieOptionnelle)
        : _isMultiDay
            ? (S.checkOutTitreEnAttente, S.checkOutIlYaNJours(_gapDays))
            : _isToday
                ? (S.checkOutTitreCeJour, S.checkOutAujourdhui)
                : (S.checkOutTitreHier, S.checkOutHier);

    return CheckHero(
      eyebrow: _isMultiDay ? S.checkOutRattrapageEyebrow : S.checkOutEyebrow,
      extra: _isMultiDay ? StepDots(count: 2, current: showPart2 ? 1 : 0) : null,
      title: title,
      badge: badge,
    );
  }

  Widget _ctaBar(AppPalette palette, bool showPart2) {
    String label;
    VoidCallback? onPressed;
    if (!_isMultiDay) {
      label = _isToday ? S.cloturerMaJournee : S.checkOutCloturerHier;
      onPressed = _sealing ? null : _close;
    } else if (!showPart2) {
      label = S.checkOutCloturerJour;
      onPressed = () => setState(() => _step = 2);
    } else {
      label = _addToday ? S.checkOutValiderAujourdhui : S.checkOutTerminerSans;
      onPressed = _sealing ? null : _close;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        height: 52,
        child: PrimaryCtaButton(label: label, onPressed: onPressed),
      ),
    );
  }
}
