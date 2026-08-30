import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/freshness_engine.dart';

void main() {
  final today = DateTime(2026, 8, 30);

  group('FreshnessEngine.compute', () {
    test('jamais révisé → frozen', () {
      expect(FreshnessEngine.compute(null, today), FreshnessLevel.frozen);
    });

    test('révisé il y a moins de 7 jours → hot', () {
      final last = today.subtract(const Duration(days: 3));
      expect(FreshnessEngine.compute(last, today), FreshnessLevel.hot);
    });

    test('révisé il y a 7 à 13 jours → cold', () {
      final last = today.subtract(const Duration(days: 10));
      expect(FreshnessEngine.compute(last, today), FreshnessLevel.cold);
    });

    test('révisé il y a 14 jours ou plus → frozen', () {
      final last = today.subtract(const Duration(days: 14));
      expect(FreshnessEngine.compute(last, today), FreshnessLevel.frozen);
    });
  });

  group('FreshnessEngine.computeAll — générique sur la clé', () {
    test('clé int (sourate) — comportement inchangé', () {
      final dates = <int, DateTime>{
        1: today.subtract(const Duration(days: 1)),
        2: today.subtract(const Duration(days: 20)),
      };
      final result = FreshnessEngine.computeAll<int>(dates, today);
      expect(result[1], FreshnessLevel.hot);
      expect(result[2], FreshnessLevel.frozen);
    });

    test('clé String composite (verset) — fonctionne à l\'identique', () {
      final dates = <String, DateTime>{
        '2:255': today.subtract(const Duration(days: 10)),
      };
      final result = FreshnessEngine.computeAll<String>(dates, today);
      expect(result['2:255'], FreshnessLevel.cold);
    });
  });
}
