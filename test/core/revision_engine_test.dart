import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/revision_engine.dart';
import 'package:quran_revision/models/daily_session.dart';
import 'package:quran_revision/models/prayer.dart';
import 'package:quran_revision/models/revision_unit.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/sourate.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';

Sourate _sourate(int id, int verses, int words) =>
    Sourate(id: id, nameAr: 'س$id', nameFr: 'S$id', verses: verses, words: words);

void main() {
  group('RevisionEngine.buildDayUnits — nouveau moteur pages/jour', () {
    test('une sourate entière tient dans le budget journalier', () async {
      // Sourate 1 = 7 versets, 1 page (d'après les données de test)
      final selections = [
        SourateSelection.whole(_sourate(1, 7, 50)) // 7 versets
      ];
      final config = UserConfig(
        selections: selections,
        pagesPerDay: 2, // Budget de 2 pages/jour
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: false,
      );

      // Mock page metadata: surah 1 has all 7 verses on page 1
      final mockPageMetadata = {
        1: {1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1}
      };

      final selection = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      expect(selection.units.length, 1);
      expect(selection.units.first.sourate.id, 1);
      expect(selection.units.first.verseStart, 1);
      expect(selection.units.first.verseEnd, 7);
      expect(selection.units.first.isWhole, isTrue);
      expect(selection.cycleTotal, 1);
      expect(selection.cyclePosition, 0);
    });

    test('deux sourates tiennent dans le budget journalier', () async {
      // Sourate 1 = 1 page, Sourate 2 = 1 page (d'après les données de test)
      final selections = [
        SourateSelection.whole(_sourate(1, 7, 50)), // 1 page
        SourateSelection.whole(_sourate(2, 7, 50)), // 1 page
      ];
      final config = UserConfig(
        selections: selections,
        pagesPerDay: 2, // Budget de 2 pages/jour
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: false,
      );

      // Pages GLOBALEMENT distinctes (1 et 2) — comme dans le vrai mushaf, où
      // un numéro de page n'appartient qu'à une seule sourate à la fois.
      // Deux sourates réutilisant le même numéro de page seraient regroupées
      // en un seul slot de cycle (voir "regroupement par page partagée",
      // cadrage 2026-09-05) : pas le comportement testé ici.
      final mockPageMetadata = {
        1: {1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1},
        2: {1: 2, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2, 7: 2}
      };

      final selection = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      expect(selection.units.length, 2);
      expect(selection.units[0].sourate.id, 1);
      expect(selection.units[0].verseStart, 1);
      expect(selection.units[0].verseEnd, 7);
      expect(selection.units[0].isWhole, isTrue);
      expect(selection.units[1].sourate.id, 2);
      expect(selection.units[1].verseStart, 1);
      expect(selection.units[1].verseEnd, 7);
      expect(selection.units[1].isWhole, isTrue);
      expect(selection.cycleTotal, 2);
      expect(selection.cyclePosition, 0);
    });

    test('une sourate dépasse le budget et est découpée par pages', () async {
      // Pour ce test, créons une sourate qui dépasse clairement le budget
      // Disons que la sourate 1 occupe 2 pages mais nous n'avons que 1 page de budget
      final selections = [
        SourateSelection.whole(_sourate(1, 7, 50)) // 7 versets
      ];
      final config = UserConfig(
        selections: selections,
        pagesPerDay: 1, // Budget de 1 page/jour
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: false,
      );

      // Mock page metadata: surah 1 spans 2 pages (4 verses on page 1, 3 verses on page 2)
      final mockPageMetadata = {
        1: {1: 1, 2: 1, 3: 1, 4: 1, 5: 2, 6: 2, 7: 2}
      };

      final selection = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      // Avec 1 page de budget et la sourate ayant 4 versets sur la page 1, on prend 4 versets
      expect(selection.units.length, 1);
      expect(selection.units.first.sourate.id, 1);
      expect(selection.units.first.verseStart, 1);
      expect(selection.units.first.verseEnd, 4);
      expect(selection.units.first.isWhole, isFalse);
    });

    test('le shuffle fonctionne au niveau des sourates', () async {
      final selections = List.generate(
          5, (i) => SourateSelection.whole(_sourate(i + 1, 7, 50)));
      final config = UserConfig(
        selections: selections,
        pagesPerDay: 1,
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: true,
      );

      // Mock page metadata: all surahs have 1 verse per page for simplicity
      final mockPageMetadata = <int, Map<int, int>>{};
      for (var i = 0; i < 5; i++) {
        final surahId = i + 1;
        final versesMap = <int, int>{};
        for (var j = 0; j < 7; j++) {
          final verseNum = j + 1;
          // Simple mapping: verse N is on page N
          versesMap[verseNum] = verseNum;
        }
        mockPageMetadata[surahId] = versesMap;
      }

      // Deux appels avec la même configuration doivent produire le même ordre
      final selection1 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );
      final selection2 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      expect(selection1.units.length, selection2.units.length);
      expect(
        selection1.units.map((u) => u.sourate.id).toList(),
        selection2.units.map((u) => u.sourate.id).toList(),
      );
    });

    test('la position dans le cycle est respectée', () async {
      final selections = [
        SourateSelection.whole(_sourate(1, 7, 50)), // index 0
        SourateSelection.whole(_sourate(2, 7, 50)), // index 1
        SourateSelection.whole(_sourate(3, 7, 50)), // index 2
      ];
      final config = UserConfig(
        selections: selections,
        pagesPerDay: 1,
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: false,
      );

      // Chaque sourate tient sur 1 page, mais avec un numéro de page
      // GLOBALEMENT distinct (1/2/3) — sinon les 3 seraient regroupées en un
      // seul slot de cycle (voir "regroupement par page partagée").
      final mockPageMetadata = {
        1: {1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1},
        2: {1: 2, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2, 7: 2},
        3: {1: 3, 2: 3, 3: 3, 4: 3, 5: 3, 6: 3, 7: 3},
      };

      // Position 0 : doit prendre la sourate 1
      final selection0 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      // Position 1 : doit prendre la sourate 2
      final selection1 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 1,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      // Position 2 : doit prendre la sourate 3
      final selection2 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 2,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      expect(selection0.units.first.sourate.id, 1);
      expect(selection1.units.first.sourate.id, 2);
      expect(selection2.units.first.sourate.id, 3);

      // Tous ont cycleTotal = 3
      expect(selection0.cycleTotal, 3);
      expect(selection1.cycleTotal, 3);
      expect(selection2.cycleTotal, 3);
    });

    test('le cycle boucle correctement', () async {
      final selections = [
        SourateSelection.whole(_sourate(1, 7, 50)), // index 0
        SourateSelection.whole(_sourate(2, 7, 50)), // index 1
      ];
      final config = UserConfig(
        selections: selections,
        pagesPerDay: 1,
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: false,
      );

      // Chaque sourate tient sur 1 page, mais avec un numéro de page
      // GLOBALEMENT distinct (1/2) — sinon les 2 seraient regroupées en un
      // seul slot de cycle (voir "regroupement par page partagée").
      final mockPageMetadata = {
        1: {1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1},
        2: {1: 2, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2, 7: 2},
      };

      // Position 0 : sourate 1
      final selection0 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      // Position 1 : sourate 2
      final selection1 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 1,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      // Position 2 : doit boucler à la sourate 0 (2 % 2 = 0)
      final selection2 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 2,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      expect(selection0.units.first.sourate.id, 1);
      expect(selection1.units.first.sourate.id, 2);
      expect(selection2.units.first.sourate.id, 1); // Bouclé à l'index 0

      expect(selection0.cycleTotal, 2);
      expect(selection1.cycleTotal, 2);
      expect(selection2.cycleTotal, 2);
    });

    test('aucune sourate sélectionnée retourne une sélection vide', () async {
      final config = UserConfig(
        selections: [],
        pagesPerDay: 1,
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: false,
      );
      final selection = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: const {},
      );

      expect(selection.units.isEmpty, isTrue);
      expect(selection.cycleTotal, 0);
      expect(selection.cyclePosition, 0);
    });

    test(
        'plusieurs sourates sélectionnées qui tiennent chacune sur 1 page et '
        'partagent le même numéro de page réelle sont regroupées en un seul '
        'slot de cycle (cadrage "regroupement par page partagée", '
        '2026-09-05, ex. Al-Kawthar/Al-Ma\'un/Quraysh sur la même page)',
        () async {
      final selections = [
        SourateSelection.whole(_sourate(106, 4, 20)),
        SourateSelection.whole(_sourate(107, 7, 20)),
        SourateSelection.whole(_sourate(108, 3, 20)),
        // Sourate non voisine, sur sa propre page : ne doit jamais être
        // absorbée dans le groupe des 3 premières.
        SourateSelection.whole(_sourate(2, 5, 50)),
      ];
      final config = UserConfig(
        selections: selections,
        pagesPerDay: 1,
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: false,
      );
      final mockPageMetadata = {
        106: {1: 602, 2: 602, 3: 602, 4: 602},
        107: {1: 602, 2: 602, 3: 602, 4: 602, 5: 602, 6: 602, 7: 602},
        108: {1: 602, 2: 602, 3: 602},
        2: {1: 3, 2: 3, 3: 4, 4: 4, 5: 4},
      };

      final selection = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      expect(selection.units.map((u) => u.sourate.id).toList(), [106, 107, 108],
          reason: 'les 3 sourates de la page 602 sont proposées ensemble, '
              'jamais étalées sur plusieurs jours');
      expect(selection.groups, hasLength(1),
          reason: 'un seul groupe de 3 unités — une seule position de cycle');
      expect(selection.groups.single, hasLength(3));
      expect(selection.cycleTotal, 2,
          reason: '2 slots au total : le groupe de la page 602, et la '
              'sourate 2 (page différente) — pas 4 sourates individuelles');

      // Position 1 (après le groupe) : doit prendre la sourate 2, seule.
      final next = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 1,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );
      expect(next.units.map((u) => u.sourate.id).toList(), [2]);
    });

    test(
        'une sourate non sélectionnée ne rejoint jamais un groupe de page '
        'partagée, même si elle tient sur la même page réelle qu\'une '
        'sourate sélectionnée (tranché au cadrage 2026-09-05)', () async {
      // Seules 106 et 108 sont sélectionnées ; 107 (même page) ne l'est pas.
      final selections = [
        SourateSelection.whole(_sourate(106, 4, 20)),
        SourateSelection.whole(_sourate(108, 3, 20)),
      ];
      final config = UserConfig(
        selections: selections,
        pagesPerDay: 1,
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: false,
      );
      final mockPageMetadata = {
        106: {1: 602, 2: 602, 3: 602, 4: 602},
        107: {1: 602, 2: 602, 3: 602, 4: 602, 5: 602, 6: 602, 7: 602},
        108: {1: 602, 2: 602, 3: 602},
      };

      final selection = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
      );

      expect(selection.units.map((u) => u.sourate.id).toList(), [106, 108],
          reason: '107 (non sélectionnée) absente du plan malgré la page partagée');
      expect(selection.groups, hasLength(1));
      expect(selection.groups.single, hasLength(2));
      expect(selection.cycleTotal, 1);
    });
  });

  // Ancien tests conservés pour régression mais mis à jour pour utiliser le nouveau moteur
  group('RevisionEngine.buildDayPlan — compatibilité avec le nouveau moteur', () {
    test('un seul unité/jour reste possible quand le cycle est long', () async {
      final selections = [
        SourateSelection.whole(_sourate(1, 5, 50)),
        SourateSelection.whole(_sourate(2, 5, 50)),
        SourateSelection.whole(_sourate(3, 5, 50)),
      ];
      final config = UserConfig(
        selections: selections,
        pagesPerDay: 1, // Approximation : 1 page par unité de 5 versets/50 mots
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: false,
      );
      // Chaque sourate mockée sur 2 pages distinctes : avec pagesPerDay=1,
      // la 1re dépasse toujours le budget → toujours exactement 1 unité
      // (partielle) proposée, quelle que soit la sourate en position de cycle.
      final mockPageMetadata = {
        1: {1: 1, 2: 1, 3: 2, 4: 2, 5: 2},
        2: {1: 3, 2: 3, 3: 4, 4: 4, 5: 4},
        3: {1: 5, 2: 5, 3: 6, 4: 6, 5: 6},
      };
      final session = await RevisionEngine.buildDayPlan(
        config: config,
        prayersAlone: [Prayer.fajr],
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: mockPageMetadata,
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

  group('RevisionEngine.distributeToRakaas — apprentissage (Phase 9)', () {
    // Fajr (2 rakaas récitées) + Maghrib (3 rakaas, 2 récitées) = 4 rakaas
    // récitées au total, dont la dernière revient à l'apprentissage.
    final prayers = [Prayer.fajr, Prayer.maghrib];
    final revision = [
      RevisionUnit(
          sourate: _sourate(112, 4, 20), verseStart: 1, verseEnd: 4, isWhole: true),
      RevisionUnit(
          sourate: _sourate(113, 5, 25), verseStart: 1, verseEnd: 5, isWhole: true),
    ];
    final learning = RevisionUnit(
        sourate: _sourate(99, 8, 60), verseStart: 1, verseEnd: 3, isWhole: false);

    List<RakaaAssignment> recited(List<PrayerPlan> plan) => [
          for (final pp in plan)
            for (final r in pp.rakaas)
              if (r.unit != null) r,
        ];

    test("la portion à apprendre occupe la toute dernière rakaa récitée du jour",
        () {
      final plan = RevisionEngine.distributeToRakaas(
        units: revision,
        prayersAlone: prayers,
        learningUnit: learning,
      );

      final filled = recited(plan);
      expect(filled.length, 4); // aucune rakaa récitée laissée vide
      expect(filled.last.isLearning, isTrue);
      expect(filled.last.unit, learning);
      // Toutes les précédentes sont de la révision, jamais l'apprentissage.
      for (final r in filled.take(3)) {
        expect(r.isLearning, isFalse);
        expect(r.unit!.sourate.id, isNot(99));
      }
    });

    test('sans portion à apprendre, la dernière rakaa reste de la révision', () {
      final plan =
          RevisionEngine.distributeToRakaas(units: revision, prayersAlone: prayers);
      final filled = recited(plan);
      expect(filled.length, 4);
      expect(filled.every((r) => !r.isLearning), isTrue);
    });

    test(
        'la rakaa d\'apprentissage est exclue de coverageForFirstRakaas — elle ne '
        'fait pas avancer le cycle et se confirme au check-out', () {
      final plan = RevisionEngine.distributeToRakaas(
        units: revision,
        prayersAlone: prayers,
        learningUnit: learning,
      );
      // "Tout fait" = les 4 rakaas récitées : seules les 3 de révision
      // remontent comme unités couvertes.
      final coverage = RevisionEngine.coverageForFirstRakaas(plan, 4);
      expect(coverage.coveredUnits.length, 3);
      expect(coverage.coveredUnits.any((u) => u.sourate.id == 99), isFalse);
    });
  });

  group('RevisionEngine.buildDayPlan — cas limites', () {
    test('aucune sourate sélectionnée ne fait pas planter (division par zéro)', () async {
      final config = UserConfig(
        selections: const [],
        pagesPerDay: 1,
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
      );
      final session = await RevisionEngine.buildDayPlan(
        config: config,
        prayersAlone: [Prayer.fajr],
        cyclePosition: 0,
        today: DateTime(2026, 1, 1),
        pageMetadata: const {},
      );
      expect(session.totalUnits, 0);
      expect(session.cycleTotal, 0);
      // Toutes les rakaas restent "Al-Fatiha seule" (aucune unité à assigner).
      expect(session.plan.first.rakaas.every((r) => r.unit == null), isTrue);
    });
  });
}
