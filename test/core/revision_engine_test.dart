import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/revision_engine.dart';
import 'package:quran_revision/models/prayer.dart';
import 'package:quran_revision/models/sourate.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';

Sourate _sourate(int id, int verses, int words) =>
    Sourate(id: id, nameAr: 'س$id', nameFr: 'S$id', verses: verses, words: words);

void main() {
  group('RevisionEngine.buildDayPlan — rythme par durée (par défaut)', () {
    test('un seul unité/jour reste possible quand le cycle est long', () {
      final selections = [
        SourateSelection.whole(_sourate(1, 5, 50)),
        SourateSelection.whole(_sourate(2, 5, 50)),
        SourateSelection.whole(_sourate(3, 5, 50)),
      ];
      final config = UserConfig(
        selections: selections,
        revisionDays: 30,
        startDate: DateTime(2026, 1, 1),
        shuffleEnabled: false,
      );
      final session = RevisionEngine.buildDayPlan(
        config: config,
        prayersAlone: [Prayer.fajr],
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
      );
      // Avec 3 unités et 30 jours restants, la cible du jour est 1 unité —
      // elle est répétée dans toutes les rakaas récitées de la prière.
      expect(session.totalUnits, 1);
      final surats = session.plan.first.rakaas
          .where((r) => r.unit != null)
          .map((r) => r.unit!.sourate.id)
          .toSet();
      expect(surats, {1});
    });
  });

  group('RevisionEngine.buildDayPlan — rythme par lignes/jour', () {
    test('assemble plusieurs unités/jour pour atteindre le seuil de lignes', () {
      // ~8,5 mots/ligne : chaque sourate ci-dessous fait ~5 lignes.
      final selections = [
        SourateSelection.whole(_sourate(1, 5, 42)),
        SourateSelection.whole(_sourate(2, 5, 42)),
        SourateSelection.whole(_sourate(3, 5, 42)),
        SourateSelection.whole(_sourate(4, 5, 42)),
      ];
      final config = UserConfig(
        selections: selections,
        revisionDays: 30,
        startDate: DateTime(2026, 1, 1),
        shuffleEnabled: false,
        paceByLines: true,
        targetLinesPerDay: 12,
      );
      final session = RevisionEngine.buildDayPlan(
        config: config,
        // 2 prières pour avoir assez de rakaas à voix haute (4) et laisser
        // les 3 unités du jour apparaître quelque part dans le plan.
        prayersAlone: [Prayer.fajr, Prayer.dhuhr],
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
      );
      // ~5 lignes/unité, seuil 12 → il faut 3 unités pour dépasser le seuil.
      expect(session.totalUnits, 3);
      final surats = session.plan
          .expand((p) => p.rakaas)
          .where((r) => r.unit != null)
          .map((r) => r.unit!.sourate.id)
          .toSet();
      expect(surats, {1, 2, 3});
    });

    test('avance dans le cycle cycliquement à partir de cyclePosition', () {
      final selections = [
        SourateSelection.whole(_sourate(1, 5, 42)),
        SourateSelection.whole(_sourate(2, 5, 42)),
        SourateSelection.whole(_sourate(3, 5, 42)),
      ];
      final config = UserConfig(
        selections: selections,
        revisionDays: 30,
        startDate: DateTime(2026, 1, 1),
        shuffleEnabled: false,
        paceByLines: true,
        targetLinesPerDay: 100, // au-delà du total dispo → tout le cycle
      );
      final session = RevisionEngine.buildDayPlan(
        config: config,
        prayersAlone: [Prayer.fajr],
        cyclePosition: 1,
        today: DateTime(2026, 1, 1),
      );
      expect(session.totalUnits, 3);
    });
  });

  group('RevisionEngine.buildDayPlan — cas limites', () {
    test('aucune sourate sélectionnée ne fait pas planter (division par zéro)', () {
      final config = UserConfig(
        selections: const [],
        revisionDays: 30,
        startDate: DateTime(2026, 1, 1),
      );
      final session = RevisionEngine.buildDayPlan(
        config: config,
        prayersAlone: [Prayer.fajr],
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
      );
      expect(session.totalUnits, 0);
      expect(session.cycleTotal, 0);
      // Toutes les rakaas restent "Al-Fatiha seule" (aucune unité à assigner).
      expect(session.plan.first.rakaas.every((r) => r.unit == null), isTrue);
    });
  });
}
