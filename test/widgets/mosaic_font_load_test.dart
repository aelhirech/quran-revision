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

// Lifecycle trap, in its own file: Amiri must not be loaded yet when the
// mosaic first lays out, which another test in the same process would undo.
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await HafsService.initialize();
  });

  testWidgets('les cellules se recalculent quand Amiri finit de charger', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: AppState(null, riwaya: Riwaya.hafs),
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: Mosaic(
              tiles: const [
                MosaicTile(
                  surahId: 63,
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
    );
    double cellWidth() => tester.getSize(find.byType(InkWell)).width;
    final before = cellWidth();

    await tester.runAsync(
      () => GoogleFonts.pendingFonts([GoogleFonts.amiri()]),
    );
    await tester.pump();

    // The fallback test font is far wider than Amiri for this name.
    expect(cellWidth(), lessThan(before));
  });
}
