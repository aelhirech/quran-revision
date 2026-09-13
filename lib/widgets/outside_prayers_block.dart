import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/revision_unit.dart';
import 'unit_range_label.dart';
import 'verse_bottom_sheet.dart';

/// Content that did not fit in the chosen prayers, shown read-only — the
/// rakaa layout is a display and must not hide day content the check-out
/// will still credit (cadrage 2026-09-08, `PlanScreen`). Reused as-is by the
/// onboarding demo, whose "hors prières" case is the exact same situation on
/// fake content.
class OutsidePrayersBlock extends StatelessWidget {
  final List<RevisionUnit> units;
  const OutsidePrayersBlock({super.key, required this.units});

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.horsPrieresTitre,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: palette.textPrimary)),
          const SizedBox(height: 4),
          Text(S.horsPrieresDesc,
              style: TextStyle(fontSize: 11.5, color: palette.textMuted)),
          const SizedBox(height: 10),
          for (final u in units)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: UnitRangeLabel(unit: u, nameColor: palette.textPrimary),
                  ),
                  IconButton(
                    icon: Icon(Icons.menu_book_outlined, color: palette.gold, size: 18),
                    tooltip: S.voirLeTexte,
                    onPressed: () => VerseBottomSheet.show(
                        context, u.sourate, u.verseStart, u.verseEnd),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
