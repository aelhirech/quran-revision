import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quran_revision/core/reciters.dart';
import 'package:quran_revision/services/audio_download_service.dart';

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
