import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/services/translation_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HafsService.initialize();
    await TranslationService.load('fr');
    await TranslationService.load('en');
  });

  test('a locale that was never loaded has no translation', () {
    expect(TranslationService.verse('de', 112, 1), isNull);
  });

  // The translations are only shown next to Hafs: every Hafs verse must have
  // one, or a verse would silently show no text under it.
  test('every Hafs verse has a non-empty translation in both languages', () {
    for (var surahId = 1; surahId <= 114; surahId++) {
      for (var ayahId = 1; ayahId <= HafsService.verseCounts[surahId]!; ayahId++) {
        for (final locale in ['fr', 'en']) {
          final text = TranslationService.verse(locale, surahId, ayahId);
          expect(text, isNotNull, reason: '$locale $surahId:$ayahId');
          expect(text!.trim(), isNotEmpty, reason: '$locale $surahId:$ayahId');
        }
      }
    }
  });

  // Catches the two files being swapped.
  test('each language reads its own file', () {
    expect(TranslationService.verse('fr', 112, 1), contains('Il est Allah, Unique'));
    expect(TranslationService.verse('en', 112, 1), contains('He is Allah'));
  });
}
