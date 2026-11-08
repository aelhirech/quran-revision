part of 'reinforcement_engine.dart';

List<_Link> _askableLinks(List<Passage> chain) {
  final occurrences = <String, int>{};
  for (final p in chain) {
    occurrences[p._key] = (occurrences[p._key] ?? 0) + 1;
  }
  return [
    for (var i = 0; i + 1 < chain.length; i++)
      if (chain[i + 1].ayahId <= chain[i].ayahId + 1 &&
          occurrences[chain[i]._key] == 1 &&
          occurrences[chain[i + 1]._key] == 1)
        (
          prompt: chain[i],
          answer: chain[i + 1],
          neighbours: chain.sublist(max(0, i + 1 - _neighbourReach),
              min(chain.length, i + 2 + _neighbourReach)),
        ),
  ];
}

bool _similar(Passage a, Passage b) {
  final common = a._wordSet.where(b._wordSet.contains).length;
  return common / max(a._wordSet.length, b._wordSet.length) >= _similarity;
}

PassageQuestion? _passageQuestion(
    _Link link, _Chains chains, Random random, int level) {
  final answer = link.answer;
  final all = chains.all;
  final wrong = <Passage>[];
  // The prompt's key too: the same text carried in another surah must not
  // come back as a choice under its own prompt.
  final takenKeys = {answer._key, link.prompt._key};

  bool pick(List<Passage> pool, [bool Function(Passage)? fits]) {
    if (wrong.length == _maxWrongChoices || pool.isEmpty) return false;
    bool open(Passage c) =>
        (fits == null || fits(c)) && !takenKeys.contains(c._key);
    // A choice that starts mid-verse next to an answer that starts a verse
    // (or the reverse) would give the answer away.
    bool sameKind(Passage c) => c.startsVerse == answer.startsVerse;

    var choice =
        _sampleFit(pool, (Passage c) => open(c) && sameKind(c), random);
    if (choice == null) {
      final opens = pool.where(open).toList();
      if (opens.isEmpty) return false;
      final sameKinds = opens.where(sameKind).toList();
      final from = sameKinds.isEmpty ? opens : sameKinds;
      choice = from[random.nextInt(from.length)];
    }
    wrong.add(choice);
    takenKeys.add(choice._key);
    return true;
  }

  // The surah's chain holds the same passages, in the same order, as
  // [all] filtered on the surah.
  final sameSurah = chains.bySurah[answer.surahId]!;
  // Each level draws its own kind of wrong choice first, then the easier
  // kinds: no question is lost to its level (US-21 crit. 2).
  if (level >= 4) while (pick(chains.similarTo(answer))) {}
  if (level >= 3) while (pick(link.neighbours)) {}
  if (level >= 2) while (pick(sameSurah)) {}
  while (pick(all, (c) => c.surahId != answer.surahId)) {}
  while (pick(all)) {}

  if (wrong.isEmpty) return null;
  return PassageQuestion(
    prompt: link.prompt,
    answer: answer,
    choices: [answer, ...wrong]..shuffle(random),
    level: level,
  );
}
