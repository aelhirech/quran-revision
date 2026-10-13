import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/services/word_gloss_service.dart';

import 'test_helpers.dart';

int _wordCount(String verse) =>
    verse.split(' ').where((token) => bareWord(token).isNotEmpty).length;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HafsService.initialize();
  });

  test('1. aucun sens avant le chargement, 77 429 après', () async {
    expect(WordGlossService.glosses(112, 1), isNull);
    await WordGlossService.load();
    var total = 0;
    HafsService.verseCounts.forEach((surah, verses) {
      for (var ayah = 1; ayah <= verses; ayah++) {
        total += WordGlossService.glosses(surah, ayah)?.length ?? 0;
      }
    });
    expect(total, 77429);
  });

  // The engine pairs words and meanings by rank: these seven verses are the
  // only ones it must leave out. A new source for the Arabic text would
  // change this list.
  test('2. un sens par mot du verset, sauf dans sept versets', () async {
    await WordGlossService.load();
    final misaligned = <(int, int)>[];
    HafsService.verseCounts.forEach((surah, verses) {
      for (var ayah = 1; ayah <= verses; ayah++) {
        final glosses = WordGlossService.glosses(surah, ayah);
        expect(glosses, isNotNull, reason: '$surah:$ayah');
        expect(glosses!.every((gloss) => gloss.isNotEmpty), isTrue,
            reason: '$surah:$ayah');
        if (glosses.length != _wordCount(HafsService.getVerse(surah, ayah))) {
          misaligned.add((surah, ayah));
        }
      }
    });
    expect(misaligned, [(2, 181), (8, 6), (13, 37), (15, 7), (27, 20), (36, 22), (37, 130)]);
  });

  // The source writes no-break spaces before ":" and after "«": kept as is.
  test('3. les sens sont ceux de la source, sans retouche', () async {
    await WordGlossService.load();
    expect(WordGlossService.glosses(112, 1),
        ['Dis\u00A0:', '«\u00A0Il (est)', 'Allâh,', 'Un.']);
    expect(WordGlossService.glosses(17, 79)!.first, 'Et parmi ');
  });

  test('4. disponible en français et en Hafs seulement', () {
    expect(WordGlossService.availableFor('fr', Riwaya.hafs), isTrue);
    expect(WordGlossService.availableFor('en', Riwaya.hafs), isFalse);
    expect(WordGlossService.availableFor('fr', Riwaya.warsh), isFalse);
  });
}
