import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/revision_unit.dart';
import '../widgets/unit_range_label.dart';
import '../widgets/verse_toggle_chips.dart';

/// A surah/portion of the day plan in [CheckOutScreen] — label up top, then
/// one chip per verse (number/checked): each verse is confirmed or corrected
/// individually (US-3 crit. 3, verse granularity unified between revision
/// and learning), rather than a single checkbox for the whole range.
class CheckOutRow extends StatelessWidget {
  final RevisionUnit unit;
  final Set<int> uncheckedVerses; // subset of UNCHECKED verses
  final void Function(int ayahId) onToggleVerse;

  const CheckOutRow({
    super.key,
    required this.unit,
    required this.uncheckedVerses,
    required this.onToggleVerse,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final allChecked = uncheckedVerses.isEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceCardSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UnitRangeLabel(
            unit: unit,
            nameColor: allChecked ? palette.textPrimary : palette.textMuted,
          ),
          const SizedBox(height: 10),
          VerseToggleChips(
            verses: unit.verses.toList(),
            unchecked: uncheckedVerses,
            onToggle: onToggleVerse,
            checkedBorderColor: palette.primary,
            checkedFillColor: palette.primary,
            childFor: (v, checked) => checked
                ? Icon(Icons.check, size: 14, color: palette.onPrimary)
                : Text('$v', style: TextStyle(fontSize: 11, color: palette.textMuted)),
          ),
        ],
      ),
    );
  }
}
