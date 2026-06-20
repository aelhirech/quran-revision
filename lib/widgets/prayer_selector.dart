import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/prayer_l10n.dart';
import '../core/strings.dart';
import '../models/prayer.dart';

class PrayerSelector extends StatelessWidget {
  final Set<Prayer> selected;
  final void Function(Prayer) onToggle;

  const PrayerSelector({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final fard = Prayer.values.where((p) => p.isFard).toList();
    final sunna = Prayer.values.where((p) => !p.isFard && !p.isTahiyyat).toList();
    final tahiyyat = Prayer.values.where((p) => p.isTahiyyat).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chipGroup(context, S.priereObligatoires, fard),
        const SizedBox(height: 12),
        _chipGroup(context, S.priereSureratoires, sunna),
        const SizedBox(height: 12),
        _chipGroup(context, S.priereMasjid, tahiyyat),
      ],
    );
  }

  Widget _chipGroup(BuildContext context, String label, List<Prayer> prayers) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: prayers.map((p) => _chip(context, p)).toList(),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, Prayer p) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = selected.contains(p);
    return GestureDetector(
      onTap: () => onToggle(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cs.primary : AppColors.cardBorder,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.check, color: Colors.white, size: 14),
              ),
            Text(
              '${p.displayName}  ${p.rakaas}r',
              style: TextStyle(
                color: isSelected ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
