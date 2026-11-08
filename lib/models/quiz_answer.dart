enum QuizKind { passage, word }

/// One answer given in the Quiz tab. Kept apart from `ayah_facts`: recognising
/// a verse is never a revision (US-21).
class QuizAnswer {
  final QuizKind kind;
  final int surahId;
  final int ayahId;

  /// The passage's index in its verse, or the word's rank among its words:
  /// with [surahId] and [ayahId], what identifies the question.
  final int rank;

  /// The difficulty the question was asked at, 1 to 4; 0 for a word.
  final int level;
  final bool held;

  const QuizAnswer({
    required this.kind,
    required this.surahId,
    required this.ayahId,
    required this.rank,
    required this.level,
    required this.held,
  });
}
