import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_revision/core/day_dates.dart';
import 'package:quran_revision/core/revision_engine.dart';
import 'package:quran_revision/models/ayah_fact.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/sourate.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';
import 'package:quran_revision/services/ayah_facts_service.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/services/page_metadata_service.dart';
import 'package:quran_revision/state/app_state.dart';

import '../services/test_helpers.dart';

/// US-29: a surah learned in full joins revision whole, once, on the seal of
/// the day its last verse was acquired — and the cycle cursor keeps pointing
/// at the same verse.

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initFfiTestDb('qr_test_app_state_learning_widen_');
    await HafsService.initialize();
    await PageMetadataService.initialize();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearFactsBetweenTests();
  });

  final today = dayKey(DateTime.now());
  final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
  // Late: the surah list needs HafsService, loaded in setUpAll.
  late final probe = AppState(null, riwaya: Riwaya.hafs);
  Sourate byId(int id) => probe.sourates.firstWhere((s) => s.id == id);

  // 60/65: real multi-page surahs under revision. 108 (Al-Kawthar, 3 verses)
  // is the surah being learned.
  SourateSelection whole(int id) => SourateSelection.whole(byId(id));
  SourateSelection range(int id, int start, int end) =>
      SourateSelection(sourate: byId(id), verseStart: start, verseEnd: end);

  AppState newState(List<SourateSelection> selections,
          {int cyclePosition = 0, bool shuffle = false}) =>
      AppState(
        UserConfig(
          selections: selections,
          pagesPerDay: 1,
          startDate: DateTime(2026, 1, 1),
          shuffleEnabled: shuffle,
          riwaya: Riwaya.hafs,
        ),
        riwaya: Riwaya.hafs,
        initialCyclePosition: cyclePosition,
      );

  Future<void> learn(AppState state, String date, int surahId,
      List<int> ayahIds) async {
    await AyahFactsLearning.proposeLearnVerses(
        date, Riwaya.hafs, surahId, ayahIds);
    await state.markLearnVerses(date, surahId, ayahIds, true);
  }

  List<SourateSelection> selectionsOf(AppState state, int surahId) =>
      state.config!.selections.where((s) => s.sourate.id == surahId).toList();

  test('plage partielle complétée aujourd\'hui : sourate entière, annoncée',
      () async {
    final state = newState([whole(60), whole(65), range(108, 1, 2)]);
    await learn(state, yesterday, 108, [1, 2]);
    await learn(state, today, 108, [3]);

    final outcome = await state.checkOut(today);

    expect(outcome.memorized.map((s) => s.id), [108]);
    expect(selectionsOf(state, 108).single.isWhole, isTrue);
    expect(state.config!.selections.indexOf(whole(108)), 2,
        reason: 'la plage est remplacée à sa place, pas ajoutée en fin');
  });

  test('refaire la fin de journée du même jour : rien à annoncer', () async {
    final state = newState([whole(60), whole(65), range(108, 1, 2)]);
    await learn(state, today, 108, [1, 2, 3]);
    await state.checkOut(today);
    final before = [...state.config!.selections];

    final again = await state.checkOut(today);

    expect(again.memorized, isEmpty);
    expect(state.config!.selections, before);
  });

  test('plage resserrée après l\'élargissement : le réglage fait foi',
      () async {
    final state = newState([whole(60), whole(65), range(108, 1, 2)]);
    await learn(state, yesterday, 108, [1, 2, 3]);
    await state.checkOut(yesterday);
    expect(selectionsOf(state, 108).single.isWhole, isTrue);
    expect(
        await state.saveConfig(state.config!.copyWith(
            selections: [whole(60), whole(65), range(108, 1, 2)])),
        isTrue);

    final outcome = await state.checkOut(today);

    expect(outcome.memorized, isEmpty);
    expect(selectionsOf(state, 108).single, range(108, 1, 2));
  });

  test('rattrapage : la fin de journée d\'hier élargit la sourate complétée hier',
      () async {
    final state = newState([whole(60), whole(65), range(108, 1, 2)]);
    await learn(state, yesterday, 108, [1, 2, 3]);

    final outcome = await state.checkOut(yesterday);

    expect(outcome.memorized.map((s) => s.id), [108]);
    expect(selectionsOf(state, 108).single.isWhole, isTrue);
  });

  test('sélection déjà entière : aucune annonce, curseur inchangé', () async {
    final state =
        newState([whole(60), whole(65), whole(108)], cyclePosition: 1);
    await learn(state, today, 108, [1, 2, 3]);

    final outcome = await state.checkOut(today);

    expect(outcome.memorized, isEmpty);
    expect(state.cyclePosition, 1);
  });

  test(
      'mélange activé, sourate élargie placée avant le curseur : le curseur '
      'pointe le même verset', () async {
    // Al-Mulk (67) v.1-12 sits on its first page only; whole, it adds pages.
    final state = newState(
        [whole(60), whole(65), range(67, 1, 12), whole(78), whole(80)],
        shuffle: true);
    final pages = PageMetadataService.pageMetadataFor(Riwaya.hafs);
    final oldCycle =
        RevisionEngine.buildCycle(config: state.config!, pageMetadata: pages);
    final mulkAt =
        oldCycle.indexWhere((e) => e.any((u) => u.sourate.id == 67));
    expect(mulkAt, lessThan(oldCycle.length - 1),
        reason: 'précondition : Al-Mulk doit se placer avant le curseur');
    final cursor = mulkAt + 1;
    final anchor = oldCycle[cursor].first;
    final reanchored = newState(state.config!.selections,
        cyclePosition: cursor, shuffle: true);
    await learn(reanchored, today, 67, List.generate(30, (i) => i + 1));

    final outcome = await reanchored.checkOut(today);

    expect(outcome.memorized.map((s) => s.id), [67]);
    final newCycle = RevisionEngine.buildCycle(
        config: reanchored.config!, pageMetadata: pages);
    expect(newCycle.length, greaterThan(oldCycle.length));
    final pointed = newCycle[reanchored.cyclePosition].first;
    expect((pointed.sourate.id, pointed.verseStart),
        (anchor.sourate.id, anchor.verseStart));
    expect(reanchored.cyclePosition, isNot(cursor),
        reason: 'sans réancrage, l\'index seul aurait pointé une autre page');
  });

  test('sourate apprise retirée des réglages : pas remise un autre jour',
      () async {
    final state = newState([whole(60), whole(65)]);
    await learn(state, yesterday, 108, [1, 2, 3]);

    final outcome = await state.checkOut(today);

    expect(outcome.memorized, isEmpty);
    expect(selectionsOf(state, 108), isEmpty);
  });

  test('sourate apprise dans une autre riwaya : sélection Hafs inchangée',
      () async {
    final state = newState([whole(60), whole(65), range(108, 1, 2)]);
    await AyahFactsLearning.proposeLearnVerses(
        today, Riwaya.warsh, 108, [1, 2, 3]);
    await AyahFactsRitual.setReachForVerses(
        today, Riwaya.warsh, 108, [1, 2, 3], true,
        type: AyahFactType.learn);

    final outcome = await state.checkOut(today);

    expect(outcome.memorized, isEmpty);
    expect(selectionsOf(state, 108).single, range(108, 1, 2));
  });

  test('deux sélections de la même sourate : une seule reste, entière',
      () async {
    final state = newState(
        [whole(60), range(108, 1, 1), whole(65), range(108, 3, 3)]);
    await learn(state, today, 108, [1, 2, 3]);

    await state.checkOut(today);

    expect(state.config!.selections, [whole(60), whole(108), whole(65)]);
  });
}
