import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';

/// Première ligne fixe, hors du flux scrollable des versets, sur tout écran
/// de lecture du texte coranique — décision actée dans docs/CHANGELOG.md
/// ("Bismillah (décidé)"). L'appelant décide quand l'afficher (sourate avec
/// Bismillah, portion commençant au verset 1).
class BismillahLine extends StatelessWidget {
  const BismillahLine({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        S.bismillah,
        textAlign: TextAlign.center,
        style: GoogleFonts.scheherazadeNew(fontSize: 24, color: palette.gold),
      ),
    );
  }
}
