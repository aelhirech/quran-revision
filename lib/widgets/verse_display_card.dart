import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import 'ornamental_divider.dart';

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
    final palette = context.palette;

    if (isComplete) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(S.sourateCompleted,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.primary)),
        ),
      );
    }

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: visible ? palette.surfaceCardSolid : palette.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: visible
            ? Column(
                children: [
                  Text(
                    verseText,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.scheherazadeNew(
                        fontSize: 28, height: 2.0, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 14),
                  const OrnamentalDivider(lineWidth: 30),
                  const SizedBox(height: 10),
                  Text(S.masquerVerset,
                      style: TextStyle(
                          color: palette.textMuted,
                          fontStyle: FontStyle.italic,
                          fontSize: 12)),
                ],
              )
            : Column(
                children: [
                  Icon(Icons.visibility_outlined,
                      color: palette.textMuted, size: 32),
                  const SizedBox(height: 12),
                  Text(S.afficherVerset,
                      style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(S.appuyerPourReveler(blockSize),
                      style: TextStyle(
                          color: palette.textMuted,
                          fontStyle: FontStyle.italic,
                          fontSize: 12)),
                ],
              ),
      ),
    );
  }
}
