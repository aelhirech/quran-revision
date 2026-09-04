import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_revision/core/revision_engine.dart';
import 'package:quran_revision/models/revision_unit.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/sourate.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';
import 'package:quran_revision/services/ayah_facts_service.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/state/app_state.dart';

import '../services/test_helpers.dart';

// verses/words assez petits pour que RevisionEngine ne découpe pas la
// sourate en plusieurs unités (seuil de découpe à 150 mots, voir
// RevisionEngine._wordLimit) — une sourate = une unité, comme attendu par
// les assertions ci-dessous. Passe explicitement par des paramètres réduits
// plutôt que les défauts de `testSourate` (50/500 — dépasserait ce seuil).
Sourate _sourate(int id) => testSourate(id, verses: 10, words: 50);

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
  // Même setup que test/services/ayah_facts_service_test.dart (voir
  // `initFfiTestDb`, factorisé Phase 8 Sprint 1) : ffi pour sqflite (pas de
  // plugin plateforme en `flutter test`), pointé vers un répertoire
  // temporaire propre à CE fichier pour ne jamais partager history.db avec
  // un autre fichier de test tournant en parallèle. AppState construit
  // `_sourates` depuis HafsService dès son constructeur —
  // TestWidgetsFlutterBinding donne accès à rootBundle pour charger le vrai
  // asset hafs.json en test.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initFfiTestDb('qr_test_app_state_checkin_');
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

  test(
      'check-out "fait par défaut" (comportement CheckOutScreen sans exception) '
      'avance le cycle jour après jour — régression bug "cycle figé, même '
      'sourate en boucle" (backlog 2026-09-04)', () async {
    final config = UserConfig(
      selections: [
        SourateSelection.whole(_sourate(401)),
        SourateSelection.whole(_sourate(402)),
        SourateSelection.whole(_sourate(403)),
      ],
      revisionDays: 30,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
    );
    final state = AppState(config, riwaya: Riwaya.hafs);
    final proposedSourateIds = <int>[];

    var day = DateTime.now().subtract(const Duration(days: 3));
    for (var i = 0; i < 3; i++) {
      final dateStr = _isoDate(day);
      final selection = RevisionEngine.selectDayUnits(
          config: config, cyclePosition: state.cyclePosition, today: day);
      expect(selection.units, hasLength(1),
          reason: 'revisionDays=30 pour 3 unités : dailyTarget doit rester à 1/jour');
      proposedSourateIds.add(selection.units.single.sourate.id);

      await AyahFactsService.proposeUnits(dateStr, Riwaya.hafs, selection.units);
      // Simule CheckOutScreen : clôture sans rien décocher → tout est
      // confirmé "fait" avant d'appeler checkOut (voir _close()).
      await state.markUnitsReached(selection.units, date: dateStr);
      await state.checkOut(dateStr);

      expect(state.cyclePosition, (i + 1) % 3,
          reason: 'sans le fix (reach jamais écrit), cyclePosition resterait '
              'gelé à 0 pour toujours — le modulo 3 au dernier tour est le '
              'bouclage normal du cycle (3 unités/3 jours), pas le bug');
      day = day.add(const Duration(days: 1));
    }

    expect(proposedSourateIds.toSet(), hasLength(3),
        reason: '3 sourates distinctes proposées sur 3 jours — avant le fix, '
            'cyclePosition figé aurait reproposé la sourate 401 les 3 jours '
            '(symptôme backlog : "ça propose toujours la même sourate")');
  });

  test(
      'check-out avec une exception décochée : cyclePosition n\'avance que '
      'jusqu\'à l\'exception, dayUnits() reconstruit fidèlement depuis '
      'ayah_facts (plusieurs unités le même jour)', () async {
    // IDs 111/112 (pas 501/502 comme les autres tests de ce fichier) :
    // AppState.dayUnits() résout chaque surah_id via _sourateById() sur la
    // vraie liste des 114 sourates (HafsService) — un id hors plage 1..114
    // ne serait jamais retrouvé et l'unité serait silencieusement filtrée.
    final config = UserConfig(
      selections: [
        SourateSelection.whole(_sourate(111)),
        SourateSelection.whole(_sourate(112)),
      ],
      revisionDays: 30,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
      paceByLines: true,
      // 50 mots ≈ 5.9 lignes/sourate : les 2 unités tiennent dans le même jour.
      targetLinesPerDay: 10,
    );
    final state = AppState(config, riwaya: Riwaya.hafs);
    // Date dédiée (-20j), non partagée avec les autres tests de ce fichier,
    // pour ne pas mélanger des lignes ayah_facts d'un autre scénario.
    final day = _isoDate(DateTime.now().subtract(const Duration(days: 20)));

    final selection = RevisionEngine.selectDayUnits(
        config: config, cyclePosition: 0, today: DateTime.parse(day));
    expect(selection.units, hasLength(2));

    await AyahFactsService.proposeUnits(day, Riwaya.hafs, selection.units);

    final rebuilt = await state.dayUnits(date: day);
    expect(rebuilt.toSet(), selection.units.toSet(),
        reason:
            'dayUnits() doit reconstruire exactement les unités proposées depuis ayah_facts');

    // Simule CheckOutScreen : l'utilisateur décoche la 2e unité (exception)
    // — seule la 1re reste confirmée "fait" à la clôture.
    await state.markUnitsReached([selection.units.first], date: day);
    await state.checkOut(day);

    expect(state.cyclePosition, 1,
        reason: 'la 2e unité reste reach=0 (exception décochée) : le '
            'comptage s\'arrête à la 1re, cyclePosition n\'avance que de 1 '
            'malgré 2 unités proposées ce jour-là');
  });

  test(
      'check-out : décocher une unité déjà reach=1 (rakaa cochée plus tôt '
      'dans PlanScreen, avant que le jour ne devienne "en attente") repasse '
      'bien reach=0 — régression trouvée en revue de code (annuler une '
      'progression ne doit jamais rester un no-op silencieux)', () async {
    final config = UserConfig(
      selections: [
        SourateSelection.whole(_sourate(103)),
        SourateSelection.whole(_sourate(104)),
      ],
      revisionDays: 30,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
      paceByLines: true,
      targetLinesPerDay: 10,
    );
    final state = AppState(config, riwaya: Riwaya.hafs);
    final day = _isoDate(DateTime.now().subtract(const Duration(days: 25)));

    final selection = RevisionEngine.selectDayUnits(
        config: config, cyclePosition: 0, today: DateTime.parse(day));
    expect(selection.units, hasLength(2));

    await AyahFactsService.proposeUnits(day, Riwaya.hafs, selection.units);
    // Simule : les 2 unités ont déjà été cochées dans PlanScreen plus tôt
    // ce jour-là (reach=1 pour les 2), avant que le jour ne soit resté non
    // scellé et ne devienne "en attente".
    await state.markUnitsReached(selection.units, date: day);
    expect(
        await AyahFactsService.isRangeReached(day, Riwaya.hafs,
            selection.units[1].sourate.id, selection.units[1].verseStart, selection.units[1].verseEnd),
        isTrue);

    // Dans CheckOutScreen, l'utilisateur décoche la 2e unité (il constate
    // qu'elle n'a en fait pas été faite) : la 1re reste confirmée, la 2e
    // doit explicitement repasser à reach=0 (pas juste "ne pas être
    // reconfirmée" — elle était déjà à 1).
    await state.markUnitsReached([selection.units.first], date: day);
    await state.markUnitsReached([selection.units[1]], date: day, reach: false);

    expect(
        await AyahFactsService.isRangeReached(day, Riwaya.hafs,
            selection.units[1].sourate.id, selection.units[1].verseStart, selection.units[1].verseEnd),
        isFalse,
        reason: 'décocher une unité déjà reach=1 doit explicitement écrire '
            'reach=0, pas laisser l\'ancienne valeur en place');

    await state.checkOut(day);
    expect(state.cyclePosition, 1,
        reason: 'la 2e unité repassée à reach=0 ne doit plus compter, même '
            'si elle avait été cochée plus tôt dans la journée');
  });
}
