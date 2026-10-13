import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/reinforcement_engine.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/services/word_gloss_service.dart';

import '../services/test_helpers.dart';

// Written apart from the engine's private rules, on purpose: the tests state
// the rule, they do not borrow its implementation.
final _bracketed = RegExp(r'\([^)]*\)|\[[^\]]*\]');
final _longWord = RegExp(r'\p{L}{4,}', unicode: true);

Set<String> _longWords(String gloss) => {
      for (final match in _longWord.allMatches(gloss.replaceAll(_bracketed, ' ')))
        match[0]!.toLowerCase(),
    };

Map<int, Set<int>> _whole(int from, int to) =>
    wholeSurahs(from, to, HafsService.verseCounts);

void _expectValid(List<WordQuestion> questions, Map<int, Set<int>> carried) {
  for (final question in questions) {
    final answer = question.answer;
    final where = '${answer.id}';
    expect(bareWord(answer.arabic).length, greaterThanOrEqualTo(3), reason: where);
    expect(question.choices.length, inInclusiveRange(2, 4), reason: where);
    expect(question.choices.map((choice) => choice.gloss).toSet(), hasLength(question.choices.length),
        reason: 'un même sens deux fois parmi les choix de $where');
    expect(question.choices.map((choice) => bareWord(choice.arabic)).toSet(),
        hasLength(question.choices.length),
        reason: 'deux choix au même mot arabe pour $where');
    for (final choice in question.choices) {
      expect(carried[choice.surahId]?.contains(choice.ayahId), isTrue,
          reason: '${choice.id} hors de ce que l\'utilisateur porte');
      expect(WordGlossService.glosses(choice.surahId, choice.ayahId)![choice.rank],
          choice.gloss);
      if (choice.id == answer.id) continue;
      expect(_longWords(choice.gloss).intersection(_longWords(answer.gloss)),
          isEmpty,
          reason: '« ${choice.gloss} » trop proche de « ${answer.gloss} »');
    }
    expect((question.passage.surahId, question.passage.ayahId),
        (answer.surahId, answer.ayahId));
    expect(question.passage.words[question.wordIndex], answer.arabic, reason: where);
  }
  expect(questions.map((question) => bareWord(question.answer.arabic)).toSet(),
      hasLength(questions.length),
      reason: 'un même mot posé deux fois dans la série');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HafsService.initialize();
    await WordGlossService.load();
  });

  List<WordQuestion> words(
    Map<int, Set<int>> carried,
    int seed, {
    Set<(int, int)> today = const {},
    Set<(int, int, int)> avoid = const {},
    int? surahId,
  }) =>
      ReinforcementWords.buildWordQuestions(
        carried: carried,
        textOf: HafsService.getVerse,
        glossesOf: WordGlossService.glosses,
        random: Random(seed),
        today: today,
        avoid: avoid,
        surahId: surahId,
      );

  List<SeriesQuestion> mixed(
    Map<int, Set<int>> carried,
    int seed, {
    List<String>? Function(int, int) glossesOf = WordGlossService.glosses,
  }) =>
      ReinforcementWords.buildMixedSeries(
        carried: carried,
        textOf: HafsService.getVerse,
        glossesOf: glossesOf,
        random: Random(seed),
      );

  group('buildWordQuestions', () {
    test('1. invariants sur les sourates 78 à 114, 20 graines', () {
      final carried = _whole(78, 114);
      for (var seed = 0; seed < 20; seed++) {
        final series = words(carried, seed);
        expect(series, hasLength(10));
        _expectValid(series, carried);
      }
    });

    test('2. un verset sans un sens par mot n\'est jamais interrogé', () {
      final surah = _whole(37, 37);
      for (var seed = 0; seed < 20; seed++) {
        final series = words(surah, seed);
        _expectValid(series, surah);
        for (final question in series) {
          expect(question.choices.any((choice) => choice.ayahId == 130), isFalse);
        }
      }
      // With two verses carried, every askable word is asked: 37:130 would
      // show up if nothing kept it out.
      final pair = {
        37: {130, 131}
      };
      final series = words(pair, 1);
      expect(series, isNotEmpty);
      expect(series.every((question) => question.choices.every((choice) => choice.ayahId == 131)),
          isTrue);
    });

    test('3. les deux sens de question apparaissent', () {
      final carried = _whole(78, 114);
      final directions = {
        for (var seed = 0; seed < 20; seed++)
          for (final question in words(carried, seed)) question.arabicToMeaning,
      };
      expect(directions, {true, false});
    });

    test('4. les mots posés à la série précédente ne reviennent pas', () {
      final carried = _whole(78, 114);
      for (var seed = 0; seed < 20; seed++) {
        final first = words(carried, seed).map((question) => question.answer.id).toSet();
        final second = words(carried, seed, avoid: first);
        expect(second, hasLength(10));
        expect(second.map((question) => question.answer.id).toSet().intersection(first),
            isEmpty);
      }
    });

    test('5. cinq mots viennent du plan du jour', () {
      final carried = _whole(78, 114);
      final today = {for (final v in carried[78]!) (78, v)};
      for (var seed = 0; seed < 20; seed++) {
        final series = words(carried, seed, today: today);
        expect(series, hasLength(10));
        expect(series.where((question) => question.answer.surahId == 78), hasLength(5));
      }
    });

    test('6. série sur une sourate : mots et mauvais choix de cette sourate',
        () {
      final carried = _whole(78, 114);
      for (var seed = 0; seed < 20; seed++) {
        final series = words(carried, seed, surahId: 93);
        _expectValid(series, carried);
        expect(series, isNotEmpty);
        for (final question in series) {
          expect(question.choices.every((choice) => choice.surahId == 93), isTrue);
        }
      }
    });

    test('6 bis. série sur une sourate : le plan du jour ne pèse pas', () {
      final carried = _whole(78, 78);
      // All but verse 1 is in today's plan: were the plan counted, the half
      // kept for the rest would bring a word of verse 1 into every series.
      final today = {
        for (final v in carried[78]!)
          if (v != 1) (78, v),
      };
      final fromVerseOne = [
        for (var seed = 0; seed < 20; seed++)
          if (words(carried, seed, surahId: 78, today: today)
              .any((question) => question.answer.ayahId == 1))
            seed,
      ];
      expect(fromVerseOne.length, lessThan(20));
    });

    test('7. sourate sans autre mot posable : mauvais choix pris ailleurs', () {
      final carried = {
        112: {1},
        113: {1, 2, 3, 4, 5},
      };
      final series = words(carried, 1, surahId: 112);
      _expectValid(series, carried);
      expect(series, hasLength(1));
      expect(series.single.answer.gloss, 'Allâh,');
      expect(
          series.single.choices.where((choice) => choice.surahId == 113), hasLength(3));
    });

    test('8. sans données ou sans mot posable : liste vide', () {
      expect(
          ReinforcementWords.buildWordQuestions(
            carried: _whole(78, 114),
            textOf: HafsService.getVerse,
            glossesOf: (_, _) => null,
            random: Random(1),
          ),
          isEmpty);
      expect(words({}, 1), isEmpty);
      // A lone askable word has no wrong choice to stand next to.
      expect(
          words({
            112: {1}
          }, 1),
          isEmpty);
    });

    test('9. un même sens est proposé une seule fois', () {
      // Al-Kawthar with made-up meanings: seven of its words share one.
      final glosses = {
        1: ['premier', 'double', 'double'],
        2: ['double', 'double', 'double'],
        3: ['et', 'double', 'il', 'double'],
      };
      final series = ReinforcementWords.buildWordQuestions(
        carried: {
          108: {1, 2, 3}
        },
        textOf: HafsService.getVerse,
        glossesOf: (_, ayah) => glosses[ayah],
        random: Random(1),
      );
      final question = series.singleWhere((question) => question.answer.gloss == 'premier');
      expect(question.choices.map((choice) => choice.gloss).toSet(), {'premier', 'double'});
      expect(question.choices, hasLength(2));
    });
  });

  group('buildMixedSeries', () {
    test('10. cinq passages et cinq mots', () {
      final carried = _whole(78, 114);
      for (var seed = 0; seed < 20; seed++) {
        final series = mixed(carried, seed);
        expect(series.whereType<PassageQuestion>(), hasLength(5));
        expect(series.whereType<WordQuestion>(), hasLength(5));
        _expectValid(series.whereType<WordQuestion>().toList(), carried);
      }
    });

    test('11. sans données de mots, dix passages', () {
      final series = mixed(_whole(78, 114), 1, glossesOf: (_, _) => null);
      expect(series.whereType<PassageQuestion>(), hasLength(10));
    });

    test('12. trop peu de passages : les mots complètent', () {
      // Al-Kawthar offers two passage questions only.
      final series = mixed({
        108: {1, 2, 3}
      }, 1);
      expect(series.whereType<PassageQuestion>(), hasLength(2));
      expect(series.whereType<WordQuestion>().length, greaterThan(5));
    });

    test('13. trop peu de mots : les passages complètent', () {
      // Only 112:1 has meanings here: one askable word, no wrong choice.
      final series = mixed(_whole(78, 114), 1,
          glossesOf: (surah, ayah) => surah == 112 && ayah == 1
              ? WordGlossService.glosses(surah, ayah)
              : null);
      expect(series.whereType<PassageQuestion>(), hasLength(10));
    });
  });
}
