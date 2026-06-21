import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';

class VerseRangePicker extends StatefulWidget {
  final Sourate sourate;
  final SourateSelection current;

  const VerseRangePicker({super.key, required this.sourate, required this.current});

  @override
  State<VerseRangePicker> createState() => _VerseRangePickerState();
}

class _VerseRangePickerState extends State<VerseRangePicker> {
  late RangeValues _range;

  @override
  void initState() {
    super.initState();
    _range = RangeValues(
      widget.current.verseStart.toDouble(),
      widget.current.verseEnd.toDouble(),
    );
  }

  /// Taille des blocs de division rapide.
  /// Les longues sourates (>100v) se découpent par 100 pour éviter
  /// des blocs trop nombreux ; les moyennes (50-100v) par 50.
  int get _chunkSize => widget.sourate.verses > 100 ? 100 : 50;

  List<({int start, int end})> get _chunks {
    final size = _chunkSize;
    final total = widget.sourate.verses;
    return [
      for (int s = 1; s <= total; s += size)
        (start: s, end: (s + size - 1).clamp(s, total)),
    ];
  }

  Widget _chunkRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _chunks.map((c) {
          final isActive = _range.start.round() == c.start && _range.end.round() == c.end;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text('v.${c.start}–${c.end}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.green : null)),
              backgroundColor: isActive ? AppColors.greenContainer : null,
              side: isActive
                  ? const BorderSide(color: AppColors.green, width: 1.5)
                  : null,
              onPressed: () => setState(() => _range = RangeValues(
                    c.start.toDouble(),
                    c.end.toDouble(),
                  )),
            ),
          );
        }).toList(),
      ),
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
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text(widget.sourate.nameFr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(widget.sourate.nameAr,
              style: const TextStyle(fontSize: 20, height: 1.8)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('v.$start',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.green)),
              Text('$count ${S.versetsLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('v.$end',
                  style: const TextStyle(
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
          if (widget.sourate.verses > 50) ...[
            const SizedBox(height: 12),
            _chunkRow(),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(
                      context, SourateSelection.whole(widget.sourate)),
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
                        verseEnd: end),
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
