part of 'reinforcement_tab.dart';

// Kept apart to hold the tab under the file size ceiling.
extension _Offer on _ReinforcementTabState {
  // The memo holds one riwaya's text.
  ReinforcementCorpus _corpusFor(Riwaya riwaya) {
    if (riwaya != _corpusRiwaya) {
      _corpus.clear();
      _corpusRiwaya = riwaya;
    }
    return _corpus;
  }

  Future<void> _warm(
    ReinforcementCorpus corpus,
    Map<int, Set<int>> carried,
    SeriesMode mode,
    String Function(int, int) textOf,
  ) => corpus.warm(
    carried,
    textOf,
    mode == SeriesMode.passages ? null : WordGlossService.glosses,
  );

  Future<void> _computeOffer() async {
    final generation = ++_generation;
    final mode = _modeFor(_state);
    final riwaya = _state.riwaya;
    final inputs = await _state.reinforcementInputs();
    if (!mounted || generation != _generation) return;
    final last = _offeredFor;
    if (last != null &&
        _offered != null &&
        last.mode == mode &&
        last.riwaya == riwaya &&
        sameCarried(last.carried, inputs.carried)) {
      return;
    }
    if (mode != SeriesMode.passages) {
      await WordGlossService.load();
      if (!mounted || generation != _generation) return;
    }
    final corpus = _corpusFor(riwaya);
    String textOf(int surahId, int ayahId) =>
        VerseService.getVerse(surahId, ayahId, riwaya: riwaya);
    await _warm(corpus, inputs.carried, mode, textOf);
    if (!mounted || generation != _generation) return;
    final fromPassages = mode == SeriesMode.words
        ? const <int>{}
        : ReinforcementEngine.surahsOfferingPassages(
            carried: inputs.carried,
            textOf: textOf,
            corpus: corpus,
          );
    final offered = mode == SeriesMode.passages
        ? fromPassages
        : {
            ...fromPassages,
            // Reading every word of a large selection is the costly part: a
            // surah that already offers passages needs no word to be offered.
            ...ReinforcementWords.surahsOfferingWords(
              carried: inputs.carried,
              textOf: textOf,
              glossesOf: WordGlossService.glosses,
              corpus: corpus,
              except: fromPassages,
            ),
          };
    _update(() {
      _offered = offered;
      _offeredFor = (mode: mode, riwaya: riwaya, carried: inputs.carried);
    });
  }
}
