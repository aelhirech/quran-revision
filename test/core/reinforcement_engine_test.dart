import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/reinforcement_engine.dart';
import 'package:quran_revision/models/learning_progress.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/services/hafs_service.dart';
import 'package:quran_revision/services/warsh_service.dart';

import '../services/test_helpers.dart';

final _pause = RegExp('[ۖۗۘۚ]');

String _key(Iterable<String> tokens) =>
    tokens.map(bareWord).where((w) => w.isNotEmpty).join(' ');

int _words(Passage p) => _key(p.words).split(' ').length;

(int, int, int) _id(Passage p) => (p.surahId, p.ayahId, p.index);

/// The invariants of any series (Backlog test 3).
void _expectValid(List<PassageQuestion> series, Map<int, Set<int>> carried) {
  expect(series.length, lessThanOrEqualTo(10));
  for (final q in series) {
    final p = q.prompt;
    final a = q.answer;
    expect(a.surahId, p.surahId);
    final sameVerse = a.ayahId == p.ayahId && a.index == p.index + 1;
    final nextVerse = p.endsVerse && a.ayahId == p.ayahId + 1 && a.index == 0;
    expect(sameVerse || nextVerse, isTrue,
        reason: '${_id(a)} ne suit pas ${_id(p)}');
    expect(q.choices.length, inInclusiveRange(2, 4));
    expect(q.choices.where((c) => identical(c, a)).length, 1);
    expect(q.choices.any((c) => identical(c, p)), isFalse);
    for (final c in q.choices) {
      expect(carried[c.surahId]?.contains(c.ayahId), isTrue,
          reason: '${_id(c)} hors de ce que l\'utilisateur porte');
    }
    final keys = q.choices.map((c) => _key(c.words)).toSet();
    expect(keys.length, q.choices.length,
        reason: 'deux choix au même texte pour ${_id(p)}');
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HafsService.initialize();
    await WarshService.initialize();
  });

  List<PassageQuestion> hafsSeries(
    Map<int, Set<int>> carried,
    int seed, {
    Set<(int, int)> today = const {},
    Set<(int, int, int)> avoid = const {},
    int? surahId,
  }) =>
      ReinforcementEngine.buildSeries(
        carried: carried,
        textOf: HafsService.getVerse,
        random: Random(seed),
        today: today,
        avoid: avoid,
        surahId: surahId,
      );

  group('passagesOf', () {
    test('1. découpe sans perte, coupes seulement après un signe de pause', () {
      final riwayas = {
        HafsService.verseCounts: HafsService.getVerse,
        WarshService.verseCounts: WarshService.getVerse,
      };
      riwayas.forEach((counts, textOf) {
        counts.forEach((surah, verses) {
          for (var ayah = 1; ayah <= verses; ayah++) {
            final verse = textOf(surah, ayah);
            final passages = ReinforcementEngine.passagesOf(surah, ayah, verse);
            expect(passages.map((p) => p.text).join(' '), verse);
            expect(passages.first.startsVerse, isTrue);
            expect(passages.last.endsVerse, isTrue);
            for (var i = 0; i < passages.length; i++) {
              expect(passages[i].index, i);
              if (i < passages.length - 1) {
                expect(_pause.hasMatch(passages[i].words.last), isTrue,
                    reason: 'coupe sans signe de pause dans $surah:$ayah');
              }
            }
          }
        });
      });
    });

    test('2. Hafs 2:255 donne six passages, Hafs 94:5 un seul', () {
      final throne =
          ReinforcementEngine.passagesOf(2, 255, HafsService.getVerse(2, 255));
      expect(throne.map(_words), [12, 7, 7, 6, 12, 6]);
      expect(
          ReinforcementEngine.passagesOf(94, 5, HafsService.getVerse(94, 5)),
          hasLength(1));
    });
  });

  group('buildSeries', () {
    test('3. invariants sur les sourates 78 à 114, 20 graines', () {
      final carried = wholeSurahs(78, 114, HafsService.verseCounts);
      for (var seed = 0; seed < 20; seed++) {
        final series = hafsSeries(carried, seed);
        expect(series, hasLength(10));
        _expectValid(series, carried);
      }
    });

    test('4. un passage répété dans la sourate n\'est ni posé ni attendu', () {
      for (var seed = 0; seed < 20; seed++) {
        final kafirun = hafsSeries(wholeSurahs(109, 109, HafsService.verseCounts), seed);
        expect(kafirun, hasLength(1));
        expect(_id(kafirun.single.prompt), (109, 1, 0));
        expect(_id(kafirun.single.answer), (109, 2, 0));

        final refrain = _key(HafsService.getVerse(55, 13).split(' '));
        for (final q
            in hafsSeries(wholeSurahs(55, 55, HafsService.verseCounts), seed)) {
          expect(_key(q.prompt.words), isNot(refrain));
          expect(_key(q.answer.words), isNot(refrain));
        }
      }
    });

    test('5. une plage partielle n\'est jamais dépassée', () {
      final carried = {
        2: {255, 256, 257, 258, 259, 260}
      };
      for (var seed = 0; seed < 20; seed++) {
        final series = hafsSeries(carried, seed);
        expect(series, isNotEmpty);
        _expectValid(series, carried);
        for (final q in series) {
          expect(q.prompt.ayahId == 260 && q.prompt.endsVerse, isFalse);
        }
      }
    });

    test('6. le passage similaire à la bonne suite est proposé', () {
      final carried = wholeSurahs(93, 95, HafsService.verseCounts);
      for (var seed = 0; seed < 20; seed++) {
        final question = hafsSeries(carried, seed, surahId: 94)
            .singleWhere((q) => q.prompt.ayahId == 4);
        expect(question.answer.ayahId, 5);
        expect(question.choices.map(_id), contains((94, 6, 0)));
      }
    });

    test('7. cinq questions viennent du plan du jour', () {
      final carried = wholeSurahs(78, 114, HafsService.verseCounts);
      final today = {for (final v in carried[78]!) (78, v)};
      for (var seed = 0; seed < 20; seed++) {
        final series = hafsSeries(carried, seed, today: today);
        expect(series, hasLength(10));
        expect(series.where((q) => q.prompt.surahId == 78), hasLength(5));
      }
    });

    test('7 bis. sans autre matière, le plan du jour complète la série', () {
      final carried = wholeSurahs(78, 78, HafsService.verseCounts);
      final today = {for (final v in carried[78]!) (78, v)};
      expect(hafsSeries(carried, 1, today: today), hasLength(10));
    });

    test('8. les passages posés à la série précédente ne reviennent pas', () {
      final carried = wholeSurahs(78, 114, HafsService.verseCounts);
      for (var seed = 0; seed < 20; seed++) {
        final first = hafsSeries(carried, seed).map((q) => _id(q.prompt)).toSet();
        final second = hafsSeries(carried, seed, avoid: first);
        expect(second, hasLength(10));
        expect(second.map((q) => _id(q.prompt)).toSet().intersection(first),
            isEmpty);
      }
    });

    test('8 bis. sur une petite sélection, les mêmes questions reviennent', () {
      final carried = wholeSurahs(94, 94, HafsService.verseCounts);
      final first = hafsSeries(carried, 1).map((q) => _id(q.prompt)).toSet();
      expect(hafsSeries(carried, 2, avoid: first), hasLength(first.length));
    });

    test('9. sélection trop petite : liste vide, puis questions à deux choix',
        () {
      expect(
          hafsSeries({
            108: {1, 2}
          }, 1),
          isEmpty);
      expect(hafsSeries({}, 1), isEmpty);
      final carried = {
        108: {1, 2, 3}
      };
      final series = hafsSeries(carried, 1);
      expect(series, hasLength(2));
      _expectValid(series, carried);
      for (final q in series) {
        expect(q.choices, hasLength(2));
      }
    });

    test('10. série sur une sourate : questions dedans, choix aussi d\'ailleurs',
        () {
      final carried = wholeSurahs(78, 114, HafsService.verseCounts);
      for (var seed = 0; seed < 20; seed++) {
        final today = {for (final v in carried[78]!) (78, v)};
        final series = hafsSeries(carried, seed, surahId: 93, today: today);
        _expectValid(series, carried);
        expect(series, hasLength(10));
        expect(series.every((q) => q.prompt.surahId == 93), isTrue);
        expect(
            series.any((q) => q.choices.any((c) => c.surahId != 93)), isTrue);
      }
    });

    test('10 bis. série sur une sourate : le plan du jour ne pèse pas', () {
      final carried = wholeSurahs(78, 78, HafsService.verseCounts);
      // All but verse 1 is in today's plan: were the plan counted, the half
      // kept for the rest would bring verse 1 into every series.
      final today = {
        for (final v in carried[78]!)
          if (v != 1) (78, v),
      };
      final fromVerseOne = [
        for (var seed = 0; seed < 20; seed++)
          if (hafsSeries(carried, seed, surahId: 78, today: today)
              .any((q) => q.prompt.ayahId == 1))
            seed,
      ];
      expect(fromVerseOne.length, lessThan(20));
    });

    test('12. les invariants tiennent sur une sélection Warsh', () {
      final carried = wholeSurahs(78, 114, WarshService.verseCounts);
      for (var seed = 0; seed < 20; seed++) {
        final series = ReinforcementEngine.buildSeries(
          carried: carried,
          textOf: WarshService.getVerse,
          random: Random(seed),
        );
        expect(series, hasLength(10));
        _expectValid(series, carried);
      }
    });
  });

  test('11. carriedVerses : plages choisies et versets appris en cours', () {
    final carried = ReinforcementEngine.carriedVerses(
      selections: [
        SourateSelection(
            sourate: testSourate(2, verses: 286), verseStart: 255, verseEnd: 260),
      ],
      learning: [
        LearningProgress(
          sourate: testSourate(67, verses: 30),
          learnedVerses: {1, 2, 3},
          startDate: DateTime(2026, 10, 1),
        ),
        LearningProgress(
          sourate: testSourate(112, verses: 4),
          learnedVerses: {1, 2, 3, 4},
          startDate: DateTime(2026, 10, 1),
        ),
      ],
    );
    expect(carried, {
      2: {255, 256, 257, 258, 259, 260},
      67: {1, 2, 3},
    });
  });
}
