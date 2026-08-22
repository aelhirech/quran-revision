import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/sourate_selection.dart';
import '../services/verse_service.dart';
import '../state/app_state.dart';
import '../widgets/ornamental_divider.dart';

/// Lecture plein texte d'une sourate (ou d'une plage de versets sélectionnée),
/// accessible depuis le Récap — pas de mode caché/révélé, juste la lecture.
class SurahReaderScreen extends StatelessWidget {
  final SourateSelection selection;

  const SurahReaderScreen({super.key, required this.selection});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;
    final riwaya = context.watch<AppState>().riwaya;
    final s = selection.sourate;
    final verses = [
      for (var v = selection.verseStart; v <= selection.verseEnd; v++)
        VerseService.getVerse(s.id, v, riwaya: riwaya),
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(s.nameFr),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          children: [
            Text(
              s.nameAr,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.amiri(fontSize: 28, color: palette.textPrimary),
            ),
            const SizedBox(height: 12),
            const OrnamentalDivider(),
            const SizedBox(height: 20),
            Text(
              verses.join('  '),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.amiri(
                fontSize: 24,
                height: 2.2,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
