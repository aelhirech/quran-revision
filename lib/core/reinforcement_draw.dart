part of 'reinforcement_engine.dart';

const _sampleTries = 20;

// A few random draws usually land on a fitting choice, and the caller reads
// the whole pool only when they all miss: each fitting choice stays equally
// likely either way.
T? _sampleFit<T>(List<T> pool, bool Function(T) fits, Random random) {
  for (var i = 0; i < _sampleTries; i++) {
    final candidate = pool[random.nextInt(pool.length)];
    if (fits(candidate)) return candidate;
  }
  return null;
}

typedef _Tiers<C> = ({Queue<C> today, Queue<C> risk, Queue<C> others});

/// [candidates] in shuffled order, sorted by what they are: questions to ask
/// again (oldest miss first), then fresh and avoided ones, each by tier.
({Queue<C> retries, _Tiers<C> fresh, _Tiers<C> avoided}) _classify<C>({
  required List<C> shuffled,
  required (int, int, int) Function(C) idOf,
  required Set<(int, int)> today,
  required Set<(int, int, int)> avoid,
  required int? surahId,
  required List<(int, int, int)> retry,
  required Set<int> atRisk,
}) {
  final retryRank = {for (final (rank, id) in retry.indexed) id: rank};
  final retries = <C>[];
  final _Tiers<C> fresh = (today: Queue(), risk: Queue(), others: Queue());
  final _Tiers<C> avoided = (today: Queue(), risk: Queue(), others: Queue());
  // Sorted in one pass, shuffled order kept: filtering lazily read each id
  // up to eight times, most of a word series on a large selection
  // (measured).
  for (final candidate in shuffled) {
    final id = idOf(candidate);
    // A question answered wrong comes back even if the last series asked it
    // (US-21 crit. 4).
    if (retryRank.containsKey(id)) {
      retries.add(candidate);
      continue;
    }
    final group = avoid.contains(id) ? avoided : fresh;
    final (surah, ayah, _) = id;
    // A series on one surah ignores today's plan.
    final ofToday = surahId == null && today.contains((surah, ayah));
    final queue = ofToday
        ? group.today
        : (atRisk.contains(surah) ? group.risk : group.others);
    queue.add(candidate);
  }
  retries.sort((a, b) => retryRank[idOf(a)]!.compareTo(retryRank[idOf(b)]!));
  return (retries: Queue.of(retries), fresh: fresh, avoided: avoided);
}

/// The draw shared by passage and word questions.
List<Q> _draw<C, Q extends Object>({
  required Iterable<C> candidates,
  required (int, int, int) Function(C) idOf,
  required Q? Function(C) build,
  required Random random,
  required Set<(int, int)> today,
  required Set<(int, int, int)> avoid,
  required int? surahId,
  required int count,
  required List<(int, int, int)> retry,
  required Set<int> atRisk,
}) {
  final sorted = _classify(
    shuffled: candidates.toList()..shuffle(random),
    idOf: idOf,
    today: today,
    avoid: avoid,
    surahId: surahId,
    retry: retry,
    atRisk: atRisk,
  );

  final drawn = <Q>[];
  int fill(Queue<C> queue, int target) {
    final before = drawn.length;
    while (drawn.length < target && queue.isNotEmpty) {
      final question = build(queue.removeFirst());
      if (question != null) drawn.add(question);
    }
    return drawn.length - before;
  }

  // Half the series at most: the rest stays for what is new.
  fill(sorted.retries, count ~/ 2);
  var fromToday = 0;
  // Avoided questions come second: they only fill what the rest left open.
  for (final group in [sorted.fresh, sorted.avoided]) {
    // Today's plan gets half the series at most while other material is
    // left, so that it does not crowd out the rest of what is carried.
    fromToday += fill(
        group.today, min(count, drawn.length + count ~/ 2 - fromToday));
    // Surahs at risk of being forgotten come right after today's plan
    // (US-21 crit. 5).
    fill(group.risk, count);
    fill(group.others, count);
    fromToday += fill(group.today, count);
  }
  fill(sorted.retries, count);
  return drawn..shuffle(random);
}
