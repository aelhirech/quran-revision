import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/freshness_engine.dart';
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
import '../widgets/sourate_picker_sheet.dart';
import '../widgets/unit_range_label.dart';
import '../widgets/verse_chip.dart';
import '../widgets/verse_chips_scaffold.dart';

/// « Illuminer ma journée avec le Coran » — le rituel d'ouverture de la
/// journée (Phase 9), poussé depuis l'onglet Plan du jour. Confirme, dans
/// cet ordre, les quatre décisions du jour :
///   1. le rythme de révision (pages/jour) — ajuster régénère la proposition ;
///   2. ce qu'il y a à réviser (lignes `ayah_facts` déjà écrites par le
///      moteur quotidien, `reach=0`) : ajouter/retirer/étendre écrit
///      directement dans la table, il n'y a pas d'objet "plan" à promouvoir ;
///   3. ce qu'il y a à apprendre (sourate + nombre de versets) — récité dans
///      la dernière rakaa du plan ;
///   4. les prières du jour, celles où c'est l'utilisateur qui récite (seul
///      ou en imam).
///
/// Se ferme en renvoyant la liste de prières choisies : c'est l'appelant
/// (`DayPlanTab`) qui déclenche la répartition en rakaas.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  List<RevisionUnit>? _units;
  LearningProgress? _learning;
  RevisionUnit? _learningUnit;
  final Set<Prayer> _prayers = {};
  int _tahiyyatCount = 0;
  List<Prayer>? _lastPrayers;
  bool _isYesterday = false;

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
    await context.read<AppState>().removeFromDayPlan(unit.sourate.id);
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
    // Une seule classification par unité pour tout le build — évite de
    // rappeler FreshnessEngine.computeForRange jusqu'à 3x pour la même unité
    // (liste principale + filtre et rendu de la section "À prioriser").
    final freshnessByUnit = units == null
        ? const <RevisionUnit, FreshnessLevel>{}
        : {
            for (final u in units)
              u: state.freshnessFor(u.sourate.id, u.verseStart, u.verseEnd),
          };

    return Scaffold(
      backgroundColor: palette.cream,
      body: units == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  _hero(units.fold(0, (s, u) => s + u.verseCount)),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      children: [
                        _rhythmSection(palette, state),
                        const SizedBox(height: 22),
                        ..._watchSection(palette, freshnessByUnit, units),
                        _sectionLabel(palette, S.checkInVueDuJour),
                        const SizedBox(height: 8),
                        for (final unit in units)
                          _UnitRow(
                            unit: unit,
                            subtitle:
                                freshnessDiscreetLabel(freshnessByUnit[unit]!),
                            onTap: () => _openDetail(unit),
                            trailingIcon: Icons.close,
                            onTrailing: () => _remove(unit),
                          ),
                        const SizedBox(height: 14),
                        OutlinedActionButton(
                            icon: Icons.add,
                            label: S.checkInAjouterSourate,
                            onTap: _openAddSheet),
                        const SizedBox(height: 22),
                        _learningSection(palette, state),
                        const SizedBox(height: 22),
                        _prayerSection(palette),
                      ],
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
        title: S.checkInTitle,
        badge: S.checkInVersesProposed(totalVerses),
      );

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
                label: S.checkInPagesParJour(p),
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
          // Même carte que les unités de révision (`_UnitRow`) : seuls
          // l'action de fin et le choix du nombre de versets diffèrent.
          _UnitRow(
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

  List<Widget> _watchSection(AppPalette palette,
      Map<RevisionUnit, FreshnessLevel> freshnessByUnit, List<RevisionUnit> units) {
    final watch =
        units.where((u) => freshnessNeedsAttention(freshnessByUnit[u]!)).toList();
    if (watch.isEmpty) return const [];
    return [
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(palette, S.checkInAPrioriser),
            const SizedBox(height: 8),
            for (final u in watch)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(u.sourate.nameFr,
                        style: TextStyle(fontSize: 12.5, color: palette.textPrimary)),
                    Text(freshnessDiscreetLabel(freshnessByUnit[u]!),
                        style: TextStyle(fontSize: 11, color: palette.danger)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
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
    final ready = _effectivePrayers.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!ready)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(S.checkInPrieresManquantes,
                  style: TextStyle(fontSize: 11, color: palette.textMuted)),
            ),
          SizedBox(
            height: 52,
            child: PrimaryCtaButton(
              label: S.checkInLancerPlan,
              icon: Icons.check_rounded,
              // Les ajustements (rythme, ajouts/retraits, apprentissage) sont
              // déjà écrits en direct dans ayah_facts — "Valider" ne fait que
              // rendre les prières à l'appelant, qui répartit en rakaas.
              onPressed:
                  ready ? () => Navigator.of(context).pop(_effectivePrayers) : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'une sourate du check-in — utilisée par la liste de révision
/// (action de fin « × », retirer du jour) et par la carte d'apprentissage
/// (action de fin « échanger », plus un [footer] pour le nombre de versets).
/// Les deux étaient le même Container/Row copié-collé à 200 lignes d'écart.
class _UnitRow extends StatelessWidget {
  final RevisionUnit unit;
  final String subtitle;
  final VoidCallback onTap;
  final IconData trailingIcon;
  final VoidCallback onTrailing;
  final Widget? footer;

  const _UnitRow({
    required this.unit,
    required this.subtitle,
    required this.onTap,
    required this.trailingIcon,
    required this.onTrailing,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: palette.surfaceCardSolid,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _arabicInitial(palette, unit.sourate),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UnitRangeLabel(unit: unit, nameColor: palette.textPrimary),
                        const SizedBox(height: 1),
                        Text(subtitle,
                            style: TextStyle(fontSize: 11, color: palette.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onTrailing,
                    icon: Icon(trailingIcon, size: 16, color: palette.textMuted),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (footer != null) ...[
                const SizedBox(height: 10),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _arabicInitial(AppPalette palette, Sourate s) => Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: palette.gold.withValues(alpha: 0.55), width: 2),
      ),
      child: Text(s.nameAr.characters.first,
          style: GoogleFonts.amiri(fontSize: 16, color: palette.goldDark)),
    );

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
