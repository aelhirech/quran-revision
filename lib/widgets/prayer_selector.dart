import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_rules.dart';
import '../core/prayer_l10n.dart';
import '../core/strings.dart';
import '../models/prayer.dart';
import 'pill_chip.dart';

class PrayerSelector extends StatelessWidget {
  final Set<Prayer> selected;
  final void Function(Prayer) onToggle;

  /// Nombre de fois que l'utilisateur entrera à la mosquée (0 = aucune).
  /// Séparé du Set car tahiyyatMasjid peut apparaître plusieurs fois dans la session.
  final int tahiyyatCount;
  final ValueChanged<int> onTahiyyatCountChanged;

  const PrayerSelector({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.tahiyyatCount,
    required this.onTahiyyatCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fard = Prayer.values.where((p) => p.isFard).toList();
    final sunna = Prayer.values.where((p) => !p.isFard && !p.isTahiyyat).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chipGroup(context, S.priereObligatoires, fard),
        const SizedBox(height: 12),
        _chipGroup(context, S.priereSureratoires, sunna),
        const SizedBox(height: 12),
        _tahiyyatGroup(context),
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
    final isSelected = selected.contains(p);
    return PillChip(
      label: p.displayName,
      selected: isSelected,
      onTap: () => onToggle(p),
    );
  }

  Widget _tahiyyatGroup(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;
    final isActive = tahiyyatCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.priereMasjid.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? cs.primary : palette.textPrimary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepBtn(
                icon: Icons.remove,
                enabled: tahiyyatCount > 0,
                color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                onTap: () => onTahiyyatCountChanged(tahiyyatCount - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  tahiyyatCount == 0
                      ? S.tahiyyatCount
                      : '${Prayer.tahiyyatMasjid.displayName}  ×$tahiyyatCount',
                  style: TextStyle(
                    color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              _stepBtn(
                icon: Icons.add,
                enabled: tahiyyatCount < AppRules.maxTahiyyatCount,
                color: isActive ? cs.onPrimary : cs.onSurface,
                onTap: () => onTahiyyatCountChanged(tahiyyatCount + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepBtn({
    required IconData icon,
    required bool enabled,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: enabled ? color : color.withValues(alpha: 0.3)),
      ),
    );
  }
}
