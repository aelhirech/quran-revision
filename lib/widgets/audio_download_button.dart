import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/reciters.dart';
import '../core/strings.dart';
import '../models/sourate.dart';
import '../services/audio_download_service.dart';

/// Downloads the WHOLE surah for [reciter], whatever range the sheet shows
/// (US-10 criterion 1). Three states: download / progress / available.
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
  // closed, sheet.
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
    final failure = await _service.downloadSurah(
        widget.reciter, widget.sourate.id, widget.sourate.verses);
    if (failure == null || !mounted) return;
    final message = switch (failure) {
      DownloadFailure.notOnWifi => S.audioTelechargementWifi,
      DownloadFailure.interrupted => S.audioErreurTelechargement,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SurahDownload?>(
      valueListenable: _service.current,
      builder: (context, running, _) {
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
                  // 0 done (Wi-Fi check, first verse) spins instead of an empty ring.
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
        return IconButton(
          // Another surah downloading: one download at a time.
          onPressed: running == null ? _download : null,
          icon: const Icon(Icons.download_for_offline_outlined),
          tooltip: S.telechargerSourate,
        );
      },
    );
  }
}
