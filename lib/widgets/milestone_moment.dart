import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/day_close.dart';
import 'ornamental_divider.dart';
import 'primary_cta_button.dart';

/// Rare milestone shown at check-out (US-13): a surah just memorized, a full
/// revision round, or both in a single moment — never two dialogs in a row.
/// Sober register on purpose (no emoji, no bounce): an ornament draws itself,
/// then the text fades in slowly.
class MilestoneMoment extends StatelessWidget {
  final SealOutcome outcome;

  const MilestoneMoment({super.key, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final memorized = outcome.memorized;
    final title = memorized.isNotEmpty && outcome.cycleWrapped
        ? S.jalonDoubleTitre
        : memorized.isNotEmpty
            ? S.jalonMemoriseeTitre(memorized.length)
            : S.jalonTourTitre;
    final body = [
      if (memorized.isNotEmpty)
        S.jalonMemoriseeCorps(
            memorized.map((s) => s.nameFr).join(', '), memorized.length),
      if (outcome.cycleWrapped) S.jalonTourCorps,
    ].join('\n\n');

    return Dialog(
      backgroundColor: palette.surfaceCardSolid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OrnamentalDivider(lineWidth: 44, draw: true),
            const SizedBox(height: 20),
            for (final sourate in memorized)
              Text(sourate.nameAr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.amiri(fontSize: 30, color: palette.goldDark))
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 800.ms),
            if (memorized.isNotEmpty) const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary),
            ).animate().fadeIn(delay: 600.ms, duration: 800.ms),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: palette.textMuted),
            ).animate().fadeIn(delay: 800.ms, duration: 800.ms),
            const SizedBox(height: 28),
            PrimaryCtaButton(
              label: S.continuer,
              height: 48,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
