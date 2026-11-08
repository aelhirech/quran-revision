import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/day_dates.dart';
import 'package:quran_revision/models/quiz_answer.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/services/ayah_facts_service.dart';

import 'test_helpers.dart';

QuizAnswer _answer(int ayah, bool held,
        {QuizKind kind = QuizKind.passage, int rank = 0, int level = 1}) =>
    QuizAnswer(
        kind: kind,
        surahId: 78,
        ayahId: ayah,
        rank: rank,
        level: level,
        held: held);

void main() {
  setUpAll(() => initFfiTestDb('qr_test_quiz_answers_'));

  setUp(clearFactsBetweenTests);

  final today = dayKey(DateTime.now());

  test('les réponses de passages se relisent dans l\'ordre donné', () async {
    await QuizAnswers.record(today, Riwaya.hafs, _answer(3, true, level: 2));
    await QuizAnswers.record(today, Riwaya.hafs, _answer(1, false));
    await QuizAnswers.record(
        today, Riwaya.hafs, _answer(1, true, kind: QuizKind.word, level: 0));

    final answers = await QuizAnswers.passageAnswers(Riwaya.hafs);
    expect(answers.map((a) => (a.ayahId, a.level, a.held)),
        [(3, 2, true), (1, 1, false)]);
  });

  test('seule la dernière réponse d\'une question décide de son retour',
      () async {
    await QuizAnswers.record(today, Riwaya.hafs, _answer(5, false));
    await QuizAnswers.record(today, Riwaya.hafs, _answer(2, false));
    await QuizAnswers.record(today, Riwaya.hafs, _answer(5, true));
    await QuizAnswers.record(today, Riwaya.hafs, _answer(7, true));
    await QuizAnswers.record(today, Riwaya.hafs, _answer(7, false));
    await QuizAnswers.record(today, Riwaya.hafs, _answer(2, false));

    // Oldest last miss first: 7 (fifth row) before 2 (sixth row).
    expect(await QuizAnswers.pendingReturns(Riwaya.hafs, QuizKind.passage),
        [(78, 7, 0), (78, 2, 0)]);
  });

  test('passages, mots et riwayas ont chacun leurs retours', () async {
    await QuizAnswers.record(today, Riwaya.hafs, _answer(1, false));
    await QuizAnswers.record(
        today, Riwaya.hafs, _answer(1, false, kind: QuizKind.word, rank: 2));
    await QuizAnswers.record(today, Riwaya.warsh, _answer(4, false));

    expect(await QuizAnswers.pendingReturns(Riwaya.hafs, QuizKind.passage),
        [(78, 1, 0)]);
    expect(await QuizAnswers.pendingReturns(Riwaya.hafs, QuizKind.word),
        [(78, 1, 2)]);
    expect(await QuizAnswers.pendingReturns(Riwaya.warsh, QuizKind.passage),
        [(78, 4, 0)]);
  });

  test('une réponse ne compte jamais comme une révision', () async {
    for (var ayah = 1; ayah <= 5; ayah++) {
      await QuizAnswers.record(today, Riwaya.hafs, _answer(ayah, true));
    }

    expect(await AyahFactsService.lastRevisionDatesPerVerse(riwaya: Riwaya.hafs),
        isEmpty);
    expect(await AyahFactsService.currentStreak(riwaya: Riwaya.hafs), 0);
    expect(await AyahFactsService.totalActiveDays(riwaya: Riwaya.hafs), 0);
    expect(await AyahFactsRitual.pendingDate(riwaya: Riwaya.hafs), isNull);
    expect(await AyahFactsRitual.isDaySealed(today, Riwaya.hafs), isFalse);
    expect(await AyahFactsRitual.dayFacts(today, Riwaya.hafs), isEmpty);
  });
}
