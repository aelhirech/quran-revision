import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/reciters.dart';
import '../core/strings.dart';
import '../models/riwaya.dart';
import '../models/sourate.dart';
import '../services/audio_download_service.dart';
import '../services/quran_audio_handler.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import 'audio_download_button.dart';
import 'reciter_picker_sheet.dart';
import 'verse_range_slider.dart';

/// Loop playback bar of the Quran view: reciter, loop, download, and the
/// portion of the displayed range to loop on (US-11).
class VerseAudioBar extends StatefulWidget {
  final Sourate sourate;
  final int ayahStart;
  final int ayahEnd;

  const VerseAudioBar({
    super.key,
    required this.sourate,
    required this.ayahStart,
    required this.ayahEnd,
  });

  @override
  State<VerseAudioBar> createState() => _VerseAudioBarState();
}

class _VerseAudioBarState extends State<VerseAudioBar> {
  Reciter? _reciter;
  bool _starting = false;
  Riwaya? _riwayaForReciter;

  // Never persisted: each opening restarts from the displayed range (US-11 crit. 5).
  late RangeValues _portion =
      RangeValues(widget.ayahStart.toDouble(), widget.ayahEnd.toDouble());

  int get _audioStart => _portion.start.round();
  int get _audioEnd => _portion.end.round();

  /// The player's loop when it belongs to this view — same reciter and surah,
  /// range within the displayed one. Covers a sub-portion started before the
  /// view was closed and reopened (US-11 crit. 4 with crit. 5).
  AudioLoop? get _ownLoop {
    final loop = QuranAudioHandler.currentLoop;
    final reciter = _reciter;
    if (loop == null || reciter == null) return null;
    final isOwn = loop.reciterId == reciter.id &&
        loop.surahId == widget.sourate.id &&
        loop.start >= widget.ayahStart &&
        loop.end <= widget.ayahEnd;
    return isOwn ? loop : null;
  }

  bool _playsPortion(AudioLoop loop) =>
      loop.start == _audioStart && loop.end == _audioEnd;

  Future<void> _ensureReciterLoaded(Riwaya riwaya) async {
    if (_riwayaForReciter == riwaya) return;
    _riwayaForReciter = riwaya;
    final saved = await StorageService.loadAudioReciter(riwaya);
    // A newer call for a different riwaya may have started (and even
    // resolved) while this one was awaiting storage — applying this result
    // would overwrite that more recent one with a stale reciter.
    if (_riwayaForReciter != riwaya) return;
    final reciter = (saved != null ? reciterById(saved) : null) ?? defaultReciterFor(riwaya);
    if (!mounted) return;
    setState(() => _reciter = reciter);
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
    final own = _ownLoop;
    // Paused on another portion: the next tap starts the new one. Playing on
    // another portion (reopened view): the pause icon is shown, so pause.
    if (own != null && (handler.playing || _playsPortion(own))) {
      await (handler.playing ? handler.pause() : handler.play());
      return;
    }
    await _startLoop(reciter);
  }

  Future<void> _startLoop(Reciter reciter) async {
    setState(() => _starting = true);
    // Snapshot: the slider may move while sources load; this start must
    // describe the portion it actually plays.
    final start = _audioStart;
    final end = _audioEnd;
    var started = false;
    try {
      final sources = await AudioDownloadService.instance
          .playableSources(reciter, widget.sourate.id, start, end);
      if (!mounted) return;
      if (sources == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.audioIndisponibleHorsConnexion)));
        // The previous loop keeps playing: show the portion it plays.
        final own = _ownLoop;
        if (own != null) {
          setState(() => _portion =
              RangeValues(own.start.toDouble(), own.end.toDouble()));
        }
        return;
      }
      await QuranAudioHandler.instance.playLoop(
        loop: (reciterId: reciter.id, surahId: widget.sourate.id, start: start, end: end),
        sources: sources,
        item: MediaItem(
          id: '${reciter.id}_${widget.sourate.id}_${start}_$end',
          title: '${widget.sourate.nameFr} · ${S.blocRange(start, end)}',
          artist: reciter.nameFr,
        ),
      );
      started = true;
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.audioErreurLecture)));
      }
    } finally {
      if (mounted) {
        setState(() => _starting = false);
        // The portion may have moved again while this start was in flight.
        // Never after a failure: retrying the same unplayable request would
        // loop forever (e.g. offline with a reciter that isn't downloaded).
        if (started) _followPortionIfPlaying();
      }
    }
  }

  /// Restarts the loop on the current portion when this bar's loop is the one
  /// playing — playLoop replaces the playlist, so there is no in-place edit.
  void _followPortionIfPlaying() {
    final reciter = _reciter;
    final own = _ownLoop;
    if (reciter == null || own == null || _starting) return;
    if (!QuranAudioHandler.instance.playing) return;
    if (_playsPortion(own)) return;
    _startLoop(reciter);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureReciterLoaded(context.watch<AppState>().riwaya);
  }

  @override
  Widget build(BuildContext context) {
    final riwaya = context.watch<AppState>().riwaya;
    final reciter = _reciter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StreamBuilder<PlaybackState>(
                stream: QuranAudioHandler.playbackStateStream,
                builder: (context, snapshot) {
                  final ownsLoop = _ownLoop != null;
                  final playing = ownsLoop && (snapshot.data?.playing ?? false);
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
                      if (ownsLoop) ...[
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
              if (reciter != null)
                AudioDownloadButton(
                  // Fresh state per reciter/surah: no stale "available" carried over.
                  key: ValueKey((reciter.id, widget.sourate.id)),
                  reciter: reciter,
                  sourate: widget.sourate,
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
          if (widget.ayahEnd > widget.ayahStart)
            VerseRangeSlider(
              min: widget.ayahStart,
              max: widget.ayahEnd,
              values: _portion,
              onChanged: (v) => setState(() => _portion = v),
              onChangeEnd: (_) => _followPortionIfPlaying(),
            ),
        ],
      ),
    );
  }
}
