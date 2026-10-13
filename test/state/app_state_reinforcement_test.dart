import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/services/page_metadata_service.dart';
import 'package:quran_revision/state/app_state.dart';

import '../services/test_helpers.dart';

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
    await state.ensureDayPlan();

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
    await state.ensureDayPlan();
    await state.setLearningForToday(
        state.sourates.firstWhere((s) => s.id == 108), 2);

    final inputs = await state.reinforcementInputs();
    expect(inputs.carried.containsKey(108), isFalse);
    expect(inputs.today.any((verse) => verse.$1 == 108), isFalse);
  });
}
