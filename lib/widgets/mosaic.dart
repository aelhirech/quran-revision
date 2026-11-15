import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/mosaic.dart' show MosaicTile;
import '../core/strings.dart';
import '../models/sourate.dart';
import '../state/app_state.dart';
import 'mosaic_tile_shape.dart';

const mosaicGap = 6.0;
const _minSide = 20.0;
const _maxSide = 44.0;
const _maxGridHeight = 240.0;
const _nameGap = 2.0;

// The tile, or the widest name under it plus 4 px.
double _cellWidth(double side, Size nameSize) => max(side, nameSize.width + 4);

/// Height of a grid of [count] cells wrapped in [width], each a tile of
/// [side] px over a name line of [nameSize].
double mosaicGridHeight({
  required int count,
  required double width,
  required double side,
  required Size nameSize,
}) {
  final cell = _cellWidth(side, nameSize);
  final columns = max(1, ((width + mosaicGap) / (cell + mosaicGap)).floor());
  final rows = (count / columns).ceil();
  final rowHeight = side + _nameGap + nameSize.height;
  return rows * rowHeight + (rows - 1) * mosaicGap;
}

/// Largest whole tile side between 20 and 44 px whose grid fits in 240 px;
/// 20 px when none does, and the grid then grows taller. Returns that side
/// and the cell width that goes with it.
({double side, double cellWidth}) mosaicLayout({
  required int count,
  required double width,
  required Size nameSize,
}) {
  var side = _minSide;
  for (var candidate = _maxSide; candidate > _minSide; candidate--) {
    final height = mosaicGridHeight(
      count: count,
      width: width,
      side: candidate,
      nameSize: nameSize,
    );
    if (height <= _maxGridHeight) {
      side = candidate;
      break;
    }
  }
  return (side: side, cellWidth: _cellWidth(side, nameSize));
}

TextStyle _nameStyle(AppPalette palette) =>
    GoogleFonts.amiri(fontSize: 12, height: 1.4, color: palette.primary);

// Widest width and tallest height of [names] laid out on one line, so that
// no name is ever cut or shrunk (US-32 crit. 3).
Size _measureNames(
  Iterable<String> names,
  TextStyle style,
  TextScaler textScaler,
) {
  var width = 0.0;
  var height = 0.0;
  for (final name in names) {
    final painter = TextPainter(
      text: TextSpan(text: name, style: style),
      textDirection: TextDirection.rtl,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    width = max(width, painter.width);
    height = max(height, painter.height);
    painter.dispose();
  }
  return Size(width, height);
}

/// The surahs as tiles in mushaf order, led by how many risk being forgotten
/// (US-21 crit. 1: that count comes before everything else).
class Mosaic extends StatelessWidget {
  final List<MosaicTile> tiles;
  final ValueChanged<MosaicTile> onTap;

  const Mosaic({super.key, required this.tiles, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final atRisk = tiles.where((tile) => tile.atRisk).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (atRisk > 0)
              Row(
                children: [
                  const MosaicTileShape(level: 0, atRisk: true, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      SReinforcement.aRisque(atRisk),
                      style: AppText.cardTitle.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                SReinforcement.aucuneARisque,
                style: AppText.body.copyWith(color: palette.textMuted),
              ),
            const SizedBox(height: 14),
            // Amiri loads asynchronously on first use: names measured with
            // the fallback font would leave cells too narrow once it arrives.
            ListenableBuilder(
              listenable: PaintingBinding.instance.systemFonts,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final appState = context.read<AppState>();
                  final nameStyle = _nameStyle(palette);
                  final nameSize = _measureNames(
                    tiles.map(
                      (tile) =>
                          appState.sourateById(tile.surahId)?.nameAr ?? '',
                    ),
                    nameStyle,
                    MediaQuery.textScalerOf(context),
                  );
                  final layout = mosaicLayout(
                    count: tiles.length,
                    width: constraints.maxWidth,
                    nameSize: nameSize,
                  );
                  return Wrap(
                    spacing: mosaicGap,
                    runSpacing: mosaicGap,
                    children: [
                      for (final tile in tiles)
                        _tile(
                          tile,
                          appState.sourateById(tile.surahId),
                          side: layout.side,
                          cellWidth: layout.cellWidth,
                          nameStyle: nameStyle,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    MosaicTile tile,
    Sourate? sourate, {
    required double side,
    required double cellWidth,
    required TextStyle nameStyle,
  }) {
    final level = SReinforcement.niveau(tile.level);
    return Semantics(
      button: true,
      label: [
        sourate?.nameFr ?? '',
        level,
        if (tile.atRisk) SReinforcement.risqueOublier,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onTap(tile),
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(
          width: cellWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MosaicTileShape(
                level: tile.level,
                atRisk: tile.atRisk,
                size: side,
              ),
              const SizedBox(height: _nameGap),
              Text(
                sourate?.nameAr ?? '',
                style: nameStyle,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
