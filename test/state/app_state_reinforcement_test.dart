import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_revision/models/quiz_answer.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/services/page_metadata_service.dart';
import 'package:quran_revision/state/app_state.dart';

import '../services/test_helpers.dart';
import 'day_helpers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initFfiTestDb('qr_test_app_state_reinforcement_');
    await HafsService.initialize();
    await PageMetadataService.initialize();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearFactsBetweenTests();
  });

  AppState newState() {
    final sourates = AppState(null, riwaya: Riwaya.hafs).sourates;
    return AppState(
      UserConfig(
        selections: [
          for (final id in [60, 65])
            SourateSelection.whole(sourates.firstWhere((s) => s.id == id)),
        ],
        pagesPerDay: 1,
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        shuffleEnabled: false,
        riwaya: Riwaya.hafs,
      ),
      riwaya: Riwaya.hafs,
    );
  }

  test('sans configuration, rien n\'est porté', () async {
    final inputs = await AppState(null, riwaya: Riwaya.hafs).reinforcementInputs();
    expect(inputs.carried, isEmpty);
    expect(inputs.today, isEmpty);
  });

  test('les versets du plan du jour sont dans today', () async {
    final state = newState();
    await validateCheckIn(state);

    final inputs = await state.reinforcementInputs();
    final planned = {
      for (final unit in await state.dayUnits())
        for (final verse in unit.verses) (unit.sourate.id, verse),
    };
    expect(planned, isNotEmpty);
    expect(inputs.today, planned);
    expect(inputs.carried.keys, unorderedEquals([60, 65]));
    expect(inputs.carried[60], hasLength(13));
  });

  test(
      'un verset proposé à l\'apprentissage aujourd\'hui et pas encore appris '
      'n\'est ni porté ni dans today', () async {
    final state = newState();
    await validateCheckIn(state);
    await state.setLearningForToday(
        state.sourates.firstWhere((s) => s.id == 108), 2);

    final inputs = await state.reinforcementInputs();
    expect(inputs.carried.containsKey(108), isFalse);
    expect(inputs.today.any((verse) => verse.$1 == 108), isFalse);
  });

  test('US-21 : les réponses donnent le niveau et les questions à reprendre',
      () async {
    final state = newState();
    QuizAnswer passage(int ayah, bool held, int level) => QuizAnswer(
        kind: QuizKind.passage,
        surahId: 60,
        ayahId: ayah,
        rank: 0,
        level: level,
        held: held);

    for (var ayah = 1; ayah <= 3; ayah++) {
      await state.recordQuizAnswer(passage(ayah, true, 1));
    }
    await state.recordQuizAnswer(passage(4, false, 2));
    await state.recordQuizAnswer(QuizAnswer(
        kind: QuizKind.word,
        surahId: 65,
        ayahId: 1,
        rank: 3,
        level: 0,
        held: false));

    final inputs = await state.reinforcementSeriesInputs();
    expect(inputs.levels, {60: 2});
    expect(inputs.retryPassages, [(60, 4, 0)]);
    expect(inputs.retryWords, [(65, 1, 3)]);
    // Never revised: no surah at risk.
    expect(inputs.atRisk, isEmpty);
    final tiles = await state.mosaicTiles();
    expect(tiles.map((t) => (t.surahId, t.level)), [(60, 2), (65, 0)]);
  });

  test('US-21 : les niveaux attendent les réponses encore en écriture',
      () async {
    final state = newState();
    for (var ayah = 1; ayah <= 3; ayah++) {
      // Not awaited, as the series screen does.
      state.recordQuizAnswer(QuizAnswer(
          kind: QuizKind.passage,
          surahId: 65,
          ayahId: ayah,
          rank: 0,
          level: 1,
          held: true));
    }
    expect(await state.quizLevels(), {65: 2});
  });
}
