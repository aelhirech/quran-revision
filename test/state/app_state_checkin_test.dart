import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quran_revision/models/revision_unit.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/sourate.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';
import 'package:quran_revision/services/ayah_facts_service.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/state/app_state.dart';

// verses/words assez petits pour que RevisionEngine ne découpe pas la
// sourate en plusieurs unités (seuil de découpe à 150 mots, voir
// RevisionEngine._wordLimit) — une sourate = une unité, comme attendu par
// les assertions ci-dessous.
Sourate _sourate(int id) =>
    Sourate(id: id, nameAr: 'س$id', nameFr: 'S$id', verses: 10, words: 50);

String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

UserConfig _config() => UserConfig(
      selections: [
        SourateSelection.whole(_sourate(101)),
        SourateSelection.whole(_sourate(102)),
      ],
      revisionDays: 30,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
    );

void main() {
  // Même setup que test/services/ayah_facts_service_test.dart : ffi pour
  // sqflite (pas de plugin plateforme en `flutter test`), pointé vers un
  // répertoire temporaire propre à CE fichier pour ne jamais partager
  // history.db avec un autre fichier de test tournant en parallèle (voir
  // le commentaire détaillé dans ayah_facts_service_test.dart). AppState
  // construit `_sourates` depuis HafsService dès son constructeur —
  // TestWidgetsFlutterBinding donne accès à rootBundle pour charger le vrai
  // asset hafs.json en test.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final tempDir =
        await Directory.systemTemp.createTemp('qr_test_app_state_checkin_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    await HafsService.initialize();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ensureDayPlan gèle le moteur tant qu\'un jour précédent est en attente', () async {
    final yesterday = _isoDate(DateTime.now().subtract(const Duration(days: 1)));
    final today = _isoDate(DateTime.now());

    // Simule : hier, le moteur a proposé un plan jamais scellé (l'utilisateur
    // n'a pas fait de check-out) — un jour "en attente" pour aujourd'hui.
    await AyahFactsService.proposeUnits(
        yesterday, Riwaya.hafs, [RevisionUnit(sourate: _sourate(101), verseStart: 1, verseEnd: 5, isWhole: false)]);

    final state = AppState(_config(), riwaya: Riwaya.hafs);
    await state.ensureDayPlan();

    expect(state.pendingDate, yesterday,
        reason: 'le jour non scellé doit être détecté');
    final todayFacts = await AyahFactsService.dayFacts(today, Riwaya.hafs);
    expect(todayFacts, isEmpty,
        reason:
            'le moteur ne doit PAS proposer le plan du jour tant que hier '
            'est en attente — sinon cyclePosition, non avancé, ferait '
            'proposer deux fois les mêmes versets (bug identifié en revue '
            'de cadrage Sprint 2)');

    await AyahFactsService.sealDay(yesterday, Riwaya.hafs);
  });

  test(
      'checkOut scelle, avance le cycle une fois, puis ensureDayPlan peut proposer aujourd\'hui',
      () async {
    final yesterday = _isoDate(DateTime.now().subtract(const Duration(days: 2)));
    final today = _isoDate(DateTime.now());
    final config = _config();

    final state = AppState(config, riwaya: Riwaya.hafs);
    // Pose un jour en attente avec la première unité du cycle (sourate 101,
    // en position 0) entièrement faite — pour vérifier que checkOut avance
    // bien le cycle d'exactement 1.
    await AyahFactsService.proposeUnits(yesterday, Riwaya.hafs,
        [RevisionUnit(sourate: _sourate(101), verseStart: 1, verseEnd: 10, isWhole: true)]);
    await AyahFactsService.setReach(yesterday, Riwaya.hafs, 101, 1, 10, true);

    await state.ensureDayPlan();
    expect(state.pendingDate, yesterday);
    expect(state.cyclePosition, 0);

    final wrapped = await state.checkOut(yesterday);
    expect(wrapped, isFalse,
        reason: '1 unité complétée sur 2 dans le cycle : pas de bouclage');
    expect(state.cyclePosition, 1,
        reason: 'la seule unité reach=1 fait avancer le cycle de 1');
    expect(state.pendingDate, isNull);

    await state.ensureDayPlan();
    final todayFacts = await AyahFactsService.dayFacts(today, Riwaya.hafs);
    expect(todayFacts, isNotEmpty,
        reason: 'plus de jour en attente : le moteur peut proposer aujourd\'hui');

    await AyahFactsService.sealDay(today, Riwaya.hafs);
  });

  test(
      'checkOut ignore une unité retirée au check-in au lieu de rompre le comptage des suivantes',
      () async {
    // Bug trouvé en revue de code : le comptage s'arrêtait à la première
    // unité "non faite", mais une unité retirée au check-in (plus aucune
    // ligne en base) était traitée comme "non faite" — ce qui bloquait à
    // tort le comptage d'unités suivantes réellement complétées.
    final yesterday = _isoDate(DateTime.now().subtract(const Duration(days: 3)));
    final config = UserConfig(
      selections: [
        SourateSelection.whole(_sourate(201)),
        SourateSelection.whole(_sourate(202)),
        SourateSelection.whole(_sourate(203)),
      ],
      revisionDays: 30,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
      paceByLines: true,
      targetLinesPerDay: 15, // sous ce seuil, les 3 unités sont sélectionnées
    );
    final state = AppState(config, riwaya: Riwaya.hafs);

    await AyahFactsService.proposeUnits(yesterday, Riwaya.hafs, [
      RevisionUnit(sourate: _sourate(201), verseStart: 1, verseEnd: 10, isWhole: true),
      RevisionUnit(sourate: _sourate(202), verseStart: 1, verseEnd: 10, isWhole: true),
      RevisionUnit(sourate: _sourate(203), verseStart: 1, verseEnd: 10, isWhole: true),
    ]);
    // 201 et 203 faites ; 202 retirée au check-in (plus aucune ligne).
    await AyahFactsService.setReach(yesterday, Riwaya.hafs, 201, 1, 10, true);
    await AyahFactsService.setReach(yesterday, Riwaya.hafs, 203, 1, 10, true);
    await AyahFactsService.removeFromDayPlan(yesterday, Riwaya.hafs, 202);

    await state.ensureDayPlan();
    expect(state.pendingDate, yesterday);

    await state.checkOut(yesterday);
    expect(state.cyclePosition, 2,
        reason:
            '201 et 203 comptent (202 est ignorée, pas bloquante) : le cycle avance de 2, pas 1');
  });
}
