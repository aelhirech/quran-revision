import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/reciters.dart';

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

enum DownloadFailure { notOnWifi, interrupted }

/// Offline copies of KSU recitations (US-10). Single instance, like
/// `QuranAudioHandler`: it owns the one download in progress, exposed through
/// [current] so any open `VerseBottomSheet` can show it.
///
/// "Downloaded" is read from the disk and nothing else: each verse is written
/// as `.part` then renamed, so an `.mp3` on disk is always a complete file —
/// no flag or table exists that could drift from what's really stored.
class AudioDownloadService {
  AudioDownloadService._();
  static final AudioDownloadService instance = AudioDownloadService._();

  @visibleForTesting
  AudioDownloadService.withRoot(Directory root) : _root = root;

  final ValueNotifier<SurahDownload?> current = ValueNotifier(null);
  Directory? _root;

  // Cache dir, not Application Support: ~1 GB per reciter must not end up in
  // the user's iCloud backup. The OS may purge it; a purged verse simply
  // falls back to streaming.
  Future<Directory> _rootDir() async => _root ??=
      Directory(p.join((await getApplicationCacheDirectory()).path, 'quran_audio'));

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

  Future<bool> isSurahComplete(Reciter reciter, int surahId, int verseCount) async {
    final local = await _localTrackNames(await _surahDir(reciter, surahId));
    for (var ayah = 1; ayah <= verseCount; ayah++) {
      if (!local.contains(audioTrackFileName(ayah))) return false;
    }
    return true;
  }

  // An unknown state (plugin failure) reads as online but not on Wi-Fi:
  // playback then tries to stream as before US-10, and a download is refused
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

  Future<bool> _isOnWifi() async {
    final connections = await _connections();
    return connections.contains(ConnectivityResult.wifi) ||
        connections.contains(ConnectivityResult.ethernet);
  }

  /// Downloads every verse of the surah not yet on disk, one after another
  /// (sequential on purpose: KSU is an undocumented source, no parallel
  /// burst). Verses already there are skipped — that's how an interrupted
  /// download resumes. Wi-Fi is checked once, at start only. Null on success,
  /// and also when another download already runs (the UI disables the
  /// button then, so there is nothing to report).
  Future<DownloadFailure?> downloadSurah(
      Reciter reciter, int surahId, int verseCount) async {
    if (current.value != null) return null;
    // Claimed before the first await so a second tap can't start a parallel run.
    current.value = SurahDownload(reciter.id, surahId, 0, verseCount);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      if (!await _isOnWifi()) return DownloadFailure.notOnWifi;
      final dir = await _surahDir(reciter, surahId);
      await dir.create(recursive: true);
      final local = await _localTrackNames(dir);
      final urls = audioTrackUrls(reciter, surahId, 1, verseCount);
      for (var ayah = 1; ayah <= verseCount; ayah++) {
        final name = audioTrackFileName(ayah);
        if (!local.contains(name)) {
          await _downloadTrack(client, urls[ayah - 1], File(p.join(dir.path, name)));
        }
        current.value = SurahDownload(reciter.id, surahId, ayah, verseCount);
      }
      return null;
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
}
