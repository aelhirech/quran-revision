import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/revision_unit.dart';
import 'package:quran_revision/models/sourate.dart';
import 'package:quran_revision/services/ayah_facts_service.dart';

Sourate _sourate(int id) =>
    Sourate(id: id, nameAr: 'س$id', nameFr: 'S$id', verses: 50, words: 500);

RevisionUnit _unit(int surahId, int start, int end) => RevisionUnit(
      sourate: _sourate(surahId),
      verseStart: start,
      verseEnd: end,
      isWhole: false,
    );

void main() {
  // AyahFactsService garde un singleton sqflite privé (`_db`), rechargé une
  // seule fois par process — comme pour l'app réelle. On force le backend
  // ffi (pas de plugin plateforme en `flutter test`) et on pointe vers un
  // répertoire temporaire propre à CE fichier de test : `flutter test` lance
  // les fichiers de test dans des process séparés mais qui partagent le même
  // système de fichiers, et databaseFactoryFfi résout `getDatabasesPath()`
  // vers un chemin par défaut identique pour tous — sans un répertoire
  // dédié, deux fichiers de test tournant en parallèle (ex. celui-ci et
  // test/state/app_state_checkin_test.dart) peuvent lire/écrire le même
  // `history.db` et se polluer l'un l'autre (constaté : une ligne "today"
  // écrite ici apparaissait dans l'autre fichier).
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final tempDir = await Directory.systemTemp.createTemp('qr_test_ayah_facts_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  group('pendingDate — gating du moteur quotidien', () {
    test('null quand aucun jour non scellé', () async {
      expect(await AyahFactsService.pendingDate(riwaya: Riwaya.hafs), isNull);
    });

    test('renvoie la date la plus ancienne non scellée', () async {
      await AyahFactsService.proposeUnits(
          '2020-01-05', Riwaya.hafs, [_unit(1, 1, 5)]);
      expect(await AyahFactsService.pendingDate(riwaya: Riwaya.hafs),
          '2020-01-05');

      await AyahFactsService.sealDay('2020-01-05', Riwaya.hafs);
      expect(await AyahFactsService.pendingDate(riwaya: Riwaya.hafs), isNull);
    });

    test('ne mélange pas les riwayat', () async {
      await AyahFactsService.proposeUnits(
          '2020-01-06', Riwaya.warsh, [_unit(2, 1, 5)]);
      expect(await AyahFactsService.pendingDate(riwaya: Riwaya.hafs), isNull);
      expect(await AyahFactsService.pendingDate(riwaya: Riwaya.warsh),
          '2020-01-06');
      await AyahFactsService.sealDay('2020-01-06', Riwaya.warsh);
    });

    test('ignore le plan du jour même — pas un jour en attente/rattrapage',
        () async {
      // Bug trouvé en revue de code : sans le filtre `date < aujourd'hui`,
      // le plan tout juste proposé pour aujourd'hui (checked_out=0 tant
      // qu'il n'est pas scellé) se comptait lui-même comme "en attente",
      // renvoyant l'utilisateur vers l'écran de rattrapage pour son propre
      // plan du jour à chaque réouverture de l'app.
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await AyahFactsService.proposeUnits(today, Riwaya.hafs, [_unit(3, 1, 5)]);
      expect(await AyahFactsService.pendingDate(riwaya: Riwaya.hafs), isNull);
      await AyahFactsService.sealDay(today, Riwaya.hafs);
    });
  });

  group('proposeUnits — idempotence', () {
    test('reach=0/checked_out=0 par défaut, ré-écrire ne duplique pas', () async {
      const date = '2020-02-01';
      await AyahFactsService.proposeUnits(date, Riwaya.hafs, [_unit(10, 1, 3)]);
      await AyahFactsService.proposeUnits(date, Riwaya.hafs, [_unit(10, 1, 3)]);
      final facts = await AyahFactsService.dayFacts(date, Riwaya.hafs);
      expect(facts, hasLength(1));
      expect(facts.first.verseStart, 1);
      expect(facts.first.verseEnd, 3);
      expect(facts.first.reach, isFalse);
      await AyahFactsService.sealDay(date, Riwaya.hafs);
    });
  });

  group('setReach / isRangeReached', () {
    test('reach=1 seulement quand toute la plage est cochée', () async {
      const date = '2020-02-02';
      await AyahFactsService.proposeUnits(date, Riwaya.hafs, [_unit(11, 1, 3)]);
      expect(
          await AyahFactsService.isRangeReached(date, Riwaya.hafs, 11, 1, 3),
          isFalse);

      await AyahFactsService.setReach(date, Riwaya.hafs, 11, 1, 3, true);
      expect(
          await AyahFactsService.isRangeReached(date, Riwaya.hafs, 11, 1, 3),
          isTrue);

      await AyahFactsService.setReach(date, Riwaya.hafs, 11, 2, 2, false);
      expect(
          await AyahFactsService.isRangeReached(date, Riwaya.hafs, 11, 1, 3),
          isFalse,
          reason: 'un seul verset décoché suffit à invalider toute la plage');
      await AyahFactsService.sealDay(date, Riwaya.hafs);
    });
  });

  group('setCold', () {
    test('flague un verset précis sans toucher les autres', () async {
      const date = '2020-02-03';
      await AyahFactsService.proposeUnits(date, Riwaya.hafs, [_unit(12, 1, 3)]);
      await AyahFactsService.setCold(date, Riwaya.hafs, 12, 2, true);
      final facts = await AyahFactsService.dayFacts(date, Riwaya.hafs);
      expect(facts.first.coldVerses, {2});
      await AyahFactsService.sealDay(date, Riwaya.hafs);
    });
  });

  group('removeFromDayPlan', () {
    test('retire toute la sourate quand aucune plage précisée', () async {
      const date = '2020-02-04';
      await AyahFactsService.proposeUnits(date, Riwaya.hafs, [_unit(13, 1, 3)]);
      await AyahFactsService.removeFromDayPlan(date, Riwaya.hafs, 13);
      expect(await AyahFactsService.dayFacts(date, Riwaya.hafs), isEmpty);
    });
  });

  group('sealDay', () {
    test('scelle uniquement la date/riwaya visée', () async {
      const date = '2020-02-05';
      const otherDate = '2020-02-06';
      await AyahFactsService.proposeUnits(date, Riwaya.hafs, [_unit(14, 1, 2)]);
      await AyahFactsService.proposeUnits(
          otherDate, Riwaya.hafs, [_unit(15, 1, 2)]);
      await AyahFactsService.sealDay(date, Riwaya.hafs);
      expect(await AyahFactsService.pendingDate(riwaya: Riwaya.hafs), otherDate);
      await AyahFactsService.sealDay(otherDate, Riwaya.hafs);
    });
  });

  group('dayFacts — groupement par sourate', () {
    test('regroupe les versets contigus en une plage min-max', () async {
      const date = '2020-02-07';
      await AyahFactsService.proposeUnits(date, Riwaya.hafs, [
        _unit(20, 1, 4),
        _unit(21, 10, 12),
      ]);
      final facts = await AyahFactsService.dayFacts(date, Riwaya.hafs)
        ..sort((a, b) => a.surahId.compareTo(b.surahId));
      expect(facts, hasLength(2));
      expect(facts[0].surahId, 20);
      expect(facts[0].verseStart, 1);
      expect(facts[0].verseEnd, 4);
      expect(facts[1].surahId, 21);
      expect(facts[1].verseStart, 10);
      expect(facts[1].verseEnd, 12);
      await AyahFactsService.sealDay(date, Riwaya.hafs);
    });
  });

  group('startLearning — sourate démarrée sans verset appris', () {
    test('apparaît dans loadMainLearningProgress avec 0 verset appris',
        () async {
      await AyahFactsService.startLearning(30, Riwaya.hafs);
      final progress = await AyahFactsService.loadMainLearningProgress(
          riwaya: Riwaya.hafs, sourates: [_sourate(30)]);
      expect(progress, hasLength(1));
      expect(progress.first.sourate.id, 30);
      expect(progress.first.learnedVerses, isEmpty);
    });

    test('reste "en cours" même si le seul verset appris est ensuite désappris',
        () async {
      await AyahFactsService.startLearning(31, Riwaya.hafs);
      await AyahFactsService.learnVerse(31, 1, Riwaya.hafs);
      await AyahFactsService.unlearnVerse(31, 1, Riwaya.hafs);
      final progress = await AyahFactsService.loadMainLearningProgress(
          riwaya: Riwaya.hafs, sourates: [_sourate(31)]);
      expect(progress, hasLength(1));
      expect(progress.first.learnedVerses, isEmpty);
    });

    test('deleteLearnFacts retire aussi la ligne "verset 1 visé"', () async {
      await AyahFactsService.startLearning(32, Riwaya.hafs);
      await AyahFactsService.deleteLearnFacts(32, Riwaya.hafs);
      final progress = await AyahFactsService.loadMainLearningProgress(
          riwaya: Riwaya.hafs, sourates: [_sourate(32)]);
      expect(progress, isEmpty);
    });
  });
}
