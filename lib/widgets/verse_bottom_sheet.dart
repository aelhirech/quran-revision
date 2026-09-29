import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/strings.dart';
import '../models/sourate.dart';
import '../services/surah_metadata_service.dart';
import '../services/verse_service.dart';
import '../state/app_state.dart';
import 'bismillah_line.dart';
import 'draggable_handle.dart';
import 'verse_audio_bar.dart';
import 'verse_row.dart';

/// Vue Coran partagée entre Plan du jour, Récap et Apprendre — un seul
/// mécanisme pour "afficher le Coran entre ayah_start et ayah_end", plutôt
/// que la logique quasi identique dupliquée dans 3 écrans (feuille de
/// versets d'une rakaa, écran de lecture d'une sourate, bloc de mémorisation).
class VerseBottomSheet extends StatelessWidget {
  final Sourate sourate;
  final int ayahStart;
  final int ayahEnd;

  /// Verse right before [ayahStart], shown dimmed above it as a recall aid
  /// when learning a range that doesn't start at verse 1 — memorizing a verse
  /// together with the one before it is more effective than in isolation.
  /// Never affects audio/playback range, only the read list.
  final int? contextAyah;

  const VerseBottomSheet({
    super.key,
    required this.sourate,
    required this.ayahStart,
    required this.ayahEnd,
    this.contextAyah,
  });

  static void show(BuildContext context, Sourate sourate, int ayahStart, int ayahEnd,
      {int? contextAyah}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerseBottomSheet(
        sourate: sourate,
        ayahStart: ayahStart,
        ayahEnd: ayahEnd,
        contextAyah: contextAyah,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final riwaya = context.watch<AppState>().riwaya;
    final ayahNumbers = [
      ?contextAyah,
      for (var v = ayahStart; v <= ayahEnd; v++) v,
    ];
    final verses = [
      for (final ayahId in ayahNumbers)
        VerseService.getVerse(sourate.id, ayahId, riwaya: riwaya),
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
            const DraggableHandle(),
            _header(cs),
            VerseAudioBar(sourate: sourate, ayahStart: ayahStart, ayahEnd: ayahEnd),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: verses.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (_, i) {
                  final ayahId = ayahNumbers[i];
                  return VerseRow(
                    number: ayahId,
                    text: verses[i],
                    isContext: contextAyah != null && ayahId == contextAyah,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
