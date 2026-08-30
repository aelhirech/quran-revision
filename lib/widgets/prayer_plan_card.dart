import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/freshness_engine.dart';
import '../core/prayer_l10n.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../widgets/verse_bottom_sheet.dart';
import 'index_badge.dart';

class PrayerPlanCard extends StatelessWidget {
  final int prayerIndex;
  final PrayerPlan pp;
  final Set<int> checked;
  final void Function(int rakaaNumber) onToggle;
  final FreshnessLevel? Function(int sourateId)? freshnessOf;

  const PrayerPlanCard({
    super.key,
    required this.prayerIndex,
    required this.pp,
    required this.checked,
    required this.onToggle,
    this.freshnessOf,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.gold, width: 2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(pp.prayer.displayName,
                      style: GoogleFonts.lora(
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                          fontSize: 15)),
                  Text(pp.prayer.nameAr,
                      style: GoogleFonts.amiri(color: palette.textPrimary, fontSize: 18)),
                ],
              ),
            ),
            ...pp.rakaas.map((r) => _rakaaRow(context, r, cs, palette)),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _rakaaRow(BuildContext context, RakaaAssignment r, ColorScheme cs, AppPalette palette) {
    final hasUnit = r.unit != null;
    final isChecked = checked.contains(r.rakaaNumber);
    final state = isChecked
        ? IndexBadgeState.done
        : (hasUnit ? IndexBadgeState.unselected : IndexBadgeState.unselected);

    return InkWell(
      onTap: hasUnit
          ? () {
              HapticFeedback.selectionClick();
              onToggle(r.rakaaNumber);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            IndexBadge(text: '${r.rakaaNumber}', state: state, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  hasUnit
                      ? Text(r.unit!.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13.5,
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked
                                ? palette.textMuted
                                : palette.textPrimary,
                          ))
                      : Text(S.alFatihaSeul,
                          style: TextStyle(color: palette.textMuted, fontSize: 13)),
                  if (hasUnit) _subtitle(palette, r.unit!, freshnessOf?.call(r.unit!.sourate.id)),
                ],
              ),
            ),
            if (hasUnit)
              IconButton(
                icon: Icon(Icons.menu_book_outlined, color: palette.gold, size: 17),
                tooltip: S.versetsDeRakaa,
                onPressed: () =>
                    VerseBottomSheet.show(context, r.unit!, r.rakaaNumber),
              ),
          ],
        ),
      ),
    );
  }

  /// Sous-titre d'une rakaa : compte de versets et/ou badge de fraîcheur.
  Widget _subtitle(AppPalette palette, RevisionUnit unit, FreshnessLevel? freshness) {
    final showCount = !unit.isWhole;
    final showBadge = freshness == FreshnessLevel.cold ||
        freshness == FreshnessLevel.frozen;

    if (!showCount && !showBadge) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          if (showCount)
            Text(
              '${unit.verseCount} ${S.versets}',
              style: TextStyle(
                  color: palette.textMuted, fontStyle: FontStyle.italic, fontSize: 11),
            ),
          if (showCount && showBadge) const SizedBox(width: 8),
          if (showBadge) _freshnessBadge(freshness!, palette),
        ],
      ),
    );
  }

  Widget _freshnessBadge(FreshnessLevel level, AppPalette palette) {
    final label = level == FreshnessLevel.frozen ? S.fraicheurGelee : S.fraicheurFroide;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: palette.gold.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: palette.goldDark),
      ),
    );
  }
}
