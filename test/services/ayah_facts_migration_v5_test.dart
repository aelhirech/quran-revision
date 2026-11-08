import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quran_revision/models/quiz_answer.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/services/ayah_facts_service.dart';

import 'test_helpers.dart';

/// A device on schema 5 (before the Quiz answers, US-21) keeps its
/// `ayah_facts` rows and gains `quiz_answers`. One test per file: see
/// `ayah_facts_migration_test.dart` (process-wide `_db` singleton).
void main() {
  setUpAll(() async {
    final tempDir = await initFfiTestDb('qr_test_migration_v5_');
    final seed = await databaseFactory.openDatabase(
      p.join(tempDir.path, 'history.db'),
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE ayah_facts (
              user_id     TEXT NOT NULL,
              date        TEXT NOT NULL,
              riwaya      TEXT NOT NULL,
              surah_id    INTEGER NOT NULL,
              ayah_id     INTEGER NOT NULL,
              type        TEXT NOT NULL,
              reach       INTEGER NOT NULL DEFAULT 0,
              needs_work  INTEGER NOT NULL DEFAULT 0,
              checked_out INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.insert('ayah_facts', {
            'user_id': 'local',
            'date': '2020-03-01',
            'riwaya': Riwaya.hafs.name,
            'surah_id': 7,
            'ayah_id': 4,
            'type': 'revise',
            'reach': 1,
          });
        },
      ),
    );
    await seed.close();
  });

  test('appareil en v5 : les faits restent, le journal du Quiz apparaît',
      () async {
    final facts = await AyahFactsRitual.dayFacts('2020-03-01', Riwaya.hafs);
    expect(facts, hasLength(1));
    expect(facts.first.surahId, 7);

    const answer = QuizAnswer(
        kind: QuizKind.passage,
        surahId: 7,
        ayahId: 4,
        rank: 0,
        level: 1,
        held: false);
    await QuizAnswers.record('2020-03-02', Riwaya.hafs, answer);
    expect(await QuizAnswers.pendingReturns(Riwaya.hafs, QuizKind.passage),
        [(7, 4, 0)]);
  });
}
