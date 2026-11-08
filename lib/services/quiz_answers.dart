part of 'ayah_facts_service.dart';

/// The Quiz tab's answers (US-21), in their own table so that no reader of
/// `ayah_facts` can ever take an answer for a revision. Rows are only added:
/// levels and questions to ask again are rebuilt from them.
class QuizAnswers {
  static Future<void> _create(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_answers (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id       TEXT NOT NULL,
        date          TEXT NOT NULL,
        riwaya        TEXT NOT NULL,
        kind          TEXT NOT NULL,
        surah_id      INTEGER NOT NULL,
        ayah_id       INTEGER NOT NULL,
        rank_in_verse INTEGER NOT NULL,
        level         INTEGER NOT NULL,
        held          INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_answers_question '
      'ON quiz_answers(riwaya, kind, surah_id, ayah_id, rank_in_verse, id)',
    );
  }

  static Future<void> record(
    String date,
    Riwaya riwaya,
    QuizAnswer answer,
  ) async {
    final db = await AyahFactsService._open();
    await db.insert('quiz_answers', {
      'user_id': AyahFactsService._userId,
      'date': date,
      'riwaya': riwaya.name,
      'kind': answer.kind.name,
      'surah_id': answer.surahId,
      'ayah_id': answer.ayahId,
      'rank_in_verse': answer.rank,
      'level': answer.level,
      'held': answer.held ? 1 : 0,
    });
  }

  /// Every passage answer of [riwaya], in the order given.
  static Future<List<QuizAnswer>> passageAnswers(Riwaya riwaya) async {
    final db = await AyahFactsService._open();
    final rows = await db.query(
      'quiz_answers',
      where: 'riwaya = ? AND kind = ?',
      whereArgs: [riwaya.name, QuizKind.passage.name],
      orderBy: 'id',
    );
    return [for (final row in rows) _answerOf(row)];
  }

  /// The questions of [kind] whose last answer was wrong, oldest first.
  static Future<List<(int, int, int)>> pendingReturns(
    Riwaya riwaya,
    QuizKind kind,
  ) async {
    final db = await AyahFactsService._open();
    final rows = await db.rawQuery(
      'SELECT surah_id, ayah_id, rank_in_verse FROM quiz_answers q '
      'WHERE riwaya = ? AND kind = ? AND held = 0 AND id = ('
      'SELECT MAX(id) FROM quiz_answers r WHERE r.riwaya = q.riwaya '
      'AND r.kind = q.kind AND r.surah_id = q.surah_id '
      'AND r.ayah_id = q.ayah_id AND r.rank_in_verse = q.rank_in_verse) '
      'ORDER BY id',
      [riwaya.name, kind.name],
    );
    return [
      for (final row in rows)
        (
          row['surah_id'] as int,
          row['ayah_id'] as int,
          row['rank_in_verse'] as int,
        ),
    ];
  }

  static QuizAnswer _answerOf(Map<String, Object?> row) => QuizAnswer(
    kind: QuizKind.values.byName(row['kind'] as String),
    surahId: row['surah_id'] as int,
    ayahId: row['ayah_id'] as int,
    rank: row['rank_in_verse'] as int,
    level: row['level'] as int,
    held: row['held'] == 1,
  );
}
