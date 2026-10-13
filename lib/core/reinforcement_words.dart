part of 'reinforcement_engine.dart';

const _minWordLetters = 3;
const _minMeaningLetters = 3;
const _sharedMeaningLetters = 4;

final _bracketed = RegExp(r'\([^)]*\)|\[[^\]]*\]');
final _letterRun = RegExp(r'\p{L}+', unicode: true);

/// A word of a carried verse, with the meaning its source gives it.
class WordChoice {
  final int surahId;
  final int ayahId;
  final int rank;
  final String arabic;
  final String gloss;
  final String _normalized;

  // Normalizing every word of a large selection is a measurable share of a
  // series: the engine hands over the form it already computed.
  WordChoice._(this.surahId, this.ayahId, this.rank, this.arabic, this.gloss,
      this._normalized);

  /// Same role as [Passage.id]; the third field is the word's rank among the
  /// words of its verse.
  (int, int, int) get id => (surahId, ayahId, rank);

  // The source writes what it adds to the Arabic between brackets: those
  // segments say nothing of the word itself.
  late final List<String> _meaningWords = [
    for (final run in _letterRun.allMatches(gloss.replaceAll(_bracketed, ' ')))
      run[0]!.toLowerCase(),
  ];
  late final Set<String> _longMeaningWords = {
    for (final word in _meaningWords)
      if (word.length >= _sharedMeaningLetters) word,
  };

  // Short words and bare particles ("et", "de", "il") make no question.
  late final bool _askable = _normalized.length >= _minWordLetters &&
      _meaningWords.any((word) => word.length >= _minMeaningLetters);
}

class WordQuestion extends SeriesQuestion {
  /// The passage that holds the asked word, and the word's rank among the
  /// tokens of [Passage.words].
  final Passage passage;
  final int wordIndex;
  final WordChoice answer;
  final List<WordChoice> choices;

  /// The Arabic word is shown and its meaning asked, or the reverse.
  final bool arabicToMeaning;

  const WordQuestion({
    required this.passage,
    required this.wordIndex,
    required this.answer,
    required this.choices,
    required this.arabicToMeaning,
  });

  @override
  int get answerIndex => choices.indexWhere((choice) => choice.id == answer.id);
}

class ReinforcementWords {
  static List<WordQuestion> buildWordQuestions({
    required Map<int, Set<int>> carried,
    required String Function(int surahId, int ayahId) textOf,
    required List<String>? Function(int surahId, int ayahId) glossesOf,
    required Random random,
    Set<(int, int)> today = const {},
    Set<(int, int, int)> avoid = const {},
    int? surahId,
    int count = _seriesLength,
  }) {
    // A surah's words are analysed when a question first reads them. A series
    // on the whole selection reads them all; a series on one surah leaves the
    // rest of a large selection alone.
    final bySurah = <int, List<WordChoice>>{};
    List<WordChoice> wordsOf(int id) => bySurah.putIfAbsent(
        id,
        () => [
              // Sorted so that a given seed always yields the same series.
              for (final ayah in (carried[id] ?? const <int>{}).toList()
                ..sort())
                ..._askableWords(
                    id, ayah, textOf(id, ayah), glossesOf(id, ayah)),
            ]);
    late final all = [
      for (final id in carried.keys.toList()..sort()) ...wordsOf(id),
    ];
    final asked = <String>{};

    return ReinforcementEngine._draw(
      candidates: surahId == null ? all : wordsOf(surahId),
      idOf: (word) => word.id,
      build: (word) {
        if (asked.contains(word._normalized)) return null;
        final question = _question(
            word, wordsOf(word.surahId), () => all, textOf, random);
        if (question != null) asked.add(word._normalized);
        return question;
      },
      random: random,
      today: today,
      avoid: avoid,
      surahId: surahId,
      count: count,
    );
  }

  /// Half passages, half words. When one kind falls short, the other makes
  /// up for it.
  static List<SeriesQuestion> buildMixedSeries({
    required Map<int, Set<int>> carried,
    required String Function(int surahId, int ayahId) textOf,
    required List<String>? Function(int surahId, int ayahId) glossesOf,
    required Random random,
    Set<(int, int)> today = const {},
    Set<(int, int, int)> avoidPassages = const {},
    Set<(int, int, int)> avoidWords = const {},
    int? surahId,
  }) {
    List<WordQuestion> wordQuestions(int count) => buildWordQuestions(
          carried: carried,
          textOf: textOf,
          glossesOf: glossesOf,
          random: random,
          today: today,
          avoid: avoidWords,
          surahId: surahId,
          count: count,
        );

    const half = _seriesLength ~/ 2;
    var words = wordQuestions(half);
    final passages = ReinforcementEngine.buildSeries(
      carried: carried,
      textOf: textOf,
      random: random,
      today: today,
      avoid: avoidPassages,
      surahId: surahId,
      count: _seriesLength - words.length,
    );
    // Words are drawn again only when passages fell short, which takes a
    // selection small enough for a second draw to cost nothing.
    if (words.length == half && passages.length < half) {
      words = wordQuestions(_seriesLength - passages.length);
    }
    return [...passages, ...words]..shuffle(random);
  }

  static Iterable<WordChoice> _askableWords(
      int surahId, int ayahId, String verse, List<String>? glosses) {
    if (glosses == null) return const [];
    final words = [
      for (final token in verse.split(' '))
        if (_normalize(token) case final bare when bare.isNotEmpty)
          (withoutHizbSign(token), bare),
    ];
    // Meanings are matched to words by rank alone: a verse that does not have
    // one meaning per word would pair each word with its neighbour's.
    if (words.length != glosses.length) return const [];
    return [
      for (final (rank, (token, bare)) in words.indexed)
        WordChoice._(surahId, ayahId, rank, token, glosses[rank], bare),
    ].where((word) => word._askable);
  }

  static WordQuestion? _question(
    WordChoice word,
    List<WordChoice> sameSurah,
    List<WordChoice> Function() everywhere,
    String Function(int surahId, int ayahId) textOf,
    Random random,
  ) {
    final wrong = <WordChoice>[];
    final takenWords = {word._normalized};
    final takenGlosses = {word.gloss};

    bool pick(List<WordChoice> pool) {
      if (wrong.length == _maxWrongChoices) return false;
      final open = pool
          .where((candidate) =>
              !takenWords.contains(candidate._normalized) &&
              !takenGlosses.contains(candidate.gloss) &&
              // "un livre" next to "Le Livre" would be a second right answer.
              !candidate._longMeaningWords
                  .any(word._longMeaningWords.contains))
          .toList();
      if (open.isEmpty) return false;
      final choice = open[random.nextInt(open.length)];
      wrong.add(choice);
      takenWords.add(choice._normalized);
      takenGlosses.add(choice.gloss);
      return true;
    }

    while (pick(sameSurah)) {}
    // The other surahs are read only when this one ran short of choices.
    if (wrong.length < _maxWrongChoices) {
      final all = everywhere();
      while (pick(all)) {}
    }
    if (wrong.isEmpty) return null;

    final spots = [
      for (final passage in ReinforcementEngine.passagesOf(
          word.surahId, word.ayahId, textOf(word.surahId, word.ayahId)))
        for (var i = 0; i < passage.words.length; i++)
          if (_normalize(passage.words[i]).isNotEmpty) (passage, i),
    ];
    final (passage, wordIndex) = spots[word.rank];
    return WordQuestion(
      passage: passage,
      wordIndex: wordIndex,
      answer: word,
      choices: [word, ...wrong]..shuffle(random),
      arabicToMeaning: random.nextBool(),
    );
  }
}
