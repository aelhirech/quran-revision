import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/reciters.dart';
import 'package:quran_revision/models/riwaya.dart';

void main() {
  group('recitersFor', () {
    test('never returns a cross-riwaya reciter', () {
      for (final r in recitersFor(Riwaya.hafs)) {
        expect(r.riwaya, Riwaya.hafs);
      }
      for (final r in recitersFor(Riwaya.warsh)) {
        expect(r.riwaya, Riwaya.warsh);
      }
    });

    test('every reciter id is unique across the catalog', () {
      final ids = kReciters.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('defaultReciterFor', () {
    test('picks a reciter that actually belongs to the riwaya', () {
      expect(defaultReciterFor(Riwaya.hafs).riwaya, Riwaya.hafs);
      expect(defaultReciterFor(Riwaya.warsh).riwaya, Riwaya.warsh);
    });
  });

  group('reciterById', () {
    test('resolves a known id and returns null for an unknown one', () {
      expect(reciterById('husary.t')?.riwaya, Riwaya.hafs);
      expect(reciterById('dosary')?.riwaya, Riwaya.warsh);
      expect(reciterById('not-a-real-id'), isNull);
    });
  });

  group('audioTrackUrls', () {
    final reciter = reciterById('husary.t')!;

    test('builds one zero-padded url per verse, in order', () {
      final urls = audioTrackUrls(reciter, 1, 1, 3);
      expect(urls, [
        'https://quran.ksu.edu.sa/ayat/mp3/Hussary.teacher_64kbps/001001.mp3',
        'https://quran.ksu.edu.sa/ayat/mp3/Hussary.teacher_64kbps/001002.mp3',
        'https://quran.ksu.edu.sa/ayat/mp3/Hussary.teacher_64kbps/001003.mp3',
      ]);
    });

    test('pads a two-digit surah id to three digits', () {
      final urls = audioTrackUrls(reciter, 12, 5, 5);
      expect(urls, ['https://quran.ksu.edu.sa/ayat/mp3/Hussary.teacher_64kbps/012005.mp3']);
    });

    test('a single verse produces a single url', () {
      expect(audioTrackUrls(reciter, 114, 1, 1).length, 1);
    });
  });
}
