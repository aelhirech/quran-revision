import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/strings.dart';
import '../models/sourate.dart';
import '../services/surah_metadata_service.dart';
import '../services/verse_service.dart';
import '../state/app_state.dart';
import 'bismillah_line.dart';
import 'verse_row.dart';

/// Vue Coran partagée entre Plan du jour, Récap et Apprendre — un seul
/// mécanisme pour "afficher le Coran entre ayah_start et ayah_end", plutôt
/// que la logique quasi identique dupliquée dans 3 écrans (feuille de
/// versets d'une rakaa, écran de lecture d'une sourate, bloc de mémorisation).
class VerseBottomSheet extends StatelessWidget {
  final Sourate sourate;
  final int ayahStart;
  final int ayahEnd;

  const VerseBottomSheet({
    super.key,
    required this.sourate,
    required this.ayahStart,
    required this.ayahEnd,
  });

  static void show(BuildContext context, Sourate sourate, int ayahStart, int ayahEnd) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerseBottomSheet(
        sourate: sourate,
        ayahStart: ayahStart,
        ayahEnd: ayahEnd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final riwaya = context.watch<AppState>().riwaya;
    final verses = [
      for (var v = ayahStart; v <= ayahEnd; v++)
        VerseService.getVerse(sourate.id, v, riwaya: riwaya),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _handle(cs),
            _header(cs),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: verses.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (_, i) =>
                    VerseRow(number: ayahStart + i, text: verses[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _handle(ColorScheme cs) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Text(
            sourate.nameAr,
            style: GoogleFonts.scheherazadeNew(fontSize: 28, height: 1.8),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 4),
          Text(
            '${sourate.nameFr}  ·  ${S.blocRange(ayahStart, ayahEnd)}',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (ayahStart == 1 && SurahMetadataService.bismillahPre(sourate.id))
            const BismillahLine(),
          Divider(color: cs.outlineVariant),
        ],
      ),
    );
  }
}
