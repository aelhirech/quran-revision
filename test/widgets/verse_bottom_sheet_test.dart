import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_revision/core/app_theme.dart';
import 'package:quran_revision/core/strings.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/state/app_state.dart';
import 'package:quran_revision/widgets/verse_audio_bar.dart';
import 'package:quran_revision/widgets/verse_bottom_sheet.dart';
import 'package:quran_revision/widgets/verse_row.dart';

import '../services/test_helpers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // No network in tests: fall back to the default font instead of fetching.
    GoogleFonts.config.allowRuntimeFetching = false;
    await initFfiTestDb('qr_test_verse_bottom_sheet_');
    await HafsService.initialize();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Al-Baqara 1..50. Pumping it again replaces the sheet with a fresh one,
  // like closing then reopening it.
  Future<void> pumpSheet(WidgetTester tester) async {
    final baqara = testSourate(2, verses: 286);
    final state = AppState(
      UserConfig(
        selections: [SourateSelection.whole(baqara)],
        pagesPerDay: 1,
        startDate: DateTime.now(),
        shuffleEnabled: false,
        riwaya: Riwaya.hafs,
      ),
      riwaya: Riwaya.hafs,
    );
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: VerseBottomSheet(
              key: UniqueKey(), sourate: baqara, ayahStart: 1, ayahEnd: 50),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // The list is lazy: read the first built row, never count them.
  int firstVerse(WidgetTester tester) =>
      tester.widget<VerseRow>(find.byType(VerseRow).first).number;

  // US-16 regression: header and audio bar now scroll with the verses. If they
  // were lazy list items, the bar's state would be disposed off-screen and the
  // US-11 portion reset to the full range on scrolling back up.
  testWidgets('la portion audio survit à un défilement aller-retour', (tester) async {
    await pumpSheet(tester);

    final barState = tester.state(find.byType(VerseAudioBar));
    await tester.tap(find.byTooltip(S.debutPlusUn));
    await tester.pump();
    expect(find.text('v.2'), findsOneWidget);

    final list = find.byType(CustomScrollView);
    // The first drag only grows the sheet to its max size; the next ones scroll.
    for (var i = 0; i < 3; i++) {
      await tester.drag(list, const Offset(0, -20000));
      await tester.pumpAndSettle();
    }
    // The bar stays mounted (that's the point), so check its position instead.
    expect(tester.getRect(find.byType(VerseAudioBar, skipOffstage: false)).bottom,
        lessThan(tester.getRect(list).top),
        reason: 'the bar must have scrolled off-screen');

    for (var i = 0; i < 3; i++) {
      await tester.drag(list, const Offset(0, 20000));
      await tester.pumpAndSettle();
    }
    expect(tester.state(find.byType(VerseAudioBar)), same(barState));
    expect(find.text('v.2'), findsOneWidget);
  });

  // US-18: the portion lives in the sheet, so the text follows the slider.
  testWidgets('resserrer la portion masque les versets, élargir les réaffiche',
      (tester) async {
    await pumpSheet(tester);
    expect(firstVerse(tester), 1);

    await tester.tap(find.byTooltip(S.debutPlusUn));
    await tester.pump();
    await tester.tap(find.byTooltip(S.debutPlusUn));
    await tester.pump();
    expect(firstVerse(tester), 3);
    // The header keeps the plan's range, whatever the portion.
    expect(find.textContaining(S.blocRange(1, 50)), findsOneWidget);

    await tester.tap(find.byTooltip(S.debutMoinsUn));
    await tester.pump();
    expect(firstVerse(tester), 2);
  });

  testWidgets('le texte suit la poignée pendant le glissé, avant le relâché',
      (tester) async {
    await pumpSheet(tester);
    final slider = tester.getRect(find.byType(RangeSlider));

    final gesture =
        await tester.startGesture(Offset(slider.left + 24, slider.center.dy));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    expect(firstVerse(tester), greaterThan(1));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('une feuille rouverte repart de la plage entière', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.byTooltip(S.debutPlusUn));
    await tester.pump();
    expect(firstVerse(tester), 2);

    await pumpSheet(tester);
    expect(firstVerse(tester), 1);
  });
}
