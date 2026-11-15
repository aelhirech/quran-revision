import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quran_revision/core/app_theme.dart';
import 'package:quran_revision/core/mosaic.dart' show MosaicTile;
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/state/app_state.dart';
import 'package:quran_revision/widgets/mosaic.dart';

import '../services/test_helpers.dart';

// Grid widths inside the tab's card: screen minus 2 × 16 px of page padding
// and 2 × 16 px of card padding.
const _width375 = 375.0 - 64;
const _width320 = 320.0 - 64;

// Widest surah name in Amiri 12 px at ×1 (40.4 px measured), and its line
// height.
const _name = Size(40, 12 * 1.4);

double _height(int count, double width, double side, {Size name = _name}) =>
    mosaicGridHeight(count: count, width: width, side: side, nameSize: name);

bool _fits(int count, double width, double side) =>
    _height(count, width, side) <= 240;

double _side(int count, double width) =>
    mosaicLayout(count: count, width: width, nameSize: _name).side;

void main() {
  test('un seul carreau prend la plus grande taille, 44 px', () {
    expect(_side(1, _width375), 44);
    expect(_side(1, _width320), 44);
  });

  test('20 carreaux tiennent dans 240 px', () {
    final side = _side(20, _width375);
    expect(side, greaterThan(20));
    expect(_fits(20, _width375, side), isTrue);
  });

  test('113 carreaux sur un téléphone : 20 px, et la grille s\'allonge', () {
    for (final width in [_width375, _width320]) {
      expect(_side(113, width), 20);
      expect(_fits(113, width, 20), isFalse);
    }
  });

  test('la cellule prend la largeur du nom quand il dépasse le carreau', () {
    final wide = mosaicLayout(
      count: 1,
      width: _width375,
      nameSize: const Size(60, 17),
    );
    expect(wide.side, 44);
    expect(wide.cellWidth, 64);
    final narrow = mosaicLayout(
      count: 1,
      width: _width375,
      nameSize: const Size(30, 17),
    );
    expect(narrow.cellWidth, 44);
  });

  test(
    'un nom plus large fait moins de colonnes, donc une grille plus haute',
    () {
      final narrow = _height(113, _width375, 20, name: const Size(20, 17));
      final wide = _height(113, _width375, 20, name: const Size(60, 17));
      expect(wide, greaterThan(narrow));
    },
  );

  test('toujours le plus grand côté qui tient, entre 20 et 44 px', () {
    for (final width in [_width320, _width375, 700.0]) {
      for (var count = 1; count <= 113; count++) {
        final side = _side(count, width);
        expect(side, inInclusiveRange(20, 44));
        if (side > 20) expect(_fits(count, width, side), isTrue);
        if (side < 44) {
          expect(
            _fits(count, width, side + 1),
            isFalse,
            reason: '$count carreaux, $width px : ${side + 1} tenait',
          );
        }
      }
    }
  });

  group('noms arabes sur la vraie police', () {
    setUpAll(() async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await HafsService.initialize();
      // Without the real font, the test font (Ahem) gives wrong widths.
      await GoogleFonts.pendingFonts([GoogleFonts.amiri()]);
    });

    Future<void> pumpMosaic(
      WidgetTester tester,
      List<int> surahIds, {
      required double screenWidth,
      required double scale,
    }) async {
      tester.view.physicalSize = Size(screenWidth, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final appState = AppState(null, riwaya: Riwaya.hafs);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: app!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Mosaic(
                  tiles: [
                    for (final id in surahIds)
                      MosaicTile(
                        surahId: id,
                        verseStart: 1,
                        verseEnd: 1,
                        level: 0,
                        daysSinceRevision: null,
                        atRisk: false,
                      ),
                  ],
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    // Al-Munafiqun, Al-Imran and Al-Mumtahana: the longest names.
    for (final scale in [1.0, 1.5]) {
      testWidgets('les noms longs ne débordent pas à 320 px, ×$scale', (
        tester,
      ) async {
        await pumpMosaic(tester, [3, 60, 63], screenWidth: 320, scale: scale);
        expect(tester.takeException(), isNull);
        for (final name in ['آل عمران', 'الممتحنة', 'المنافقون']) {
          expectOneLine(tester, name);
        }
      });

      testWidgets('113 sourates ne débordent pas à 320 px, ×$scale', (
        tester,
      ) async {
        await pumpMosaic(
          tester,
          [for (var id = 2; id <= 114; id++) id],
          screenWidth: 320,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
