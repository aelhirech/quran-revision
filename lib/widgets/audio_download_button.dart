import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/reciters.dart';
import '../core/strings.dart';
import '../models/sourate.dart';
import '../services/audio_download_service.dart';

/// Why a queued download isn't running — shared with the Settings card.
String queuedStateLabel(DownloadFailure? blockedBy) => switch (blockedBy) {
      DownloadFailure.notOnWifi => S.audioEtatAttenteWifi,
      DownloadFailure.storageFull => S.audioEtatEspacePlein,
      _ => S.audioEtatAttente,
    };

/// Downloads the WHOLE surah for [reciter], whatever range the sheet shows
/// (US-10 criterion 1). Four states: download / progress / queued / available.
class AudioDownloadButton extends StatefulWidget {
  final Reciter reciter;
  final Sourate sourate;

  const AudioDownloadButton({super.key, required this.reciter, required this.sourate});

  @override
  State<AudioDownloadButton> createState() => _AudioDownloadButtonState();
}

class _AudioDownloadButtonState extends State<AudioDownloadButton> {
  final _service = AudioDownloadService.instance;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _service.current.addListener(_onDownloadChanged);
    _refreshComplete();
  }

  @override
  void dispose() {
    _service.current.removeListener(_onDownloadChanged);
    super.dispose();
  }

  // Also catches the end of a download started from an earlier, since
  // closed, sheet — or from Settings.
  void _onDownloadChanged() {
    if (_service.current.value == null) _refreshComplete();
  }

  // The parent keys this widget by (reciter, surah), so a reciter change
  // builds a new State instead of reusing this one.
  Future<void> _refreshComplete() async {
    final complete = await _service.isSurahComplete(
        widget.reciter, widget.sourate.id, widget.sourate.verses);
    if (!mounted) return;
    setState(() => _complete = complete);
  }

  Future<void> _download() async {
    final startsNow = await _service.queueSurah(widget.reciter, widget.sourate.id);
    if (startsNow || !mounted) return;
    _showSnack(S.audioEnAttenteWifi);
  }

  void _showSnack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_service.current, _service.pending, _service.blockedBy]),
      builder: (context, _) {
        final running = _service.current.value;
        if (running != null && running.isFor(widget.reciter, widget.sourate.id)) {
          return Tooltip(
            message: S.telechargementEnCours(running.done, running.total),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  // 0 done (network check, first verse) spins instead of an empty ring.
                  value: running.done == 0 ? null : running.done / running.total,
                ),
              ),
            ),
          );
        }
        if (_complete) {
          return IconButton(
            onPressed: null,
            icon: Icon(Icons.offline_pin, color: context.palette.primary),
            tooltip: S.disponibleHorsConnexion,
          );
        }
        if (_service.isQueued(widget.reciter, widget.sourate.id)) {
          final reason = queuedStateLabel(_service.blockedBy.value);
          // Tooltips need a long press on a phone: a tap tells why it waits.
          return IconButton(
            onPressed: () => _showSnack(reason),
            icon: const Icon(Icons.schedule),
            tooltip: reason,
          );
        }
        return IconButton(
          onPressed: _download,
          icon: const Icon(Icons.download_for_offline_outlined),
          tooltip: S.telechargerSourate,
        );
      },
    );
  }
}
