import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;
import '../core/app_colors.dart';
import '../core/quran_data.dart';
import '../core/strings.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';
import '../state/app_state.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/verse_range_picker.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _introSeen = false;
  final Map<int, SourateSelection> _selections = {};
  int _revisionDays = 30;
  int _versesPerDay = 20;
  bool _useVersesPerDay = false;
  bool _groupByJuz = false;
  bool _groupByHizb = false;
  String _search = '';

  List<Sourate> get _filtered => allSourates
      .where((s) =>
          s.nameFr.toLowerCase().contains(_search.toLowerCase()) ||
          s.nameAr.contains(_search) ||
          s.id.toString() == _search)
      .toList();

  int get _totalVerses =>
      _selections.values.fold(0, (sum, s) => sum + s.verseCount);

  int get _estimatedDays => _useVersesPerDay && _versesPerDay > 0
      ? (_totalVerses / _versesPerDay).ceil().clamp(1, 9999)
      : _revisionDays;

  List<Object> get _listItems {
    final sourates = _filtered;
    if (_search.isNotEmpty) return sourates;
    if (_groupByJuz) return _groupedBy(sourates, (s) => quran.getJuzNumber(s.id, 1));
    if (_groupByHizb) return _groupedBy(sourates, _hizbOf);
    return sourates;
  }

  // Cache calculé une seule fois : surah id → numéro de Hizb (1-60).
  // Basé sur la position cumulative des versets dans le Coran (6236 versets total).
  static Map<int, int>? _hizbCache;

  int _hizbOf(Sourate s) {
    if (_hizbCache == null) {
      int cumulative = 7; // Al-Fatiha (id 1, 7 versets, exclue de allSourates)
      final cache = <int, int>{};
      for (final r in allSourates) {
        cache[r.id] = (cumulative / 6236 * 60).floor().clamp(0, 59) + 1;
        cumulative += r.verses;
      }
      _hizbCache = cache;
    }
    return _hizbCache![s.id] ?? 1;
  }

  /// Groupe les sourates par la valeur retournée par [key], en insérant des
  /// entêtes (int) à chaque changement de groupe.
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

  void _toggleAll() {
    setState(() {
      if (_selections.length == allSourates.length) {
        _selections.clear();
      } else {
        for (final s in allSourates) {
          _selections.putIfAbsent(s.id, () => SourateSelection.whole(s));
        }
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
      builder: (_) =>
          VerseRangePicker(sourate: s, current: _selections[s.id]!),
    );
    if (result != null) setState(() => _selections[s.id] = result);
  }

  Future<void> _confirm() async {
    if (_selections.isEmpty) return;
    final config = UserConfig(
      selections: _selections.values.toList(),
      revisionDays: _useVersesPerDay ? _estimatedDays : _revisionDays,
      startDate: DateTime.now(),
      versesPerDay: _useVersesPerDay ? _versesPerDay : null,
    );
    await context.read<AppState>().saveConfig(config);
  }

  @override
  Widget build(BuildContext context) {
    if (!_introSeen) return _IntroScreen(onNext: () => setState(() => _introSeen = true));
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            OnboardingHeader(
              selectionsLength: _selections.length,
              totalVerses: _totalVerses,
              allSouratesCount: allSourates.length,
              groupByJuz: _groupByJuz,
              groupByHizb: _groupByHizb,
              useVersesPerDay: _useVersesPerDay,
              revisionDays: _revisionDays,
              versesPerDay: _versesPerDay,
              estimatedDays: _estimatedDays,
              onToggleAll: _toggleAll,
              // Juz et Hizb sont mutuellement exclusifs
              onGroupByJuzChanged: (v) => setState(() {
                _groupByJuz = v;
                if (v) _groupByHizb = false;
              }),
              onGroupByHizbChanged: (v) => setState(() {
                _groupByHizb = v;
                if (v) _groupByJuz = false;
              }),
              onModeChanged: (v) => setState(() => _useVersesPerDay = v),
              onRevisionDaysChanged: (v) => setState(() => _revisionDays = v),
              onVersesPerDayChanged: (v) => setState(() => _versesPerDay = v),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: S.rechercherSourate,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Expanded(child: _list(cs)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _selections.isEmpty ? null : _confirm,
                  child: Text(
                    _selections.isEmpty ? S.selectSourates : S.commencer,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(ColorScheme cs) {
    final items = _listItems;
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is int) {
          final label = _groupByHizb ? S.hizb(item) : S.juz(item);
          return _groupHeader(cs, label);
        }
        final s = item as Sourate;
        final sel = _selections[s.id];
        final selected = sel != null;
        return GestureDetector(
          onLongPress: () => _longPressSourate(s),
          child: CheckboxListTile(
            value: selected,
            onChanged: (_) => _toggleSourate(s),
            title: Row(
              children: [
                Text(s.nameFr),
                if (sel != null && !sel.isWhole) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.greenContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('v.${sel.verseStart}–${sel.verseEnd}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.green,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
            subtitle: Text(
                '${s.nameAr}  ·  ${sel != null && !sel.isWhole ? '${sel.verseCount}/${s.verses}' : s.verses} ${S.versetsLabel}'),
            secondary: CircleAvatar(
              backgroundColor:
                  selected ? cs.primary : cs.surfaceContainerHighest,
              foregroundColor:
                  selected ? cs.onPrimary : cs.onSurfaceVariant,
              radius: 18,
              child: Text('${s.id}', style: const TextStyle(fontSize: 11)),
            ),
          ),
        );
      },
    );
  }

  Widget _groupHeader(ColorScheme cs, String label) {
    return Container(
      color: AppColors.greenContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.green,
              letterSpacing: 0.8)),
    );
  }
}

class _IntroScreen extends StatelessWidget {
  final VoidCallback onNext;
  const _IntroScreen({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 3),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.greenContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.menu_book, size: 36, color: AppColors.green),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
              const SizedBox(height: 24),
              Text(
                S.introTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  height: 1.2,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.08),
              const SizedBox(height: 20),
              Text(
                S.introLine1,
                style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant, height: 1.55),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 14),
              Text(
                S.introLine2,
                style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant, height: 1.55),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(S.introAction,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
