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
