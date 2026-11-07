import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran_revision/core/app_theme.dart';
import 'package:quran_revision/core/freshness_engine.dart';
import 'package:quran_revision/core/strings.dart';
import 'package:quran_revision/widgets/freshness_badge.dart';
import 'package:quran_revision/widgets/index_badge.dart';
import 'package:quran_revision/models/user_config.dart';
import 'package:quran_revision/widgets/outlined_action_button.dart';
import 'package:quran_revision/widgets/pill_chip.dart';
import 'package:quran_revision/widgets/profile_info_card.dart';
import 'package:quran_revision/widgets/primary_cta_button.dart';
import 'package:quran_revision/widgets/unit_range_label.dart';

import '../services/test_helpers.dart';

// Layout invariant, not an appearance test: on the smallest supported screen
// with enlarged text, nothing overflows (see test/CLAUDE.md).
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Without the real font, the test font (Ahem) gives wrong widths.
    final outfit = FontLoader('Outfit');
    for (final weight in ['Regular', 'SemiBold', 'Bold']) {
      outfit.addFont(rootBundle.load('assets/fonts/Outfit-$weight.ttf'));
    }
    await outfit.load();
  });

  Future<void> pumpSmall(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.5)),
        child: app!,
      ),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ));
    await tester.pump();
  }

  // A label squeezed into a fixed box wraps or clips without any overflow
  // error: laid out narrower than its natural width means it broke a line.
  void expectOneLine(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
    expect(paragraph.size.width,
        greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.01),
        reason: '"$text" is broken over several lines');
  }

  testWidgets('PrimaryCtaButton', (tester) async {
    await pumpSmall(
        tester,
        PrimaryCtaButton(
            label: 'Voir mon plan du jour', icon: Icons.arrow_forward, onPressed: () {}));
    expectOneLine(tester, 'Voir mon plan du jour');
  });

  testWidgets('OutlinedActionButton', (tester) async {
    await pumpSmall(
        tester,
        OutlinedActionButton(
            icon: Icons.add, label: 'Ajouter une sourate au plan', onTap: () {}));
    expectOneLine(tester, 'Ajouter une sourate au plan');
  });

  testWidgets('IndexBadge with three digits, smallest size', (tester) async {
    await pumpSmall(tester, const Row(children: [IndexBadge(text: '282', size: 26)]));
    expectOneLine(tester, '282');
  });

  testWidgets('FreshnessBadge', (tester) async {
    await pumpSmall(tester,
        const Row(children: [FreshnessBadge(level: FreshnessLevel.neverRevised)]));
  });

  testWidgets('UnitRangeLabel', (tester) async {
    await pumpSmall(tester,
        UnitRangeLabel(unit: testUnit(2, 255, 286), nameColor: Colors.black));
  });

  testWidgets('ProfileInfoCard keeps the value readable', (tester) async {
    await pumpSmall(
        tester,
        ProfileInfoCard(
          config: UserConfig(
              selections: const [],
              pagesPerDay: 10,
              startDate: DateTime(2026, 1, 1)),
          elapsed: 120,
          onEditRythme: () {},
          onEditSourates: () {},
        ));
    await tester.pump(const Duration(seconds: 1));
    // The value used to be written one letter per line.
    expectOneLine(tester, S.pagesParJour(10));
    expectOneLine(tester, S.rythmeLabelCourt);
  });

  testWidgets('quick-select PillChip row', (tester) async {
    // Same wrapping as selection_page.dart, kept here to lock the invariant.
    await pumpSmall(
        tester,
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(children: [
              PillChip(label: SOnboarding.toutLeCoran, onTap: () {}, selected: false),
              const SizedBox(width: 6),
              PillChip(label: SOnboarding.fractionTroisQuarts, onTap: () {}, selected: false),
              const SizedBox(width: 6),
              PillChip(label: SOnboarding.fractionMoitie, onTap: () {}, selected: false),
              const SizedBox(width: 6),
              PillChip(label: SOnboarding.fractionQuart, onTap: () {}, selected: false),
            ]),
          ),
        ));
    expectOneLine(tester, SOnboarding.toutLeCoran);
  });

  // Mirror the Row layouts of check_in_sections.dart and prayer_plan_card.dart:
  // a FittedBox in a non-flex Row child gets unbounded width and shrinks nothing.
  testWidgets('label and shrinking button side by side', (tester) async {
    await pumpSmall(
        tester,
        Row(children: [
          Expanded(child: Text(SCheckIn.checkInPrieres)),
          Flexible(
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.history, size: 16),
              label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(S.derniereSelection, style: AppText.caption)),
            ),
          ),
        ]));
  });

  testWidgets('learning rakaa subtitle row', (tester) async {
    await pumpSmall(
        tester,
        Row(children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(S.rakaaApprentissage, style: AppText.caption)),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(S.versetsCount(10), style: AppText.caption)),
          const SizedBox(width: 8),
          const Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: FreshnessBadge(level: FreshnessLevel.neverRevised),
            ),
          ),
        ]));
  });

  test('blocRange never breaks around the dash', () {
    expect(S.blocRange(1, 10), 'v.1\u2060–\u206010');
  });
}
