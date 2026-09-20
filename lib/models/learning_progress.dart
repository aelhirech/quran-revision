import 'sourate.dart';

class LearningProgress {
  final Sourate sourate;
  final Set<int> learnedVerses; // 1-indexed
  final DateTime startDate;

  const LearningProgress({
    required this.sourate,
    required this.learnedVerses,
    required this.startDate,
  });

  int get totalVerses => sourate.verses;
  int get learnedCount => learnedVerses.length;
  double get progress => totalVerses == 0 ? 0 : learnedCount / totalVerses;
  bool get isComplete => learnedCount >= totalVerses;
  int get nextVerse {
    for (int i = 1; i <= totalVerses; i++) {
      if (!learnedVerses.contains(i)) return i;
    }
    return totalVerses;
  }

  /// Les [count] prochains versets **non encore acquis**, en sautant les
  /// trous (l'utilisateur peut avoir désappris un verset au milieu) plutôt
  /// que de repartir de `nextVerse + 1`. Source unique de la règle « qu'est-ce
  /// qu'on travaille ensuite » : partagée par la proposition du jour
  /// (`AppState._proposeLearning`) et le bloc de pratique
  /// (`LearnSurahScreen._currentBlock`) — les deux la calculaient séparément,
  /// avec le risque de proposer une portion au plan du jour et une autre à
  /// l'écran de pratique. [nextVerse] en est le cas dégénéré `count == 1`.
  List<int> nextBlock(int count) {
    final result = <int>[];
    for (int v = 1; v <= totalVerses && result.length < count; v++) {
      if (!learnedVerses.contains(v)) result.add(v);
    }
    return result;
  }

  /// How many days finishing this surah takes at [versesPerDay] — the
  /// check-out's "regard devant" (US-1 crit. 5), always phrased
  /// conditionally ("if you keep this pace"), never persisted: derived
  /// fresh on every read, so it silently "recalculates after an absence"
  /// with no dedicated code for that, exactly like `DaySelection.cycleDays`.
  int daysToFinish(int versesPerDay) => versesPerDay <= 0
      ? 0
      : ((totalVerses - learnedCount) / versesPerDay).ceil();

  LearningProgress withVerseLearned(int verse) => LearningProgress(
        sourate: sourate,
        learnedVerses: {...learnedVerses, verse},
        startDate: startDate,
      );

  LearningProgress withVerseUnlearned(int verse) => LearningProgress(
        sourate: sourate,
        learnedVerses: {...learnedVerses}..remove(verse),
        startDate: startDate,
      );

  Map<String, dynamic> toJson() => {
        'sourate': sourate.toJson(),
        'learnedVerses': learnedVerses.toList(),
        'startDate': startDate.toIso8601String(),
      };

  factory LearningProgress.fromJson(Map<String, dynamic> j) => LearningProgress(
        sourate: Sourate.fromJson(j['sourate'] as Map<String, dynamic>),
        learnedVerses: (j['learnedVerses'] as List).map((v) => v as int).toSet(),
        startDate: DateTime.tryParse(j['startDate'] as String? ?? '') ?? DateTime.now(),
      );

  factory LearningProgress.start(Sourate s) => LearningProgress(
        sourate: s,
        learnedVerses: {},
        startDate: DateTime.now(),
      );
}

/// Dérivé partagé entre `ProfileScreen`/`RecapScreen` — les deux comptent le
/// nombre de sourates réellement mémorisées depuis la même liste, plutôt que
/// de répéter chacun leur `.where((p) => p.isComplete).length`.
extension LearningProgressListX on List<LearningProgress> {
  int get memorisedCount => where((p) => p.isComplete).length;
}
