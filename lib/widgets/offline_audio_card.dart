import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/reciters.dart';
import '../core/strings.dart';
import '../services/audio_download_service.dart';
import '../services/audio_prefs.dart';
import '../state/app_state.dart';
import 'audio_download_button.dart';
import 'confirm_dialog.dart';

/// Settings for offline listening (US-10 Sprint B): mobile data rule, whole
/// Quran download, and one row per reciter stored on the phone.
class OfflineAudioCard extends StatefulWidget {
  const OfflineAudioCard({super.key});

  @override
  State<OfflineAudioCard> createState() => _OfflineAudioCardState();
}

class _OfflineAudioCardState extends State<OfflineAudioCard> {
  final _service = AudioDownloadService.instance;
  bool _allowMobile = false;
  Map<String, int> _bytesByReciter = const {};

  @override
  void initState() {
    super.initState();
    AudioPrefs.loadAllowMobileDownload().then((v) {
      if (mounted) setState(() => _allowMobile = v);
    });
    _service.current.addListener(_onCurrentChanged);
    // A surah already downloading at mount must still refresh when it ends.
    _downloadingReciterId = _service.current.value?.reciterId;
    _refreshUsage();
  }

  @override
  void dispose() {
    _service.current.removeListener(_onCurrentChanged);
    super.dispose();
  }

  String? _downloadingReciterId;

  // Once per finished surah, and only for its reciter: this card stays
  // mounted (IndexedStack), and a full Quran download finishes 114 surahs.
  void _onCurrentChanged() {
    final running = _service.current.value;
    if (running != null) {
      _downloadingReciterId = running.reciterId;
      return;
    }
    final finished = reciterById(_downloadingReciterId ?? '');
    _downloadingReciterId = null;
    if (finished != null) _refreshUsage(only: finished);
  }

  Future<void> _refreshUsage({Reciter? only}) async {
    final usage = {..._bytesByReciter};
    for (final reciter in only != null ? [only] : kReciters) {
      final bytes = await _service.reciterDiskUsage(reciter);
      bytes > 0 ? usage[reciter.id] = bytes : usage.remove(reciter.id);
    }
    if (!mounted) return;
    setState(() => _bytesByReciter = usage);
  }

  Future<void> _toggleMobile(bool allow) async {
    setState(() => _allowMobile = allow);
    await AudioPrefs.saveAllowMobileDownload(allow);
    // A queue waiting for Wi-Fi may now go.
    if (allow) unawaited(_service.resumePending());
  }

  Future<void> _downloadWholeQuran() async {
    final reciter = await AudioPrefs.chosenReciter(context.read<AppState>().riwaya);
    if (!mounted) return;
    final confirmed = await confirmDialog(
      context,
      title: S.telechargerToutLeCoran,
      message: S.telechargerToutConfirm(reciter.nameFr),
      confirmLabel: S.telecharger,
    );
    if (!confirmed || !mounted) return;
    final startsNow = await _service.queueReciter(reciter);
    if (startsNow || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.audioEnAttenteWifi)));
  }

  Future<void> _delete(Reciter reciter) async {
    final confirmed = await confirmDialog(
      context,
      title: S.supprimerAudioTitre(reciter.nameFr),
      message: S.supprimerAudioConfirm(S.tailleAudio(_bytesByReciter[reciter.id] ?? 0)),
      confirmLabel: S.supprimer,
      danger: true,
    );
    if (!confirmed) return;
    await _service.deleteReciter(reciter);
    await _refreshUsage(only: reciter);
  }

  String _stateLabel(Reciter reciter) {
    final running = _service.current.value;
    if (running != null && running.reciterId == reciter.id) {
      return S.audioEtatEnCours(running.surahId, running.done, running.total);
    }
    if (!_service.isReciterQueued(reciter)) return S.audioEtatPret;
    return queuedStateLabel(_service.blockedBy.value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListenableBuilder(
        listenable: Listenable.merge([_service.current, _service.pending, _service.blockedBy]),
        builder: (context, _) {
          // A reciter queued with nothing on disk yet still gets its row:
          // otherwise "download all" would vanish while it waits for Wi-Fi.
          final reciters = kReciters
              .where((r) => _bytesByReciter.containsKey(r.id) || _service.isReciterQueued(r))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(S.ecouteHorsConnexion,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
              ),
              SwitchListTile(
                secondary: Icon(Icons.signal_cellular_alt, color: cs.primary),
                title: Text(S.autoriserDonneesMobiles),
                subtitle: Text(S.autoriserDonneesMobilesDetail),
                value: _allowMobile,
                onChanged: _toggleMobile,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.download_for_offline_outlined, color: cs.primary),
                title: Text(S.telechargerToutLeCoran),
                subtitle: Text(S.telechargerToutLeCoranDetail),
                onTap: _downloadWholeQuran,
              ),
              for (final reciter in reciters) ...[
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.headphones_outlined, color: cs.primary),
                  title: Text(reciter.nameFr),
                  subtitle: Text(
                      '${S.tailleAudio(_bytesByReciter[reciter.id] ?? 0)} · ${_stateLabel(reciter)}'),
                  trailing: IconButton(
                    onPressed: () => _delete(reciter),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: S.supprimer,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
