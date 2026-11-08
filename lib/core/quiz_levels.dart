import '../models/quiz_answer.dart';

const _hitsToRise = 3;
const _missesToFall = 2;
const maxQuizLevel = 4;

/// A surah's Quiz level, rebuilt from its passage answers rather than stored
/// (US-21 crit. 2 and 3).
class QuizLevels {
  /// Surah id → level 1 to 4. A surah never asked is absent (level 0, "not
  /// played yet"). [answers] must be in the order they were given.
  static Map<int, int> fold(Iterable<QuizAnswer> answers) {
    final levels = <int, int>{};
    final hits = <int, int>{};
    final misses = <int, int>{};
    for (final answer in answers) {
      if (answer.kind != QuizKind.passage) continue;
      final surah = answer.surahId;
      final level = levels[surah] ??= 1;
      // A series is composed before it is played: once a level changed
      // mid-series, the answers still asked at the old one prove nothing.
      if (answer.level != level) continue;
      if (answer.held) {
        misses[surah] = 0;
        hits[surah] = (hits[surah] ?? 0) + 1;
        if (hits[surah] == _hitsToRise && level < maxQuizLevel) {
          levels[surah] = level + 1;
          hits[surah] = 0;
        }
      } else {
        hits[surah] = 0;
        misses[surah] = (misses[surah] ?? 0) + 1;
        if (misses[surah] == _missesToFall && level > 1) {
          levels[surah] = level - 1;
          misses[surah] = 0;
        }
      }
    }
    return levels;
  }

  /// The surahs whose level moved from [before] to [after]. A surah absent
  /// from [before] starts at level 1 for free: reaching it is not announced
  /// (crit. 3 speaks of repeated answers), rising past it in the same series
  /// is.
  static Map<int, ({int from, int to})> changes(
          Map<int, int> before, Map<int, int> after) =>
      {
        for (final MapEntry(key: id, value: level) in after.entries)
          if ((before[id] ?? 1) case final from when from != level)
            id: (from: from, to: level),
      };
}
