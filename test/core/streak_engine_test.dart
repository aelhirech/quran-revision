import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/streak_engine.dart';

void main() {
  final today = DateTime(2026, 8, 30);

  String d(int daysAgo) =>
      today.subtract(Duration(days: daysAgo)).toIso8601String().substring(0, 10);

  group('StreakEngine.compute', () {
    test('aucune activité → 0', () {
      expect(
        StreakEngine.compute(activeDates: {}, pauseDates: {}, today: today),
        0,
      );
    });

    test('série consécutive jusqu\'à aujourd\'hui', () {
      final active = {d(0), d(1), d(2)};
      expect(
        StreakEngine.compute(activeDates: active, pauseDates: {}, today: today),
        3,
      );
    });

    test('activité seulement hier, rien aujourd\'hui et pas en pause → 0 '
        '(comportement existant : le jour courant doit être actif ou en '
        'pause pour que le décompte démarre, "canStart" seul ne suffit pas)',
        () {
      final active = {d(1), d(2)};
      expect(
        StreakEngine.compute(activeDates: active, pauseDates: {}, today: today),
        0,
      );
    });

    test('un trou non couvert par une pause casse la série', () {
      final active = {d(0), d(2)}; // d(1) manquant, pas en pause
      expect(
        StreakEngine.compute(activeDates: active, pauseDates: {}, today: today),
        1,
      );
    });

    test('un jour de pause ne casse pas la série (mais ne compte pas non plus)', () {
      final active = {d(0), d(2)};
      final pause = {d(1)};
      expect(
        StreakEngine.compute(activeDates: active, pauseDates: pause, today: today),
        2,
      );
    });

    test('aucune activité ni hier ni aujourd\'hui (et pas en pause) → 0', () {
      final active = {d(3)};
      expect(
        StreakEngine.compute(activeDates: active, pauseDates: {}, today: today),
        0,
      );
    });

    test('aujourd\'hui en pause sans aucune activité récente reste à 0', () {
      final active = {d(5)};
      final pause = {d(0)};
      expect(
        StreakEngine.compute(activeDates: active, pauseDates: pause, today: today),
        0,
      );
    });
  });
}
