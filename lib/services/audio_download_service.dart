import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/reciters.dart';
import 'audio_prefs.dart';
import 'quran_audio_handler.dart';
import 'verse_service.dart';

/// The one surah download in progress, and how many of its verses are on disk.
class SurahDownload {
  final String reciterId;
  final int surahId;
  final int done;
  final int total;

  const SurahDownload(this.reciterId, this.surahId, this.done, this.total);

  bool isFor(Reciter reciter, int surahId) =>
      reciterId == reciter.id && this.surahId == surahId;
}

enum DownloadFailure { notOnWifi, storageFull, interrupted }

/// Offline copies of KSU recitations (US-10). Single instance, like
/// `QuranAudioHandler`: it owns the download queue, exposed through
/// [current], [pending] and [blockedBy] so any open view can show it.
///
/// "Downloaded" is read from the disk and nothing else: each verse is written
/// as `.part` then renamed, so an `.mp3` on disk is always a complete file —
/// no flag or table exists that could drift from what's really stored. The
/// queue only remembers what the user asked for, not what is stored.
class AudioDownloadService {
  AudioDownloadService._();
  static final AudioDownloadService instance = AudioDownloadService._();

  @visibleForTesting
  AudioDownloadService.withRoot(Directory root) : _root = root;

  static const int _surahCount = 114;

  final ValueNotifier<SurahDownload?> current = ValueNotifier(null);

  /// Intents not yet complete, oldest first: `'reciterId'` (whole reciter) or
  /// `'reciterId:surahId'`. Mirror of [AudioPrefs.loadPendingDownloads].
  final ValueNotifier<List<String>> pending = ValueNotifier(const []);

  /// Why the last pass stopped with intents left; null when it didn't stop
  /// on a blocking cause (a failing file is skipped, not blocking).
  final ValueNotifier<DownloadFailure?> blockedBy = ValueNotifier(null);

  Directory? _root;
  Future<void>? _loading;
  Future<void>? _pass;
  bool _passRequested = false;
  bool _cancelRequested = false;

  // Cache dir, not Application Support: ~1 GB per reciter must not end up in
  // the user's iCloud backup. The OS may purge it; a purged verse simply
  // falls back to streaming.
  Future<Directory> _rootDir() async => _root ??=
      Directory(p.join((await getApplicationCacheDirectory()).path, 'quran_audio'));

  Future<Directory> _reciterDir(Reciter reciter) async =>
      Directory(p.join((await _rootDir()).path, reciter.id));

  Future<Directory> _surahDir(Reciter reciter, int surahId) async => Directory(
      p.normalize(p.join((await _rootDir()).path, audioSurahRelativeDir(reciter, surahId))));

  /// One directory listing rather than one stat per verse (up to 286).
  Future<Set<String>> _localTrackNames(Directory surahDir) async {
    if (!await surahDir.exists()) return {};
    final entries = await surahDir.list().toList();
    return {
      for (final e in entries)
        if (e.path.endsWith('.mp3')) p.basename(e.path),
    };
  }

  /// One URI per verse: the local file when it's on disk, the KSU URL
  /// otherwise — a partly downloaded range plays mixed. Null when offline
  /// with at least one verse missing: never a partial or silent loop
  /// (US-10 criterion 4).
  Future<List<Uri>?> playableSources(
      Reciter reciter, int surahId, int ayahStart, int ayahEnd) async {
    final dir = await _surahDir(reciter, surahId);
    final local = await _localTrackNames(dir);
    final urls = audioTrackUrls(reciter, surahId, ayahStart, ayahEnd);
    final sources = [
      for (var ayah = ayahStart; ayah <= ayahEnd; ayah++)
        local.contains(audioTrackFileName(ayah))
            ? Uri.file(p.join(dir.path, audioTrackFileName(ayah)))
            : Uri.parse(urls[ayah - ayahStart]),
    ];
    if (sources.any((u) => !u.isScheme('file')) && await _isOffline()) return null;
    return sources;
  }

  Future<bool> isSurahComplete(Reciter reciter, int surahId, int verseCount) async =>
      _hasAllVerses(await _localTrackNames(await _surahDir(reciter, surahId)), verseCount);

  bool _hasAllVerses(Set<String> local, int verseCount) {
    for (var ayah = 1; ayah <= verseCount; ayah++) {
      if (!local.contains(audioTrackFileName(ayah))) return false;
    }
    return true;
  }

  /// Bytes on disk for [reciter], `.part` files included: it's what the
  /// user gets back by deleting.
  Future<int> reciterDiskUsage(Reciter reciter) async {
    final dir = await _reciterDir(reciter);
    if (!await dir.exists()) return 0;
    var bytes = 0;
    try {
      await for (final entry in dir.list(recursive: true)) {
        // stat, not length: a `.part` renamed mid-listing must not throw.
        final stat = await entry.stat();
        if (stat.type == FileSystemEntityType.file) bytes += stat.size;
      }
    } on FileSystemException catch (e) {
      debugPrint('Disk usage listing failed (${reciter.id}): $e');
    }
    return bytes;
  }

  // An unknown state (plugin failure) reads as online but not on Wi-Fi:
  // playback then tries to stream as before US-10, and a download waits
  // rather than risking mobile data on a guess.
  Future<List<ConnectivityResult>> _connections() async {
    try {
      return await Connectivity().checkConnectivity();
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return const [];
    }
  }

  Future<bool> _isOffline() async =>
      (await _connections()).contains(ConnectivityResult.none);

  Future<bool> _networkAllowsDownload() async {
    final connections = await _connections();
    if (connections.contains(ConnectivityResult.wifi) ||
        connections.contains(ConnectivityResult.ethernet)) {
      return true;
    }
    if (connections.isEmpty || connections.contains(ConnectivityResult.none)) return false;
    return AudioPrefs.loadAllowMobileDownload();
  }

  // ── Queue ────────────────────────────────────────────────────────────────

  bool isQueued(Reciter reciter, int surahId) =>
      pending.value.contains(reciter.id) ||
      pending.value.contains('${reciter.id}:$surahId');

  bool isReciterQueued(Reciter reciter) =>
      pending.value.any((intent) => _belongsTo(intent, reciter));

  // Exact id or `id:`: 'husary' must never match 'husary.t'.
  static bool _belongsTo(String intent, Reciter reciter) =>
      intent == reciter.id || intent.startsWith('${reciter.id}:');

  /// Queues the whole surah. Returns whether the network rule lets it start
  /// now — false means it waits for Wi-Fi (or for mobile data to be allowed).
  Future<bool> queueSurah(Reciter reciter, int surahId) =>
      _queue('${reciter.id}:$surahId');

  Future<bool> queueReciter(Reciter reciter) => _queue(reciter.id);

  Future<bool> _queue(String intent) async {
    await _loadPending();
    if (!pending.value.contains(intent)) {
      await _savePending([...pending.value, intent]);
    }
    final allowed = await _networkAllowsDownload();
    unawaited(resumePending());
    return allowed;
  }

  // Memoized future, not a bool: a second caller arriving mid-load would
  // otherwise read the empty list and overwrite the stored queue with it.
  Future<void> _loadPending() => _loading ??=
      AudioPrefs.loadPendingDownloads().then((intents) => pending.value = intents);

  Future<void> _savePending(List<String> intents) {
    pending.value = List.unmodifiable(intents);
    return AudioPrefs.savePendingDownloads(intents);
  }

  /// Runs the queue until empty or blocked. Called at launch, on return from
  /// the background, and after each new intent. Downloads only progress while
  /// the app is in the foreground: iOS suspends it otherwise (US-10 crit. 3).
  /// A call during a pass schedules one more pass rather than a parallel one
  /// — that's how a download cut by the background restarts on return.
  Future<void> resumePending() {
    final running = _pass;
    if (running != null) {
      _passRequested = true;
      return running;
    }
    return _pass = _runPasses().whenComplete(() => _pass = null);
  }

  Future<void> _runPasses() async {
    await _loadPending();
    do {
      _passRequested = false;
      await _runPass();
    } while (_passRequested && !_cancelRequested);
  }

  Future<void> _runPass() async {
    blockedBy.value = null;
    final skipped = <String>{};
    while (!_cancelRequested) {
      final next = pending.value.where((i) => !skipped.contains(i)).firstOrNull;
      if (next == null) return;
      final failure = await _runIntent(next);
      if (failure == null) {
        await _savePending(pending.value.where((i) => i != next).toList());
      } else if (failure == DownloadFailure.interrupted) {
        // A failing file must not hold the rest of the queue: kept, and
        // retried at the next pass.
        skipped.add(next);
      } else {
        // No Wi-Fi or no space: nothing else in the queue could go either.
        blockedBy.value = failure;
        return;
      }
    }
  }

  Future<DownloadFailure?> _runIntent(String intent) async {
    final parts = intent.split(':');
    final reciter = reciterById(parts.first);
    final surahId = parts.length > 1 ? int.tryParse(parts[1]) : null;
    // Reciter gone from the catalog, or a malformed entry: drop the intent.
    if (reciter == null || (parts.length > 1 && surahId == null)) return null;
    if (surahId != null) return _downloadSurah(reciter, surahId);
    DownloadFailure? result;
    for (var id = 1; id <= _surahCount; id++) {
      final failure = await _downloadSurah(reciter, id);
      if (failure == null) continue;
      if (failure != DownloadFailure.interrupted || _cancelRequested) return failure;
      result = failure; // one failing surah doesn't stop the others
    }
    return result;
  }

  /// Downloads every verse of the surah not yet on disk, one after another
  /// (sequential on purpose: KSU is an undocumented source, no parallel
  /// burst). Verses already there are skipped — that's how an interrupted
  /// download resumes. The network rule is checked before each verse, so
  /// leaving Wi-Fi mid-surah stops it instead of going on over mobile data.
  Future<DownloadFailure?> _downloadSurah(Reciter reciter, int surahId) async {
    final verseCount = VerseService.verseCount(surahId, reciter.riwaya);
    final dir = await _surahDir(reciter, surahId);
    final local = await _localTrackNames(dir);
    if (_hasAllVerses(local, verseCount)) return null;
    current.value = SurahDownload(reciter.id, surahId, 0, verseCount);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      await dir.create(recursive: true);
      final urls = audioTrackUrls(reciter, surahId, 1, verseCount);
      for (var ayah = 1; ayah <= verseCount; ayah++) {
        final name = audioTrackFileName(ayah);
        if (!local.contains(name)) {
          if (_cancelRequested) return DownloadFailure.interrupted;
          if (!await _networkAllowsDownload()) return DownloadFailure.notOnWifi;
          await _downloadTrack(client, urls[ayah - 1], File(p.join(dir.path, name)));
        }
        current.value = SurahDownload(reciter.id, surahId, ayah, verseCount);
      }
      return null;
    } on FileSystemException catch (e) {
      // Network errors are Socket/Http/TimeoutException: a file system error
      // while writing is, in practice, a full disk.
      debugPrint('Audio download write failed (${reciter.id}, surah $surahId): $e');
      return DownloadFailure.storageFull;
    } catch (e) {
      debugPrint('Audio download failed (${reciter.id}, surah $surahId): $e');
      return DownloadFailure.interrupted;
    } finally {
      client.close(force: true);
      current.value = null;
    }
  }

  Future<void> _downloadTrack(HttpClient client, String url, File target) async {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: request.uri);
    }
    final part = File('${target.path}.part');
    final sink = part.openWrite();
    try {
      // The timeout catches a stalled connection, which would otherwise hang
      // the whole surah download forever.
      await sink.addStream(response.timeout(const Duration(seconds: 30)));
    } finally {
      // `Stream.pipe` only closes the sink on success: an error would leak
      // the `.part` file handle and block the retry from reopening it.
      await sink.close();
    }
    await part.rename(target.path);
  }

  /// Cancels [reciter]'s download if it runs, forgets its intents and frees
  /// its whole directory. Other reciters' intents resume afterwards.
  Future<void> deleteReciter(Reciter reciter) async {
    await _loadPending();
    await _savePending(pending.value.where((i) => !_belongsTo(i, reciter)).toList());
    final running = _pass;
    if (running != null) {
      // Wait for the verse in flight: deleting under it would fail its
      // rename, which reads as a full disk.
      _cancelRequested = true;
      await running;
      _cancelRequested = false;
    }
    // A loop on local files would fail on its next round once they're gone.
    if (QuranAudioHandler.currentLoop?.reciterId == reciter.id) {
      await QuranAudioHandler.instance.stop();
    }
    final dir = await _reciterDir(reciter);
    if (await dir.exists()) await dir.delete(recursive: true);
    if (running != null) unawaited(resumePending());
  }
}
