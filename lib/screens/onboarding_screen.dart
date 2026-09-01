import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/riwaya.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';
import '../services/hizb_metadata_service.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../widgets/index_badge.dart';
import '../widgets/ornamental_divider.dart';
import '../widgets/pill_chip.dart';
import '../widgets/preset_dropdown.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/verse_range_picker.dart';

/// Nombre d'étapes comptées dans le stepper (`_StepHeader`) — Intro/Riwaya
/// n'y figurent pas (pages d'accueil, pas de config), Célébration non plus
/// (aboutissement, poussé hors du PageView).
const int _kOnboardingSteps = 4;

class OnboardingScreen extends StatefulWidget {
  /// Non-null quand l'utilisateur bascule vers un parcours (riwaya) jamais
  /// configuré — la riwaya est déjà décidée, l'assistant saute directement
  /// à la sélection des sourates (pas d'intro, pas de choix de riwaya).
  final Riwaya? presetRiwaya;

  const OnboardingScreen({super.key, this.presetRiwaya});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  final Map<int, SourateSelection> _selections = {};
  int _revisionDays = 30;
  bool _paceByLines = false;
  int _targetLinesPerDay = 15;
  bool _groupByHizb = true;
  String _search = '';
  late Riwaya _riwaya = widget.presetRiwaya ?? Riwaya.hafs;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _totalVerses =>
      _selections.values.fold(0, (sum, s) => sum + s.verseCount);

  /// Fraction (1.0/0.75/0.5/0.25) dont la sélection actuelle est
  /// structurellement identique à ce que produirait un tap sur la pill
  /// correspondante — dérivé de `_selections`, pas suivi manuellement (pas
  /// de flag à invalider à chaque site de mutation).
  double? get _lastQuickFraction {
    // Une plage partielle (long-press → VerseRangePicker) ne peut jamais
    // correspondre à un preset — tous les presets sélectionnent des
    // sourates entières. Court-circuite avant la comparaison par id.
    if (_selections.values.any((sel) => !sel.isWhole)) return null;
    final allSourates = context.read<AppState>().sourates;
    final currentIds = _selections.keys.toSet();
    for (final fraction in const [1.0, 0.75, 0.5, 0.25]) {
      if (setEquals(currentIds, _quickSelectionIds(fraction, allSourates))) {
        return fraction;
      }
    }
    return null;
  }

  /// Ids des sourates que sélectionnerait `_quickSelect(fraction)`, sans
  /// muter l'état — sert à la fois à l'appliquer et à détecter si la
  /// sélection actuelle y correspond déjà.
  Set<int> _quickSelectionIds(double fraction, List<Sourate> allSourates) {
    if (fraction >= 1.0) return allSourates.map((s) => s.id).toSet();
    final total = allSourates.fold(0, (sum, s) => sum + s.verses);
    final target = (total * fraction).round();
    final ids = <int>{};
    int count = 0;
    for (final s in allSourates.reversed) {
      if (count >= target) break;
      ids.add(s.id);
      count += s.verses;
    }
    return ids;
  }

  List<Object> get _listItems {
    final allSourates = context.read<AppState>().sourates;
    final sourates = allSourates
        .where((s) =>
            _search.isEmpty ||
            s.nameFr.toLowerCase().contains(_search.toLowerCase()) ||
            s.nameAr.contains(_search) ||
            s.id.toString() == _search)
        .toList();
    if (_search.isNotEmpty || !_groupByHizb) return sourates;
    return _groupedBy(
        sourates, (s) => HizbMetadataService.surahStartHizb[s.id] ?? 1);
  }

  List<Object> _groupedBy(List<Sourate> sourates, int Function(Sourate) key) {
    final result = <Object>[];
    int? currentGroup;
    for (final s in sourates) {
      final group = key(s);
      if (group != currentGroup) {
        currentGroup = group;
        result.add(group);
      }
      result.add(s);
    }
    return result;
  }

  void _toggleSourate(Sourate s) {
    setState(() {
      if (_selections.containsKey(s.id)) {
        _selections.remove(s.id);
      } else {
        _selections[s.id] = SourateSelection.whole(s);
      }
    });
  }

  Future<void> _longPressSourate(Sourate s) async {
    final wasSelected = _selections.containsKey(s.id);
    if (!wasSelected) {
      setState(() => _selections[s.id] = SourateSelection.whole(s));
    }
    final result = await showModalBottomSheet<SourateSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerseRangePicker(sourate: s, current: _selections[s.id]!),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => _selections[s.id] = result);
    } else if (!wasSelected) {
      // Feuille fermée sans confirmer : annule la présélection faite pour
      // pouvoir l'ouvrir, sinon la sourate reste cochée par accident.
      setState(() => _selections.remove(s.id));
    }
  }

  /// Sélectionne [fraction] du Coran depuis la FIN (ordre de mémorisation
  /// courant) — même forme de boucle que `_quickSelectionIds` (qui, lui,
  /// ne fait que comparer un id-set), mais construit `_selections`
  /// directement en un seul passage plutôt que de dériver deux fois la
  /// même liste.
  void _quickSelect(double fraction) {
    final allSourates = context.read<AppState>().sourates;
    setState(() {
      _selections.clear();
      if (fraction >= 1.0) {
        for (final s in allSourates) {
          _selections[s.id] = SourateSelection.whole(s);
        }
      } else {
        final total = allSourates.fold(0, (sum, s) => sum + s.verses);
        final target = (total * fraction).round();
        int count = 0;
        for (final s in allSourates.reversed) {
          if (count >= target) break;
          _selections[s.id] = SourateSelection.whole(s);
          count += s.verses;
        }
      }
    });
    HapticFeedback.selectionClick();
  }

  void _nextPage() {
    _pageController.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _prevPage() {
    _pageController.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  /// Choix de riwaya (première page, seulement quand presetRiwaya est null) —
  /// bascule AppState immédiatement pour que la page de sélection suivante
  /// affiche les bons comptes de versets/mots.
  Future<void> _confirmRiwaya(Riwaya riwaya) async {
    final ok = await context.read<AppState>().setRiwaya(riwaya);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.warshUnavailable)));
      return;
    }
    setState(() => _riwaya = riwaya);
    _nextPage();
  }

  Future<void> _confirm() async {
    if (_selections.isEmpty) return;
    final config = UserConfig(
      selections: _selections.values.toList(),
      revisionDays: _revisionDays,
      startDate: DateTime.now(),
      paceByLines: _paceByLines,
      targetLinesPerDay: _targetLinesPerDay,
      riwaya: _riwaya,
    );
    await context.read<AppState>().saveConfig(config);
  }

  /// Pousse l'écran de célébration AVANT de persister la config — la config
  /// n'est sauvée qu'au tap sur le CTA final de cet écran (`_confirm`, passé
  /// en `onStart`). Une route poussée reste au-dessus de la pile de
  /// Navigator même quand `main.dart` bascule `MaterialApp.home` vers
  /// `ShellScreen` en dessous (même mécanisme que `CheckInScreen`/
  /// `CheckOutScreen`, poussés en plein écran depuis `DayPlanTab`) — pousser
  /// avant de persister élimine toute course entre les deux.
  Future<void> _showCelebration() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CelebrationPage(
          selections: _selections,
          totalVerses: _totalVerses,
          onStart: _confirm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showIntroAndRiwaya = widget.presetRiwaya == null;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          if (showIntroAndRiwaya) _IntroPage(onNext: _nextPage),
          if (showIntroAndRiwaya) _RiwayaPage(onSelect: _confirmRiwaya),
          _SelectionPage(
            selections: _selections,
            totalVerses: _totalVerses,
            groupByHizb: _groupByHizb,
            search: _search,
            listItems: _listItems,
            lastQuickFraction: _lastQuickFraction,
            onQuickSelect: _quickSelect,
            onToggleSourate: _toggleSourate,
            onLongPress: _longPressSourate,
            onGroupByHizbChanged: (v) => setState(() => _groupByHizb = v),
            onSearchChanged: (v) => setState(() => _search = v),
            onNext: _selections.isEmpty ? null : _nextPage,
          ),
          _RhythmPage(
            revisionDays: _revisionDays,
            onRevisionDaysChanged: (v) => setState(() => _revisionDays = v),
            paceByLines: _paceByLines,
            onPaceByLinesChanged: (v) => setState(() => _paceByLines = v),
            targetLinesPerDay: _targetLinesPerDay,
            onTargetLinesPerDayChanged: (v) =>
                setState(() => _targetLinesPerDay = v),
            onBack: _prevPage,
            onNext: _nextPage,
          ),
          _NotificationsPage(onBack: _prevPage, onNext: _nextPage),
          _RecapPage(
            selections: _selections,
            totalVerses: _totalVerses,
            onBack: _prevPage,
            onConfirm: _selections.isEmpty ? null : _showCelebration,
          ),
        ],
      ),
    );
  }
}

// ─── Page 0 : Intro ──────────────────────────────────────────────────────────

class _IntroPage extends StatelessWidget {
  final VoidCallback onNext;
  const _IntroPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            Text(
              S.bismillah,
              style: GoogleFonts.amiri(fontSize: 22, color: palette.gold),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 26),
            Text(
              S.introTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
                height: 1.25,
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.08),
            const SizedBox(height: 16),
            const OrnamentalDivider(),
            const SizedBox(height: 24),
            Text(
              S.introLine1,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15.5,
                  fontStyle: FontStyle.italic,
                  color: palette.textPrimary.withValues(alpha: 0.7),
                  height: 1.7),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 14),
            Text(
              S.introLine2,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15.5,
                  fontStyle: FontStyle.italic,
                  color: palette.textPrimary.withValues(alpha: 0.7),
                  height: 1.7),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const Spacer(flex: 4),
            SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(label: S.introAction, onPressed: onNext),
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Page : Choix de riwaya ──────────────────────────────────────────────────

class _RiwayaPage extends StatelessWidget {
  final void Function(Riwaya) onSelect;
  const _RiwayaPage({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Text(
              S.choisirRiwayaTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
                height: 1.25,
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
            const SizedBox(height: 12),
            Text(
              S.choisirRiwayaSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: palette.textPrimary.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            const SizedBox(height: 32),
            _RiwayaChoiceCard(
              label: S.hafs,
              description: S.hafsDescription,
              onTap: () => onSelect(Riwaya.hafs),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 14),
            _RiwayaChoiceCard(
              label: S.warsh,
              description: S.warshDescription,
              onTap: () => onSelect(Riwaya.warsh),
            ).animate().fadeIn(delay: 280.ms, duration: 400.ms).slideY(begin: 0.1),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

class _RiwayaChoiceCard extends StatelessWidget {
  final String label;
  final String description;
  final VoidCallback onTap;

  const _RiwayaChoiceCard({
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary)),
            const SizedBox(height: 6),
            Text(description,
                style: TextStyle(fontSize: 13, color: palette.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─── Page 1 : Sélection sourates ─────────────────────────────────────────────

class _SelectionPage extends StatelessWidget {
  final Map<int, SourateSelection> selections;
  final int totalVerses;
  final bool groupByHizb;
  final String search;
  final List<Object> listItems;
  final double? lastQuickFraction;
  final void Function(double fraction) onQuickSelect;
  final void Function(Sourate) onToggleSourate;
  final Future<void> Function(Sourate) onLongPress;
  final ValueChanged<bool> onGroupByHizbChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onNext;

  const _SelectionPage({
    required this.selections,
    required this.totalVerses,
    required this.groupByHizb,
    required this.search,
    required this.listItems,
    required this.lastQuickFraction,
    required this.onQuickSelect,
    required this.onToggleSourate,
    required this.onLongPress,
    required this.onGroupByHizbChanged,
    required this.onSearchChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          _StepHeader(
            step: 1,
            total: _kOnboardingSteps,
            title: S.etapeSelection,
            subtitle: S.souratesCount(selections.length, totalVerses),
          ),
          // Boutons de sélection rapide
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.selectionRapide,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    PillChip(
                      label: S.toutLeCoran,
                      onTap: () => onQuickSelect(1.0),
                      selected: lastQuickFraction == 1.0,
                    ),
                    const SizedBox(width: 6),
                    PillChip(
                      label: S.fractionTroisQuarts,
                      onTap: () => onQuickSelect(0.75),
                      selected: lastQuickFraction == 0.75,
                    ),
                    const SizedBox(width: 6),
                    PillChip(
                      label: S.fractionMoitie,
                      onTap: () => onQuickSelect(0.5),
                      selected: lastQuickFraction == 0.5,
                    ),
                    const SizedBox(width: 6),
                    PillChip(
                      label: S.fractionQuart,
                      onTap: () => onQuickSelect(0.25),
                      selected: lastQuickFraction == 0.25,
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.08),
          // Recherche + groupement
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: S.rechercherSourate,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      isDense: true,
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
                const SizedBox(width: 8),
                _GroupToggle(
                  icon: Icons.menu_book_outlined,
                  label: S.hizbCourt,
                  value: groupByHizb,
                  onChanged: onGroupByHizbChanged,
                ),
              ],
            ),
          ),
          // Liste (sticky headers Hizb)
          Expanded(
            child: _SourateList(
              items: listItems,
              selections: selections,
              onToggle: onToggleSourate,
              onLongPress: onLongPress,
            ).animate().fadeIn(duration: 300.ms),
          ),
          // Bouton suivant
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onNext,
                child: Text(
                  onNext == null ? S.selectSourates : S.continuer,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 2 : Rythme / objectif ──────────────────────────────────────────────

class _RhythmPage extends StatelessWidget {
  final int revisionDays;
  final ValueChanged<int> onRevisionDaysChanged;
  final bool paceByLines;
  final ValueChanged<bool> onPaceByLinesChanged;
  final int targetLinesPerDay;
  final ValueChanged<int> onTargetLinesPerDayChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _RhythmPage({
    required this.revisionDays,
    required this.onRevisionDaysChanged,
    required this.paceByLines,
    required this.onPaceByLinesChanged,
    required this.targetLinesPerDay,
    required this.onTargetLinesPerDayChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeader(
              step: 2,
              total: _kOnboardingSteps,
              title: S.etapeRythme,
              subtitle: S.rythmeQuestion,
              onBack: onBack,
            ),
            const SizedBox(height: 24),
            if (!paceByLines) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PillChip(
                    label: S.rythmeTranquille,
                    selected: revisionDays == 90,
                    onTap: () => onRevisionDaysChanged(90),
                  ),
                  PillChip(
                    label: S.rythmeRegulier,
                    selected: revisionDays == 30,
                    onTap: () => onRevisionDaysChanged(30),
                  ),
                  PillChip(
                    label: S.rythmeIntensif,
                    selected: revisionDays == 14,
                    onTap: () => onRevisionDaysChanged(14),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06),
              const SizedBox(height: 16),
            ],
            _RecapCard(
              icon: Icons.calendar_today_outlined,
              label: S.cycleObjectif,
              trailing: paceByLines
                  ? PresetDropdown(
                      value: targetLinesPerDay,
                      presets: linesPerDayPresets,
                      labelBuilder: S.lignesParJourValeur,
                      customDialogTitle: S.lignesCustomTitle,
                      customSuffix: S.lignesSuffix,
                      color: cs.onSurface,
                      onChanged: onTargetLinesPerDayChanged,
                    )
                  : PresetDropdown(
                      value: revisionDays,
                      presets: durationPresets,
                      labelBuilder: S.joursDuration,
                      customDialogTitle: S.dureeCustomTitle,
                      customSuffix: S.joursSuffix,
                      color: cs.onSurface,
                      onChanged: onRevisionDaysChanged,
                    ),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(S.rythmeParDuree)),
                  ButtonSegment(value: true, label: Text(S.rythmeParLignes)),
                ],
                selected: {paceByLines},
                onSelectionChanged: (s) => onPaceByLinesChanged(s.first),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(label: S.continuer, onPressed: onNext),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Page 3 : Rappels (priming permission notifications) ────────────────────

class _NotificationsPage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _NotificationsPage({required this.onBack, required this.onNext});

  @override
  State<_NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<_NotificationsPage> {
  bool _working = false;

  Future<void> _enable() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await NotificationService.enable();
    } finally {
      if (mounted) setState(() => _working = false);
    }
    if (!mounted) return;
    widget.onNext();
  }

  Future<void> _skip() async {
    await NotificationService.disable();
    if (!mounted) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StepHeader(
              step: 3,
              total: _kOnboardingSteps,
              title: S.etapeRappels,
              onBack: widget.onBack,
            ),
            const Spacer(flex: 2),
            Icon(Icons.notifications_active_outlined, size: 64, color: palette.gold)
                .animate()
                .scale(
                    begin: const Offset(0.6, 0.6),
                    duration: 400.ms,
                    curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Text(
              S.rappelsTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 12),
            Text(
              S.rappelsBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: palette.textPrimary.withValues(alpha: 0.7),
                  height: 1.5),
            ).animate().fadeIn(delay: 180.ms, duration: 300.ms),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(
                label: S.activerRappels,
                onPressed: _working ? null : _enable,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _working ? null : _skip,
              child: Text(S.plusTard, style: TextStyle(color: palette.textMuted)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Page 4 : Récap ──────────────────────────────────────────────────────────

class _RecapPage extends StatelessWidget {
  final Map<int, SourateSelection> selections;
  final int totalVerses;
  final VoidCallback onBack;
  final VoidCallback? onConfirm;

  const _RecapPage({
    required this.selections,
    required this.totalVerses,
    required this.onBack,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeader(
              step: 4,
              total: _kOnboardingSteps,
              title: S.etapeRecap,
              onBack: onBack,
            ),
            const SizedBox(height: 24),
            const OrnamentalDivider(),
            const SizedBox(height: 24),
            // Récap sélection
            _RecapCard(
              icon: Icons.menu_book_outlined,
              label: S.souratesCount(selections.length, totalVerses),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(label: S.commencer, onPressed: onConfirm),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Écran de célébration (poussé, pas une page du PageView) ────────────────

class _CelebrationPage extends StatefulWidget {
  final Map<int, SourateSelection> selections;
  final int totalVerses;
  final Future<void> Function() onStart;

  const _CelebrationPage({
    required this.selections,
    required this.totalVerses,
    required this.onStart,
  });

  @override
  State<_CelebrationPage> createState() => _CelebrationPageState();
}

class _CelebrationPageState extends State<_CelebrationPage> {
  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await widget.onStart();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopScope(
      canPop: !_starting,
      child: Scaffold(
        backgroundColor: palette.cream,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                const Text('✨', style: TextStyle(fontSize: 56))
                    .animate()
                    .scale(
                        begin: const Offset(0.3, 0.3),
                        duration: 600.ms,
                        curve: Curves.elasticOut)
                    .then()
                    .shimmer(duration: 800.ms),
                const SizedBox(height: 20),
                Text(
                  S.bienvenueTitre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 12),
                Text(
                  S.bienvenueSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: palette.textPrimary.withValues(alpha: 0.7),
                      height: 1.6),
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                const SizedBox(height: 28),
                const OrnamentalDivider(),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: palette.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.gold.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    S.souratesCount(widget.selections.length, widget.totalVerses),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.goldDark),
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.15),
                const Spacer(flex: 4),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryCtaButton(
                    label: S.continuer,
                    onPressed: _starting ? null : _start,
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Widgets internes ─────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  const _StepHeader({
    required this.step,
    required this.total,
    required this.title,
    this.subtitle,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: cs.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer)),
              ),
              Text(S.etapeN(step, total),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                subtitle!,
                key: ValueKey(subtitle),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8)),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: step / total,
              backgroundColor:
                  cs.onPrimaryContainer.withValues(alpha: 0.2),
              color: context.palette.gold,
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _GroupToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: value ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: value ? cs.primary : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: value ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: value ? cs.primary : cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Segment de la liste des sourates : `header` non-null = groupe Hizb
/// (rendu en en-tête épinglé), `header == null` = liste plate (recherche
/// active ou groupement désactivé).
class _Section {
  final int? header;
  final List<Sourate> entries;
  const _Section(this.header, this.entries);
}

List<_Section> _sectionize(List<Object> items) {
  final sections = <_Section>[];
  int? currentHeader;
  var currentEntries = <Sourate>[];
  void flush() {
    if (currentHeader != null || currentEntries.isNotEmpty) {
      sections.add(_Section(currentHeader, currentEntries));
    }
  }

  for (final item in items) {
    if (item is int) {
      flush();
      currentHeader = item;
      currentEntries = <Sourate>[];
    } else {
      currentEntries.add(item as Sourate);
    }
  }
  flush();
  return sections;
}

class _SourateList extends StatelessWidget {
  final List<Object> items;
  final Map<int, SourateSelection> selections;
  final void Function(Sourate) onToggle;
  final Future<void> Function(Sourate) onLongPress;

  const _SourateList({
    required this.items,
    required this.selections,
    required this.onToggle,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sections = _sectionize(items);
    return CustomScrollView(
      slivers: [
        for (final section in sections) ...[
          if (section.header != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: _HizbHeaderDelegate(
                label: S.hizb(section.header!),
                palette: palette,
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _tile(palette, section.entries[i]),
              childCount: section.entries.length,
            ),
          ),
        ],
      ],
    );
  }

  Widget _tile(AppPalette palette, Sourate s) {
    final sel = selections[s.id];
    final selected = sel != null;
    return GestureDetector(
      onLongPress: () => onLongPress(s),
      child: CheckboxListTile(
        value: selected,
        onChanged: (_) {
          HapticFeedback.selectionClick();
          onToggle(s);
        },
        dense: true,
        title: Row(
          children: [
            Text(s.nameFr,
                style: TextStyle(fontSize: 14, color: palette.textPrimary)),
            if (sel != null && !sel.isWhole) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: palette.gold.withValues(alpha: 0.6)),
                ),
                child: Text('v.${sel.verseStart}–${sel.verseEnd}',
                    style: TextStyle(fontSize: 10, color: palette.goldDark)),
              ),
            ],
          ],
        ),
        subtitle: Text(
            '${sel != null && !sel.isWhole ? '${sel.verseCount}/${s.verses}' : s.verses} ${S.versetsLabel}',
            style: TextStyle(fontSize: 12, color: palette.textMuted)),
        secondary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: IndexBadge(
                text: '${s.id}',
                size: 30,
                state: selected ? IndexBadgeState.selected : IndexBadgeState.unselected,
              ),
            ),
            const SizedBox(width: 10),
            Text(s.nameAr, style: GoogleFonts.amiri(fontSize: 18, color: palette.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _HizbHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;
  final AppPalette palette;

  const _HizbHeaderDelegate({required this.label, required this.palette});

  @override
  double get minExtent => 28;
  @override
  double get maxExtent => 28;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Color.alphaBlend(palette.gold.withValues(alpha: 0.14), palette.cream),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      // FittedBox : l'en-tête épinglé a une hauteur fixe (minExtent/maxExtent
      // ci-dessus) — sans ça, un réglage d'accessibilité "texte agrandi"
      // ferait déborder le label hors de sa bande.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.goldDark,
                letterSpacing: 0.8)),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HizbHeaderDelegate oldDelegate) =>
      label != oldDelegate.label || palette != oldDelegate.palette;
}

class _RecapCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;

  const _RecapCard({required this.icon, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
