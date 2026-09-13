import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/sourate.dart';
import '../models/user_config.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import '../widgets/check_hero.dart';
import '../widgets/freshness_badge.dart';
import '../widgets/outlined_action_button.dart';
import '../widgets/pill_chip.dart';
import '../widgets/prayer_selector.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/hook_banner.dart';
import '../widgets/sourate_picker_sheet.dart';
import '../widgets/step_dots.dart';
import '../widgets/unit_row.dart';
import '../widgets/verse_chip.dart';
import '../widgets/verse_chips_scaffold.dart';

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
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> with HookVisibilityMixin {
  static const _stepCount = 3;

  List<RevisionUnit>? _units;
  LearningProgress? _learning;
  RevisionUnit? _learningUnit;
  final Set<Prayer> _prayers = {};
  int _tahiyyatCount = 0;
  List<Prayer>? _lastPrayers;
  bool _isYesterday = false;
  int _step = 0;

  @override
  String get hookId => 'check_in';

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
    loadHook();
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

  Future<void> _addSourate(Sourate s) async {
    await context.read<AppState>().addToDayPlan(
        RevisionUnit(sourate: s, verseStart: 1, verseEnd: s.verses, isWhole: true));
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
      builder: (_) => _CheckInDetailScreen(unit: unit),
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
                  if (showHook)
                    HookBanner(
                      icon: Icons.wb_sunny_outlined,
                      title: S.hookCheckInTitle,
                      body: S.hookCheckInBody,
                      onDismiss: dismissHook,
                    ),
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

  Widget _hero(int totalVerses) => CheckHero(
        eyebrow: S.checkInEyebrow,
        extra: StepDots(count: _stepCount, current: _step),
        title: S.checkInTitle,
        badge: S.checkInVersesProposed(totalVerses),
      );

  // Freshness classification computed only in case 0, the only step reading it.
  List<Widget> _stepChildren(
      AppPalette palette, AppState state, List<RevisionUnit> units) {
    switch (_step) {
      case 0:
        final freshnessByUnit = {
          for (final u in units)
            u: state.freshnessFor(u.sourate.id, u.verseStart, u.verseEnd),
        };
        return [
          _rhythmSection(palette, state),
          const SizedBox(height: 22),
          _sectionLabel(palette, S.checkInVueDuJour),
          const SizedBox(height: 8),
          for (final unit in units)
            UnitRow(
              unit: unit,
              subtitle: freshnessDiscreetLabel(freshnessByUnit[unit]!),
              onTap: () => _openDetail(unit),
              trailingIcon: Icons.close,
              onTrailing: () => _remove(unit),
            ),
          const SizedBox(height: 14),
          OutlinedActionButton(
              icon: Icons.add,
              label: S.checkInAjouterSourate,
              onTap: _openAddSheet),
        ];
      case 1:
        return [_learningSection(palette, state)];
      case 2:
      default: // _step is a plain int, never statically exhaustive
        return [_prayerSection(palette)];
    }
  }

  Widget _rhythmSection(AppPalette palette, AppState state) {
    final current = state.config?.pagesPerDay ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(palette, S.checkInRythme),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in pagesPerDayPresets)
              PillChip(
                label: S.pagesParJour(p),
                selected: p == current,
                onTap: () => _setPagesPerDay(p),
              ),
          ],
        ),
      ],
    );
  }

  Widget _learningSection(AppPalette palette, AppState state) {
    final learningUnit = _learningUnit;
    final count =
        state.config?.versesToLearnPerDay ?? defaultVersesToLearnPerDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(palette, S.checkInApprentissage),
        const SizedBox(height: 8),
        if (learningUnit == null)
          OutlinedActionButton(
              icon: Icons.school_outlined,
              label: S.checkInChoisirSourate,
              onTap: _pickLearningSourate)
        else ...[
          // Même carte que les unités de révision (`UnitRow`) : seuls
          // l'action de fin et le choix du nombre de versets diffèrent.
          UnitRow(
            unit: learningUnit,
            subtitle: _learning == null
                ? S.checkInApprentissageDesc
                : '${_learning!.learnedCount}/${_learning!.totalVerses} ${S.versets}',
            trailingIcon: Icons.swap_horiz,
            onTrailing: _pickLearningSourate,
            onTap: _pickLearningSourate,
            footer: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in versesToLearnPresets)
                  PillChip(
                    label: S.checkInVersetsAApprendre(n),
                    selected: n == count,
                    onTap: () => _setLearning(learningUnit.sourate, n),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _setLearning(null, count),
            child: Text(S.checkInAucunApprentissage,
                style: TextStyle(fontSize: 12, color: palette.textMuted)),
          ),
        ],
      ],
    );
  }

  Widget _prayerSection(AppPalette palette) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel(palette, S.checkInPrieres),
              if (_lastPrayers != null)
                TextButton.icon(
                  onPressed: _applyLastPrayers,
                  icon: const Icon(Icons.history, size: 16),
                  label: Text(_isYesterday ? S.commeHier : S.derniereSelection,
                      style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          Text(S.checkInPrieresDesc,
              style: TextStyle(fontSize: 11, color: palette.textMuted)),
          const SizedBox(height: 10),
          PrayerSelector(
            selected: _prayers,
            onToggle: (p) => setState(() {
              _prayers.contains(p) ? _prayers.remove(p) : _prayers.add(p);
            }),
            tahiyyatCount: _tahiyyatCount,
            onTahiyyatCountChanged: (n) => setState(() => _tahiyyatCount = n),
          ),
        ],
      );

  void _applyLastPrayers() {
    if (_lastPrayers == null) return;
    // tahiyyatMasjid peut apparaître plusieurs fois — on compte les occurrences
    final tahiyyat = _lastPrayers!.where((p) => p.isTahiyyat).length;
    final others = _lastPrayers!.where((p) => !p.isTahiyyat).toSet();
    setState(() {
      _prayers
        ..clear()
        ..addAll(others);
      _tahiyyatCount = tahiyyat;
    });
  }

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
                              ? () => Navigator.of(context).pop(_effectivePrayers)
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

class _CheckInDetailScreen extends StatefulWidget {
  final RevisionUnit unit;
  const _CheckInDetailScreen({required this.unit});

  @override
  State<_CheckInDetailScreen> createState() => _CheckInDetailScreenState();
}

class _CheckInDetailScreenState extends State<_CheckInDetailScreen> {
  late RevisionUnit _unit;
  bool _extending = false;

  @override
  void initState() {
    super.initState();
    _unit = widget.unit;
  }

  Future<void> _extend() async {
    if (_extending) return; // évite un double-tap qui étendrait de 2 versets
    final next = _unit.verseEnd + 1;
    if (next > _unit.sourate.verses) return;
    setState(() => _extending = true);
    await context.read<AppState>().extendDayPlanVerse(_unit.sourate.id, next);
    if (!mounted) return;
    setState(() {
      _extending = false;
      _unit = RevisionUnit(
          sourate: _unit.sourate,
          verseStart: _unit.verseStart,
          verseEnd: next,
          isWhole: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return VerseChipsScaffold(
      title: '${_unit.sourate.nameFr} · v.${_unit.verseStart}–${_unit.verseEnd}',
      headerLabel: S.checkInVersetsInclus,
      chips: [
        for (int v = _unit.verseStart; v <= _unit.verseEnd; v++)
          VerseChip(
            borderColor: palette.cardBorder,
            child: Text('$v', style: TextStyle(fontSize: 11, color: palette.textMuted)),
          ),
        if (_unit.verseEnd < _unit.sourate.verses)
          VerseChip(
            borderColor: palette.gold.withValues(alpha: 0.7),
            onTap: _extend,
            child: Icon(Icons.add, size: 14, color: palette.textPrimary),
          ),
      ],
      footer: Text(S.checkInExtendHint,
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: palette.textMuted)),
    );
  }
}
