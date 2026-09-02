import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import 'ornamental_divider.dart';
import 'verse_row.dart';

class VerseDisplayCard extends StatelessWidget {
  // Numéro de verset → texte, dans l'ordre d'affichage.
  final Map<int, String> verses;
  final bool visible;
  final bool isComplete;
  final VoidCallback onToggle;

  const VerseDisplayCard({
    super.key,
    required this.verses,
    required this.visible,
    required this.isComplete,
    required this.onToggle,
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

    if (verses.isEmpty) return const SizedBox.shrink();

    final lastVerseKey = verses.keys.last;
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in verses.entries) ...[
                    VerseRow(number: entry.key, text: entry.value, fontSize: 26),
                    if (entry.key != lastVerseKey) const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 14),
                  const OrnamentalDivider(lineWidth: 30),
                  const SizedBox(height: 10),
                  Text(S.masquerVerset,
                      textAlign: TextAlign.center,
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
                  Text(S.appuyerPourReveler(verses.length),
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
