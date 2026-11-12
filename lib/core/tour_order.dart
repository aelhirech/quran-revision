import 'dart:math';

import '../models/sourate_selection.dart';
import '../models/user_config.dart';
import 'freshness_engine.dart';
import 'mosaic.dart';

/// The order of the surahs for one round (US-26): drawn once when the round
/// starts and stored in [UserConfig.tourOrder], never recomputed from the
/// revision dates mid-round, or the cursor would land on another page.
class TourOrder {
  /// Surah ids of [selections], those not revised for longest first.
  ///
  /// [shuffle]: a weighted draw, weight = days since last revision + 1, a
  /// never-revised surah weighing more than the oldest revised one. Without
  /// [shuffle]: a strict sort on the same age, ties in mushaf order.
  static List<int> compute({
    required List<SourateSelection> selections,
    required bool shuffle,
    required Map<int, Map<int, DateTime>> lastRevisionByAyah,
    required DateTime today,
    required Random random,
  }) {
    final spans = surahSpans(selections);
    // Sorted ids: the draw consumes [random] in a fixed order, so one seed
    // always gives one order.
    final ids = spans.keys.toList()..sort();
    final ages = <int, int?>{
      for (final id in ids)
        id: FreshnessEngine.daysSinceLastRevision(
          lastRevisionByAyah: lastRevisionByAyah[id] ?? const {},
          verseStart: spans[id]!.$1,
          verseEnd: spans[id]!.$2,
          today: today,
        ),
    };
    // Never revised counts as older than the oldest revised surah; a date in
    // the future (clock change) counts as today.
    final oldest = ages.values.whereType<int>().fold(0, max);
    final weights = {
      for (final id in ids) id: ages[id] == null ? oldest + 2 : max(0, ages[id]!) + 1,
    };
    final keys = <int, double>{
      for (final id in ids)
        id: shuffle
            // Weighted random permutation (Efraimidis-Spirakis): the smaller
            // key goes first, and a heavier surah tends to draw a smaller one.
            ? -log(1 - random.nextDouble()) / weights[id]!
            : -weights[id]!.toDouble(),
    };
    // `sort` is not stable, hence the explicit tie on id (mushaf order).
    return ids
      ..sort((a, b) {
        final byKey = keys[a]!.compareTo(keys[b]!);
        return byKey != 0 ? byKey : a.compareTo(b);
      });
  }

  /// [UserConfig.selections] in the order of the round. A surah missing from
  /// [UserConfig.tourOrder] (learned mid-round) goes last, so it never lands
  /// before the cursor.
  static List<SourateSelection> arrange(UserConfig config) {
    final order = config.tourOrder;
    if (order == null) return _legacyArrange(config);
    final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
    // Absent ids rank after every listed one, among themselves by id.
    return List<SourateSelection>.from(config.selections)
      ..sort((a, b) {
        final rankA = rank[a.sourate.id] ?? order.length + a.sourate.id;
        final rankB = rank[b.sourate.id] ?? order.length + b.sourate.id;
        final byRank = rankA.compareTo(rankB);
        return byRank != 0 ? byRank : a.verseStart.compareTo(b.verseStart);
      });
  }

  /// True when [order] holds exactly the surahs of [selections].
  static bool covers(List<int>? order, List<SourateSelection> selections) {
    if (order == null) return false;
    final ids = surahSpans(selections).keys.toSet();
    return order.length == ids.length && ids.containsAll(order);
  }

  /// Order of a config saved before US-26: kept until its round ends, so the
  /// update never moves the cursor under the user's feet.
  static List<SourateSelection> _legacyArrange(UserConfig config) {
    final arranged = List<SourateSelection>.from(config.selections);
    if (!config.shuffleEnabled) return arranged;
    // Sorted on a per-surah key rather than shuffled as a list: a
    // Fisher-Yates pass over n+1 elements shares nothing with the pass over
    // n, so adding one surah (`handOffLearnedSurahs`) reordered every other
    // one while `cyclePosition` stayed put — pages skipped, pages repeated.
    final seed = config.startDate.millisecondsSinceEpoch;
    return arranged
      ..sort((a, b) {
        final byKey = _shuffleKey(seed, a.sourate.id)
            .compareTo(_shuffleKey(seed, b.sourate.id));
        return byKey != 0 ? byKey : a.sourate.id.compareTo(b.sourate.id);
      });
  }

  /// Deterministic per-surah shuffle rank — same seed and same surah give the
  /// same rank whatever else the selection holds.
  static int _shuffleKey(int seed, int surahId) =>
      Random(seed + surahId).nextInt(1 << 31);
}
