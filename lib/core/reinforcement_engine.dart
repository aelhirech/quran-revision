import 'dart:collection';
import 'dart:math';

import '../models/learning_progress.dart';
import '../models/sourate_selection.dart';

part 'reinforcement_choices.dart';
part 'reinforcement_corpus.dart';
part 'reinforcement_draw.dart';
part 'reinforcement_words.dart';

const _seriesLength = 10;
const _maxPassageWords = 12;
const _similarity = 0.5;
const _neighbourReach = 3;
const _maxWrongChoices = 3;

// U+00A0 is here because the Hafs text glues the hizb sign to the next word
// with a no-break space.
final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ‏ ]');
final _pauseSign = RegExp('[ۖۗۘۚ]');

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

  /// The difficulty its wrong choices were drawn at, 1 to 4.
  final int level;

  const PassageQuestion({
    required this.prompt,
    required this.answer,
    required this.choices,
    required this.level,
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
    Map<int, int> levels = const {},
    List<(int, int, int)> retry = const [],
    Set<int> atRisk = const {},
  }) {
    // Without a memo, a throwaway one: same questions, a single code path.
    final chains = (corpus ?? ReinforcementCorpus())._chainsOf(carried, textOf);
    return _draw(
      candidates: [
        for (final id in chains.bySurah.keys)
          if (surahId == null || id == surahId) ...chains.linksOf(id),
      ],
      idOf: (link) => link.prompt.id,
      // A surah not played yet is asked at the first level.
      build: (link) => _passageQuestion(link, chains, random,
          (levels[link.prompt.surahId] ?? 0).clamp(1, 4)),
      random: random,
      today: today,
      avoid: avoid,
      retry: retry,
      atRisk: atRisk,
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
        // The condition of [_passageQuestion]: a wrong choice is any carried passage
        // whose text is neither the prompt's nor the answer's. Both of those
        // texts are among the distinct ones.
        if (chains.linksOf(id).any((link) =>
            chains.keyCount > {link.prompt._key, link.answer._key}.length))
          id,
    };
  }
}
