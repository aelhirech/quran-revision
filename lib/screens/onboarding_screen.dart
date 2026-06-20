import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;
import '../core/app_colors.dart';
import '../core/quran_data.dart';
import '../core/strings.dart';
import '../state/app_state.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // id -> SourateSelection (null = pas sélectionnée)
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

  Future<void> _longPressSourate(Sourate s) async {
    // Assure que la sourate est sélectionnée avant d'ouvrir le picker
    if (!_selections.containsKey(s.id)) {
      setState(() => _selections[s.id] = SourateSelection.whole(s));
    }
    final current = _selections[s.id]!;
    final result = await showModalBottomSheet<SourateSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerseRangePicker(
        sourate: s,
        current: current,
      ),
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
            _header(cs),
            _searchBar(),
            Expanded(child: _list(cs)),
            _footer(cs),
          ],
        ),
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    return Container(
      width: double.infinity,
      color: cs.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.configInitiale,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cs.onPrimaryContainer)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.souratesCount(_selections.length, _totalVerses),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                      fontSize: 13)),
              TextButton.icon(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () => setState(() {
                  if (_selections.length == allSourates.length) {
                    _selections.clear();
                  } else {
                    for (final s in allSourates) {
                      _selections.putIfAbsent(s.id, () => SourateSelection.whole(s));
                    }
                  }
                }),
                icon: Icon(
                  _selections.length == allSourates.length
                      ? Icons.deselect
                      : Icons.select_all,
                  color: cs.onPrimaryContainer,
                  size: 16,
                ),
                label: Text(
                  _selections.length == allSourates.length
                      ? S.toutDeselectionner
                      : S.toutSelectionner,
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _durationRow(cs),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 16,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(S.regrouperParJuz,
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Switch.adaptive(
                value: _groupByJuz,
                onChanged: (v) => setState(() => _groupByJuz = v),
                activeThumbColor: cs.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _durationRow(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _modeChip(cs,
                label: S.parDuree,
                active: !_useVersesPerDay,
                onTap: () => setState(() => _useVersesPerDay = false)),
            const SizedBox(width: 8),
            _modeChip(cs,
                label: S.parVersetsJour,
                active: _useVersesPerDay,
                onTap: () => setState(() => _useVersesPerDay = true)),
          ],
        ),
        const SizedBox(height: 8),
        if (!_useVersesPerDay)
          Row(
            children: [
              Text(S.reviserEn,
                  style: TextStyle(
                      color: cs.onPrimaryContainer, fontSize: 13)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _revisionDays,
                items: [7, 14, 21, 30, 60, 90]
                    .map((d) => DropdownMenuItem(
                        value: d, child: Text(S.joursDuration(d))))
                    .toList(),
                onChanged: (v) => setState(() => _revisionDays = v!),
                dropdownColor: cs.primaryContainer,
                style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600),
              ),
            ],
          )
        else
          Row(
            children: [
              _stepperButton(cs, Icons.remove,
                  () => setState(() => _versesPerDay = (_versesPerDay - 5).clamp(5, 500))),
              const SizedBox(width: 8),
              Text(S.versetsParJour(_versesPerDay),
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(width: 8),
              _stepperButton(cs, Icons.add,
                  () => setState(() => _versesPerDay = (_versesPerDay + 5).clamp(5, 500))),
              const Spacer(),
              if (_totalVerses > 0)
                Text(
                    '→ ${S.joursDuration(_estimatedDays)} ${S.joursEstimes}',
                    style: TextStyle(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontStyle: FontStyle.italic)),
            ],
          ),
      ],
    );
  }

  Widget _modeChip(ColorScheme cs,
      {required String label,
      required bool active,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? cs.primary
                  : cs.onPrimaryContainer.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? cs.onPrimary : cs.onPrimaryContainer)),
      ),
    );
  }

  Widget _stepperButton(
      ColorScheme cs, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        child: Icon(icon, color: cs.onPrimary, size: 16),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: S.rechercherSourate,
          prefixIcon: const Icon(Icons.search),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onChanged: (v) => setState(() => _search = v),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.greenContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'v.${sel.verseStart}–${sel.verseEnd}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.green,
                          fontWeight: FontWeight.w700),
                    ),
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
              child: Text('${s.id}',
                  style: const TextStyle(fontSize: 11)),
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

  Widget _footer(ColorScheme cs) {
    return Padding(
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
    );
  }
}

/// BottomSheet pour sélectionner une plage de versets d'une sourate.
class _VerseRangePicker extends StatefulWidget {
  final Sourate sourate;
  final SourateSelection current;

  const _VerseRangePicker({required this.sourate, required this.current});

  @override
  State<_VerseRangePicker> createState() => _VerseRangePickerState();
}

class _VerseRangePickerState extends State<_VerseRangePicker> {
  late RangeValues _range;

  @override
  void initState() {
    super.initState();
    _range = RangeValues(
      widget.current.verseStart.toDouble(),
      widget.current.verseEnd.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = _range.start.round();
    final end = _range.end.round();
    final count = end - start + 1;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text(widget.sourate.nameFr,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          Text(widget.sourate.nameAr,
              style: const TextStyle(fontSize: 20, height: 1.8)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('v.$start',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.green)),
              Text('$count ${S.versetsLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('v.$end',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.green)),
            ],
          ),
          RangeSlider(
            values: _range,
            min: 1,
            max: widget.sourate.verses.toDouble(),
            divisions: widget.sourate.verses - 1,
            activeColor: AppColors.green,
            onChanged: (v) => setState(() => _range = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    SourateSelection.whole(widget.sourate),
                  ),
                  child: Text(S.toutSelectionner),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    SourateSelection(
                      sourate: widget.sourate,
                      verseStart: start,
                      verseEnd: end,
                    ),
                  ),
                  child: const Text('Confirmer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
