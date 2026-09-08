import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/strings.dart';
import '../../models/riwaya.dart';
import '../../models/sourate.dart';
import '../../models/sourate_selection.dart';
import '../../models/user_config.dart';
import '../../services/hizb_metadata_service.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import '../../widgets/index_badge.dart';
import '../../widgets/ornamental_divider.dart';
import '../../widgets/pill_chip.dart';
import '../../widgets/preset_dropdown.dart';
import '../../widgets/primary_cta_button.dart';
import '../../widgets/verse_range_picker.dart';

part 'steps/intro_page.dart';
part 'steps/riwaya_page.dart';
part 'steps/selection_page.dart';
part 'steps/rhythm_page.dart';
part 'steps/notifications_page.dart';
part 'steps/recap_page.dart';
part 'steps/celebration_page.dart';
part 'widgets/step_header.dart';
part 'widgets/group_toggle.dart';
part 'widgets/sourate_list.dart';
part 'widgets/recap_card.dart';

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
  int _pagesPerDay = 1;
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
      pagesPerDay: _pagesPerDay,
      startDate: DateTime.now(),
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
            pagesPerDay: _pagesPerDay,
            onPagesPerDayChanged: (v) => setState(() => _pagesPerDay = v),
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
