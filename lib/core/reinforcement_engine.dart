import 'dart:collection';
import 'dart:math';

import '../models/learning_progress.dart';
import '../models/sourate_selection.dart';

part 'reinforcement_corpus.dart';
part 'reinforcement_words.dart';

const _seriesLength = 10;
const _maxPassageWords = 12;
const _similarity = 0.5;
const _neighbourReach = 3;
const _maxWrongChoices = 3;
const _sampleTries = 20;

// U+00A0 is here because the Hafs text glues the hizb sign to the next word
// with a no-break space.
final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ‏ ]');
final _pauseSign = RegExp('[ۖۗۘۚ]');

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

String _normalize(String token) =>
    token.replaceAll(_marks, '').replaceAll('ٱ', 'ا');

const _hizbSign = '\u06DE\u00A0';

/// [token] without the hizb sign that Hafs glues to a verse's first word.
String withoutHizbSign(String token) =>
    token.startsWith(_hizbSign) ? token.substring(_hizbSign.length) : token;

/// A whole verse, or a piece of it cut at the mushaf's pause signs.
class Passage {
  final int surahId;
  final int ayahId;
  final int index;
  final List<String> words;
  final bool startsVerse;
  final bool endsVerse;

  Passage({
    required this.surahId,
    required this.ayahId,
    required this.index,
    required this.words,
    required this.startsVerse,
    required this.endsVerse,
  });

  String get text => words.join(' ');

  /// What identifies a passage, across two builds of the same text.
  (int, int, int) get id => (surahId, ayahId, index);

  late final List<String> _normalized =
      words.map(_normalize).where((w) => w.isNotEmpty).toList();
  late final String _key = _normalized.join(' ');
  late final Set<String> _wordSet = _normalized.toSet();
}

sealed class SeriesQuestion {
  const SeriesQuestion();

  /// Rank of the right choice among the proposed ones.
  int get answerIndex;
}

class PassageQuestion extends SeriesQuestion {
  final Passage prompt;
  final Passage answer;
  final List<Passage> choices;

  const PassageQuestion({
    required this.prompt,
    required this.answer,
    required this.choices,
  });

  @override
  int get answerIndex => choices.indexWhere((choice) => choice.id == answer.id);
}

typedef _Link = ({Passage prompt, Passage answer, List<Passage> neighbours});

class ReinforcementEngine {
  static List<Passage> passagesOf(int surahId, int ayahId, String verse) {
    final merged = <List<String>>[];
    var mergedSize = 0;
    var piece = <String>[];
    var pieceSize = 0;

    // A verse of 12 words or fewer needs no special case: all its pieces
    // merge back into one passage.
    void closePiece() {
      if (merged.isNotEmpty && mergedSize + pieceSize <= _maxPassageWords) {
        merged.last.addAll(piece);
        mergedSize += pieceSize;
      } else {
        merged.add(piece);
        mergedSize = pieceSize;
      }
      piece = [];
      pieceSize = 0;
    }

    for (final token in verse.split(' ')) {
      piece.add(token);
      if (_normalize(token).isNotEmpty) pieceSize++;
      if (_pauseSign.hasMatch(token)) closePiece();
    }
    if (piece.isNotEmpty) closePiece();

    return [
      for (var i = 0; i < merged.length; i++)
        Passage(
          surahId: surahId,
          ayahId: ayahId,
          index: i,
          words: merged[i],
          startsVerse: i == 0,
          endsVerse: i == merged.length - 1,
        ),
    ];
  }

  static Map<int, Set<int>> carriedVerses({
    required List<SourateSelection> selections,
    required List<LearningProgress> learning,
  }) {
    final carried = <int, Set<int>>{};
    for (final s in selections) {
      carried.putIfAbsent(s.sourate.id, () => {}).addAll(
          [for (var v = s.verseStart; v <= s.verseEnd; v++) v]);
    }
    for (final p in learning) {
      if (p.isComplete || p.learnedVerses.isEmpty) continue;
      carried.putIfAbsent(p.sourate.id, () => {}).addAll(p.learnedVerses);
    }
    return carried;
  }

  static List<PassageQuestion> buildSeries({
    required Map<int, Set<int>> carried,
    required String Function(int surahId, int ayahId) textOf,
    required Random random,
    Set<(int, int)> today = const {},
    Set<(int, int, int)> avoid = const {},
    int? surahId,
    int count = _seriesLength,
    ReinforcementCorpus? corpus,
  }) {
    // Without a memo, a throwaway one: same questions, a single code path.
    final chains = (corpus ?? ReinforcementCorpus())._chainsOf(carried, textOf);
    return _draw(
      candidates: [
        for (final id in chains.bySurah.keys)
          if (surahId == null || id == surahId) ...chains.linksOf(id),
      ],
      idOf: (link) => link.prompt.id,
      build: (link) => _question(link, chains, random),
      random: random,
      today: today,
      avoid: avoid,
      surahId: surahId,
      count: count,
    );
  }

  /// The surahs on which [buildSeries] finds at least one question.
  static Set<int> surahsOfferingPassages({
    required Map<int, Set<int>> carried,
    required String Function(int surahId, int ayahId) textOf,
    ReinforcementCorpus? corpus,
  }) {
    final chains = (corpus ?? ReinforcementCorpus())._chainsOf(carried, textOf);
    return {
      for (final id in chains.bySurah.keys)
        // The condition of [_question]: a wrong choice is any carried passage
        // whose text is neither the prompt's nor the answer's. Both of those
        // texts are among the distinct ones.
        if (chains.linksOf(id).any((link) =>
            chains.keyCount > {link.prompt._key, link.answer._key}.length))
          id,
    };
  }

  /// The draw shared by passage and word questions.
  static List<Q> _draw<C, Q extends Object>({
    required Iterable<C> candidates,
    required (int, int, int) Function(C) idOf,
    required Q? Function(C) build,
    required Random random,
    required Set<(int, int)> today,
    required Set<(int, int, int)> avoid,
    required int? surahId,
    required int count,
  }) {
    final shuffled = candidates.toList()..shuffle(random);

    // A series on one surah ignores today's plan.
    bool isToday(C candidate) {
      final (surah, ayah, _) = idOf(candidate);
      return surahId == null && today.contains((surah, ayah));
    }

    final drawn = <Q>[];
    int fill(Queue<C> queue, int target) {
      final before = drawn.length;
      while (drawn.length < target && queue.isNotEmpty) {
        final question = build(queue.removeFirst());
        if (question != null) drawn.add(question);
      }
      return drawn.length - before;
    }

    var fromToday = 0;
    // Avoided questions come second: they only fill what the rest left open.
    for (final avoided in [false, true]) {
      final pool = shuffled.where(
          (candidate) => avoid.contains(idOf(candidate)) == avoided);
      final ofToday = Queue.of(pool.where(isToday));
      final others =
          Queue.of(pool.where((candidate) => !isToday(candidate)));
      // Today's plan gets half the series at most while other material is
      // left, so that it does not crowd out the rest of what is carried.
      fromToday +=
          fill(ofToday, min(count, drawn.length + count ~/ 2 - fromToday));
      fill(others, count);
      fromToday += fill(ofToday, count);
    }
    return drawn..shuffle(random);
  }

  static List<_Link> _askableLinks(List<Passage> chain) {
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

  static bool _similar(Passage a, Passage b) {
    final common = a._wordSet.where(b._wordSet.contains).length;
    return common / max(a._wordSet.length, b._wordSet.length) >= _similarity;
  }

  static PassageQuestion? _question(
      _Link link, _Chains chains, Random random) {
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
    pick(all, (c) => _similar(c, answer));
    pick(link.neighbours);
    pick(all, (c) => c.surahId != answer.surahId);
    while (pick(sameSurah)) {}
    while (pick(all)) {}

    if (wrong.isEmpty) return null;
    return PassageQuestion(
      prompt: link.prompt,
      answer: answer,
      choices: [answer, ...wrong]..shuffle(random),
    );
  }
}
