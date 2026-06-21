import 'package:flutter/material.dart';
import '../core/strings.dart';
import '../widgets/duration_picker.dart';

class OnboardingHeader extends StatelessWidget {
  final int selectionsLength;
  final int totalVerses;
  final int allSouratesCount;
  final bool groupByJuz;
  final bool useVersesPerDay;
  final int revisionDays;
  final int versesPerDay;
  final int estimatedDays;
  final VoidCallback onToggleAll;
  final ValueChanged<bool> onGroupByJuzChanged;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<int> onRevisionDaysChanged;
  final ValueChanged<int> onVersesPerDayChanged;

  const OnboardingHeader({
    super.key,
    required this.selectionsLength,
    required this.totalVerses,
    required this.allSouratesCount,
    required this.groupByJuz,
    required this.useVersesPerDay,
    required this.revisionDays,
    required this.versesPerDay,
    required this.estimatedDays,
    required this.onToggleAll,
    required this.onGroupByJuzChanged,
    required this.onModeChanged,
    required this.onRevisionDaysChanged,
    required this.onVersesPerDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allSelected = selectionsLength == allSouratesCount;

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
              Text(S.souratesCount(selectionsLength, totalVerses),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                      fontSize: 13)),
              TextButton.icon(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: onToggleAll,
                icon: Icon(
                  allSelected ? Icons.deselect : Icons.select_all,
                  color: cs.onPrimaryContainer,
                  size: 16,
                ),
                label: Text(
                  allSelected ? S.toutDeselectionner : S.toutSelectionner,
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DurationPicker(
            useVersesPerDay: useVersesPerDay,
            revisionDays: revisionDays,
            versesPerDay: versesPerDay,
            totalVerses: totalVerses,
            estimatedDays: estimatedDays,
            onModeChanged: onModeChanged,
            onRevisionDaysChanged: onRevisionDaysChanged,
            onVersesPerDayChanged: onVersesPerDayChanged,
          ),
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
                value: groupByJuz,
                onChanged: onGroupByJuzChanged,
                activeThumbColor: cs.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
