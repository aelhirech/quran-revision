import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/student_profile.dart';

/// Barre horizontale affichée en haut de l'onglet Apprendre.
/// Affiche "Moi" + les profils élèves, avec ajout/suppression.
class StudentProfileBar extends StatelessWidget {
  final List<StudentProfile> profiles;
  final String? activeId; // null = profil principal (Moi)
  final ValueChanged<String?> onSelect;
  final VoidCallback onAdd;
  final void Function(StudentProfile) onDelete;

  const StudentProfileBar({
    super.key,
    required this.profiles,
    required this.activeId,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(
            context,
            label: S.moi,
            selected: activeId == null,
            onTap: () => onSelect(null),
            cs: cs,
          ),
          const SizedBox(width: 8),
          ...profiles.map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _chip(
                  context,
                  label: p.name,
                  selected: activeId == p.id,
                  onTap: () => onSelect(p.id),
                  onLongPress: () => onDelete(p),
                  cs: cs,
                ),
              )),
          _addChip(context, cs),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required ColorScheme cs,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.green : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _addChip(BuildContext context, ColorScheme cs) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: AppColors.green),
            const SizedBox(width: 4),
            Text(S.ajouterEleve,
                style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

}
