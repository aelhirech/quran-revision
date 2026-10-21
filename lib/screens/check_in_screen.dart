import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/day_dates.dart';
import '../core/strings.dart';
import '../models/check_in_draft.dart';
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
import '../widgets/step_footer.dart';
import '../widgets/step_transition.dart';
import '../widgets/unit_row.dart';
import '../widgets/verse_range_picker.dart';
import 'check_in_detail_screen.dart';

part 'check_in_sections.dart';

/// « Illuminer ma journée avec le Coran » — le rituel d'ouverture de la
/// journée (Phase 9), poussé depuis l'onglet Plan du jour. Confirme, en
/// 3 étapes (`_step`, cf. `StepDots` dans le hero), les décisions du jour :
///   1. Révision — rythme (pages/jour, ajuster régénère la proposition) et
///      ce qu'il y a à réviser : ajouter/retirer/étendre modifie un
///      brouillon ([CheckInDraft]) ;
///   2. Apprentissage — sourate + nombre de versets, récité dans la dernière
///      rakaa du plan ;
///   3. Prières — celles où l'utilisateur récite (seul ou en imam).
///
/// Validating writes the draft to `ayah_facts` (`AppState.commitCheckIn`),
/// then pops with the chosen prayers: the caller (`DayPlanTab`) spreads the
/// plan across rakaas. Leaving without validating writes nothing to
/// `ayah_facts`, so the day isn't started. The two settings the screen edits
/// (pages/day, verses to learn/day) are saved as soon as they are tapped,
/// like in Settings.
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

  CheckInDraft? _draft;
  bool _saving = false;
  List<RevisionUnit>? get _units => _draft?.units;
  LearningProgress? get _learning => _draft?.learning?.progress;
  RevisionUnit? get _learningUnit => _draft?.learningUnit;
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

  Future<void> _load() async {
    final draft = await context.read<AppState>().checkInStart();
    if (!mounted) return;
    setState(() => _draft = draft);
  }

  Future<void> _loadLastPrayers() async {
    final last =
        await StorageService.loadLastSessionPrayers(context.read<AppState>().riwaya);
    if (!mounted || last == null || last.prayers.isEmpty) return;
    setState(() {
      _lastPrayers = last.prayers;
      _isYesterday = dayKey(last.date) ==
          dayKey(DateTime.now().subtract(const Duration(days: 1)));
    });
  }

  void _remove(RevisionUnit unit) =>
      setState(() => _draft = _draft!.without(unit));

  /// Lets the user pick the precise **portion** of a surah to add to the draft
  /// (`VerseRangePicker`, same pattern as check-out's "revise a surah in
  /// addition", US-3 crit. 1) instead of imposing the whole surah. Closing the
  /// range picker without confirming cancels the addition.
  Future<void> _addSourate(SourateSelection sel) async {
    if (!mounted) return;
    final s = sel.sourate;
    final range = await VerseRangePicker.show(context, sourate: s, current: sel);
    if (range == null || !mounted) return;
    setState(() => _draft = _draft!.adding(RevisionUnit(
        sourate: s,
        verseStart: range.verseStart,
        verseEnd: range.verseEnd,
        isWhole: range.isWhole)));
  }

  Future<void> _openAddSheet() async {
    final state = context.read<AppState>();
    final present = _units!.map((u) => u.sourate.id).toSet();
    final candidates = state.addableSelections(present);
    final picked = await SouratePickerSheet.show(context,
        sourates: [for (final sel in candidates) sel.sourate],
        title: SCheckIn.checkInAjouterSourate);
    if (picked != null) {
      await _addSourate(candidates.firstWhere((sel) => sel.sourate.id == picked.id));
    }
  }

  Future<void> _openDetail(RevisionUnit unit) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CheckInDetailScreen(
        unit: unit,
        onExtend: (from, to) =>
            setState(() => _draft = _draft!.replacing(from, to)),
      ),
    ));
  }

  Future<void> _setPagesPerDay(int pages) async {
    final state = context.read<AppState>();
    await state.setPagesPerDay(pages, rewriteProposal: false);
    if (!mounted) return;
    setState(() => _draft = _draft!.withUnits(state.todayPreviewUnits));
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
    final picked = await SouratePickerSheet.show(context,
        sourates: available, title: SCheckIn.checkInChoisirSourate);
    if (picked == null || !mounted) return;
    await _setLearning(picked,
        state.config?.versesToLearnPerDay ?? defaultVersesToLearnPerDay);
  }

  Future<void> _setLearning(Sourate? sourate, int count) async {
    final learning =
        await context.read<AppState>().learningDraftFor(sourate, count);
    if (!mounted) return;
    setState(() => _draft = _draft!.withLearning(learning));
  }

  Future<void> _validate() async {
    HapticFeedback.mediumImpact();
    final state = context.read<AppState>();
    setState(() => _saving = true);
    try {
      await state.commitCheckIn(_draft!);
      await state.markGuideDone('checkin_done');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.of(context).pop(_effectivePrayers);
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
                    child: StepTransition(
                      step: _step,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        children: _stepChildren(palette, state, units),
                      ),
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
          title: SGuide.guideCheckinStep0Title,
          body: SGuide.guideCheckinStep0Body(_streak, state.pagesProgress.pos),
        );
      case 1:
        return GuideStep(
          icon: Icons.school_outlined,
          title: SGuide.guideCheckinStep1Title,
          body: SGuide.guideCheckinStep1Body,
        );
      default:
        return GuideStep(
          icon: Icons.mosque_outlined,
          title: SGuide.guideCheckinStep2Title,
          body: SGuide.guideCheckinStep2Body,
        );
    }
  }

  Widget _hero(int totalVerses) => CheckHero(
        eyebrow: SCheckIn.checkInEyebrow,
        extra: StepDots(count: _stepCount, current: _step),
        title: SCheckIn.checkInTitle,
        badge: SCheckIn.checkInVersesProposed(totalVerses),
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
    return StepFooter(
      hint: onLastStep && !ready
          ? Text(SCheckIn.checkInPrieresManquantes,
              style: TextStyle(fontSize: 11, color: palette.textMuted))
          : null,
      onBack: _step > 0 ? () => setState(() => _step--) : null,
      primary: onLastStep
          ? PrimaryCtaButton(
              label: SCheckIn.checkInLancerPlan,
              icon: Icons.check_rounded,
              onPressed: ready && !_saving ? _validate : null,
            )
          : PrimaryCtaButton(
              label: SCheckIn.suivant,
              icon: Icons.arrow_forward,
              onPressed: () => setState(() => _step++),
            ),
    );
  }
}
