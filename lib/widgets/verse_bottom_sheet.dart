import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/reciters.dart';
import '../core/strings.dart';
import '../models/riwaya.dart';
import '../models/sourate.dart';
import '../services/quran_audio_handler.dart';
import '../services/storage_service.dart';
import '../services/surah_metadata_service.dart';
import '../services/verse_service.dart';
import '../state/app_state.dart';
import 'bismillah_line.dart';
import 'draggable_handle.dart';
import 'reciter_picker_sheet.dart';
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
  Reciter? _reciter;
  bool _starting = false;
  Riwaya? _riwayaForReciter;

  String _mediaId(Reciter reciter) =>
      '${reciter.id}_${widget.sourate.id}_${widget.ayahStart}_${widget.ayahEnd}';

  Future<void> _ensureReciterLoaded(Riwaya riwaya) async {
    if (_riwayaForReciter == riwaya) return;
    _riwayaForReciter = riwaya;
    final saved = await StorageService.loadAudioReciter(riwaya);
    // A newer call for a different riwaya may have started (and even
    // resolved) while this one was awaiting storage — applying this result
    // would overwrite that more recent one with a stale reciter.
    if (_riwayaForReciter != riwaya) return;
    final reciter = (saved != null ? reciterById(saved) : null) ?? defaultReciterFor(riwaya);
    if (mounted) setState(() => _reciter = reciter);
  }

  Future<void> _pickReciter(Riwaya riwaya) async {
    final picked = await showModalBottomSheet<Reciter>(
      context: context,
      builder: (_) => ReciterPickerSheet(
        reciters: recitersFor(riwaya),
        selectedId: _reciter?.id,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _reciter = picked);
    await StorageService.saveAudioReciter(riwaya, picked.id);
  }

  Future<void> _toggleLoop() async {
    if (!QuranAudioHandler.available) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.audioIndisponibleAppareil)));
      return;
    }
    final reciter = _reciter;
    if (reciter == null || _starting) return;
    final handler = QuranAudioHandler.instance;
    final mediaId = _mediaId(reciter);
    if (handler.isLoadedFor(mediaId)) {
      await (handler.playing ? handler.pause() : handler.play());
      return;
    }
    setState(() => _starting = true);
    try {
      final urls =
          audioTrackUrls(reciter, widget.sourate.id, widget.ayahStart, widget.ayahEnd);
      await handler.playLoop(
        urls: urls,
        item: MediaItem(
          id: mediaId,
          title: '${widget.sourate.nameFr} · ${S.blocRange(widget.ayahStart, widget.ayahEnd)}',
          artist: reciter.nameFr,
        ),
      );
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.audioErreurLecture)));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureReciterLoaded(context.watch<AppState>().riwaya);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final riwaya = context.watch<AppState>().riwaya;
    final verses = [
      for (var v = widget.ayahStart; v <= widget.ayahEnd; v++)
        VerseService.getVerse(widget.sourate.id, v, riwaya: riwaya),
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
            _audioBar(cs, riwaya),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: verses.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (_, i) {
                  final ayahId = widget.ayahStart + i;
                  return VerseRow(number: ayahId, text: verses[i]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _audioBar(ColorScheme cs, Riwaya riwaya) {
    final reciter = _reciter;
    final mediaId = reciter != null ? _mediaId(reciter) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          StreamBuilder<PlaybackState>(
            stream: QuranAudioHandler.playbackStateStream,
            builder: (context, snapshot) {
              final isThisRangeLoaded =
                  mediaId != null && QuranAudioHandler.isCurrentlyLoaded(mediaId);
              final playing = isThisRangeLoaded && (snapshot.data?.playing ?? false);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filled(
                    onPressed: _starting || reciter == null ? null : _toggleLoop,
                    icon: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(playing ? Icons.pause : Icons.repeat),
                    tooltip: playing ? S.arreterEcoute : S.ecouterEnBoucle,
                  ),
                  if (isThisRangeLoaded) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => QuranAudioHandler.instance.stop(),
                      icon: const Icon(Icons.stop),
                      tooltip: S.arreterEcoute,
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextButton(
              onPressed: () => _pickReciter(riwaya),
              child: Text(
                reciter?.nameFr ?? S.choisirRecitateur,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
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
          if (widget.ayahStart == 1 &&
              SurahMetadataService.bismillahPre(widget.sourate.id))
            const BismillahLine(),
          Divider(color: cs.outlineVariant),
        ],
      ),
    );
  }
}
