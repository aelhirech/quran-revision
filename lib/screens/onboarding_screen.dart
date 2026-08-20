import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/quran_data.dart';
import '../core/strings.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';
import '../state/app_state.dart';
import '../widgets/index_badge.dart';
import '../widgets/ornamental_divider.dart';
import '../widgets/pill_chip.dart';
import '../widgets/preset_dropdown.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/verse_range_picker.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  final Map<int, SourateSelection> _selections = {};
  int _revisionDays = 30;
  bool _paceByLines = false;
  int _targetLinesPerDay = 15;
  bool _groupByHizb = false;
  String _search = '';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _totalVerses =>
      _selections.values.fold(0, (sum, s) => sum + s.verseCount);

  List<Object> get _listItems {
    final sourates = allSourates
        .where((s) =>
            _search.isEmpty ||
            s.nameFr.toLowerCase().contains(_search.toLowerCase()) ||
            s.nameAr.contains(_search) ||
            s.id.toString() == _search)
        .toList();
    if (_search.isNotEmpty || !_groupByHizb) return sourates;
    return _groupedBy(sourates, (s) => sourateHizbMap[s.id] ?? 1);
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
    if (!_selections.containsKey(s.id)) {
      setState(() => _selections[s.id] = SourateSelection.whole(s));
    }
    final result = await showModalBottomSheet<SourateSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerseRangePicker(sourate: s, current: _selections[s.id]!),
    );
    if (!mounted) return;
    if (result != null) setState(() => _selections[s.id] = result);
  }

  /// Sélectionne [fraction] du Coran depuis la FIN (ordre de mémorisation courant).
  void _quickSelect(double fraction) {
    setState(() {
      _selections.clear();
      if (fraction >= 1.0) {
        for (final s in allSourates) {
          _selections[s.id] = SourateSelection.whole(s);
        }
        return;
      }
      final total = allSourates.fold(0, (sum, s) => sum + s.verses);
      final target = (total * fraction).round();
      int count = 0;
      for (final s in allSourates.reversed) {
        if (count >= target) break;
        _selections[s.id] = SourateSelection.whole(s);
        count += s.verses;
      }
    });
  }

  void _nextPage() {
    _pageController.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _prevPage() {
    _pageController.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _confirm() async {
    if (_selections.isEmpty) return;
    final config = UserConfig(
      selections: _selections.values.toList(),
      revisionDays: _revisionDays,
      startDate: DateTime.now(),
      paceByLines: _paceByLines,
      targetLinesPerDay: _targetLinesPerDay,
    );
    await context.read<AppState>().saveConfig(config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _IntroPage(onNext: _nextPage),
          _SelectionPage(
            selections: _selections,
            totalVerses: _totalVerses,
            groupByHizb: _groupByHizb,
            search: _search,
            listItems: _listItems,
            onQuickSelect: _quickSelect,
            onToggleSourate: _toggleSourate,
            onLongPress: _longPressSourate,
            onGroupByHizbChanged: (v) => setState(() => _groupByHizb = v),
            onSearchChanged: (v) => setState(() => _search = v),
            onNext: _selections.isEmpty ? null : _nextPage,
          ),
          _RecapPage(
            selections: _selections,
            totalVerses: _totalVerses,
            revisionDays: _revisionDays,
            onRevisionDaysChanged: (v) => setState(() => _revisionDays = v),
            paceByLines: _paceByLines,
            onPaceByLinesChanged: (v) => setState(() => _paceByLines = v),
            targetLinesPerDay: _targetLinesPerDay,
            onTargetLinesPerDayChanged: (v) =>
                setState(() => _targetLinesPerDay = v),
            onBack: _prevPage,
            onConfirm: _selections.isEmpty ? null : _confirm,
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

// ─── Page 1 : Sélection sourates ─────────────────────────────────────────────

class _SelectionPage extends StatelessWidget {
  final Map<int, SourateSelection> selections;
  final int totalVerses;
  final bool groupByHizb;
  final String search;
  final List<Object> listItems;
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
            total: 2,
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
                        selected: selections.length == allSourates.length),
                    const SizedBox(width: 6),
                    PillChip(label: '3/4', onTap: () => onQuickSelect(0.75), selected: false),
                    const SizedBox(width: 6),
                    PillChip(label: '1/2', onTap: () => onQuickSelect(0.5), selected: false),
                    const SizedBox(width: 6),
                    PillChip(label: '1/4', onTap: () => onQuickSelect(0.25), selected: false),
                  ],
                ),
              ],
            ),
          ),
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
                  label: 'Hizb',
                  value: groupByHizb,
                  onChanged: onGroupByHizbChanged,
                ),
              ],
            ),
          ),
          // Liste
          Expanded(child: _SourateList(
            items: listItems,
            selections: selections,
            onToggle: onToggleSourate,
            onLongPress: onLongPress,
          )),
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

// ─── Page 2 : Récap ──────────────────────────────────────────────────────────

class _RecapPage extends StatelessWidget {
  final Map<int, SourateSelection> selections;
  final int totalVerses;
  final int revisionDays;
  final ValueChanged<int> onRevisionDaysChanged;
  final bool paceByLines;
  final ValueChanged<bool> onPaceByLinesChanged;
  final int targetLinesPerDay;
  final ValueChanged<int> onTargetLinesPerDayChanged;
  final VoidCallback onBack;
  final VoidCallback? onConfirm;

  const _RecapPage({
    required this.selections,
    required this.totalVerses,
    required this.revisionDays,
    required this.onRevisionDaysChanged,
    required this.paceByLines,
    required this.onPaceByLinesChanged,
    required this.targetLinesPerDay,
    required this.onTargetLinesPerDayChanged,
    required this.onBack,
    required this.onConfirm,
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
              total: 2,
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
            ),
            const SizedBox(height: 12),
            // Rythme du cycle
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
            ),
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
            PrimaryCtaButton(label: S.commencer, onPressed: onConfirm),
            const SizedBox(height: 24),
          ],
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
            Text(subtitle!,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8))),
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
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is int) {
          return _groupHeader(palette, S.hizb(item));
        }
        final s = item as Sourate;
        final sel = selections[s.id];
        final selected = sel != null;
        return GestureDetector(
          onLongPress: () => onLongPress(s),
          child: CheckboxListTile(
            value: selected,
            onChanged: (_) => onToggle(s),
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
                IndexBadge(
                  text: '${s.id}',
                  size: 30,
                  state: selected ? IndexBadgeState.selected : IndexBadgeState.unselected,
                ),
                const SizedBox(width: 10),
                Text(s.nameAr, style: GoogleFonts.amiri(fontSize: 18, color: palette.textPrimary)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _groupHeader(AppPalette palette, String label) {
    return Container(
      color: palette.gold.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.goldDark,
              letterSpacing: 0.8)),
    );
  }
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
