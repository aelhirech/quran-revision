import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/strings.dart';
import '../models/sourate.dart';
import '../services/quran_audio_handler.dart';
import '../services/surah_metadata_service.dart';
import '../services/verse_service.dart';
import '../state/app_state.dart';
import 'bismillah_line.dart';
import 'draggable_handle.dart';
import 'guide_step.dart';
import 'verse_audio_bar.dart';
import 'verse_row.dart';

/// Vue Coran partagée entre Plan du jour, Récap et Apprendre — un seul
/// mécanisme pour "afficher le Coran entre ayah_start et ayah_end", plutôt
/// que la logique quasi identique dupliquée dans 3 écrans (feuille de
/// versets d'une rakaa, écran de lecture d'une sourate, bloc de mémorisation).
class VerseBottomSheet extends StatefulWidget {
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
  State<VerseBottomSheet> createState() => _VerseBottomSheetState();
}

class _VerseBottomSheetState extends State<VerseBottomSheet> {
  // Owned here, not by the audio bar: the slider and the verse list must read
  // the same portion. Never persisted: each opening restarts from the full
  // range (US-11 crit. 5, US-18 crit. 4).
  late RangeValues _portion;

  @override
  void initState() {
    super.initState();
    _portion = RangeValues(widget.ayahStart.toDouble(), widget.ayahEnd.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final riwaya = state.riwaya;
    final shownStart = _portion.start.round();
    final shownEnd = _portion.end.round();

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
            Expanded(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  // Header and audio bar scroll with the text but must stay
                  // SliverToBoxAdapters: a lazy list would dispose the bar once
                  // off-screen and lose its reciter/loading state while the loop plays.
                  SliverToBoxAdapter(child: _header(cs)),
                  SliverToBoxAdapter(
                    child: VerseAudioBar(
                      sourate: widget.sourate,
                      ayahStart: widget.ayahStart,
                      ayahEnd: widget.ayahEnd,
                      portion: _portion,
                      onPortionChanged: (v) => setState(() => _portion = v),
                    ),
                  ),
                  // Must stay AFTER the bar: placed before, its removal would
                  // shift the bar's slot and recreate its state mid-playback.
                  if (QuranAudioHandler.available &&
                      !state.guideDone('audio_loop_started'))
                    SliverToBoxAdapter(
                      child: GuideStep(
                        icon: Icons.play_arrow,
                        title: SGuide.guideAudioTitle,
                        body: SGuide.guideAudioBody,
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: shownEnd - shownStart + 1,
                      separatorBuilder: (context, index) => const Divider(height: 24),
                      itemBuilder: (_, i) {
                        final ayahId = shownStart + i;
                        return VerseRow(
                          number: ayahId,
                          text: VerseService.getVerse(widget.sourate.id, ayahId, riwaya: riwaya),
                        );
                      },
                    ),
                  ),
                ],
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
            widget.sourate.nameAr,
            style: GoogleFonts.scheherazadeNew(fontSize: 28, height: 1.8),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.sourate.nameFr}  ·  ${S.blocRange(widget.ayahStart, widget.ayahEnd)}',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.ayahStart == 1 && SurahMetadataService.bismillahPre(widget.sourate.id))
            const BismillahLine(),
          Divider(color: cs.outlineVariant),
        ],
      ),
    );
  }
}
