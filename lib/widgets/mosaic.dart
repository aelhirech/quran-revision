import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/mosaic.dart' show MosaicTile;
import '../core/strings.dart';
import '../state/app_state.dart';
import 'mosaic_tile_shape.dart';

const mosaicGap = 6.0;
const _minSide = 20.0;
const _maxSide = 44.0;
const _maxGridHeight = 240.0;

/// Height of a grid of [count] tiles of [side] px wrapped in [width].
double mosaicGridHeight({
  required int count,
  required double width,
  required double side,
}) {
  final columns = max(1, ((width + mosaicGap) / (side + mosaicGap)).floor());
  final rows = (count / columns).ceil();
  return rows * side + (rows - 1) * mosaicGap;
}

/// Largest whole tile side between 20 and 44 px whose grid fits in 240 px;
/// 20 px when none does, and the grid then grows taller.
double mosaicTileSide({required int count, required double width}) {
  for (var side = _maxSide; side > _minSide; side--) {
    if (mosaicGridHeight(count: count, width: width, side: side) <=
        _maxGridHeight) {
      return side;
    }
  }
  return _minSide;
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
            LayoutBuilder(
              builder: (context, constraints) {
                final side = mosaicTileSide(
                  count: tiles.length,
                  width: constraints.maxWidth,
                );
                return Wrap(
                  spacing: mosaicGap,
                  runSpacing: mosaicGap,
                  children: [
                    for (final tile in tiles) _tile(context, tile, side),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, MosaicTile tile, double side) {
    final name =
        context.read<AppState>().sourateById(tile.surahId)?.nameFr ?? '';
    final level = SReinforcement.niveau(tile.level);
    return Semantics(
      button: true,
      label: [
        name,
        level,
        if (tile.atRisk) SReinforcement.risqueOublier,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onTap(tile),
        customBorder: const CircleBorder(),
        child: MosaicTileShape(
          level: tile.level,
          atRisk: tile.atRisk,
          size: side,
        ),
      ),
    );
  }
}
