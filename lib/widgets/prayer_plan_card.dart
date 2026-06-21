import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/prayer_l10n.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../widgets/verse_bottom_sheet.dart';

class PrayerPlanCard extends StatelessWidget {
  final int prayerIndex;
  final PrayerPlan pp;
  final Set<int> checked;
  final bool isPreview;
  final void Function(int rakaaNumber) onToggle;

  const PrayerPlanCard({
    super.key,
    required this.prayerIndex,
    required this.pp,
    required this.checked,
    required this.isPreview,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.greenContainer,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(pp.prayer.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                        fontSize: 15)),
                Text(pp.prayer.nameAr,
                    style: const TextStyle(color: AppColors.green, fontSize: 17)),
              ],
            ),
          ),
          ...pp.rakaas.map((r) => _rakaaRow(context, r, cs)),
        ],
      ),
    );
  }

  Widget _rakaaRow(BuildContext context, RakaaAssignment r, ColorScheme cs) {
    final hasUnit = r.unit != null;
    final isChecked = checked.contains(r.rakaaNumber);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: hasUnit && !isPreview
          ? () {
              HapticFeedback.selectionClick();
              onToggle(r.rakaaNumber);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isChecked
                  ? AppColors.green
                  : hasUnit
                      ? AppColors.greenContainer
                      : cs.surfaceContainerHighest,
              border: Border.all(
                color: isChecked
                    ? AppColors.green
                    : hasUnit
                        ? AppColors.green.withValues(alpha: 0.3)
                        : Colors.transparent,
              ),
            ),
            child: Center(
              child: isChecked
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text('${r.rakaaNumber}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: hasUnit ? AppColors.green : cs.onSurfaceVariant)),
            ),
          ),
          title: hasUnit
              ? Text(r.unit!.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                    color: isChecked ? cs.onSurfaceVariant : cs.onSurface,
                  ))
              : Text(S.alFatihaSeul,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          subtitle: hasUnit && !r.unit!.isWhole
              ? Text('${r.unit!.verseCount} ${S.versets}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11))
              : null,
          trailing: hasUnit
              ? IconButton(
                  icon: const Icon(Icons.menu_book_outlined,
                      color: AppColors.green, size: 18),
                  tooltip: S.versetsDeRakaa,
                  onPressed: () =>
                      VerseBottomSheet.show(context, r.unit!, r.rakaaNumber),
                )
              : null,
          dense: true,
        ),
      ),
    );
  }
}
