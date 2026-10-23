import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';

/// Scaffold détail partagé entre check-in et check-out : AppBar titrée
/// "Sourate · v.X–Y" + label uppercase + grille de `VerseChip` — l'appelant
/// construit lui-même les chips (comportement différent : bookmark
/// "à retravailler" en check-out, lecture seule + extension en check-in).
class VerseChipsScaffold extends StatelessWidget {
  final String title;
  final String headerLabel;
  final List<Widget> chips;
  final Widget? footer;

  const VerseChipsScaffold({
    super.key,
    required this.title,
    required this.headerLabel,
    required this.chips,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.cream,
      appBar: AppBar(
        backgroundColor: palette.cream,
        title: Text(title, style: AppText.cardTitle.copyWith(color: palette.textPrimary)),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headerLabel.toUpperCase(),
                style: AppText.sectionTitle.copyWith(color: palette.textMuted)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
            if (footer != null) ...[
              const SizedBox(height: 14),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
