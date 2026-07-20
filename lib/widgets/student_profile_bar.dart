import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/student_profile.dart';
import 'pill_chip.dart';

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
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          PillChip(
            label: S.moi,
            selected: activeId == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          ...profiles.map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onLongPress: () => onDelete(p),
                  child: PillChip(
                    label: p.name,
                    selected: activeId == p.id,
                    onTap: () => onSelect(p.id),
                  ),
                ),
              )),
          _addChip(context),
        ],
      ),
    );
  }

  Widget _addChip(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.gold.withValues(alpha: 0.8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: palette.goldDark),
            const SizedBox(width: 4),
            Text(S.ajouterEleve,
                style: TextStyle(
                    color: palette.goldDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
