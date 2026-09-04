import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/freshness_engine.dart';

void main() {
  final today = DateTime(2026, 8, 30);

  group('FreshnessEngine.computeForRange', () {
    test('aucun verset de la plage jamais révisé → neverRevised', () {
      final level = FreshnessEngine.computeForRange(
        lastRevisionByAyah: const {},
        verseStart: 1,
        verseEnd: 5,
        today: today,
      );
      expect(level, FreshnessLevel.neverRevised);
    });

    test('tous les versets révisés il y a ≤30j → recent', () {
      final level = FreshnessEngine.computeForRange(
        lastRevisionByAyah: {
          1: today.subtract(const Duration(days: 1)),
          2: today.subtract(const Duration(days: 30)),
          3: today.subtract(const Duration(days: 5)),
        },
        verseStart: 1,
        verseEnd: 3,
        today: today,
      );
      expect(level, FreshnessLevel.recent);
    });

    test('un verset récent et un jamais révisé → partiallyRecent', () {
      final level = FreshnessEngine.computeForRange(
        lastRevisionByAyah: {1: today.subtract(const Duration(days: 2))},
        verseStart: 1,
        verseEnd: 2, // verset 2 jamais révisé
        today: today,
      );
      expect(level, FreshnessLevel.partiallyRecent);
    });

    test('un verset récent et un vieux (>30j) → partiallyRecent', () {
      final level = FreshnessEngine.computeForRange(
        lastRevisionByAyah: {
          1: today.subtract(const Duration(days: 2)),
          2: today.subtract(const Duration(days: 100)),
        },
        verseStart: 1,
        verseEnd: 2,
        today: today,
      );
      expect(level, FreshnessLevel.partiallyRecent);
    });

    test('aucun verset récent, le plus récent révisé il y a >30j → oneMonth', () {
      final level = FreshnessEngine.computeForRange(
        lastRevisionByAyah: {1: today.subtract(const Duration(days: 45))},
        verseStart: 1,
        verseEnd: 1,
        today: today,
      );
      expect(level, FreshnessLevel.oneMonth);
    });

    test('plus récent révisé il y a >90j → threeMonths', () {
      final level = FreshnessEngine.computeForRange(
        lastRevisionByAyah: {1: today.subtract(const Duration(days: 91))},
        verseStart: 1,
        verseEnd: 1,
        today: today,
      );
      expect(level, FreshnessLevel.threeMonths);
    });

    test('plus récent révisé il y a >180j → sixMonths', () {
      final level = FreshnessEngine.computeForRange(
        lastRevisionByAyah: {1: today.subtract(const Duration(days: 181))},
        verseStart: 1,
        verseEnd: 1,
        today: today,
      );
      expect(level, FreshnessLevel.sixMonths);
    });

    test('plus récent révisé il y a >365j → oneYear', () {
      final level = FreshnessEngine.computeForRange(
        lastRevisionByAyah: {1: today.subtract(const Duration(days: 400))},
        verseStart: 1,
        verseEnd: 1,
        today: today,
      );
      expect(level, FreshnessLevel.oneYear);
    });

    test('palier choisi sur le verset le plus récent, pas le plus ancien (le moins pire)', () {
      final level = FreshnessEngine.computeForRange(
        lastRevisionByAyah: {
          1: today.subtract(const Duration(days: 400)), // >1an
          2: today.subtract(const Duration(days: 40)), // >30j seulement
        },
        verseStart: 1,
        verseEnd: 2,
        today: today,
      );
      expect(level, FreshnessLevel.oneMonth);
    });

    test('exactement 30j compte comme récent (borne incluse)', () {
      final level = FreshnessEngine.computeForRange(
        lastRevisionByAyah: {1: today.subtract(const Duration(days: 30))},
        verseStart: 1,
        verseEnd: 1,
        today: today,
      );
      expect(level, FreshnessLevel.recent);
    });

    test('versets hors de lastRevisionByAyah ignorés (autre sourate)', () {
      final level = FreshnessEngine.computeForRange(
        lastRevisionByAyah: {
          1: today.subtract(const Duration(days: 1)),
          99: today.subtract(const Duration(days: 400)), // hors plage, sans effet
        },
        verseStart: 1,
        verseEnd: 1,
        today: today,
      );
      expect(level, FreshnessLevel.recent);
    });
  });
}
