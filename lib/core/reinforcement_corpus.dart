part of 'reinforcement_engine.dart';

// About 40 ms of work per slice on Windows in profile (measured).
const _warmSlice = 300;

/// The carried passages, surah by surah, and what the engine derives from
/// them without a seed.
class _Chains {
  final Map<int, List<Passage>> bySurah;
  late final List<Passage> all = [
    for (final chain in bySurah.values) ...chain,
  ];
  late final int keyCount = {for (final passage in all) passage._key}.length;
  final _links = <int, List<_Link>>{};
  late final Map<String, List<Passage>> _byWord = _indexByWord(all);
  final _similars = <(int, int, int), List<Passage>>{};

  _Chains._(this.bySurah);

  static Map<String, List<Passage>> _indexByWord(List<Passage> passages) {
    final byWord = <String, List<Passage>>{};
    for (final passage in passages) {
      for (final word in passage._wordSet) {
        (byWord[word] ??= []).add(passage);
      }
    }
    return byWord;
  }

  /// The carried passages similar to [answer]: those that filtering [all]
  /// would keep, looked for only among the ones sharing a word with it.
  /// Filtering [all] took most of a series' time (measured).
  List<Passage> similarTo(Passage answer) =>
      _similars.putIfAbsent(answer.id, () {
        final sharingAWord = {
          for (final word in answer._wordSet) ...?_byWord[word],
        };
        return sharingAWord
            .where((candidate) => ReinforcementEngine._similar(candidate, answer))
            .toList();
      });

  factory _Chains.of(Map<int, Set<int>> carried,
      List<Passage> Function(int surahId, int ayahId) versePassages) {
    // Sorted so that a given seed always yields the same series.
    return _Chains._({
      for (final id in carried.keys.toList()..sort())
        id: [
          for (final ayah in carried[id]!.toList()..sort())
            ...versePassages(id, ayah),
        ],
    });
  }

  List<_Link> linksOf(int surahId) => _links.putIfAbsent(
      surahId, () => ReinforcementEngine._askableLinks(bySurah[surahId]!));
}

/// Whether two carried selections hold the same verses.
bool sameCarried(Map<int, Set<int>> a, Map<int, Set<int>> b) =>
    a.length == b.length &&
    a.entries.every((entry) {
      final other = b[entry.key];
      return other != null &&
          other.length == entry.value.length &&
          other.containsAll(entry.value);
    });

/// What the engine reads from the carried verses, kept for a session so that
/// a series does not analyse the whole selection again. It holds the text of
/// one riwaya: [clear] it when the riwaya changes.
class ReinforcementCorpus {
  final _passages = <(int, int), List<Passage>>{};
  final _words = <(int, int), List<WordChoice>>{};
  Map<int, Set<int>>? _carried;
  _Chains? _chains;
  List<WordChoice>? _allWords;
  // Bumped by [clear]: a warm-up still running holds the old riwaya's text.
  int _epoch = 0;

  void clear() {
    _epoch++;
    _passages.clear();
    _words.clear();
    _carried = null;
    _chains = null;
    _allWords = null;
  }

  /// Analyses the carried verses ahead of any series, [_warmSlice] verses at
  /// a time, letting frames through between slices: a large selection never
  /// freezes the screen in one block. Words only when [glossesOf] is given.
  Future<void> warm(
      Map<int, Set<int>> carried,
      String Function(int surahId, int ayahId) textOf,
      List<String>? Function(int surahId, int ayahId)? glossesOf) async {
    final epoch = _epoch;
    var sliced = 0;
    for (final MapEntry(key: id, value: ayahs) in carried.entries) {
      for (final ayah in ayahs) {
        // Before the first slice too: the caller may have just done a long
        // block of its own (reading the meanings, 80 ms).
        if (sliced++ % _warmSlice == 0) {
          await Future<void>.delayed(Duration.zero);
          if (epoch != _epoch) return;
        }
        final text = textOf(id, ayah);
        for (final passage in passagesOf(id, ayah, text)) {
          // Lazy fields: left unread, the offer would compute them all in
          // one block (150 ms on the whole Quran, measured).
          passage._key;
          passage._wordSet;
        }
        if (glossesOf != null) wordsOf(id, ayah, text, glossesOf(id, ayah));
      }
    }
  }

  List<Passage> passagesOf(int surahId, int ayahId, String text) =>
      _passages.putIfAbsent((surahId, ayahId),
          () => ReinforcementEngine.passagesOf(surahId, ayahId, text));

  List<WordChoice> wordsOf(
      int surahId, int ayahId, String text, List<String>? glosses) {
    // Meanings not loaded yet: an empty answer must not be kept.
    if (glosses == null) return const [];
    return _words.putIfAbsent(
        (surahId, ayahId),
        () => ReinforcementWords._askableWords(surahId, ayahId, text, glosses)
            .toList());
  }

  // The flat lists depend on the whole selection: a new selection drops them,
  // the verses already analysed stay.
  void _follow(Map<int, Set<int>> carried) {
    final previous = _carried;
    if (previous != null && sameCarried(previous, carried)) return;
    _carried = carried;
    _chains = null;
    _allWords = null;
  }

  _Chains _chainsOf(Map<int, Set<int>> carried,
      String Function(int surahId, int ayahId) textOf) {
    _follow(carried);
    return _chains ??= _Chains.of(carried,
        (surahId, ayahId) => passagesOf(surahId, ayahId, textOf(surahId, ayahId)));
  }

  List<WordChoice> _allWordsOf(
      Map<int, Set<int>> carried, List<WordChoice> Function() build) {
    _follow(carried);
    return _allWords ??= build();
  }
}
