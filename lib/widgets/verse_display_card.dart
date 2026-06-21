import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';

class VerseDisplayCard extends StatelessWidget {
  final String verseText;
  final bool visible;
  final bool isComplete;
  final VoidCallback onToggle;
  // Nombre de versets affichés — ajuste le texte d'invite.
  final int blockSize;

  const VerseDisplayCard({
    super.key,
    required this.verseText,
    required this.visible,
    required this.isComplete,
    required this.onToggle,
    this.blockSize = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isComplete) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.greenContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(S.sourateCompleted,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green)),
        ),
      );
    }

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: visible ? Colors.white : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: visible
                ? AppColors.green.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: visible
            ? Column(
                children: [
                  Text(
                    verseText,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.scheherazadeNew(
                        fontSize: 28, height: 2.0, color: cs.onSurface),
                  ),
                  const SizedBox(height: 16),
                  Text(S.masquerVerset,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              )
            : Column(
                children: [
                  Icon(Icons.visibility_outlined,
                      color: cs.onSurfaceVariant, size: 32),
                  const SizedBox(height: 12),
                  Text(S.afficherVerset,
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(S.appuyerPourReveler(blockSize),
                      style: TextStyle(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 12)),
                ],
              ),
      ),
    );
  }
}
