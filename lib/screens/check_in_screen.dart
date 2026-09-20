import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';
import '../services/ayah_facts_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import '../widgets/check_hero.dart';
import '../widgets/freshness_badge.dart';
import '../widgets/guide_step.dart';
import '../widgets/outlined_action_button.dart';
import '../widgets/pill_chip.dart';
import '../widgets/prayer_selector.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/sourate_picker_sheet.dart';
import '../widgets/step_dots.dart';
import '../widgets/unit_row.dart';
import '../widgets/verse_range_picker.dart';
import 'check_in_detail_screen.dart';

part 'check_in_sections.dart';

/// « Illuminer ma journée avec le Coran » — le rituel d'ouverture de la
/// journée (Phase 9), poussé depuis l'onglet Plan du jour. Confirme, en
/// 3 étapes (`_step`, cf. `StepDots` dans le hero), les décisions du jour :
///   1. Révision — rythme (pages/jour, ajuster régénère la proposition) et
///      ce qu'il y a à réviser (lignes `ayah_facts` déjà écrites par le
///      moteur quotidien, `reach=0`) : ajouter/retirer/étendre écrit
///      directement dans la table, il n'y a pas d'objet "plan" à promouvoir ;
///   2. Apprentissage — sourate + nombre de versets, récité dans la dernière
///      rakaa du plan ;
///   3. Prières — celles où l'utilisateur récite (seul ou en imam).
///
/// Se ferme en renvoyant la liste de prières choisies : c'est l'appelant
/// (`DayPlanTab`) qui déclenche la répartition en rakaas.
///
/// Écran à SECTIONS simultanées (rythme+révision, apprentissage, prières),
/// pas un wizard séquentiel : le découpage en fichiers suit cette logique
/// (contrôleur ici, widgets de section dans `check_in_sections.dart` via
/// `part`/`part of`, sous-écran de détail dans `check_in_detail_screen.dart`)
/// plutôt que le pattern "une page par étape" de l'onboarding.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  static const _stepCount = 3;

  List<RevisionUnit>? _units;
  LearningProgress? _learning;
  RevisionUnit? _learningUnit;
  final Set<Prayer> _prayers = {};
  int _tahiyyatCount = 0;
  List<Prayer>? _lastPrayers;
  bool _isYesterday = false;
  int _step = 0;
  // Guide's "look behind" (crit. 4): streak already loaded by HomeScreen,
  // recomputed here rather than depending on an unrelated screen.
  int _streak = 0;

  // `setState` is `@protected`, not callable from `_CheckInSections` (an
  // extension, not a State subclass member despite sharing this library) —
  // this forwards it instead of scattering `// ignore:` comments there.
  void _setState(VoidCallback fn) => setState(fn);

  /// Liste effective : prières sélectionnées + tahiyyatMasjid répété n fois.
  /// Les doublons sont intentionnels — chaque entrée à la mosquée est une
  /// prière séparée.
  List<Prayer> get _effectivePrayers => [
        ...Prayer.values.where((p) => !p.isTahiyyat && _prayers.contains(p)),
        for (int i = 0; i < _tahiyyatCount; i++) Prayer.tahiyyatMasjid,
      ];

  @override
  void initState() {
    super.initState();
    _load();
    _loadLastPrayers();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final state = context.read<AppState>();
    final streak = await AyahFactsService.currentStreak(
        pauseDates: state.pauseDates, riwaya: state.riwaya);
    if (mounted) setState(() => _streak = streak);
  }

  /// Ce qui change au fil des ajustements de l'écran (unités du jour +
  /// portion à apprendre). La dernière session de prières, elle, ne bouge
  /// pas pendant le check-in : chargée une seule fois ([_loadLastPrayers]),
  /// pas à chaque tap de pastille.
  Future<void> _load() async {
    final state = context.read<AppState>();
    final unitsF = state.dayUnits();
    final learningF = state.learningInProgress();
    final learningUnitF = state.todayLearningUnit();
    final units = await unitsF;
    final learning = await learningF;
    final learningUnit = await learningUnitF;
    if (!mounted) return;
    setState(() {
      _units = units;
      _learning = learning;
      _learningUnit = learningUnit;
    });
  }

  Future<void> _loadLastPrayers() async {
    final last =
        await StorageService.loadLastSessionPrayers(context.read<AppState>().riwaya);
    if (!mounted || last == null || last.prayers.isEmpty) return;
    setState(() {
      _lastPrayers = last.prayers;
      _isYesterday = last.date.toIso8601String().substring(0, 10) ==
          DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String()
              .substring(0, 10);
    });
  }

  Future<void> _remove(RevisionUnit unit) async {
    await context.read<AppState>().removeFromDayPlan(unit.sourate.id,
        verseStart: unit.verseStart, verseEnd: unit.verseEnd);
    await _load();
  }

  /// Adds a surah to the day plan, then lets the user pick the precise
  /// **portion** to revise (`VerseRangePicker`, same pattern as check-out's
  /// "revise a surah in addition", US-3 crit. 1) instead of imposing the
  /// whole surah. Closing the range picker without confirming cancels the
  /// addition.
  Future<void> _addSourate(Sourate s) async {
    if (!mounted) return;
    final range = await showModalBottomSheet<SourateSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          VerseRangePicker(sourate: s, current: SourateSelection.whole(s)),
    );
    if (range == null || !mounted) return;
    await context.read<AppState>().addToDayPlan(RevisionUnit(
        sourate: s,
        verseStart: range.verseStart,
        verseEnd: range.verseEnd,
        isWhole: range.isWhole));
    await _load();
  }

  Future<void> _openAddSheet() async {
    final state = context.read<AppState>();
    final present = _units!.map((u) => u.sourate.id).toSet();
    final candidates = state.sourates.where((s) => !present.contains(s.id)).toList();
    final picked = await showModalBottomSheet<Sourate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SouratePickerSheet(
          sourates: candidates, title: S.checkInAjouterSourate),
    );
    if (picked != null) await _addSourate(picked);
  }

  Future<void> _openDetail(RevisionUnit unit) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CheckInDetailScreen(unit: unit),
    ));
    await _load();
  }

  Future<void> _setPagesPerDay(int pages) async {
    await context.read<AppState>().setPagesPerDay(pages);
    await _load();
  }

  /// Change la sourate en cours d'apprentissage (ou en démarre une). Les
  /// sourates déjà sélectionnées en révision sont exclues du choix — elles
  /// sont, par définition, déjà mémorisées.
  Future<void> _pickLearningSourate() async {
    final state = context.read<AppState>();
    final revised =
        state.config?.selections.map((s) => s.sourate.id).toSet() ?? const {};
    final available =
        state.sourates.where((s) => !revised.contains(s.id)).toList();
    final picked = await showModalBottomSheet<Sourate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SouratePickerSheet(
          sourates: available, title: S.checkInChoisirSourate),
    );
    if (picked == null || !mounted) return;
    await _setLearning(picked,
        state.config?.versesToLearnPerDay ?? defaultVersesToLearnPerDay);
  }

  Future<void> _setLearning(Sourate? sourate, int count) async {
    await context.read<AppState>().setLearningForToday(sourate, count);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final palette = context.palette;
    final units = _units;

    return Scaffold(
      backgroundColor: palette.cream,
      body: units == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  _hero(units.fold(0, (s, u) => s + u.verseCount)),
                  if (!state.guideDone('checkin_done')) _guideStep(state),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      children: _stepChildren(palette, state, units),
                    ),
                  ),
                  _ctaBar(palette),
                ],
              ),
            ),
    );
  }

  /// Step-by-step guidance across the check-in's 3 sections (US-1 crit. 4) —
  /// different content per [_step], only the Revision section carrying the
  /// "look behind" (streak + pages already done). Disappears for good only
  /// once `checkin_done` is marked (on tapping "Validate check-in"), never
  /// from a tap on the card itself.
  Widget _guideStep(AppState state) {
    switch (_step) {
      case 0:
        return GuideStep(
          icon: Icons.wb_sunny_outlined,
          title: S.guideCheckinStep0Title,
          body: S.guideCheckinStep0Body(_streak, state.pagesProgress.pos),
        );
      case 1:
        return GuideStep(
          icon: Icons.school_outlined,
          title: S.guideCheckinStep1Title,
          body: S.guideCheckinStep1Body,
        );
      default:
        return GuideStep(
          icon: Icons.mosque_outlined,
          title: S.guideCheckinStep2Title,
          body: S.guideCheckinStep2Body,
        );
    }
  }

  Widget _hero(int totalVerses) => CheckHero(
        eyebrow: S.checkInEyebrow,
        extra: StepDots(count: _stepCount, current: _step),
        title: S.checkInTitle,
        badge: S.checkInVersesProposed(totalVerses),
      );

  Widget _sectionLabel(AppPalette palette, String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: palette.textMuted),
      );

  Widget _ctaBar(AppPalette palette) {
    final onLastStep = _step == _stepCount - 1;
    final ready = _effectivePrayers.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onLastStep && !ready)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(S.checkInPrieresManquantes,
                  style: TextStyle(fontSize: 11, color: palette.textMuted)),
            ),
          SizedBox(
            height: 54,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedActionButton(
                        icon: Icons.arrow_back,
                        label: S.retour,
                        onTap: () => setState(() => _step--)),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: onLastStep
                      ? PrimaryCtaButton(
                          label: S.checkInLancerPlan,
                          icon: Icons.check_rounded,
                          // Les ajustements (rythme, ajouts/retraits,
                          // apprentissage) sont déjà écrits en direct dans
                          // ayah_facts — "Valider" ne fait que rendre les
                          // prières à l'appelant, qui répartit en rakaas.
                          onPressed: ready
                              ? () {
                                  context
                                      .read<AppState>()
                                      .markGuideDone('checkin_done');
                                  Navigator.of(context).pop(_effectivePrayers);
                                }
                              : null,
                        )
                      : PrimaryCtaButton(
                          label: S.suivant,
                          icon: Icons.arrow_forward,
                          onPressed: () => setState(() => _step++),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
