import 'dart:math';

import '../models/sourate_selection.dart';
import 'freshness_engine.dart';

const _riskAfterDays = 90;

/// A surah's tile: its Quiz level and whether it risks being forgotten.
class MosaicTile {
  final int surahId;
  final int verseStart;
  final int verseEnd;

  /// 0 ("not played yet") to 4.
  final int level;

  /// Null if no verse of the range was ever revised.
  final int? daysSinceRevision;
  final bool atRisk;

  const MosaicTile({
    required this.surahId,
    required this.verseStart,
    required this.verseEnd,
    required this.level,
    required this.daysSinceRevision,
    required this.atRisk,
  });
}

class Mosaic {
  /// One tile per selected surah, in mushaf order. A surah being learned has
  /// none until it joins the selection (US-21, default of 2026-10-22).
  static List<MosaicTile> build({
    required List<SourateSelection> selections,
    required Map<int, int> levels,
    required Map<int, Map<int, DateTime>> lastRevisionByAyah,
    required DateTime today,
    required int? tourDays,
  }) {
    final spans = surahSpans(selections);
    // A round longer than three months would turn every surah orange before
    // the plan could bring it back (US-21 crit. 5).
    final riskAfter = max(_riskAfterDays, tourDays ?? 0);
    final tiles = <MosaicTile>[];
    for (final id in spans.keys.toList()..sort()) {
      final (start, end) = spans[id]!;
      final days = FreshnessEngine.daysSinceLastRevision(
        lastRevisionByAyah: lastRevisionByAyah[id] ?? const {},
        verseStart: start,
        verseEnd: end,
        today: today,
      );
      tiles.add(
        MosaicTile(
          surahId: id,
          verseStart: start,
          verseEnd: end,
          level: levels[id] ?? 0,
          daysSinceRevision: days,
          // Never revised is not at risk: a new selection would otherwise
          // start all orange (choice of 2026-11-08).
          atRisk: days != null && days > riskAfter,
        ),
      );
    }
    return tiles;
  }
}

/// Surah id → (first, last) verse chosen: several selections of one surah
/// make one span over their whole extent.
Map<int, (int, int)> surahSpans(List<SourateSelection> selections) {
  final spans = <int, (int, int)>{};
  for (final s in selections) {
    final (start, end) = spans[s.sourate.id] ?? (s.verseStart, s.verseEnd);
    spans[s.sourate.id] = (min(start, s.verseStart), max(end, s.verseEnd));
  }
  return spans;
}

/// The tiles at risk, longest without revision first (US-23 crit. 2).
List<MosaicTile> atRiskOldestFirst(List<MosaicTile> tiles) =>
    tiles.where((tile) => tile.atRisk).toList()
      // Never null at risk: a tile is at risk only once revised.
      ..sort((a, b) => b.daysSinceRevision!.compareTo(a.daysSinceRevision!));
