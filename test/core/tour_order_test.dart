import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/revision_engine.dart';
import 'package:quran_revision/core/tour_order.dart';
import 'package:quran_revision/models/sourate.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';

import '../services/test_helpers.dart';

/// Order of the round (US-26), pure Dart with fixed seeds.

Sourate _sourate(int id) => testSourate(id, verses: 10, words: 100);

final _today = DateTime(2026, 11, 12);

/// Every verse of [surahId] (1..[verses]) last revised [days] days ago.
Map<int, DateTime> _revised(int days, {int verses = 10}) => {
      for (var v = 1; v <= verses; v++)
        v: _today.subtract(Duration(days: days)),
    };

List<SourateSelection> _whole(List<int> ids) =>
    [for (final id in ids) SourateSelection.whole(_sourate(id))];

List<int> _draw(List<SourateSelection> selections,
        Map<int, Map<int, DateTime>> history, int seed,
        {bool shuffle = true}) =>
    TourOrder.compute(
      selections: selections,
      shuffle: shuffle,
      lastRevisionByAyah: history,
      today: _today,
      random: Random(seed),
    );

/// How often each surah comes first over seeds 0..[seeds]-1.
Map<int, int> _firstCounts(List<SourateSelection> selections,
    Map<int, Map<int, DateTime>> history, int seeds) {
  final counts = <int, int>{};
  for (var seed = 0; seed < seeds; seed++) {
    final first = _draw(selections, history, seed).first;
    counts[first] = (counts[first] ?? 0) + 1;
  }
  return counts;
}

void main() {
  group('TourOrder.compute — tirage pondéré (mélange actif)', () {
    test('une sourate jamais révisée pèse plus que la plus ancienne révisée',
        () {
      // Ages 0 (weight 1) against never revised (weight 0 + 2 = 2): the never
      // revised one comes first about 2 times out of 3.
      final counts = _firstCounts(_whole([1, 2]), {1: _revised(0)}, 300);
      expect(counts[2]!, greaterThan(170));
      expect(counts[2]!, lessThan(230));
    });

    test('sans historique, les poids sont égaux : tirage uniforme', () {
      final counts = _firstCounts(_whole([1, 2, 3]), const {}, 300);
      for (final id in [1, 2, 3]) {
        expect(counts[id]!, inInclusiveRange(70, 130), reason: 'sourate $id');
      }
    });

    test(
        'une sourate à 1000 jours sort première bien plus souvent que quatre à '
        '1 jour', () {
      final counts = _firstCounts(_whole([1, 2, 3, 4, 5]), {
        1: _revised(1),
        2: _revised(1),
        3: _revised(1),
        4: _revised(1),
        5: _revised(1000),
      }, 200);
      expect(counts[5]!, greaterThanOrEqualTo(190));
    });

    test('le résultat est une permutation des sourates distinctes', () {
      final selections = [
        ..._whole([7, 3, 9]),
        SourateSelection(sourate: _sourate(5), verseStart: 1, verseEnd: 3),
        SourateSelection(sourate: _sourate(5), verseStart: 7, verseEnd: 9),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final order = _draw(selections, const {}, seed);
        expect(order.length, 4);
        expect(order.toSet(), {3, 5, 7, 9});
      }
    });

    test('même graine, même ordre', () {
      final history = {1: _revised(3), 2: _revised(40)};
      expect(_draw(_whole([1, 2, 3, 4]), history, 42),
          _draw(_whole([1, 2, 3, 4]), history, 42));
    });
  });

  group('TourOrder.compute — tri strict (mélange désactivé)', () {
    test(
        "jamais révisée en tête, puis la plus ancienne d'abord, à égalité "
        'ordre du mushaf', () {
      final order = _draw(
        _whole([1, 2, 3, 4, 5]),
        {1: _revised(3), 2: _revised(40), 4: _revised(3)},
        0,
        shuffle: false,
      );
      expect(order, [3, 5, 2, 1, 4]);
    });

    test("l'âge se lit sur la plage choisie seule", () {
      // Surah 1: only verses 1-5 chosen, verse 8 revised yesterday — the
      // chosen range was never revised, so it counts as the oldest.
      final selections = [
        SourateSelection(sourate: _sourate(1), verseStart: 1, verseEnd: 5),
        SourateSelection.whole(_sourate(2)),
      ];
      final history = {
        1: {8: _today.subtract(const Duration(days: 1))},
        2: _revised(30),
      };
      expect(_draw(selections, history, 0, shuffle: false), [1, 2]);
    });

    test('au premier tour, sans historique, ordre du mushaf', () {
      expect(_draw(_whole([9, 2, 5]), const {}, 0, shuffle: false), [2, 5, 9]);
    });
  });

  group('TourOrder.arrange', () {
    UserConfig config(List<SourateSelection> selections,
            {List<int>? tourOrder, bool shuffle = true}) =>
        UserConfig(
          selections: selections,
          pagesPerDay: 1,
          startDate: DateTime(2026, 1, 1),
          shuffleEnabled: shuffle,
          tourOrder: tourOrder,
        );

    List<int> ids(List<SourateSelection> arranged) =>
        [for (final s in arranged) s.sourate.id];

    test("suit l'ordre du tour", () {
      expect(ids(TourOrder.arrange(config(_whole([1, 2, 3]), tourOrder: [3, 1, 2])))
          , [3, 1, 2]);
    });

    test('une sourate absente passe en fin, entre absentes par id', () {
      expect(
          ids(TourOrder.arrange(
              config(_whole([9, 1, 4, 2]), tourOrder: [4, 1]))),
          [4, 1, 2, 9]);
    });

    test('un id hors sélection est ignoré', () {
      expect(ids(TourOrder.arrange(config(_whole([1, 2]), tourOrder: [7, 2, 1]))),
          [2, 1]);
    });

    test("deux plages d'une sourate restent dans l'ordre des versets", () {
      final arranged = TourOrder.arrange(config([
        SourateSelection(sourate: _sourate(5), verseStart: 7, verseEnd: 9),
        SourateSelection.whole(_sourate(1)),
        SourateSelection(sourate: _sourate(5), verseStart: 1, verseEnd: 3),
      ], tourOrder: [5, 1]));
      expect([for (final s in arranged) (s.sourate.id, s.verseStart)],
          [(5, 1), (5, 7), (1, 1)]);
    });

    test("sans ordre du tour (config d'avant US-26), repli hérité exact", () {
      final selections = _whole([4, 1, 3, 2]);
      expect(ids(TourOrder.arrange(config(selections, shuffle: false))),
          [4, 1, 3, 2],
          reason: 'sans mélange : ordre des sélections');
      final legacy = ids(TourOrder.arrange(config(selections)));
      final seed = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      int key(int id) => Random(seed + id).nextInt(1 << 31);
      expect(legacy, [1, 2, 3, 4]..sort((a, b) => key(a).compareTo(key(b))),
          reason: 'avec mélange : clé par sourate seedée par startDate');
    });
  });

  test('TourOrder.covers : même ensemble de sourates', () {
    final selections = [
      ..._whole([1, 2]),
      SourateSelection(sourate: _sourate(2), verseStart: 1, verseEnd: 3),
    ];
    expect(TourOrder.covers([2, 1], selections), isTrue);
    expect(TourOrder.covers(null, selections), isFalse);
    expect(TourOrder.covers([1], selections), isFalse);
    expect(TourOrder.covers([1, 2, 3], selections), isFalse);
  });

  group('buildCycle avec un ordre du tour', () {
    // Surah 1 over pages 1-2, surahs 2 and 3 whole on page 3, surah 4 on 4.
    final pageMetadata = {
      1: {for (var v = 1; v <= 10; v++) v: v <= 5 ? 1 : 2},
      2: {for (var v = 1; v <= 10; v++) v: 3},
      3: {for (var v = 1; v <= 10; v++) v: 3},
      4: {for (var v = 1; v <= 10; v++) v: 4},
    };

    List<List<(int, int)>> cycleOf(List<int> tourOrder) => [
          for (final entry in RevisionEngine.buildCycle(
            config: UserConfig(
              selections: _whole([1, 2, 3, 4]),
              pagesPerDay: 1,
              startDate: DateTime(2026, 1, 1),
              tourOrder: tourOrder,
            ),
            pageMetadata: pageMetadata,
          ))
            [for (final unit in entry) (unit.sourate.id, unit.verseStart)],
        ];

    test("les pages d'une sourate restent dans l'ordre du mushaf", () {
      expect(cycleOf([4, 1, 2, 3]).take(3), [
        [(4, 1)],
        [(1, 1)],
        [(1, 6)],
      ]);
    });

    test(
        "des sourates entières sur une page font une seule entrée, au rang "
        'de la mieux classée', () {
      expect(cycleOf([3, 4, 1, 2]), [
        [(3, 1), (2, 1)],
        [(4, 1)],
        [(1, 1)],
        [(1, 6)],
      ]);
    });
  });
}
