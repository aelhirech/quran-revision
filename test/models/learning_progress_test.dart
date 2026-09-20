import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/models/learning_progress.dart';
import 'package:quran_revision/models/sourate.dart';

Sourate _sourate(int id, int verses) =>
    Sourate(id: id, nameAr: 'س', nameFr: 'S$id', verses: verses, words: verses * 10);

void main() {
  group('LearningProgress.daysToFinish (US-1 crit. 5)', () {
    test('arrondit au jour supérieur (un reste occupe un jour entier)', () {
      final p = LearningProgress(
          sourate: _sourate(1, 10),
          learnedVerses: {1, 2, 3},
          startDate: DateTime(2026, 1, 1));
      // 7 versets restants, 3/jour => ceil(7/3) = 3
      expect(p.daysToFinish(3), 3);
    });

    test('sourate déjà complète', () {
      final p = LearningProgress(
          sourate: _sourate(2, 5),
          learnedVerses: {1, 2, 3, 4, 5},
          startDate: DateTime(2026, 1, 1));
      expect(p.daysToFinish(2), 0);
    });

    test('rythme nul ou absurde ne divise pas par zéro', () {
      final p = LearningProgress(
          sourate: _sourate(3, 5),
          learnedVerses: {},
          startDate: DateTime(2026, 1, 1));
      expect(p.daysToFinish(0), 0);
      expect(p.daysToFinish(-1), 0);
    });
  });
}
