import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_revision/core/revision_engine.dart';
import 'package:quran_revision/models/ayah_fact.dart';
import 'package:quran_revision/models/learning_progress.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/sourate.dart';
import 'package:quran_revision/models/revision_unit.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';
import 'package:quran_revision/services/ayah_facts_service.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/services/page_metadata_service.dart';
import 'package:quran_revision/state/app_state.dart';

import '../services/test_helpers.dart';

/// Apprentissage intégré à la boucle quotidienne (Phase 9) : les versets à
/// apprendre sont des lignes `ayah_facts` datées (`type='learn'`), proposées
/// au check-in et confirmées au check-out — mêmes sémantiques `reach=0`
/// (visé) → `reach=1` (acquis) que la révision.
String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

// Sourates 60/65 en révision : réelles et multi-pages, sans rapport avec la
// sourate apprise (108, Al-Kawthar — 3 versets, la plus courte du Coran,
// donc terminable en un seul jour de test).
UserConfig _config(List<Sourate> sourates) => UserConfig(
      selections: [
        for (final id in [60, 65])
          SourateSelection.whole(sourates.firstWhere((s) => s.id == id)),
      ],
      pagesPerDay: 1,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      shuffleEnabled: false,
      riwaya: Riwaya.hafs,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initFfiTestDb('qr_test_app_state_learning_');
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

  AppState newState({int cyclePosition = 0}) {
    final probe = AppState(null, riwaya: Riwaya.hafs);
    return AppState(_config(probe.sourates),
        riwaya: Riwaya.hafs, initialCyclePosition: cyclePosition);
  }

  Sourate kawthar(AppState state) =>
      state.sourates.firstWhere((s) => s.id == 108);

  test(
      'setLearningForToday propose les N prochains versets et devient le défaut '
      'des jours suivants', () async {
    final state = newState();
    await state.setLearningForToday(kawthar(state), 2);

    expect(await state.todayLearningUnit(), isNotNull);
    expect((await state.todayLearningUnit())!.sourate.id, 108);
    expect((await state.todayLearningUnit())!.verseStart, 1);
    expect((await state.todayLearningUnit())!.verseEnd, 2);
    expect(state.config!.versesToLearnPerDay, 2,
        reason:
            'le nombre choisi au check-in pré-remplit les jours suivants '
            '(UserConfig.versesToLearnPerDay)');

    await AyahFactsService.deleteLearnFacts(108, Riwaya.hafs);
  });

  test('les versets déjà acquis un jour précédent sont sautés, pas reproposés',
      () async {
    final yesterday = _isoDate(DateTime.now().subtract(const Duration(days: 1)));
    await AyahFactsService.proposeLearnVerses(yesterday, Riwaya.hafs, 108, [1]);
    await AyahFactsService.setReachForVerses(
        yesterday, Riwaya.hafs, 108, [1], true,
        type: AyahFactType.learn);

    final state = newState();
    await state.setLearningForToday(kawthar(state), 2);

    expect((await state.todayLearningUnit())!.verseStart, 2,
        reason: 'le verset 1 est déjà acquis : la portion du jour démarre à 2');
    expect((await state.todayLearningUnit())!.verseEnd, 3);

    await AyahFactsService.deleteLearnFacts(108, Riwaya.hafs);
  });

  test(
      "ensureDayPlan propose de lui-même la suite d'une sourate déjà en cours "
      "d'apprentissage", () async {
    final yesterday = _isoDate(DateTime.now().subtract(const Duration(days: 1)));
    // Sourate démarrée hier, aucun verset encore acquis (reach=0).
    await AyahFactsService.proposeLearnVerses(yesterday, Riwaya.hafs, 108, [1]);

    final state = newState();
    await state.ensureDayPlan();

    expect(state.pendingDate, isNull,
        reason: 'des lignes `learn` ne rendent pas un jour "en attente" — '
            'seul le type `revise` compte (AyahFactsService.pendingDate)');
    expect(await state.todayLearningUnit(), isNotNull);
    expect((await state.todayLearningUnit())!.sourate.id, 108);
    expect((await state.todayLearningUnit())!.verseEnd, 3,
        reason: 'versesToLearnPerDay par défaut = 3, la sourate en fait 3');

    await AyahFactsService.deleteLearnFacts(108, Riwaya.hafs);
  });

  test(
      'une sourate entièrement mémorisée rejoint la sélection de révision sans '
      'remettre le cycle à zéro', () async {
    final today = _isoDate(DateTime.now());
    final state = newState(cyclePosition: 1);
    await state.setLearningForToday(kawthar(state), 3);
    // Check-out : les 3 versets sont confirmés acquis.
    await state.markLearnVerses(today, 108, [1, 2, 3], true);

    final handed = await state.handOffLearnedSurahs();

    expect(handed.map((s) => s.id), [108]);
    expect(state.config!.selections.map((s) => s.sourate.id), contains(108));
    expect(state.cyclePosition, 1,
        reason:
            'ajouter une sourate fraîchement mémorisée ne doit pas invalider '
            'la position déjà atteinte dans les autres (contrairement à '
            'saveConfig, qui repart de 0 quand la sélection change)');
    final progress = await state.learningProgressList();
    expect(progress.memorisedCount, 1,
        reason: 'les faits `learn` sont conservés — ils sont la trace de '
            'mémorisation qui alimente « Sourates mémorisées »');
    expect(await state.learningInProgress(), isNull,
        reason: 'une sourate terminée ne compte plus comme "en cours"');
    expect(await state.handOffLearnedSurahs(), isEmpty,
        reason: 'la bascule est idempotente : rien à re-signaler');

    await AyahFactsService.deleteLearnFacts(108, Riwaya.hafs);
  });

  test(
      "un verset travaillé à la volée dans l'écran de pratique ne détourne pas "
      'le plan du jour vers sa sourate', () async {
    final today = _isoDate(DateTime.now());
    final state = newState();
    await state.setLearningForToday(kawthar(state), 2);
    // Sourate 30, pratiquée hors plan du jour : `learnVerses` écrit
    // `checked_out = 1`, et son id est plus petit que 108 — sans le filtre,
    // l'`ORDER BY surah_id` la ferait passer pour la portion du jour et le
    // check-out proposerait de « désapprendre » ces versets acquis.
    await AyahFactsService.learnVerses(30, [1, 2], Riwaya.hafs);

    final plan = await AyahFactsService.learnPlanFor(today, Riwaya.hafs);
    expect(plan!.surahId, 108);
    expect(plan.ayahIds, [1, 2]);

    await AyahFactsService.deleteLearnFacts(108, Riwaya.hafs);
    await AyahFactsService.deleteLearnFacts(30, Riwaya.hafs);
  });

  test(
      '« Je n\'apprends rien aujourd\'hui » survit à une réouverture de l\'app',
      () async {
    final yesterday = _isoDate(DateTime.now().subtract(const Duration(days: 1)));
    await AyahFactsService.proposeLearnVerses(yesterday, Riwaya.hafs, 108, [1]);
    // Les tests de ce fichier partagent la même base : repartir d'une
    // journée réellement neuve, sinon `ensureDayPlan` considère le plan du
    // jour comme déjà généré (c'est justement ce que ce test vérifie).
    await AyahFactsService.clearDayProposal(_isoDate(DateTime.now()), Riwaya.hafs);

    final state = newState();
    await state.ensureDayPlan(); // génère le plan du jour + propose la suite
    expect(await state.todayLearningUnit(), isNotNull);

    await state.setLearningForToday(null, 3); // refus explicite
    expect(await state.todayLearningUnit(), isNull);

    await state.ensureDayPlan(); // réouverture de l'app le même jour
    expect(await state.todayLearningUnit(), isNull,
        reason: 'la proposition n\'est faite qu\'au moment où le plan du jour '
            'est généré — sinon le refus serait annulé à chaque ouverture');

    await AyahFactsService.deleteLearnFacts(108, Riwaya.hafs);
  });

  test(
      'check-out : déclarer un verset appris EN PLUS étend la portion du jour',
      () async {
    final today = _isoDate(DateTime.now());
    final state = newState();
    await state.setLearningForToday(kawthar(state), 1);
    expect((await state.learningPlanFor(today))!.ayahIds, [1]);

    await state.extendLearningForDate(today);
    expect((await state.learningPlanFor(today))!.ayahIds, [1, 2],
        reason: 'le "+" ajoute le prochain verset non encore acquis');

    // Borné à la sourate : Al-Kawthar fait 3 versets, un 4e appel n'ajoute rien.
    await state.extendLearningForDate(today);
    await state.extendLearningForDate(today);
    expect((await state.learningPlanFor(today))!.ayahIds, [1, 2, 3]);

    await AyahFactsService.deleteLearnFacts(108, Riwaya.hafs);
  });

  test(
      'check-out : déclarer en plus le groupe SUIVANT du cycle le fait avancer '
      "d'autant (cadrage 2026-09-07)", () async {
    final day = _isoDate(DateTime.now().subtract(const Duration(days: 2)));
    final state = newState();
    // Les deux groupes du cycle (sourates 60 et 65, chacune multi-page donc
    // jamais regroupées) dans l'ordre réel du cycle.
    final groups = RevisionEngine.cycleGroups(
      config: state.config!,
      pageMetadata: PageMetadataService.pageMetadataFor(Riwaya.hafs),
    );
    expect(groups, hasLength(2));

    // Le moteur n'en propose qu'un (pagesPerDay = 1) ; l'utilisateur déclare
    // aussi le suivant, et coche tout.
    for (final group in groups) {
      await AyahFactsService.proposeUnits(day, Riwaya.hafs, group);
    }
    await state.markUnitsReached(
        [for (final g in groups) ...g], date: day);

    await state.ensureDayPlan(); // détecte le jour en attente
    expect(state.pendingDate, day);
    await state.checkOut(day);

    expect(state.cyclePosition, 0,
        reason: 'les 2 groupes du cycle faits le même jour → le cycle boucle '
            '(2 positions avancées sur un cycle de 2)');
  });

  test(
      "une sourate hors sélection déclarée en plus ne fait PAS sauter le cycle",
      () async {
    final day = _isoDate(DateTime.now().subtract(const Duration(days: 3)));
    final state = newState();
    final extra = state.sourates.firstWhere((s) => s.id == 112);

    // Seul le groupe proposé par le moteur est fait ; la sourate déclarée en
    // plus n'appartient pas au cycle configuré (60/65).
    final groups = RevisionEngine.cycleGroups(
      config: state.config!,
      pageMetadata: PageMetadataService.pageMetadataFor(Riwaya.hafs),
    );
    await AyahFactsService.proposeUnits(day, Riwaya.hafs, groups.first);
    await state.addToDayPlan(
        RevisionUnit(
            sourate: extra, verseStart: 1, verseEnd: extra.verses, isWhole: true),
        date: day);

    final units = await state.dayUnits(date: day);
    expect(units.map((u) => u.sourate.id), contains(112),
        reason: 'la sourate déclarée en plus rejoint le plan de ce jour-là');
    await state.markUnitsReached(units, date: day);

    await state.ensureDayPlan();
    await state.checkOut(day);
    expect(state.cyclePosition, 1,
        reason: 'un seul groupe du cycle fait : le curseur avance de 1, sans '
            'sauter le groupe suivant qui n\'a pas été révisé');
  });

  test('un verset décoché au check-out reste "à continuer" (reach=0)', () async {
    final today = _isoDate(DateTime.now());
    final state = newState();
    await state.setLearningForToday(kawthar(state), 3);

    await state.markLearnVerses(today, 108, [1, 2], true);
    await state.markLearnVerses(today, 108, [3], false);

    final plan = await AyahFactsService.learnPlanFor(today, Riwaya.hafs);
    expect(plan!.reachedVerses, {1, 2});
    final handed = await state.handOffLearnedSurahs();
    expect(handed, isEmpty,
        reason: 'sourate incomplète : pas de bascule en révision');

    await AyahFactsService.deleteLearnFacts(108, Riwaya.hafs);
  });
}
