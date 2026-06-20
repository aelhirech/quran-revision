import 'package:flutter/material.dart';
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
  final Map<int, SourateSelection> _selections = {};
  int _revisionDays = 30;
  int _versesPerDay = 20;
  bool _useVersesPerDay = false;
  bool _groupByJuz = false;
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
    if (!_groupByJuz || _search.isNotEmpty) return sourates;
    final result = <Object>[];
    int? currentJuz;
    for (final s in sourates) {
      final juz = quran.getJuzNumber(s.id, 1);
      if (juz != currentJuz) {
        currentJuz = juz;
        result.add(juz);
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
              useVersesPerDay: _useVersesPerDay,
              revisionDays: _revisionDays,
              versesPerDay: _versesPerDay,
              estimatedDays: _estimatedDays,
              onToggleAll: _toggleAll,
              onGroupByJuzChanged: (v) => setState(() => _groupByJuz = v),
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
        if (item is int) return _juzHeader(cs, item);
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

  Widget _juzHeader(ColorScheme cs, int juz) {
    return Container(
      color: AppColors.greenContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(S.juz(juz),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.green,
              letterSpacing: 0.8)),
    );
  }
}
