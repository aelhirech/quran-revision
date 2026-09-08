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
        pageMetadata: mockPageMetadata,
      );

      // Avec 1 page de budget et la sourate ayant 4 versets sur la page 1, on prend 4 versets
      expect(selection.units.length, 1);
      expect(selection.units.first.sourate.id, 1);
      expect(selection.units.first.verseStart, 1);
      expect(selection.units.first.verseEnd, 4);
      expect(selection.units.first.isWhole, isFalse);
    });

    // Pages GLOBALEMENT distinctes par sourate (sourate i sur les pages
    // 10i..10i+6) : avec des numéros partagés, tous les fragments tombent
    // dans les mêmes entrées de cycle et le tri final masque complètement
    // l'effet du mélange — le test passait alors même sans `shuffle`.
    final distinctPages = <int, Map<int, int>>{
      for (var i = 1; i <= 5; i++)
        i: {for (var v = 1; v <= 7; v++) v: i * 10 + v},
    };
    final shuffleSelections =
        List.generate(5, (i) => SourateSelection.whole(_sourate(i + 1, 7, 50)));

    List<int> surahOrderOf(List<List<RevisionUnit>> cycle) {
      final order = <int>[];
      for (final group in cycle) {
        for (final unit in group) {
          if (order.isEmpty || order.last != unit.sourate.id) {
            order.add(unit.sourate.id);
          }
        }
      }
      return order;
    }

    test('le shuffle réordonne les SOURATES, jamais les pages à l\'intérieur',
        () {
      final config = UserConfig(
        selections: shuffleSelections,
        pagesPerDay: 1,
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: true,
      );
      final cycle = RevisionEngine.buildCycle(
          config: config, pageMetadata: distinctPages);

      // Déterministe : même graine, même ordre.
      expect(
          surahOrderOf(RevisionEngine.buildCycle(
              config: config, pageMetadata: distinctPages)),
          surahOrderOf(cycle));
      // Et réellement mélangé, pas simplement l'ordre de la sélection.
      expect(surahOrderOf(cycle), isNot([1, 2, 3, 4, 5]));
      // Chaque sourate reste d'un seul tenant, ses pages en ordre croissant.
      expect(surahOrderOf(cycle).toSet(), hasLength(5),
          reason: 'une sourate ne doit jamais être éclatée par le mélange');
      final pagesBySurah = <int, List<int>>{};
      for (final group in cycle) {
        for (final unit in group) {
          pagesBySurah
              .putIfAbsent(unit.sourate.id, () => [])
              .add(distinctPages[unit.sourate.id]![unit.verseStart]!);
        }
      }
      for (final entry in pagesBySurah.entries) {
        expect(entry.value, List.of(entry.value)..sort(),
            reason: 'sourate ${entry.key} : pages dans l\'ordre du mushaf');
      }
    });

    test(
        "ajouter une sourate ne réordonne pas les autres — sinon `cyclePosition` "
        "désignerait soudain une page différente (handOffLearnedSurahs)", () {
      UserConfig configFor(List<SourateSelection> selections) => UserConfig(
            selections: selections,
            pagesPerDay: 1,
            startDate: DateTime(2026, 1, 1),
            riwaya: Riwaya.hafs,
            shuffleEnabled: true,
          );
      final before = surahOrderOf(RevisionEngine.buildCycle(
          config: configFor(shuffleSelections.take(4).toList()),
          pageMetadata: distinctPages));
      final after = surahOrderOf(RevisionEngine.buildCycle(
          config: configFor(shuffleSelections), pageMetadata: distinctPages));

      expect(after.where((id) => id != 5).toList(), before,
          reason: 'les 4 sourates d\'origine gardent leur ordre relatif');
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
        pageMetadata: mockPageMetadata,
      );

      // Position 1 : doit prendre la sourate 2
      final selection1 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 1,
        pageMetadata: mockPageMetadata,
      );

      // Position 2 : doit prendre la sourate 3
      final selection2 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 2,
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
        pageMetadata: mockPageMetadata,
      );

      // Position 1 : sourate 2
      final selection1 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 1,
        pageMetadata: mockPageMetadata,
      );

      // Position 2 : doit boucler à la sourate 0 (2 % 2 = 0)
      final selection2 = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 2,
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
        pageMetadata: mockPageMetadata,
      );

      expect(selection.units.map((u) => u.sourate.id).toList(), [106, 107, 108],
          reason: 'les 3 sourates de la page 602 sont proposées ensemble, '
              'jamais étalées sur plusieurs jours');
      expect(selection.groups, hasLength(1),
          reason: 'un seul groupe de 3 unités — une seule position de cycle');
      expect(selection.groups.single, hasLength(3));
      expect(selection.cycleTotal, 3,
          reason: 'le cycle compte des PAGES : la page 602 partagee par les 3 '
              'courtes sourates, plus les 2 pages de la sourate 2');

      // Position 1 (après le groupe) : doit prendre la sourate 2, seule.
      final next = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 1,
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
  group('RevisionEngine — composition buildDayUnits + distributeToRakaas', () {
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
      final selection = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        pageMetadata: mockPageMetadata,
      );
      final layout = RevisionEngine.distributeToRakaas(
        units: selection.units,
        prayersAlone: [Prayer.fajr],
      );
      // Le budget d’une page ne retient qu’une sourate — elle est répétée
      // dans toutes les rakaas récitées de la prière.
      expect(RevisionEngine.pagesOf(selection.units, mockPageMetadata), 1);
      final surats = layout.plan.first.rakaas
          .where((r) => r.unit != null)
          .map((r) => r.unit!.sourate.id)
          .toSet();
      expect(surats, {1});
    });
  });

  group('RevisionEngine.distributeToRakaas — contenu hors prières (règle D)',
      () {
    test(
        'une unité subdivisée pour remplir les rakaas ne produit jamais de '
        'contenu hors prières — le calculer par différence d\'unités listait '
        'toute la journée en double (bug 2026-09-08)', () {
      // 1 unité de 20 versets, 2 rakaas récitées : le moteur la coupe en deux
      // sous-plages, qu'aucune égalité de valeur ne rattache à l'unité mère.
      final layout = RevisionEngine.distributeToRakaas(
        units: [
          RevisionUnit(
              sourate: _sourate(2, 286, 6000),
              verseStart: 1,
              verseEnd: 20,
              isWhole: false)
        ],
        prayersAlone: [Prayer.fajr],
      );
      expect(layout.outside, isEmpty);
      expect(
          [
            for (final pp in layout.plan)
              for (final r in pp.rakaas)
                if (r.unit != null) r
          ],
          hasLength(2),
          reason: 'les deux rakaas récitées sont bien remplies');
    });

    test('plus d\'unités que de rakaas : le reste part hors prières', () {
      final units = [
        for (var i = 1; i <= 5; i++)
          RevisionUnit(
              sourate: _sourate(110 + i, 5, 25),
              verseStart: 1,
              verseEnd: 5,
              isWhole: true),
      ];
      // Fajr = 2 rakaas récitées, donc 2 unités placées et 3 laissées de côté.
      final layout = RevisionEngine.distributeToRakaas(
          units: units, prayersAlone: [Prayer.fajr]);
      expect(layout.outside, hasLength(3));
      final placed = {
        for (final pp in layout.plan)
          for (final r in pp.rakaas)
            if (r.unit != null) r.unit!,
      };
      expect(placed.intersection(layout.outside.toSet()), isEmpty,
          reason: 'rien n\'est à la fois dans une rakaa et hors prières');
      expect({...placed, ...layout.outside}, units.toSet(),
          reason: 'aucune unité du jour n\'est perdue');
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
      final layout = RevisionEngine.distributeToRakaas(
        units: revision,
        prayersAlone: prayers,
        learningUnit: learning,
      );

      final filled = recited(layout.plan);
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
          RevisionEngine.distributeToRakaas(units: revision, prayersAlone: prayers).plan;
      final filled = recited(plan);
      expect(filled.length, 4);
      expect(filled.every((r) => !r.isLearning), isTrue);
    });
  });

  group('RevisionEngine — cas limites', () {
    test('aucune sourate sélectionnée ne fait pas planter (division par zéro)', () async {
      final config = UserConfig(
        selections: const [],
        pagesPerDay: 1,
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
      );
      final selection = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        pageMetadata: const {},
      );
      final layout = RevisionEngine.distributeToRakaas(
        units: selection.units,
        prayersAlone: [Prayer.fajr],
      );
      expect(selection.cycleTotal, 0);
      expect(selection.units, isEmpty,
          reason: 'sans pagination, le moteur ne produit aucune unité');
      // Toutes les rakaas restent "Al-Fatiha seule" (aucune unité à assigner).
      expect(layout.plan.first.rakaas.every((r) => r.unit == null), isTrue);
    });
  });

  group('RevisionEngine — progression du cycle en pages réelles', () {
    // 3 sourates d'une page chacune, mais 106 et 107 partagent la page 602 :
    // le moteur les propose ensemble (1 groupe, 1 page), 61 est seule sur la
    // page 550. Total = 2 pages pour 2 groupes.
    final pageMetadata = {
      106: {1: 602, 2: 602, 3: 602, 4: 602},
      107: {1: 602, 2: 602, 3: 602, 4: 602, 5: 602, 6: 602, 7: 602},
      61: {for (var v = 1; v <= 14; v++) v: 550},
    };
    final config = UserConfig(
      selections: [
        SourateSelection.whole(_sourate(106, 4, 20)),
        SourateSelection.whole(_sourate(107, 7, 40)),
        SourateSelection.whole(_sourate(61, 14, 100)),
      ],
      pagesPerDay: 1,
      startDate: DateTime(2026, 1, 1),
      riwaya: Riwaya.hafs,
      shuffleEnabled: false,
    );

    test(
        'pagesOf compte des pages physiques, pas des sourates : deux sourates '
        'sur la même page du mushaf ne comptent que pour une', () {
      final shared = [
        RevisionUnit(
            sourate: _sourate(106, 4, 20),
            verseStart: 1,
            verseEnd: 4,
            isWhole: true),
        RevisionUnit(
            sourate: _sourate(107, 7, 40),
            verseStart: 1,
            verseEnd: 7,
            isWhole: true),
      ];
      expect(RevisionEngine.pagesOf(shared, pageMetadata), 1);
      // Sur la plage exacte demandée, pas sur toute la sourate.
      expect(
          RevisionEngine.pagesOf([
            RevisionUnit(
                sourate: _sourate(61, 14, 100),
                verseStart: 1,
                verseEnd: 3,
                isWhole: false)
          ], pageMetadata),
          1);
      expect(RevisionEngine.pagesOf(const [], pageMetadata), 0);
    });

    test(
        'cycleTotal/cyclePosition expriment le cycle dans la même unité que '
        'pagesPerDay — un groupe de page partagée coûte 1 page, pas 2', () async {
      final atStart = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        pageMetadata: pageMetadata,
      );
      expect(atStart.cycleTotal, 2, reason: '106+107 groupées, 61 seule');
      expect(RevisionEngine.pagesOf(atStart.units, pageMetadata), 1,
          reason: "un seul groupe pris ce jour-là, donc une seule page");
      expect(atStart.cyclePosition, 0);

      // Un groupe consommé : la position en pages suit celle en groupes.
      final afterFirst = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 1,
        pageMetadata: pageMetadata,
      );
      expect(afterFirst.cyclePosition, 1);
      expect(afterFirst.cycleTotal, 2);
    });

    test(
        "une page physique partagée par deux GROUPES n'est comptée qu'une fois "
        "dans cycleTotal — la sommer gonflerait le cycle complet à 659 pages "
        "au lieu des 604 du mushaf Hafs", () async {
      // 2 sourates multi-pages (donc jamais regroupées ensemble) qui se
      // partagent la page 2 : la première finit dessus, la seconde y commence.
      final straddling = {
        20: {1: 1, 2: 1, 3: 2},
        21: {1: 2, 2: 3, 3: 3},
      };
      final selection = await RevisionEngine.buildDayUnits(
        config: UserConfig(
          selections: [
            SourateSelection.whole(_sourate(20, 3, 30)),
            SourateSelection.whole(_sourate(21, 3, 30)),
          ],
          pagesPerDay: 1,
          startDate: DateTime(2026, 1, 1),
          riwaya: Riwaya.hafs,
          shuffleEnabled: false,
        ),
        cyclePosition: 0,
        pageMetadata: straddling,
      );
      expect(selection.cycleTotal, 3,
          reason: "pages 1, 2 et 3 — la somme par groupe en compterait 4");
    });

    test('sans sourate sélectionnée, le cycle en pages vaut 0/0', () async {
      final empty = await RevisionEngine.buildDayUnits(
        config: UserConfig(
          selections: const [],
          pagesPerDay: 1,
          startDate: DateTime(2026, 1, 1),
          riwaya: Riwaya.hafs,
        ),
        cyclePosition: 0,
        pageMetadata: const {},
      );
      expect(empty.cycleTotal, 0);
      expect(empty.cyclePosition, 0);
    });
  });

  // ─── Règle du plan quotidien (CLAUDE.md § « Règle du plan quotidien ») ──────
  //
  // Le cycle est une liste ORDONNÉE DE PAGES du mushaf, et `cyclePosition`
  // indexe cette liste. Ces tests verrouillent les invariants de ce bloc ;
  // ils échouaient tous avant la refonte du 2026-09-08.
  group('RevisionEngine — le cycle est une liste ordonnée de pages', () {
    // S2 mockée sur 3 pages : v.1-5 | v.6-12 | v.13-20. S112 tient sur 1 page.
    final pageMeta = {
      2: {
        for (var v = 1; v <= 5; v++) v: 1,
        for (var v = 6; v <= 12; v++) v: 2,
        for (var v = 13; v <= 20; v++) v: 3,
      },
      112: {for (var v = 1; v <= 4; v++) v: 10},
    };
    final s2 = _sourate(2, 20, 400);
    final s112 = _sourate(112, 4, 20);

    UserConfig cfg(List<SourateSelection> sel, {int pages = 1}) => UserConfig(
          selections: sel,
          pagesPerDay: pages,
          startDate: DateTime(2026, 1, 1),
          riwaya: Riwaya.hafs,
          shuffleEnabled: false,
        );

    List<RevisionUnit> dayAt(UserConfig config, int pos) =>
        RevisionEngine.buildDayUnits(
          config: config,
          cyclePosition: pos,
          pageMetadata: pageMeta,
        ).units;

    test(
        "une sourate de N pages est couverte en N jours consécutifs, sans trou "
        "ni répétition — le bug du 2026-09-08 reproposait indéfiniment sa page 1",
        () {
      final config = cfg([SourateSelection.whole(s2), SourateSelection.whole(s112)]);
      final cycle = RevisionEngine.buildDayUnits(
          config: config, cyclePosition: 0, pageMetadata: pageMeta);
      expect(cycle.cycleTotal, 4,
          reason: "3 pages pour S2 + 1 page pour S112, comptées en PAGES");

      expect(dayAt(config, 0).single.verseStart, 1);
      expect(dayAt(config, 0).single.verseEnd, 5);
      expect(dayAt(config, 1).single.verseEnd, 12);
      expect(dayAt(config, 2).single.verseEnd, 20);
      expect(dayAt(config, 3).single.sourate.id, 112);

      // Les 3 premières positions couvrent S2 en entier, sans trou ni doublon.
      final couverts = <int>[];
      for (var pos = 0; pos < 3; pos++) {
        final u = dayAt(config, pos).single;
        for (var v = u.verseStart; v <= u.verseEnd; v++) {
          couverts.add(v);
        }
      }
      expect(couverts, List.generate(20, (i) => i + 1),
          reason: "chaque verset de S2 exactement une fois, dans l'ordre");

      // Le cycle reboucle proprement, pas avant.
      expect(dayAt(config, 4).single.verseStart, 1);
    });

    test(
        "une sélection PARTIELLE ne propose jamais hors de sa plage — le bug du "
        "2026-09-08 répondait v.1-5 à une demande de v.7-15", () {
      final config = cfg([
        SourateSelection(sourate: s2, verseStart: 7, verseEnd: 15),
      ]);
      final cycle = RevisionEngine.buildDayUnits(
          config: config, cyclePosition: 0, pageMetadata: pageMeta);
      expect(cycle.cycleTotal, 2,
          reason: "v.7-15 chevauche la page 2 (v.7-12) et la page 3 (v.13-15)");

      final j0 = dayAt(config, 0).single;
      expect([j0.verseStart, j0.verseEnd], [7, 12],
          reason: "borné par le DÉBUT de la sélection, pas par le début de la page");
      final j1 = dayAt(config, 1).single;
      expect([j1.verseStart, j1.verseEnd], [13, 15],
          reason: "borné par la FIN de la sélection, pas par la fin de la page");

      for (var pos = 0; pos < 4; pos++) {
        for (final u in dayAt(config, pos)) {
          expect(u.verseStart, greaterThanOrEqualTo(7));
          expect(u.verseEnd, lessThanOrEqualTo(15));
        }
      }
    });

    test(
        "le curseur progresse à l'intérieur d'une sourate même seule sélectionnée "
        "— avec un cycle compté en groupes, cycleTotal valait 1 et la position "
        "restait bloquée à 0", () {
      final config = cfg([SourateSelection.whole(s2)]);
      final cycle = RevisionEngine.buildDayUnits(
          config: config, cyclePosition: 0, pageMetadata: pageMeta);
      expect(cycle.cycleTotal, 3);
      expect(dayAt(config, 0).single.verseEnd, 5);
      expect(dayAt(config, 1).single.verseEnd, 12);
      expect(dayAt(config, 2).single.verseEnd, 20);
    });

    test(
        "plusieurs sourates sur une même page physique forment UNE entrée, donc "
        "UNE journée et UNE page au compteur", () {
      final partagee = {
        106: {1: 602, 2: 602, 3: 602, 4: 602},
        107: {for (var v = 1; v <= 7; v++) v: 602},
      };
      final config = UserConfig(
        selections: [
          SourateSelection.whole(_sourate(106, 4, 20)),
          SourateSelection.whole(_sourate(107, 7, 40)),
        ],
        pagesPerDay: 1,
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: false,
      );
      final sel = RevisionEngine.buildDayUnits(
          config: config, cyclePosition: 0, pageMetadata: partagee);
      expect(sel.cycleTotal, 1, reason: "une page = une position de cycle");
      expect(sel.units.map((u) => u.sourate.id).toSet(), {106, 107},
          reason: "les deux sourates sont proposées le même jour");
    });

    test("un budget supérieur au cycle ne reproduit jamais deux fois la même page",
        () {
      final config = cfg([SourateSelection.whole(s2)], pages: 10);
      final sel = RevisionEngine.buildDayUnits(
          config: config, cyclePosition: 0, pageMetadata: pageMeta);
      expect(sel.groups.length, 3, reason: "3 pages disponibles, pas 10");
      final debuts = sel.units.map((u) => u.verseStart).toList();
      expect(debuts.toSet().length, debuts.length, reason: "aucun doublon");
    });

    test("une sourate sans métadonnée de pagination est ignorée du cycle", () {
      final config = cfg([
        SourateSelection.whole(s2),
        SourateSelection.whole(_sourate(99, 8, 60)), // absente de pageMeta
      ]);
      final sel = RevisionEngine.buildDayUnits(
          config: config, cyclePosition: 0, pageMetadata: pageMeta);
      expect(sel.cycleTotal, 3, reason: "seules les 3 pages de S2 entrent");
      expect(sel.units.every((u) => u.sourate.id == 2), isTrue);
    });
  });
}
