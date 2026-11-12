import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_revision/core/day_dates.dart';
import 'package:quran_revision/core/revision_engine.dart';
import 'package:quran_revision/core/tour_order.dart';
import 'package:quran_revision/models/revision_unit.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';
import 'package:quran_revision/services/ayah_facts_service.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/services/page_metadata_service.dart';
import 'package:quran_revision/services/storage_service.dart';
import 'package:quran_revision/state/app_state.dart';

import '../services/test_helpers.dart';
import 'day_helpers.dart';

/// Order of the round (US-26): drawn when a round starts, stored, kept until
/// the next one.

// Al-Qadr (page 598), Al-Asr (601) and Al-Kawthar (602): three whole surahs
// on three pages, so three cycle entries of one page each. Al-Fatiha is not
// in the app's surah list.
const _ids = [97, 103, 108];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initFfiTestDb('qr_test_app_state_tour_');
    await HafsService.initialize();
    await PageMetadataService.initialize();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearFactsBetweenTests();
  });

  // Late: the surah list needs HafsService, loaded in setUpAll.
  late final probe = AppState(null, riwaya: Riwaya.hafs);
  List<SourateSelection> whole(List<int> ids) => [
        for (final id in ids)
          SourateSelection.whole(probe.sourates.firstWhere((s) => s.id == id)),
      ];

  AppState newState({
    required bool shuffle,
    List<int>? tourOrder = _ids,
    int pagesPerDay = 10,
    int cursor = 0,
    Random? random,
  }) =>
      AppState(
        UserConfig(
          selections: whole(_ids),
          pagesPerDay: pagesPerDay,
          startDate: DateTime.now().subtract(const Duration(days: 30)),
          shuffleEnabled: shuffle,
          tourOrder: tourOrder,
        ),
        riwaya: Riwaya.hafs,
        initialCyclePosition: cursor,
        random: random,
      );

  /// A sealed past day on which every verse of [surahId] was revised.
  Future<void> revisedDaysAgo(int days, int surahId,
      {Riwaya riwaya = Riwaya.hafs}) async {
    final date = dayKey(DateTime.now().subtract(Duration(days: days)));
    final sourate = probe.sourates.firstWhere((s) => s.id == surahId);
    await AyahFactsRitual.proposeUnits(date, riwaya, [
      RevisionUnit(
          sourate: sourate, verseStart: 1, verseEnd: sourate.verses, isWhole: true),
    ]);
    await AyahFactsRitual.setReach(date, riwaya, surahId, 1, sourate.verses, true);
    await AyahFactsRitual.sealDay(date, riwaya);
  }

  /// Validates today's check-in and marks every proposed verse done.
  Future<void> doToday(AppState state) async {
    await validateCheckIn(state);
    final today = dayKey(DateTime.now());
    for (final unit in (await state.checkInStart()).units) {
      await AyahFactsRitual.setReach(today, Riwaya.hafs, unit.sourate.id,
          unit.verseStart, unit.verseEnd, true);
    }
  }

  List<List<RevisionUnit>> cycleOf(AppState state) => RevisionEngine.buildCycle(
      config: state.config!,
      pageMetadata: PageMetadataService.pageMetadataFor(Riwaya.hafs));

  test('le jour qui franchit la fin du tour tire un nouvel ordre et repart de 0',
      () async {
    for (final id in _ids) {
      await revisedDaysAgo(10, id);
    }
    // Cursor on the last entry, 2 pages a day: today = Al-Kawthar, then
    // Al-Qadr past the end.
    final state = newState(shuffle: false, pagesPerDay: 2, cursor: 2);
    await doToday(state);
    final outcome = await state.checkOut(dayKey(DateTime.now()));

    expect(outcome.cycleWrapped, isTrue);
    expect(state.cyclePosition, 0,
        reason: 'la page revue au-delà de la fin compte pour l\'ancien tour');
    expect(state.config!.tourOrder, [103, 97, 108],
        reason: 'Al-Asr (10 jours) avant les deux revues aujourd\'hui');
    expect((await StorageService.loadConfig(Riwaya.hafs))!.tourOrder, [103, 97, 108]);
    expect(await StorageService.loadCyclePosition(Riwaya.hafs), 0);
  });

  test('bouclage avec le mélange actif : nouveau tirage, curseur 0, sauvé',
      () async {
    final state = newState(shuffle: true, random: Random(7));
    await doToday(state);
    await state.checkOut(dayKey(DateTime.now()));

    final expected = TourOrder.compute(
      selections: whole(_ids),
      shuffle: true,
      lastRevisionByAyah:
          await AyahFactsService.lastRevisionDatesPerVerse(riwaya: Riwaya.hafs),
      today: DateTime.now(),
      random: Random(7),
    );
    expect(state.config!.tourOrder, expected);
    expect(state.cyclePosition, 0);
    expect((await StorageService.loadConfig(Riwaya.hafs))!.tourOrder, expected);
  });

  test('re-sceller la journée ne tire pas un nouvel ordre', () async {
    final state = newState(shuffle: true, random: Random(7));
    await doToday(state);
    final today = dayKey(DateTime.now());
    await state.checkOut(today);
    final afterFirst = state.config;

    final outcome = await state.checkOut(today);
    expect(outcome.cycleWrapped, isFalse);
    expect(identical(state.config, afterFirst), isTrue);
    expect(state.cyclePosition, 0);
  });

  test("un jour qui n'atteint pas la fin du tour garde l'ordre", () async {
    final state = newState(shuffle: false, pagesPerDay: 1);
    await doToday(state);
    await revisedDaysAgo(400, 108);
    await state.checkOut(dayKey(DateTime.now()));

    expect(state.config!.tourOrder, _ids,
        reason: 'les dates de révision changent, l\'ordre du tour non');
    expect(state.cyclePosition, 1);
  });

  test('changer le rythme garde ordre et curseur', () async {
    final state = newState(shuffle: true, tourOrder: [108, 103, 97], cursor: 1);
    await state.saveConfig(state.config!.copyWith(pagesPerDay: 3));

    expect(state.config!.tourOrder, [108, 103, 97]);
    expect(state.cyclePosition, 1);
  });

  test('changer la sélection tire un nouvel ordre et repart de 0', () async {
    await revisedDaysAgo(5, 103);
    await revisedDaysAgo(50, 97);
    final state = newState(shuffle: false, cursor: 1);
    await state.saveConfig(
        state.config!.copyWith(selections: whole([..._ids, 112])));

    expect(state.config!.tourOrder, [108, 112, 97, 103]);
    expect(state.cyclePosition, 0);
    expect((await StorageService.loadConfig(Riwaya.hafs))!.tourOrder,
        [108, 112, 97, 103]);
  });

  test('basculer le mélange tire un nouvel ordre dans les deux sens', () async {
    await revisedDaysAgo(5, 103);
    await revisedDaysAgo(50, 97);
    final state = newState(shuffle: true, tourOrder: _ids, cursor: 2);

    expect(await state.setShuffleEnabled(false), isTrue);
    expect(state.config!.tourOrder, [108, 97, 103]);
    expect(state.cyclePosition, 0);

    await state.advanceCycle(1, 3);
    expect(await state.setShuffleEnabled(true), isTrue);
    expect(TourOrder.covers(state.config!.tourOrder, state.config!.selections),
        isTrue);
    expect(state.cyclePosition, 0);
    expect(await StorageService.loadCyclePosition(Riwaya.hafs), 0);
  });

  test('une sourate apprise en cours de tour passe en fin de tour', () async {
    final state = newState(shuffle: true, tourOrder: [108, 103, 97], pagesPerDay: 1);
    final today = dayKey(DateTime.now());
    final nasr = probe.sourates.firstWhere((s) => s.id == 110);
    await state.setLearningForToday(nasr, 3);
    await state.markLearnVerses(today, 110, [1, 2, 3], true);
    await state.checkOut(today);

    expect(state.config!.selections.map((s) => s.sourate.id), contains(110));
    expect(state.config!.tourOrder, [108, 103, 97]);
    expect(cycleOf(state).last.single.sourate.id, 110);

    await AyahFactsLearning.deleteLearnFacts(110, Riwaya.hafs);
  });

  test("l'ordre de l'aperçu d'onboarding est celui enregistré", () async {
    final state = AppState(null, riwaya: Riwaya.hafs, random: Random(1));
    final seed = DateTime(2026, 11, 12).millisecondsSinceEpoch;
    final preview = state.computeTourOrder(whole(_ids), true, Random(seed));
    await state.saveConfig(UserConfig(
      selections: whole(_ids),
      pagesPerDay: 1,
      startDate: DateTime(2026, 11, 12),
      tourOrder: state.computeTourOrder(whole(_ids), true, Random(seed)),
    ));

    expect(state.config!.tourOrder, preview);
  });

  test("chaque riwaya tire avec son propre historique", () async {
    await revisedDaysAgo(10, 103);
    await revisedDaysAgo(5, 97);
    await revisedDaysAgo(5, 108);
    await revisedDaysAgo(300, 97, riwaya: Riwaya.warsh);
    final state = newState(shuffle: true, tourOrder: null);
    await state.refreshFreshness(notify: false);

    expect(state.computeTourOrder(whole(_ids), false, Random(0)), [103, 97, 108],
        reason: "Al-Qadr à 300 jours en Warsh ne compte pas en Hafs");
  });
}
