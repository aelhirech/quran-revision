import 'package:flutter/material.dart';
import '../core/strings.dart';

class DurationPicker extends StatelessWidget {
  final bool useVersesPerDay;
  final int revisionDays;
  final int versesPerDay;
  final int totalVerses;
  final int estimatedDays;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<int> onRevisionDaysChanged;
  final ValueChanged<int> onVersesPerDayChanged;

  const DurationPicker({
    super.key,
    required this.useVersesPerDay,
    required this.revisionDays,
    required this.versesPerDay,
    required this.totalVerses,
    required this.estimatedDays,
    required this.onModeChanged,
    required this.onRevisionDaysChanged,
    required this.onVersesPerDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _chip(cs, S.parDuree, !useVersesPerDay,
                () => onModeChanged(false)),
            const SizedBox(width: 8),
            _chip(cs, S.parVersetsJour, useVersesPerDay,
                () => onModeChanged(true)),
          ],
        ),
        const SizedBox(height: 8),
        if (!useVersesPerDay)
          Row(
            children: [
              Text(S.reviserEn,
                  style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: revisionDays,
                items: [7, 14, 21, 30, 60, 90]
                    .map((d) => DropdownMenuItem(
                        value: d, child: Text(S.joursDuration(d))))
                    .toList(),
                onChanged: (v) => onRevisionDaysChanged(v!),
                dropdownColor: cs.primaryContainer,
                style: TextStyle(
                    color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
              ),
            ],
          )
        else
          Row(
            children: [
              _stepper(cs, Icons.remove,
                  () => onVersesPerDayChanged((versesPerDay - 5).clamp(5, 500))),
              const SizedBox(width: 8),
              Text(S.versetsParJour(versesPerDay),
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(width: 8),
              _stepper(cs, Icons.add,
                  () => onVersesPerDayChanged((versesPerDay + 5).clamp(5, 500))),
              const Spacer(),
              if (totalVerses > 0)
                Text(
                  '→ ${S.joursDuration(estimatedDays)} ${S.joursEstimes}',
                  style: TextStyle(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
      ],
    );
  }

  Widget _chip(ColorScheme cs, String label, bool active, VoidCallback onTap) {
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

  Widget _stepper(ColorScheme cs, IconData icon, VoidCallback onTap) {
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
}
