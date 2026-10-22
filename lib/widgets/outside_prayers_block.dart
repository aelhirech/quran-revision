import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/revision_unit.dart';
import 'unit_range_label.dart';
import 'verse_bottom_sheet.dart';

/// Content that did not fit in the chosen prayers, shown read-only — the
/// rakaa layout is a display and must not hide day content the check-out
/// will still credit (cadrage 2026-09-08, `PlanScreen`).
class OutsidePrayersBlock extends StatelessWidget {
  final List<RevisionUnit> units;
  const OutsidePrayersBlock({super.key, required this.units});

  @override
  Widget build(BuildContext context) => _OutsideCard(
      title: S.horsPrieresTitre, description: S.horsPrieresDesc, units: units);
}

/// Today's learning portion when no recited rakaa hosts it (no prayer chosen,
/// US-27 crit. 7). Read-only like [OutsidePrayersBlock]: the check-out credits it.
class OutsideLearningBlock extends StatelessWidget {
  final RevisionUnit? unit;
  const OutsideLearningBlock({super.key, required this.unit});

  @override
  Widget build(BuildContext context) => _OutsideCard(
      title: S.aApprendreTitre, units: [?unit]);
}

class _OutsideCard extends StatelessWidget {
  final String title;
  final String? description;
  final List<RevisionUnit> units;
  const _OutsideCard(
      {required this.title, this.description, required this.units});

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: palette.textPrimary)),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(description!,
                  style: TextStyle(fontSize: 11.5, color: palette.textMuted)),
            ],
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
      ),
    );
  }
}
