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
import 'package:quran_revision/services/page_metadata_service.dart';
import 'package:quran_revision/state/app_state.dart';

import '../services/test_helpers.dart';

// verses/words assez petits pour que RevisionEngine ne découpe pas la
// sourate en plusieurs unités (seuil de découpe à 150 mots, voir
// RevisionEngine._wordLimit) — une sourate = une unité, comme attendu par
// les assertions ci-dessous. Passe explicitement par des paramètres réduits
// plutôt que les défauts de `testSourate` (50/500 — dépasserait ce seuil).
// L'id reste réel (1..114) : `PageMetadataService` (chargée en vrai dans
// `setUpAll`, comme `HafsService`) n'a d'entrée que pour de vrais numéros de
// sourate — un id fictif n'aurait aucune page et produirait toujours 0 unité.
Sourate _sourate(int id) => testSourate(id, verses: 10, words: 50);

String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

// Sourates 60/65 : chacune réelle, multi-page (jamais éligible au
// regroupement par page partagée — voir cadrage 2026-09-05, ce fichier ne
// teste que le comptage de cycle général, pas ce regroupement, testé
// séparément par les 2 derniers tests de ce fichier et par
// `revision_engine_test.dart`).
UserConfig _config() => UserConfig(
      selections: [
        SourateSelection.whole(_sourate(60)),
        SourateSelection.whole(_sourate(65)),
      ],
      pagesPerDay: 1,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
      riwaya: Riwaya.hafs,
    );

Map<int, Map<int, int>> get _hafsPages =>
    PageMetadataService.pageMetadataFor(Riwaya.hafs);

void main() {
  // Même setup que test/services/ayah_facts_service_test.dart (voir
  // `initFfiTestDb`, factorisé Phase 8 Sprint 1) : ffi pour sqflite (pas de
  // plugin plateforme en `flutter test`), pointé vers un répertoire
  // temporaire propre à CE fichier pour ne jamais partager history.db avec
  // un autre fichier de test tournant en parallèle. AppState construit
  // `_sourates` depuis HafsService dès son constructeur, et
  // `RevisionEngine.buildDayUnits` (via `PageMetadataService`) la pagination
  // réelle du mushaf — TestWidgetsFlutterBinding donne accès à rootBundle
  // pour charger les vrais assets en test, comme en prod (`main.dart`).
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initFfiTestDb('qr_test_app_state_checkin_');
    await HafsService.initialize();
    await PageMetadataService.initialize();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Les tests de ce fichier partagent une seule `history.db` et réutilisent
    // les mêmes dates relatives — sans ce nettoyage, l'un hérite du
    // `checked_out` posé par le précédent sur la même date.
    await clearFactsBetweenTests();
  });

  test('ensureDayPlan gèle le moteur tant qu\'un jour précédent est en attente', () async {
    final yesterday = _isoDate(DateTime.now().subtract(const Duration(days: 1)));
    final today = _isoDate(DateTime.now());

    // Simule : hier, le moteur a proposé un plan jamais scellé (l'utilisateur
    // n'a pas fait de check-out) — un jour "en attente" pour aujourd'hui.
    await AyahFactsService.proposeUnits(
        yesterday, Riwaya.hafs, [RevisionUnit(sourate: _sourate(60), verseStart: 1, verseEnd: 5, isWhole: false)]);

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
    // Pose un jour en attente avec la première unité du cycle (sourate 60,
    // en position 0) entièrement faite — pour vérifier que checkOut avance
    // bien le cycle d'exactement 1.
    await AyahFactsService.proposeUnits(yesterday, Riwaya.hafs,
        [RevisionUnit(sourate: _sourate(60), verseStart: 1, verseEnd: 10, isWhole: true)]);
    await AyahFactsService.setReach(yesterday, Riwaya.hafs, 60, 1, 10, true);

    await state.ensureDayPlan();
    expect(state.pendingDate, yesterday);
    expect(state.cyclePosition, 0);

    final wrapped = await state.checkOut(yesterday);
    expect(wrapped, isFalse,
        reason: 'une seule sourate faite sur les deux du cycle : pas de bouclage');
    // Le curseur est en PAGES depuis le 2026-09-08 : la sourate 60 en couvre
    // plusieurs, et les faire toutes doit avancer d'autant.
    final pagesFaites = RevisionEngine.pagesOf([
      RevisionUnit(
          sourate: _sourate(60), verseStart: 1, verseEnd: 10, isWhole: true)
    ], _hafsPages);
    expect(pagesFaites, greaterThan(1),
        reason: 'sinon ce test ne prouverait rien sur la progression en pages');
    expect(state.cyclePosition, pagesFaites,
        reason: 'le curseur avance du nombre de pages réellement faites');
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
    // Sourates 67/69/71 (3+3+2 pages réelles) : pagesPerDay=8 fait tenir les
    // 3 ENTIÈRES le même jour (3 groupes distincts, aucune ne partage de
    // page avec une autre), condition nécessaire pour que checkOut ait
    // plusieurs groupes à compter en une seule journée.
    final config = UserConfig(
      selections: [
        SourateSelection.whole(_sourate(67)),
        SourateSelection.whole(_sourate(69)),
        SourateSelection.whole(_sourate(71)),
      ],
      pagesPerDay: 8,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
      riwaya: Riwaya.hafs,
    );
    final state = AppState(config, riwaya: Riwaya.hafs);

    final units = await RevisionEngine.buildDayUnits(
      config: config,
      cyclePosition: 0,
      pageMetadata: _hafsPages,
    );
    expect(units.units.map((u) => u.sourate.id).toSet(), {67, 69, 71},
        reason: 'les 3 sourates entières tiennent dans le budget de 8 pages');
    await AyahFactsService.proposeUnits(yesterday, Riwaya.hafs, units.units);
    // 67 et 71 faites ; 69 retirée au check-in (plus aucune ligne).
    await AyahFactsService.setReach(yesterday, Riwaya.hafs, 67, 1, 10, true);
    await AyahFactsService.setReach(yesterday, Riwaya.hafs, 71, 1, 10, true);
    await AyahFactsService.removeFromDayPlan(yesterday, Riwaya.hafs, 69);

    await state.ensureDayPlan();
    expect(state.pendingDate, yesterday);

    await state.checkOut(yesterday);
    final attendu = RevisionEngine.pagesOf(
            units.units.where((u) => u.sourate.id == 67), _hafsPages) +
        RevisionEngine.pagesOf(
            units.units.where((u) => u.sourate.id == 71), _hafsPages);
    expect(state.cyclePosition, attendu,
        reason: 'les pages de 67 et de 71 sont comptées ; 69 retirée est '
            'ignorée sans bloquer le comptage de 71 qui la suit — sans le fix, '
            'le comptage se serait arrêté aux pages de 69');
  });

  test(
      'check-out "fait par défaut" : le cycle avance page par page et couvre '
      'chaque sourate EN ENTIER avant de passer à la suivante — régression du '
      'bug 2026-09-08 (la page 1 était reproposée indéfiniment)', () async {
    // Sourates 73/74/76, chacune multi-page. Avec pagesPerDay=1 le cycle
    // compte une position PAR PAGE : l'ancien moteur en faisait 3 positions
    // (une par sourate) et sautait tout ce qui suivait la première page.
    final config = UserConfig(
      selections: [
        SourateSelection.whole(_sourate(73)),
        SourateSelection.whole(_sourate(74)),
        SourateSelection.whole(_sourate(76)),
      ],
      pagesPerDay: 1,
      startDate: DateTime.now().subtract(const Duration(days: 20)),
      shuffleEnabled: false,
      riwaya: Riwaya.hafs,
    );
    final cycle =
        RevisionEngine.buildCycle(config: config, pageMetadata: _hafsPages);
    expect(cycle.length, greaterThan(3),
        reason: 'trois sourates multi-pages : plus de 3 positions de cycle');

    final state = AppState(config, riwaya: Riwaya.hafs);
    final proposees = <String>[];

    var day = DateTime.now().subtract(Duration(days: cycle.length + 1));
    for (var i = 0; i < cycle.length; i++) {
      final dateStr = _isoDate(day);
      final selection = RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: state.cyclePosition,
        pageMetadata: _hafsPages,
      );
      expect(selection.groups, hasLength(1),
          reason: 'pagesPerDay=1 : exactement une page par jour');
      for (final u in selection.units) {
        proposees.add('${u.sourate.id}:${u.verseStart}-${u.verseEnd}');
      }

      await AyahFactsService.proposeUnits(dateStr, Riwaya.hafs, selection.units);
      await state.markUnitsReached(selection.units, date: dateStr);
      await state.checkOut(dateStr);

      expect(state.cyclePosition, (i + 1) % cycle.length,
          reason: 'une page faite = une position de cycle');
      day = day.add(const Duration(days: 1));
    }

    // Aucune page reproposée avant le bouclage.
    expect(proposees.toSet(), hasLength(proposees.length),
        reason: 'aucune portion ne revient deux fois dans un même cycle');

    // Chaque sourate est couverte en entier, ses pages dans l'ordre du mushaf.
    for (final id in [73, 74, 76]) {
      final versets = <int>[];
      for (final cle in proposees) {
        final parts = cle.split(':');
        if (int.parse(parts[0]) != id) continue;
        final bornes = parts[1].split('-').map(int.parse).toList();
        for (var v = bornes[0]; v <= bornes[1]; v++) {
          versets.add(v);
        }
      }
      expect(versets, List.generate(versets.length, (k) => k + 1),
          reason: 'sourate $id couverte de son verset 1 à son dernier, '
              'dans l\'ordre et sans trou');
    }
  });

  test(
      'check-out avec une exception décochée : cyclePosition n\'avance que '
      'jusqu\'à l\'exception, dayUnits() reconstruit fidèlement depuis '
      'ayah_facts (plusieurs unités le même jour)', () async {
    // Sourates 77/78 (2 pages chacune, pages distinctes — jamais regroupées) :
    // AppState.dayUnits() résout chaque surah_id via _sourateById() sur la
    // vraie liste des 114 sourates (HafsService), d'où le besoin d'ids réels.
    final config = UserConfig(
      selections: [
        SourateSelection.whole(_sourate(77)),
        SourateSelection.whole(_sourate(78)),
      ],
      pagesPerDay: 1,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
      riwaya: Riwaya.hafs,
    );
    final state = AppState(config, riwaya: Riwaya.hafs);
    // Date dédiée (-20j), non partagée avec les autres tests de ce fichier,
    // pour ne pas mélanger des lignes ayah_facts d'un autre scénario.
    final day = _isoDate(DateTime.now().subtract(const Duration(days: 20)));

    final selection = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        pageMetadata: _hafsPages,
      );
    expect(selection.units, hasLength(1));

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
            'malgré 1 unité proposée ce jour-là');
  });

  test(
      'check-out : décocher une unité déjà reach=1 (rakaa cochée plus tôt '
      'dans PlanScreen, avant que le jour ne devienne "en attente") repasse '
      'bien reach=0 — régression trouvée en revue de code (annuler une '
      'progression ne doit jamais rester un no-op silencieux)', () async {
    // Sourates 79/80 (2 pages chacune, pages distinctes — jamais regroupées).
    // pagesPerDay=4 (2+2) pour que les 2 sourates ENTIÈRES tiennent le même
    // jour en 2 groupes distincts, condition nécessaire pour tester le
    // décochage de la "2e unité" du jour indépendamment de la 1re.
    final config = UserConfig(
      selections: [
        SourateSelection.whole(_sourate(79)),
        SourateSelection.whole(_sourate(80)),
      ],
      pagesPerDay: 4,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
      riwaya: Riwaya.hafs,
    );
    final state = AppState(config, riwaya: Riwaya.hafs);
    final day = _isoDate(DateTime.now().subtract(const Duration(days: 25)));

    final selection = await RevisionEngine.buildDayUnits(
        config: config,
        cyclePosition: 0,
        pageMetadata: _hafsPages,
      );
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

  test(
      'checkOut avance cyclePosition par GROUPE de page partagée, pas par '
      'unité individuelle — plusieurs sourates sur la même page réelle du '
      'mushaf comptent comme une seule position de cycle (cadrage '
      '"regroupement par page partagée", 2026-09-05)', () async {
    // 106 (Quraysh), 107 (Al-Ma\'un) et 108 (Al-Kawthar) partagent réellement
    // la même page du mushaf (602) — exactement l'exemple du cadrage. 101
    // (Al-Qari\'a, page 600) est seule sur sa page — 2 groupes au total, pas
    // 4 sourates individuelles.
    final config = UserConfig(
      selections: [
        SourateSelection.whole(_sourate(106)),
        SourateSelection.whole(_sourate(107)),
        SourateSelection.whole(_sourate(108)),
        SourateSelection.whole(_sourate(101)),
      ],
      pagesPerDay: 1,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
      riwaya: Riwaya.hafs,
    );
    final state = AppState(config, riwaya: Riwaya.hafs);
    final day = _isoDate(DateTime.now().subtract(const Duration(days: 30)));

    final selection = await RevisionEngine.buildDayUnits(
      config: config,
      cyclePosition: 0,
      pageMetadata: _hafsPages,
    );
    expect(selection.units, hasLength(3),
        reason: 'les 3 sourates de la page 602 sont proposées ensemble');
    expect(selection.groups, hasLength(1));
    expect(selection.groups.single, hasLength(3));
    expect(selection.cycleTotal, 2,
        reason: '2 groupes au total (page 602, puis 101 seule)');

    await AyahFactsService.proposeUnits(day, Riwaya.hafs, selection.units);
    // 106 et 107 faites ; 108 retirée au check-in — ne doit pas empêcher le
    // groupe de compter comme complet (seule une unité PRÉSENTE mais non
    // faite bloquerait le groupe).
    await AyahFactsService.setReach(day, Riwaya.hafs, 106, 1, 10, true);
    await AyahFactsService.setReach(day, Riwaya.hafs, 107, 1, 10, true);
    await AyahFactsService.removeFromDayPlan(day, Riwaya.hafs, 108);

    final wrapped = await state.checkOut(day);
    expect(state.cyclePosition, 1,
        reason: 'le groupe de la page 602 compte comme 1 seule position de '
            'cycle, pas 2 (108 retirée n\'empêche pas 106/107 de compter) — '
            'sans le fix, compter unité par unité aurait avancé le cycle de '
            '2 et désynchronisé cyclePosition de cycleTotal (2 groupes)');
    expect(wrapped, isFalse,
        reason: '1 groupe complété sur 2 : pas de bouclage');
  });

  test(
      "clôturer deux fois la même journée ne fait avancer le cycle qu'une "
      "fois — « Clôturer ma journée » (Phase 9 Sprint 2) permet de sceller "
      "aujourd'hui puis de relancer une manche, et le second check-out "
      "sauterait sinon du contenu jamais révisé", () async {
    final config = UserConfig(
      selections: [
        SourateSelection.whole(_sourate(73)),
        SourateSelection.whole(_sourate(74)),
        SourateSelection.whole(_sourate(76)),
      ],
      pagesPerDay: 1,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
      riwaya: Riwaya.hafs,
    );
    final state = AppState(config, riwaya: Riwaya.hafs);
    final today = _isoDate(DateTime.now());

    final selection = await RevisionEngine.buildDayUnits(
      config: config,
      cyclePosition: state.cyclePosition,
      pageMetadata: _hafsPages,
    );
    await AyahFactsService.proposeUnits(today, Riwaya.hafs, selection.units);
    await state.markUnitsReached(selection.units, date: today);

    await state.checkOut(today);
    final afterFirst = state.cyclePosition;
    expect(afterFirst, 1, reason: "la première clôture avance d'un groupe");
    expect(state.todayClosed, isTrue);

    // Seconde clôture du MÊME jour : les corrections de reach resteraient
    // possibles, mais le curseur ne doit plus bouger.
    await state.checkOut(today);
    expect(state.cyclePosition, afterFirst,
        reason: "sans le garde-fou `isDaySealed`, le cycle avancerait une "
            "seconde fois sur un contenu déjà compté");
  });
}
