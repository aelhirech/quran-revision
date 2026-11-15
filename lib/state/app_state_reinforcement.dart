part of 'app_state.dart';

typedef QuizSeriesInputs = ({
  Map<int, int> levels,
  Set<int> atRisk,
  List<(int, int, int)> retryPassages,
  List<(int, int, int)> retryWords,
});

extension AppStateReinforcement on AppState {
  /// Read-only inputs of a series: carried verses, and today's among them.
  Future<({Map<int, Set<int>> carried, Set<(int, int)> today})>
      reinforcementInputs() async {
    if (_config == null) {
      return (carried: <int, Set<int>>{}, today: <(int, int)>{});
    }
    final learningF = learningProgressList();
    final unitsF = dayUnits();
    final carried = ReinforcementEngine.carriedVerses(
        selections: _config!.selections, learning: await learningF);
    final today = {
      for (final unit in await unitsF)
        for (final verse in unit.verses)
          if (carried[unit.sourate.id]?.contains(verse) ?? false)
            (unit.sourate.id, verse),
    };
    return (carried: carried, today: today);
  }

  /// What a series needs beyond [reinforcementInputs]: levels, questions to
  /// ask again and surahs at risk (US-21). Kept apart so that working out the
  /// offer does not pay for these reads.
  Future<QuizSeriesInputs> reinforcementSeriesInputs() async {
    await _quizWrites;
    final (levels, retryPassages, retryWords) = await (
      quizLevels(),
      QuizAnswers.pendingReturns(_riwaya, QuizKind.passage),
      QuizAnswers.pendingReturns(_riwaya, QuizKind.word),
    ).wait;
    return (
      levels: levels,
      atRisk: {
        for (final tile in _mosaicTilesOf(levels))
          if (tile.atRisk) tile.surahId,
      },
      retryPassages: retryPassages,
      retryWords: retryWords,
    );
  }

  Future<Map<int, int>> quizLevels() async {
    await _quizWrites;
    return QuizLevels.fold(await QuizAnswers.passageAnswers(_riwaya));
  }

  /// [withLearning] adds the surahs being learned: the Recap only.
  Future<List<MosaicTile>> mosaicTiles({bool withLearning = false}) async {
    final (levels, learning) = await (
      quizLevels(),
      withLearning
          ? learningProgressList()
          : Future.value(const <LearningProgress>[]),
    ).wait;
    return _mosaicTilesOf(levels, learning: learning);
  }

  List<MosaicTile> _mosaicTilesOf(
    Map<int, int> levels, {
    List<LearningProgress> learning = const [],
  }) => _config == null
      ? const []
      : Mosaic.build(
          selections: _config!.selections,
          levels: levels,
          lastRevisionByAyah: _lastRevisionByAyah,
          today: DateTime.now(),
          tourDays: roundDaysOf(daySelection),
          learning: learning,
        );

  /// Nothing watches the answers live: no notification. A failed write is
  /// logged and does not block the next ones.
  Future<void> recordQuizAnswer(QuizAnswer answer) {
    final date = todayStr;
    final riwaya = _riwaya;
    return _quizWrites = _quizWrites
        .then((_) => QuizAnswers.record(date, riwaya, answer))
        .catchError((Object e) => debugPrint('[Quiz] answer not saved: $e'));
  }
}
