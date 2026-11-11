import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/mosaic.dart';
import 'package:quran_revision/models/sourate_selection.dart';

import '../services/test_helpers.dart';

void main() {
  final today = DateTime(2026, 11, 8);
  DateTime daysAgo(int days) => today.subtract(Duration(days: days));

  SourateSelection whole(int id, {int verses = 10}) =>
      SourateSelection.whole(testSourate(id, verses: verses));

  List<MosaicTile> build(
    List<SourateSelection> selections, {
    Map<int, Map<int, DateTime>> revisions = const {},
    Map<int, int> levels = const {},
    int? tourDays,
  }) =>
      Mosaic.build(
        selections: selections,
        levels: levels,
        lastRevisionByAyah: revisions,
        today: today,
        tourDays: tourDays,
      );

  test('un carreau par sourate sélectionnée, dans l\'ordre du mushaf', () {
    final tiles = build([whole(67), whole(2), whole(36)], levels: {36: 3});
    expect(tiles.map((t) => t.surahId), [2, 36, 67]);
    expect(tiles.map((t) => t.level), [0, 3, 0]);
  });

  test("à risque : la plus longtemps sans révision d'abord, les autres écartées", () {
    final tiles = build([whole(1), whole(2), whole(3), whole(4)], revisions: {
      1: {1: daysAgo(100)},
      2: {1: daysAgo(10)},
      3: {1: daysAgo(300)},
      4: {1: daysAgo(150)},
    });
    expect(atRiskOldestFirst(tiles).map((t) => t.surahId), [3, 4, 1]);
  });

  test('à risque au-delà de 90 jours depuis la plus récente révision', () {
    final tiles = build([whole(1), whole(2)], revisions: {
      1: {1: daysAgo(91), 2: daysAgo(200)},
      2: {1: daysAgo(90)},
    });
    expect(tiles.map((t) => t.atRisk), [true, false]);
    expect(tiles.first.daysSinceRevision, 91);
  });

  test('un tour plus long que 3 mois repousse le seuil à la durée du tour', () {
    final revisions = {
      1: {1: daysAgo(100)},
    };
    expect(build([whole(1)], revisions: revisions, tourDays: 120).single.atRisk,
        isFalse);
    expect(build([whole(1)], revisions: revisions, tourDays: 60).single.atRisk,
        isTrue);
    expect(build([whole(1)], revisions: revisions).single.atRisk, isTrue);
  });

  test('jamais révisée : jamais à risque', () {
    final tile = build([whole(1)]).single;
    expect(tile.daysSinceRevision, isNull);
    expect(tile.atRisk, isFalse);
  });

  test('un verset révisé récemment suffit : pas à risque', () {
    final tile = build([whole(1)], revisions: {
      1: {1: daysAgo(400), 5: daysAgo(3)},
    }).single;
    expect(tile.atRisk, isFalse);
  });

  test('plage partielle : seules ses révisions comptent', () {
    final partial = SourateSelection(
        sourate: testSourate(1, verses: 10), verseStart: 4, verseEnd: 6);
    final tile = build([partial], revisions: {
      1: {1: daysAgo(2), 5: daysAgo(150)},
    }).single;
    expect((tile.verseStart, tile.verseEnd), (4, 6));
    expect(tile.atRisk, isTrue);
  });

  test('deux plages d\'une sourate font un carreau sur toute leur étendue', () {
    final surah = testSourate(1, verses: 20);
    final tiles = build([
      SourateSelection(sourate: surah, verseStart: 12, verseEnd: 15),
      SourateSelection(sourate: surah, verseStart: 2, verseEnd: 5),
    ], revisions: {
      1: {3: daysAgo(10)},
    });
    expect(tiles, hasLength(1));
    expect((tiles.single.verseStart, tiles.single.verseEnd), (2, 15));
    expect(tiles.single.daysSinceRevision, 10);
  });
}
