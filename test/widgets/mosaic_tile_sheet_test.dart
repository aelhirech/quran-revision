import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran_revision/core/app_theme.dart';
import 'package:quran_revision/core/mosaic.dart' show MosaicTile;
import 'package:quran_revision/core/strings.dart';
import 'package:quran_revision/models/learning_progress.dart';
import 'package:quran_revision/widgets/mosaic_tile_sheet.dart';

import '../services/test_helpers.dart';

void main() {
  setUpAll(() {
    // No network in tests: fall back to the default font instead of fetching.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final surah = testSourate(112, verses: 4);
  final learning = LearningProgress(
    sourate: surah,
    learnedVerses: {1},
    startDate: DateTime(2026, 11, 15),
  );

  MosaicTile tile({required bool learningOnly}) => MosaicTile(
    surahId: 112,
    verseStart: 1,
    verseEnd: 4,
    level: 0,
    daysSinceRevision: null,
    atRisk: false,
    learning: learning,
    isLearningOnly: learningOnly,
  );

  Future<void> pump(
    WidgetTester tester,
    MosaicTile tile,
    VoidCallback? onAbandon,
  ) => tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: MosaicTileSheet(
          tile: tile,
          sourate: surah,
          lastRevision: '',
          onSeeText: () {},
          onAbandon: onAbandon,
        ),
      ),
    ),
  );

  testWidgets('US-32 : sourate seulement en cours, versets appris et abandon, '
      'sans niveau ni « Voir le texte »', (tester) async {
    var abandoned = false;
    await pump(tester, tile(learningOnly: true), () => abandoned = true);

    expect(find.text(S.versetsAppris(1, 4)), findsOneWidget);
    expect(find.text(S.voirLeTexte), findsNothing);
    expect(find.text(SReinforcement.niveau(0)), findsNothing);
    await tester.tap(find.text(S.supprimerApprentissage));
    expect(abandoned, isTrue);
  });

  testWidgets(
    'US-32 : sourate sélectionnée et en cours, la partie révisée reste',
    (tester) async {
      await pump(tester, tile(learningOnly: false), () {});

      expect(find.text(S.versetsAppris(1, 4)), findsOneWidget);
      expect(find.text(S.voirLeTexte), findsOneWidget);
      expect(find.text(SReinforcement.niveau(0)), findsOneWidget);
      expect(find.text(S.supprimerApprentissage), findsOneWidget);
    },
  );

  testWidgets('sans onAbandon, aucun bouton de suppression', (tester) async {
    await pump(
      tester,
      const MosaicTile(
        surahId: 112,
        verseStart: 1,
        verseEnd: 4,
        level: 2,
        daysSinceRevision: 3,
        atRisk: false,
      ),
      null,
    );
    expect(find.text(S.supprimerApprentissage), findsNothing);
  });
}
