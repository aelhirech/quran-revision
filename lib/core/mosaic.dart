import 'dart:math';

import '../models/learning_progress.dart';
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

  /// The surah's learning when it is being learned, null otherwise.
  final LearningProgress? learning;

  /// Being learned without being in the selection: nothing revised to show.
  final bool isLearningOnly;

  const MosaicTile({
    required this.surahId,
    required this.verseStart,
    required this.verseEnd,
    required this.level,
    required this.daysSinceRevision,
    required this.atRisk,
    this.learning,
    this.isLearningOnly = false,
  });

  /// Bounded so that a surah started with nothing learned still differs from
  /// one not played yet, and one nearly done from a full tile (US-32 crit. 1).
  double? get learningFraction => learning?.progress.clamp(0.12, 0.88);
}

class Mosaic {
  /// One tile per selected surah or surah being learned, in mushaf order.
  /// Only the Recap passes [learning]: the Quiz shows what is already known
  /// (US-32 crit. 1).
  static List<MosaicTile> build({
    required List<SourateSelection> selections,
    required Map<int, int> levels,
    required Map<int, Map<int, DateTime>> lastRevisionByAyah,
    required DateTime today,
    required int? tourDays,
    List<LearningProgress> learning = const [],
  }) {
    final spans = surahSpans(selections);
    final learningById = {
      for (final p in learning)
        if (!p.isComplete) p.sourate.id: p,
    };
    // A round longer than three months would turn every surah orange before
    // the plan could bring it back (US-21 crit. 5).
    final riskAfter = max(_riskAfterDays, tourDays ?? 0);
    final tiles = <MosaicTile>[];
    for (final id in {...spans.keys, ...learningById.keys}.toList()..sort()) {
      final progress = learningById[id];
      final span = spans[id];
      final learningOnly = span == null;
      final (start, end) = span ?? (1, progress!.totalVerses);
      final days = learningOnly
          ? null
          : FreshnessEngine.daysSinceLastRevision(
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
          // Learned verses can be asked about, so a level may exist; a surah
          // only being learned still shows as not played (US-32 scoping).
          level: learningOnly ? 0 : levels[id] ?? 0,
          daysSinceRevision: days,
          // Never revised is not at risk: a new selection would otherwise
          // start all orange (choice of 2026-11-08). A tile being built never
          // turns orange either; its risk shows in the Quiz (US-32 scoping).
          atRisk: progress == null && days != null && days > riskAfter,
          learning: progress,
          isLearningOnly: learningOnly,
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
