import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/quiz_levels.dart';
import 'package:quran_revision/models/quiz_answer.dart';

QuizAnswer _passage(int level, bool held, {int surah = 1}) => QuizAnswer(
    kind: QuizKind.passage,
    surahId: surah,
    ayahId: 1,
    rank: 0,
    level: level,
    held: held);

/// Answers given one after the other, each at the level reached so far, as
/// the Quiz tab asks them.
Map<int, int> _play(List<bool> answers) {
  final given = <QuizAnswer>[];
  for (final held in answers) {
    final level = QuizLevels.fold(given)[1] ?? 1;
    given.add(_passage(level, held));
  }
  return QuizLevels.fold(given);
}

void main() {
  test('une sourate jamais interrogée n\'a pas de niveau', () {
    expect(QuizLevels.fold([]), isEmpty);
  });

  test('la première réponse, juste ou fausse, met la sourate au niveau 1', () {
    expect(_play([true]), {1: 1});
    expect(_play([false]), {1: 1});
  });

  test('3 réussites de suite font monter d\'un niveau', () {
    expect(_play([true, true]), {1: 1});
    expect(_play([true, true, true]), {1: 2});
    expect(_play([true, true, false, true, true]), {1: 1});
  });

  test('2 erreurs de suite font descendre d\'un niveau, jamais sous 1', () {
    expect(_play([true, true, true, false]), {1: 2});
    expect(_play([true, true, true, false, false]), {1: 1});
    expect(_play([false, false, false, false]), {1: 1});
  });

  test('le niveau ne dépasse pas 4', () {
    expect(_play(List.filled(15, true)), {1: 4});
  });

  test('les compteurs repartent de zéro à chaque changement de niveau', () {
    // Three hits at 1 rise to 2; a miss then a hit at 2 leave it at 2.
    expect(_play([true, true, true, false, true, false]), {1: 2});
  });

  test('une réponse posée à un autre niveau que le courant ne compte pas', () {
    final answers = [
      for (var i = 0; i < 3; i++) _passage(1, true),
      // Composed at level 1 before the rise: ignored.
      _passage(1, false),
      _passage(1, false),
    ];
    expect(QuizLevels.fold(answers), {1: 2});
  });

  test('chaque sourate a son niveau, les mots ne comptent pas', () {
    final answers = [
      for (var i = 0; i < 3; i++) _passage(1, true, surah: 2),
      _passage(1, false, surah: 3),
      for (var i = 0; i < 5; i++)
        QuizAnswer(
            kind: QuizKind.word,
            surahId: 4,
            ayahId: 1,
            rank: i,
            level: 0,
            held: true),
    ];
    expect(QuizLevels.fold(answers), {2: 2, 3: 1});
  });

  test('changes : montée et descente annoncées, premier niveau non', () {
    expect(
        QuizLevels.changes(
            {1: 1, 2: 3, 3: 2}, {1: 2, 2: 2, 3: 2, 4: 1, 5: 2}),
        {
          1: (from: 1, to: 2),
          2: (from: 3, to: 2),
          // Never played before the series, and already risen in it.
          5: (from: 1, to: 2),
        });
  });
}
