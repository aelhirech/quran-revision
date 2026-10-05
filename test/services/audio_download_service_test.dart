import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quran_revision/core/reciters.dart';
import 'package:quran_revision/services/audio_download_service.dart';
import 'package:quran_revision/services/audio_prefs.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;
  late AudioDownloadService service;
  final reciter = reciterById('husary.t')!;

  Future<File> writeTrack(int surahId, int ayahId) async {
    final file = File(p.normalize(p.join(
        root.path, audioSurahRelativeDir(reciter, surahId), audioTrackFileName(ayahId))));
    await file.parent.create(recursive: true);
    return file.writeAsBytes([0]);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('quran_audio_test_');
    service = AudioDownloadService.withRoot(root);
  });

  tearDown(() => root.delete(recursive: true));

  // No connectivity plugin in unit tests: the check fails and reads as
  // online, so these cover the source mix, not the offline refusal.
  group('playableSources', () {
    test('local verse gives a file uri, missing verse gives the KSU url', () async {
      await writeTrack(1, 2);
      final sources = (await service.playableSources(reciter, 1, 1, 3))!;
      expect(sources.map((u) => u.scheme), ['https', 'file', 'https']);
      expect(sources[0].toString(), audioTrackUrls(reciter, 1, 1, 1).single);
      expect(File.fromUri(sources[1]).existsSync(), isTrue);
    });

    test('a leftover .part file is never treated as downloaded', () async {
      final mp3 = await writeTrack(1, 1);
      await mp3.rename('${mp3.path}.part');
      final sources = (await service.playableSources(reciter, 1, 1, 1))!;
      expect(sources.single.scheme, 'https');
    });
  });

  group('reciterDiskUsage', () {
    test('sums every file of the reciter, .part included, and only theirs', () async {
      final mp3 = await writeTrack(1, 1);
      await File('${mp3.path}.part').writeAsBytes([0, 0]);
      await writeTrack(2, 1);
      expect(await service.reciterDiskUsage(reciter), 4);
      expect(await service.reciterDiskUsage(reciterById('afasy')!), 0);
    });
  });

  // Network plugin missing in unit tests: every pass stops on "not on Wi-Fi",
  // which is exactly the "intent waits and stays stored" case.
  group('download queue', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await HafsService.initialize();
    });

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('an intent blocked by the network stays queued and stored', () async {
      final startsNow = await service.queueSurah(reciter, 1);
      await service.resumePending();
      expect(startsNow, isFalse);
      expect(service.blockedBy.value, DownloadFailure.notOnWifi);
      expect(service.isQueued(reciter, 1), isTrue);
      expect(service.isQueued(reciter, 2), isFalse);
      expect(await AudioPrefs.loadPendingDownloads(), ['husary.t:1']);
    });

    test('queueing twice keeps one intent; a whole reciter covers every surah', () async {
      await service.queueSurah(reciter, 1);
      await service.queueSurah(reciter, 1);
      await service.queueReciter(reciter);
      await service.resumePending();
      expect(await AudioPrefs.loadPendingDownloads(), ['husary.t:1', 'husary.t']);
      expect(service.isQueued(reciter, 114), isTrue);
    });

    test('a fully stored surah leaves the queue without any network', () async {
      for (var ayah = 1; ayah <= 7; ayah++) {
        await writeTrack(1, ayah);
      }
      await service.queueSurah(reciter, 1);
      await service.resumePending();
      expect(await AudioPrefs.loadPendingDownloads(), isEmpty);
      expect(service.blockedBy.value, isNull);
    });

    test('deleting a reciter drops its intents and files, not a prefix namesake', () async {
      final husary = reciterById('husary')!;
      await writeTrack(1, 1);
      await service.queueSurah(reciter, 2);
      await service.queueReciter(reciter);
      await service.queueSurah(husary, 2);
      await service.resumePending();
      await service.deleteReciter(reciter);
      expect(await AudioPrefs.loadPendingDownloads(), ['husary:2']);
      expect(await service.reciterDiskUsage(reciter), 0);
    });
  });

  group('isSurahComplete', () {
    test('true only when every verse of the surah is on disk', () async {
      await writeTrack(114, 1);
      await writeTrack(114, 2);
      expect(await service.isSurahComplete(reciter, 114, 3), isFalse);
      await writeTrack(114, 3);
      expect(await service.isSurahComplete(reciter, 114, 3), isTrue);
    });

    test('files of another reciter do not count', () async {
      await writeTrack(114, 1);
      final other = reciterById('afasy')!;
      expect(await service.isSurahComplete(other, 114, 1), isFalse);
    });
  });
}
