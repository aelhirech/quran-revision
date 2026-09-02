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

  // Ci-dessous : tests de régression écrits avant refonte de RevisionEngine
  // (règle test/CLAUDE.md) pour verrouiller des comportements jusqu'ici non
  // couverts — voir docs/DOCUMENTATION_TECHNIQUE.md §11 "ne couvre pas".

  group('RevisionEngine.buildUnits — découpage par limite de mots (150)', () {
    test('une sélection > 150 mots est découpée en chunks contigus sans trou ni recouvrement', () {
      final sel = SourateSelection.whole(_sourate(1, 40, 320));
      final units = RevisionEngine.buildUnits([sel]);

      expect(units.length, 3);
      expect(units.map((u) => [u.verseStart, u.verseEnd]).toList(), [
        [1, 14],
        [15, 28],
        [29, 40],
      ]);
      expect(units.every((u) => u.isWhole), isFalse);
      // Couverture exacte de la plage d'origine, sans trou ni chevauchement.
      for (int i = 0; i < units.length - 1; i++) {
        expect(units[i + 1].verseStart, units[i].verseEnd + 1);
      }
      expect(units.first.verseStart, 1);
      expect(units.last.verseEnd, 40);
    });

    test('une sélection <= 150 mots reste une unité entière', () {
      final sel = SourateSelection.whole(_sourate(1, 10, 100));
      final units = RevisionEngine.buildUnits([sel]);
      expect(units.length, 1);
      expect(units.single.isWhole, isTrue);
    });
  });

  group('RevisionEngine.selectDayUnits — shuffle déterministe', () {
    test('même config (même startDate) → même ordre à chaque appel', () {
      final selections = List.generate(
          8, (i) => SourateSelection.whole(_sourate(i + 1, 5, 50)));
      final config = UserConfig(
        selections: selections,
        revisionDays: 30,
        startDate: DateTime(2026, 3, 4),
        shuffleEnabled: true,
      );
      final a = RevisionEngine.selectDayUnits(
          config: config, cyclePosition: 0, today: DateTime(2026, 3, 5));
      final b = RevisionEngine.selectDayUnits(
          config: config, cyclePosition: 0, today: DateTime(2026, 3, 5));

      expect(a.cycleTotal, b.cycleTotal);
      expect(a.daysRemaining, b.daysRemaining);
      expect(
        a.units.map((u) => u.sourate.id).toList(),
        b.units.map((u) => u.sourate.id).toList(),
      );
    });
  });

  group('RevisionEngine.distributeToRakaas — jamais de rakaa vide malgré la pénurie', () {
    test('1 seule unité disponible pour 5 rakaas à voix haute réparties sur 2 prières', () {
      final units = RevisionEngine.buildUnits(
          [SourateSelection.whole(_sourate(1, 1, 5))]);
      final plan = RevisionEngine.distributeToRakaas(
        units: units,
        prayersAlone: [Prayer.witr, Prayer.fajr], // suratRakaas 3 + 2 = 5
      );
      final suratRakaas = plan
          .expand((p) => p.rakaas.take(p.prayer.suratRakaas))
          .toList();
      expect(suratRakaas.length, 5);
      expect(suratRakaas.every((r) => r.unit != null), isTrue);
      expect(suratRakaas.every((r) => r.unit!.sourate.id == 1), isTrue);
    });
  });

  group('RevisionEngine.distributeToRakaas — no-repeat sourate par prière (S6-B)', () {
    test('assez d\'unités distinctes → chaque rakaa d\'une même prière a une sourate différente', () {
      final units = RevisionEngine.buildUnits([
        SourateSelection.whole(_sourate(1, 1, 5)),
        SourateSelection.whole(_sourate(2, 1, 5)),
      ]);
      final plan = RevisionEngine.distributeToRakaas(
        units: units,
        prayersAlone: [Prayer.fajr], // suratRakaas = 2
      );
      final ids = plan.first.rakaas
          .where((r) => r.unit != null)
          .map((r) => r.unit!.sourate.id)
          .toList();
      expect(ids.toSet(), {1, 2});
      expect(ids.length, ids.toSet().length);
    });

    test('rakaas au-delà de suratRakaas restent "Al-Fatiha seule" (silencieuses)', () {
      final units = RevisionEngine.buildUnits([
        SourateSelection.whole(_sourate(1, 1, 5)),
        SourateSelection.whole(_sourate(2, 1, 5)),
        SourateSelection.whole(_sourate(3, 1, 5)),
      ]);
      final plan = RevisionEngine.distributeToRakaas(
        units: units,
        prayersAlone: [Prayer.dhuhr], // rakaas=4, suratRakaas=2
      );
      final rakaas = plan.first.rakaas;
      expect(rakaas.length, 4);
      expect(rakaas[0].unit, isNotNull);
      expect(rakaas[1].unit, isNotNull);
      expect(rakaas[2].unit, isNull);
      expect(rakaas[3].unit, isNull);
    });
  });

  group('RevisionEngine.distributeToRakaas — subdivision en rakaas (_expandToRakaas)', () {
    test('assez de lignes/slot (>= 5) → la sourate est subdivisée en plages contiguës', () {
      // 10 versets, 100 mots → ~11.76 lignes ; 2 slots → ~5.88 lignes/slot (>= 5).
      final units = RevisionEngine.buildUnits(
          [SourateSelection.whole(_sourate(1, 10, 100))]);
      final plan = RevisionEngine.distributeToRakaas(
        units: units,
        prayersAlone: [Prayer.fajr], // suratRakaas = 2, seule prière
      );
      final rakaas = plan.first.rakaas;
      expect(rakaas[0].unit!.verseStart, 1);
      expect(rakaas[0].unit!.verseEnd, 5);
      expect(rakaas[1].unit!.verseStart, 6);
      expect(rakaas[1].unit!.verseEnd, 10);
    });

    test('pas assez de lignes/slot (< 5) → la sourate n\'est pas subdivisée, elle est répétée entière', () {
      // 10 versets, 60 mots → ~7.06 lignes ; 2 slots → ~3.53 lignes/slot (< 5).
      final units = RevisionEngine.buildUnits(
          [SourateSelection.whole(_sourate(1, 10, 60))]);
      final plan = RevisionEngine.distributeToRakaas(
        units: units,
        prayersAlone: [Prayer.fajr],
      );
      final rakaas = plan.first.rakaas;
      expect(rakaas[0].unit!.verseStart, 1);
      expect(rakaas[0].unit!.verseEnd, 10);
      expect(rakaas[1].unit!.verseStart, 1);
      expect(rakaas[1].unit!.verseEnd, 10);
    });
  });

  // Extrait de PlanScreen._coverageForFirstRakaas (sprint "simplify-ayah-facts",
  // 2026-09-02) vers le moteur pur — verrouille le comportement au moment du
  // déplacement (règle test/CLAUDE.md : pas de changement de RevisionEngine
  // sans filet de sécurité).
  group('RevisionEngine.coverageForFirstRakaas — "une part faite" (déclaration manuelle)', () {
    test('n rakaas répétant la même unité (pénurie) → 1 seule unité distincte comptée', () {
      final units = RevisionEngine.buildUnits(
          [SourateSelection.whole(_sourate(1, 1, 5))]);
      final plan = RevisionEngine.distributeToRakaas(
        units: units,
        prayersAlone: [Prayer.witr, Prayer.fajr], // 5 rakaas à voix haute
      );
      final coverage = RevisionEngine.coverageForFirstRakaas(plan, 3);
      expect(coverage.units, 1);
      expect(coverage.coveredUnits.length, 3);
      expect(coverage.coveredUnits.every((u) => u.sourate.id == 1), isTrue);
    });

    test('s\'arrête exactement à n même en traversant plusieurs prières', () {
      final units = RevisionEngine.buildUnits([
        SourateSelection.whole(_sourate(1, 1, 5)),
        SourateSelection.whole(_sourate(2, 1, 5)),
      ]);
      final plan = RevisionEngine.distributeToRakaas(
        units: units,
        // Fajr : 2 rakaas à voix haute (sourates 1 et 2) ; Dhouhr : 2 de plus.
        prayersAlone: [Prayer.fajr, Prayer.dhuhr],
      );
      final coverage = RevisionEngine.coverageForFirstRakaas(plan, 3);
      expect(coverage.coveredUnits.length, 3);
      // Les 2 premières rakaas (Fajr, sourates 1+2) + la 1ère de Dhouhr.
      expect(coverage.coveredUnits[0].sourate.id, 1);
      expect(coverage.coveredUnits[1].sourate.id, 2);
    });

    test('les rakaas silencieuses (unit == null) ne comptent pas dans n', () {
      final units = RevisionEngine.buildUnits(
          [SourateSelection.whole(_sourate(1, 1, 5))]);
      final plan = RevisionEngine.distributeToRakaas(
        units: units,
        // Dhouhr : rakaas=4, suratRakaas=2 → r3/r4 silencieuses, avant Fajr.
        prayersAlone: [Prayer.dhuhr, Prayer.fajr],
      );
      // n=3 force à traverser les 2 rakaas silencieuses de Dhouhr (r3, r4)
      // pour atteindre la 1ère rakaa réelle de Fajr — si le skip comptait à
      // tort les silencieuses dans n, on n'obtiendrait que 2 unités ici.
      final coverage = RevisionEngine.coverageForFirstRakaas(plan, 3);
      expect(coverage.coveredUnits.length, 3);
    });
  });
}
