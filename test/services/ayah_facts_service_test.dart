import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/revision_unit.dart';
import 'package:quran_revision/models/ayah_fact.dart';
import 'package:quran_revision/services/ayah_facts_service.dart';

import 'test_helpers.dart';

void main() {
  // AyahFactsService garde un singleton sqflite privé (`_db`), rechargé une
  // seule fois par process — comme pour l'app réelle. `initFfiTestDb` pointe
  // vers un répertoire temporaire propre à CE fichier de test : `flutter
  // test` lance les fichiers de test dans des process séparés mais qui
  // partagent le même système de fichiers, et databaseFactoryFfi résout
  // `getDatabasesPath()` vers un chemin par défaut identique pour tous —
  // sans un répertoire dédié, deux fichiers de test tournant en parallèle
  // (ex. celui-ci et test/state/app_state_checkin_test.dart) peuvent
  // lire/écrire le même `history.db` et se polluer l'un l'autre (constaté :
  // une ligne "today" écrite ici apparaissait dans l'autre fichier).
  setUpAll(() => initFfiTestDb('qr_test_ayah_facts_'));

  group('pendingDate — gating du moteur quotidien', () {
    test('null quand aucun jour non scellé', () async {
      expect(await AyahFactsRitual.pendingDate(riwaya: Riwaya.hafs), isNull);
    });

    test('renvoie la date la plus ancienne non scellée', () async {
      await AyahFactsRitual.proposeUnits(
          '2020-01-05', Riwaya.hafs, [testUnit(1, 1, 5)]);
      expect(await AyahFactsRitual.pendingDate(riwaya: Riwaya.hafs),
          '2020-01-05');

      await AyahFactsRitual.sealDay('2020-01-05', Riwaya.hafs);
      expect(await AyahFactsRitual.pendingDate(riwaya: Riwaya.hafs), isNull);
    });

    test('ne mélange pas les riwayat', () async {
      await AyahFactsRitual.proposeUnits(
          '2020-01-06', Riwaya.warsh, [testUnit(2, 1, 5)]);
      expect(await AyahFactsRitual.pendingDate(riwaya: Riwaya.hafs), isNull);
      expect(await AyahFactsRitual.pendingDate(riwaya: Riwaya.warsh),
          '2020-01-06');
      await AyahFactsRitual.sealDay('2020-01-06', Riwaya.warsh);
    });

    test('ignore le plan du jour même — pas un jour en attente/rattrapage',
        () async {
      // Bug trouvé en revue de code : sans le filtre `date < aujourd'hui`,
      // le plan tout juste proposé pour aujourd'hui (checked_out=0 tant
      // qu'il n'est pas scellé) se comptait lui-même comme "en attente",
      // renvoyant l'utilisateur vers l'écran de rattrapage pour son propre
      // plan du jour à chaque réouverture de l'app.
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await AyahFactsRitual.proposeUnits(today, Riwaya.hafs, [testUnit(3, 1, 5)]);
      expect(await AyahFactsRitual.pendingDate(riwaya: Riwaya.hafs), isNull);
      await AyahFactsRitual.sealDay(today, Riwaya.hafs);
    });
  });

  group('proposeUnits — idempotence', () {
    test('reach=0/checked_out=0 par défaut, ré-écrire ne duplique pas', () async {
      const date = '2020-02-01';
      await AyahFactsRitual.proposeUnits(date, Riwaya.hafs, [testUnit(10, 1, 3)]);
      await AyahFactsRitual.proposeUnits(date, Riwaya.hafs, [testUnit(10, 1, 3)]);
      final facts = await AyahFactsRitual.dayFacts(date, Riwaya.hafs);
      expect(facts, hasLength(1));
      expect(facts.first.verseStart, 1);
      expect(facts.first.verseEnd, 3);
      expect(facts.first.reach, isFalse);
      await AyahFactsRitual.sealDay(date, Riwaya.hafs);
    });
  });

  group('setReach / rangeStatus', () {
    test('reach=1 seulement quand toute la plage est cochée', () async {
      const date = '2020-02-02';
      await AyahFactsRitual.proposeUnits(date, Riwaya.hafs, [testUnit(11, 1, 3)]);
      expect(
          (await AyahFactsRitual.rangeStatus(date, Riwaya.hafs, 11, 1, 3)).reached,
          isFalse);

      await AyahFactsRitual.setReach(date, Riwaya.hafs, 11, 1, 3, true);
      expect(
          (await AyahFactsRitual.rangeStatus(date, Riwaya.hafs, 11, 1, 3)).reached,
          isTrue);

      await AyahFactsRitual.setReach(date, Riwaya.hafs, 11, 2, 2, false);
      expect(
          (await AyahFactsRitual.rangeStatus(date, Riwaya.hafs, 11, 1, 3)).reached,
          isFalse,
          reason: 'un seul verset décoché suffit à invalider toute la plage');
      await AyahFactsRitual.sealDay(date, Riwaya.hafs);
    });
  });

  group('setReachForVerses — granularité verset du check-out (US-3 crit. 3)', () {
    test('décoche un verset précis sans toucher les autres de la même plage',
        () async {
      const date = '2020-02-08';
      await AyahFactsRitual.proposeUnits(date, Riwaya.hafs, [testUnit(16, 1, 3)]);
      await AyahFactsRitual.setReachForVerses(
          date, Riwaya.hafs, 16, [1, 2, 3], true,
          type: AyahFactType.revise);
      await AyahFactsRitual.setReachForVerses(date, Riwaya.hafs, 16, [2], false,
          type: AyahFactType.revise);

      final facts = await AyahFactsRitual.dayFacts(date, Riwaya.hafs);
      expect(facts, hasLength(1));
      expect(facts.first.reachedVerses, {1, 3},
          reason: 'seul le verset 2, explicitement décoché, doit manquer');
      expect(facts.first.reach, isFalse,
          reason: 'un seul verset manquant suffit à invalider toute la plage');
      await AyahFactsRitual.sealDay(date, Riwaya.hafs);
    });
  });

  group('returningVerses — verset revenu seul (US-3 crit. 4)', () {
    test('un verset décoché à un check-out SCELLÉ est bien signalé revenant',
        () async {
      const d1 = '2020-04-01';
      const today = '2020-04-02';
      await AyahFactsRitual.proposeUnits(d1, Riwaya.hafs, [testUnit(50, 1, 3)]);
      await AyahFactsRitual.setReachForVerses(d1, Riwaya.hafs, 50, [1, 3], true,
          type: AyahFactType.revise);
      // Verset 2 reste reach=0, puis la journée est scellée (checked_out=1).
      await AyahFactsRitual.sealDay(d1, Riwaya.hafs);

      final returning = await AyahFactsRitual.returningVerses(
          today, Riwaya.hafs, {(50, 1), (50, 2), (50, 3)});
      expect(returning, {(50, 2)},
          reason: 'seul le verset laissé à reach=0 au scellement revient');
    });

    test('un jour encore en attente (pas scellé) ne compte jamais comme "revenu"',
        () async {
      const pending = '2020-04-03';
      const today = '2020-04-04';
      await AyahFactsRitual.proposeUnits(
          pending, Riwaya.hafs, [testUnit(51, 1, 2)]);
      // reach=0 par défaut, mais jamais scellé : ce n'est pas une déclaration
      // "laissé de côté" de l'utilisateur, juste un plan pas encore clôturé.
      final returning = await AyahFactsRitual.returningVerses(
          today, Riwaya.hafs, {(51, 1), (51, 2)});
      expect(returning, isEmpty);
      await AyahFactsRitual.sealDay(pending, Riwaya.hafs);
    });
  });

  group('removeFromDayPlan', () {
    test('retire toute la sourate quand aucune plage précisée', () async {
      const date = '2020-02-04';
      await AyahFactsRitual.proposeUnits(date, Riwaya.hafs, [testUnit(13, 1, 3)]);
      await AyahFactsRitual.removeFromDayPlan(date, Riwaya.hafs, 13);
      expect(await AyahFactsRitual.dayFacts(date, Riwaya.hafs), isEmpty);
    });
  });

  group('sealDay', () {
    test('scelle uniquement la date/riwaya visée', () async {
      const date = '2020-02-05';
      const otherDate = '2020-02-06';
      await AyahFactsRitual.proposeUnits(date, Riwaya.hafs, [testUnit(14, 1, 2)]);
      await AyahFactsRitual.proposeUnits(
          otherDate, Riwaya.hafs, [testUnit(15, 1, 2)]);
      await AyahFactsRitual.sealDay(date, Riwaya.hafs);
      expect(await AyahFactsRitual.pendingDate(riwaya: Riwaya.hafs), otherDate);
      await AyahFactsRitual.sealDay(otherDate, Riwaya.hafs);
    });
  });

  group('dayFacts — groupement par sourate', () {
    test('regroupe les versets contigus en une plage min-max', () async {
      const date = '2020-02-07';
      await AyahFactsRitual.proposeUnits(date, Riwaya.hafs, [
        testUnit(20, 1, 4),
        testUnit(21, 10, 12),
      ]);
      final facts = await AyahFactsRitual.dayFacts(date, Riwaya.hafs)
        ..sort((a, b) => a.surahId.compareTo(b.surahId));
      expect(facts, hasLength(2));
      expect(facts[0].surahId, 20);
      expect(facts[0].verseStart, 1);
      expect(facts[0].verseEnd, 4);
      expect(facts[1].surahId, 21);
      expect(facts[1].verseStart, 10);
      expect(facts[1].verseEnd, 12);
      await AyahFactsRitual.sealDay(date, Riwaya.hafs);
    });
  });

  // `startLearning` (une ligne `ayah_id=1, reach=0` écrite au démarrage d'une
  // sourate) a été supprimée en Phase 9 : c'est désormais `proposeLearnVerses`
  // qui écrit la portion du jour, avec la même sémantique "visé (0) → atteint
  // (1)". Les invariants qu'elle protégeait (retour TestFlight 2026-09-01 :
  // une sourate démarrée ne doit pas disparaître de "en cours") restent
  // couverts ici, sur le nouveau chemin d'écriture.
  group('démarrage d\'une sourate sans verset appris', () {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    test('apparaît dans loadMainLearningProgress avec 0 verset appris',
        () async {
      await AyahFactsLearning.proposeLearnVerses(today, Riwaya.hafs, 30, [1]);
      final progress = await AyahFactsLearning.loadMainLearningProgress(
          riwaya: Riwaya.hafs, sourates: [testSourate(30)]);
      expect(progress, hasLength(1));
      expect(progress.first.sourate.id, 30);
      expect(progress.first.learnedVerses, isEmpty);
    });

    test('reste "en cours" même si le seul verset appris est ensuite désappris',
        () async {
      await AyahFactsLearning.proposeLearnVerses(today, Riwaya.hafs, 31, [1]);
      await AyahFactsLearning.learnVerses(31, [1], Riwaya.hafs);
      await AyahFactsLearning.unlearnVerse(31, 1, Riwaya.hafs);
      final progress = await AyahFactsLearning.loadMainLearningProgress(
          riwaya: Riwaya.hafs, sourates: [testSourate(31)]);
      expect(progress, hasLength(1));
      expect(progress.first.learnedVerses, isEmpty);
    });

    test('deleteLearnFacts retire aussi la ligne "verset 1 visé"', () async {
      await AyahFactsLearning.proposeLearnVerses(today, Riwaya.hafs, 32, [1]);
      await AyahFactsLearning.deleteLearnFacts(32, Riwaya.hafs);
      final progress = await AyahFactsLearning.loadMainLearningProgress(
          riwaya: Riwaya.hafs, sourates: [testSourate(32)]);
      expect(progress, isEmpty);
    });
  });

  group('dette technique — sprint 4 (2026-09-08)', () {
    test(
        "dayFacts rend une entrée par PLAGE CONTIGUË, pas une plage MIN..MAX "
        "par sourate : depuis que le cycle est une liste de pages, deux "
        "fragments non adjacents de la même sourate peuvent tomber le même "
        "jour, et les fusionner créditerait des versets jamais proposés",
        () async {
      const jour = '2031-03-01';
      final s2 = testSourate(2, verses: 286, words: 6000);
      await AyahFactsRitual.proposeUnits(jour, Riwaya.hafs, [
        RevisionUnit(sourate: s2, verseStart: 1, verseEnd: 5, isWhole: false),
        RevisionUnit(sourate: s2, verseStart: 200, verseEnd: 203, isWhole: false),
      ]);

      final groupes = await AyahFactsRitual.dayFacts(jour, Riwaya.hafs);
      expect(groupes, hasLength(2),
          reason: 'deux plages disjointes de la sourate 2, pas une seule');
      expect(groupes.map((g) => [g.verseStart, g.verseEnd]).toList(),
          [[1, 5], [200, 203]]);
      expect(groupes.every((g) => g.surahId == 2), isTrue);
    });

    test('dayFacts fusionne bien deux plages ADJACENTES en une seule entrée',
        () async {
      const jour = '2031-03-02';
      final s2 = testSourate(2, verses: 286, words: 6000);
      await AyahFactsRitual.proposeUnits(jour, Riwaya.hafs, [
        RevisionUnit(sourate: s2, verseStart: 1, verseEnd: 5, isWhole: false),
        RevisionUnit(sourate: s2, verseStart: 6, verseEnd: 9, isWhole: false),
      ]);
      final groupes = await AyahFactsRitual.dayFacts(jour, Riwaya.hafs);
      expect(groupes, hasLength(1));
      expect([groupes.first.verseStart, groupes.first.verseEnd], [1, 9]);
    });

    test(
        "unlearnVerse retrograde TOUTES les lignes datees du verset — les "
        "lecteurs de « appris » ignorent la date, ne rabattre que la plus "
        "recente ferait du desapprentissage un no-op silencieux",
        () async {
      const j1 = '2031-04-01';
      const j2 = '2031-04-09';
      for (final jour in [j1, j2]) {
        await AyahFactsLearning.proposeLearnVerses(jour, Riwaya.hafs, 40, [1]);
        await AyahFactsRitual.setReach(jour, Riwaya.hafs, 40, 1, 1, true,
            type: AyahFactType.learn);
      }

      await AyahFactsLearning.unlearnVerse(40, 1, Riwaya.hafs);

      final appris = await AyahFactsLearning.learnedVersesBySourate(
          riwaya: Riwaya.hafs);
      expect(appris[40] ?? const <int>{}, isNot(contains(1)),
          reason: "le verset ne doit plus etre acquis apres desapprentissage");
      // L'historique tient a l'EXISTENCE des lignes datees, pas a leur
      // `reach` : les deux jours restent en base, a reach=0.
      final plans = [
        for (final jour in [j1, j2])
          await AyahFactsLearning.learnPlanFor(jour, Riwaya.hafs),
      ];
      expect(plans.every((p) => p?.ayahIds.contains(1) ?? false), isTrue,
          reason: "les deux lignes datees restent, seul leur reach retombe");
    });
  });
}
