import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Bouton pleine largeur à bordure dorée, sans fond — l'action secondaire du
/// rituel quotidien, par opposition au `PrimaryCtaButton` rempli. Partagé par
/// les trois gestes « ajouter » du check-in et du check-out (ajouter une
/// sourate au plan, choisir une sourate à apprendre, déclarer une sourate
/// révisée en plus), qui en avaient chacun leur copie.
class OutlinedActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const OutlinedActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.gold.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: palette.textPrimary),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(fontSize: 13, color: palette.textPrimary)),
          ],
        ),
      ),
    );
  }
}
