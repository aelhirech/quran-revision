import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Day close (US-13/US-14): what sealing a day unlocks (`SealOutcome`) and
/// the day recap rebuilt from `ayah_facts` (`dayRecap`).
String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initFfiTestDb('qr_test_app_state_day_close_');
    await HafsService.initialize();
    await PageMetadataService.initialize();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearFactsBetweenTests();
  });

  AppState newState() {
    final probe = AppState(null, riwaya: Riwaya.hafs);
    final mumtahanah = probe.sourates.firstWhere((s) => s.id == 60);
    return AppState(
      UserConfig(
        selections: [SourateSelection.whole(mumtahanah)],
        pagesPerDay: 1,
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        shuffleEnabled: false,
        riwaya: Riwaya.hafs,
      ),
      riwaya: Riwaya.hafs,
    );
  }

  Sourate byId(AppState state, int id) =>
      state.sourates.firstWhere((s) => s.id == id);

  test(
      'sceller le jour où le dernier verset est acquis annonce la sourate '
      'mémorisée, une seule fois', () async {
    final today = _isoDate(DateTime.now());
    final state = newState();
    await state.setLearningForToday(byId(state, 108), 3);
    await state.markLearnVerses(today, 108, [1, 2, 3], true);

    final first = await state.checkOut(today);
    expect(first.memorized.map((s) => s.id), [108]);
    expect(first.hasMilestone, isTrue);

    final second = await state.checkOut(today);
    expect(second.memorized, isEmpty,
        reason: 'rouvrir et re-sceller la journée ne rejoue pas le jalon');
    expect(second.hasMilestone, isFalse);

    await AyahFactsLearning.deleteLearnFacts(108, Riwaya.hafs);
  });

  test(
      'tour bouclé et sourate mémorisée le même soir remontent dans un seul '
      'résultat (US-13 crit. 3)', () async {
    final today = _isoDate(DateTime.now());
    final probe = AppState(null, riwaya: Riwaya.hafs);
    // Al-Kawthar alone fits on one page: a one-entry cycle, wrapped by a
    // single done day.
    final state = AppState(
      UserConfig(
        selections: [SourateSelection.whole(byId(probe, 108))],
        pagesPerDay: 1,
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        shuffleEnabled: false,
        riwaya: Riwaya.hafs,
      ),
      riwaya: Riwaya.hafs,
    );
    await state.ensureDayPlan();
    await AyahFactsRitual.setReach(today, Riwaya.hafs, 108, 1, 3, true);
    await state.setLearningForToday(byId(state, 103), 3);
    await state.markLearnVerses(today, 103, [1, 2, 3], true);

    final outcome = await state.checkOut(today);
    expect(outcome.cycleWrapped, isTrue);
    expect(outcome.memorized.map((s) => s.id), [103]);

    await AyahFactsLearning.deleteLearnFacts(103, Riwaya.hafs);
  });

  test('le bilan du jour dit ce qui a été revu, appris, et ce qui revient',
      () async {
    final today = _isoDate(DateTime.now());
    final state = newState();
    final mumtahanah = byId(state, 60);
    await AyahFactsRitual.proposeUnits(today, Riwaya.hafs, [
      RevisionUnit(sourate: mumtahanah, verseStart: 1, verseEnd: 6, isWhole: false),
    ]);
    await AyahFactsRitual.setReach(today, Riwaya.hafs, 60, 1, 4, true);
    await state.setLearningForToday(byId(state, 108), 2);
    await state.markLearnVerses(today, 108, [1], true);

    final recap = await state.dayRecap(today);
    expect(recap.revised.map((s) => s.id), [60]);
    expect(recap.learnedVerses, 1);
    expect(recap.leftover, isTrue,
        reason: 'versets 5-6 et verset appris 2 restés à reach=0');

    await AyahFactsRitual.setReach(today, Riwaya.hafs, 60, 5, 6, true);
    await state.markLearnVerses(today, 108, [2], true);
    expect((await state.dayRecap(today)).leftover, isFalse);

    final tomorrow =
        _isoDate(DateTime.now().add(const Duration(days: 1)));
    final empty = await state.dayRecap(tomorrow);
    expect(empty.revised, isEmpty);
    expect(empty.learnedVerses, 0);
    expect(empty.leftover, isFalse,
        reason: "le bilan d'un jour ne remonte rien d'un autre jour");

    await AyahFactsLearning.deleteLearnFacts(108, Riwaya.hafs);
  });

  test('le bilan survit au scellement (checked_out = 1)', () async {
    final today = _isoDate(DateTime.now());
    final state = newState();
    await state.setLearningForToday(byId(state, 108), 1);
    await state.markLearnVerses(today, 108, [1], true);
    await state.checkOut(today);

    expect((await state.dayRecap(today)).learnedVerses, 1,
        reason: 'learnPlanFor filtre checked_out = 0 ; le bilan, lui, lit '
            'la journée après son scellement');

    await AyahFactsLearning.deleteLearnFacts(108, Riwaya.hafs);
  });
}
