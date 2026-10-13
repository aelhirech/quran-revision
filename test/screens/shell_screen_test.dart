import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_revision/core/app_theme.dart';
import 'package:quran_revision/core/strings.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';
import 'package:quran_revision/screens/shell_screen.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/services/page_metadata_service.dart';
import 'package:quran_revision/state/app_state.dart';

import '../services/test_helpers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // No network in tests: fall back to the default font instead of fetching.
    GoogleFonts.config.allowRuntimeFetching = false;
    await initFfiTestDb('qr_test_shell_screen_');
    await HafsService.initialize();
    await PageMetadataService.initialize();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The label, not the index: a tab inserted before Récap moves the index of
  // every tab after it, and an index that was not corrected would still read
  // the same number.
  String selectedTab(WidgetTester tester) {
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    return (bar.destinations[bar.selectedIndex] as NavigationDestination).label;
  }

  testWidgets(
      'la première clôture ouvre le Récap puis les Réglages, une seule fois',
      (tester) async {
    final state = AppState(UserConfig(
      selections: [SourateSelection.whole(testSourate(114, verses: 6, words: 20))],
      pagesPerDay: 1,
      startDate: DateTime.now(),
      shuffleEnabled: false,
    ));
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const ShellScreen(),
      ),
    ));
    // `ShellScreen.initState` starts SQLite reads that never complete under
    // the fake clock: nothing below waits for them. The bar slides in, and
    // cannot be tapped before: one frame starts the slide, the next ends it.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(selectedTab(tester), S.planDuJour);

    await state.markGuideDone('checkout_done');
    await tester.pump();
    expect(selectedTab(tester), S.recap);

    await state.markGuideDone('recap_seen');
    await tester.pump();
    expect(selectedTab(tester), S.reglages);

    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text(S.planDuJour)));
    await tester.pump();
    expect(selectedTab(tester), S.planDuJour);

    await state.markGuideDone('settings_seen');
    await tester.pump();
    expect(selectedTab(tester), S.planDuJour);

    // flutter_animate starts each entrance on a timer, and a timer left
    // pending fails the test: let the last ones fire.
    await tester.pump(const Duration(seconds: 1));
  });
}
