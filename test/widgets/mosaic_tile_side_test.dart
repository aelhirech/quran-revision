import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/widgets/mosaic.dart';

// Grid widths inside the tab's card: screen minus 2 × 16 px of page padding
// and 2 × 16 px of card padding.
const _width375 = 375.0 - 64;
const _width320 = 320.0 - 64;

bool _fits(int count, double width, double side) =>
    mosaicGridHeight(count: count, width: width, side: side) <= 240;

void main() {
  test('un seul carreau prend la plus grande taille, 44 px', () {
    expect(mosaicTileSide(count: 1, width: _width375), 44);
    expect(mosaicTileSide(count: 1, width: _width320), 44);
  });

  test('20 carreaux tiennent dans 240 px', () {
    final side = mosaicTileSide(count: 20, width: _width375);
    expect(side, greaterThanOrEqualTo(20));
    expect(_fits(20, _width375, side), isTrue);
  });

  test('114 carreaux sur un téléphone : 20 px, et la grille s\'allonge', () {
    for (final width in [_width375, _width320]) {
      expect(mosaicTileSide(count: 114, width: width), 20);
      expect(_fits(114, width, 20), isFalse);
    }
  });

  test('114 carreaux tiennent dans 240 px quand la largeur le permet', () {
    final side = mosaicTileSide(count: 114, width: 700);
    expect(side, greaterThan(20));
    expect(_fits(114, 700, side), isTrue);
  });

  test('toujours le plus grand côté qui tient, entre 20 et 44 px', () {
    for (final width in [_width320, _width375, 700.0]) {
      for (var count = 1; count <= 114; count++) {
        final side = mosaicTileSide(count: count, width: width);
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
}
