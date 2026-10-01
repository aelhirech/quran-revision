part of 'ayah_facts_service.dart';

/// Faits d'apprentissage (`type = 'learn'`) — voir [AyahFactsService] pour le
/// schéma partagé (`_open`/`_userId`, accessibles ici via `part of`).
class AyahFactsLearning {
  /// Verses of [surahId] still acquired on the most recent date strictly
  /// before [beforeDate] — the "last learned block" the check-out lets the
  /// user withdraw (US-12). Sorted, empty if nothing was learned before.
  static Future<List<int>> lastLearnedBlock(
      int surahId, String beforeDate, Riwaya riwaya) async {
    final db = await AyahFactsService._open();
    final rows = await db.rawQuery(
        'WITH learned AS (SELECT ayah_id, date FROM ayah_facts '
        'WHERE riwaya = ? AND type = ? AND reach = 1 AND surah_id = ?) '
        'SELECT ayah_id FROM learned '
        'WHERE date = (SELECT MAX(date) FROM learned WHERE date < ?) '
        'ORDER BY ayah_id',
        [riwaya.name, AyahFactType.learn.name, surahId, beforeDate]);
    return [for (final row in rows) row['ayah_id'] as int];
  }

  /// Repasse un verset à `reach = 0` ("visé, pas encore atteint") plutôt que
  /// de supprimer sa ligne — sinon désapprendre le seul verset qui rattachait
  /// une sourate à "en cours d'apprentissage" (typiquement le verset 1, voir
  /// [startLearning]) la faisait disparaître, reproduisant le même bug par un
  /// autre chemin. Cohérent avec `revise` (`setReach`), qui ne supprime
  /// jamais non plus une ligne pour revenir à "pas fait".
  ///
  /// EVERY dated row of that verse is downgraded, not just the most recent
  /// one: every reader of "learned" (`learnedVersesBySourate`,
  /// `learnedVersesForSourate`, hence `LearningProgress`/`isComplete`) asks
  /// whether ANY row is at 1, with no date clause. Downgrading a single row
  /// would leave the verse acquired and make the gesture a silent no-op. What
  /// carries the history is the EXISTENCE of the dated rows, not their
  /// `reach` — same semantics as `setReach` on the revision side.
  ///
  /// One UPDATE for the whole list: a half-applied withdrawal could let the
  /// check-out hand-off see the surah as complete.
  static Future<void> unlearnVerses(
      int surahId, List<int> ayahIds, Riwaya riwaya) async {
    if (ayahIds.isEmpty) return;
    final db = await AyahFactsService._open();
    final placeholders = List.filled(ayahIds.length, '?').join(', ');
    await db.update('ayah_facts', {'reach': 0},
        where: 'surah_id = ? AND riwaya = ? AND type = ? '
            'AND ayah_id IN ($placeholders)',
        whereArgs: [surahId, riwaya.name, AyahFactType.learn.name, ...ayahIds]);
  }

  static Future<Map<int, Set<int>>> learnedVersesBySourate(
      {required Riwaya riwaya}) async {
    final db = await AyahFactsService._open();
    final rows = await db.query('ayah_facts',
        columns: ['surah_id', 'ayah_id'],
        where: 'riwaya = ? AND type = ? AND reach = 1',
        whereArgs: [riwaya.name, AyahFactType.learn.name]);
    final result = <int, Set<int>>{};
    for (final row in rows) {
      final surahId = row['surah_id'] as int;
      result.putIfAbsent(surahId, () => {}).add(row['ayah_id'] as int);
    }
    return result;
  }

  /// Versets acquis d'**une seule** sourate — filtré en SQL plutôt que de
  /// charger [learnedVersesBySourate] en entier pour n'en garder qu'une clé
  /// (le check-in appelle ce chemin à chaque ajustement de la portion).
  static Future<Set<int>> learnedVersesForSourate(
      {required Riwaya riwaya, required int surahId}) async {
    final db = await AyahFactsService._open();
    final rows = await db.query('ayah_facts',
        columns: ['ayah_id'],
        where: 'riwaya = ? AND type = ? AND reach = 1 AND surah_id = ?',
        whereArgs: [riwaya.name, AyahFactType.learn.name, surahId]);
    return {for (final row in rows) row['ayah_id'] as int};
  }

  /// Learning rows of day [date]: how many verses were acquired, out of how
  /// many proposed. No `checked_out` filter, unlike [learnPlanFor]: this
  /// reads a day AFTER it was sealed (US-14 day recap).
  static Future<({int reached, int total})> learnCountsOn(
      String date, Riwaya riwaya) async {
    final db = await AyahFactsService._open();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total, SUM(reach) AS reached FROM ayah_facts '
      'WHERE date = ? AND riwaya = ? AND type = ?',
      [date, riwaya.name, AyahFactType.learn.name],
    );
    return (
      reached: (rows.first['reached'] as int?) ?? 0,
      total: (rows.first['total'] as int?) ?? 0,
    );
  }

  /// Date de première ligne `learn` par sourate (`MIN(date)` groupé) — sert
  /// de `startDate` approximatif pour `LearningProgress`.
  static Future<Map<int, DateTime>> learnStartDatesBySourate(
      {required Riwaya riwaya}) async {
    final db = await AyahFactsService._open();
    final rows = await db.rawQuery(
      'SELECT surah_id, MIN(date) as start FROM ayah_facts '
      'WHERE riwaya = ? AND type = ? GROUP BY surah_id',
      [riwaya.name, AyahFactType.learn.name],
    );
    return {
      for (final row in rows)
        row['surah_id'] as int: DateTime.parse(row['start'] as String),
    };
  }

  /// Reconstruit les `LearningProgress` du profil principal à partir des
  /// faits `ayah_facts` (type='learn') — une seule requête groupée par
  /// donnée nécessaire, pas un aller-retour SQL par sourate en cours.
  /// Utilisé par `LearnScreen`/`RecapScreen`/`ProfileScreen`. Itère sur
  /// `startDates` (pas `versesBySourate`) pour inclure aussi les sourates
  /// juste démarrées via [startLearning], dont aucun verset n'a encore
  /// `reach = 1`.
  static Future<List<LearningProgress>> loadMainLearningProgress({
    required Riwaya riwaya,
    required List<Sourate> sourates,
  }) async {
    final versesBySourate = await learnedVersesBySourate(riwaya: riwaya);
    final startDates = await learnStartDatesBySourate(riwaya: riwaya);
    final byId = {for (final s in sourates) s.id: s};
    final result = <LearningProgress>[];
    for (final entry in startDates.entries) {
      final sourate = byId[entry.key];
      if (sourate == null) continue;
      result.add(LearningProgress(
        sourate: sourate,
        learnedVerses: versesBySourate[entry.key] ?? {},
        startDate: entry.value,
      ));
    }
    return result;
  }

  /// Supprime tous les faits d'apprentissage d'une sourate — hand-off
  /// apprentissage→révision (remplace `LearningService.remove`).
  static Future<void> deleteLearnFacts(int surahId, Riwaya riwaya) async {
    final db = await AyahFactsService._open();
    await db.delete('ayah_facts',
        where: 'surah_id = ? AND riwaya = ? AND type = ?',
        whereArgs: [surahId, riwaya.name, AyahFactType.learn.name]);
  }

  /// Écrit les versets que l'utilisateur veut *apprendre* le jour [date] —
  /// mêmes sémantiques que `AyahFactsRitual.proposeUnits` côté révision
  /// (`reach = 0` = visé, pas encore acquis ; `ConflictAlgorithm.ignore` pour
  /// ne jamais écraser un verset déjà marqué appris). C'est ce que la
  /// dernière rakaa du plan du jour fait réciter (voir
  /// `RakaaDistributor.distributeToRakaas`).
  static Future<void> proposeLearnVerses(
      String date, Riwaya riwaya, int surahId, List<int> ayahIds) async {
    if (ayahIds.isEmpty) return;
    final db = await AyahFactsService._open();
    final batch = db.batch();
    for (final ayahId in ayahIds) {
      batch.insert(
        'ayah_facts',
        AyahFact(
          userId: AyahFactsService._userId,
          date: date,
          riwaya: riwaya,
          surahId: surahId,
          ayahId: ayahId,
          type: AyahFactType.learn,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Portion à apprendre **proposée** pour [date], ou `null` si aucune.
  ///
  /// Filtre `checked_out = 0`, ce qui distingue la proposition du jour
  /// (écrite par [proposeLearnVerses]) des versets travaillés à la volée
  /// dans l'écran de pratique — sans
  /// ce filtre, pratiquer une autre sourate le même jour pouvait détourner
  /// le plan du jour vers elle (`ORDER BY surah_id` prend le plus petit id),
  /// et le check-out proposait alors de « désapprendre » des versets
  /// réellement acquis.
  /// Still needed after US-12 removed that screen: its `checked_out = 1`
  /// rows remain in existing devices' history.
  ///
  /// S'il reste plusieurs sourates candidates (l'utilisateur a changé de
  /// sourate en cours de journée après en avoir déjà acquis des versets),
  /// celle qui porte encore des versets non acquis l'emporte : c'est la
  /// proposition active, pas le reliquat de la précédente.
  static Future<({int surahId, List<int> ayahIds, Set<int> reachedVerses})?>
      learnPlanFor(String date, Riwaya riwaya) async {
    final db = await AyahFactsService._open();
    final rows = await db.query('ayah_facts',
        columns: ['surah_id', 'ayah_id', 'reach'],
        where: 'date = ? AND riwaya = ? AND type = ? AND checked_out = 0',
        whereArgs: [date, riwaya.name, AyahFactType.learn.name],
        orderBy: 'surah_id, ayah_id');
    if (rows.isEmpty) return null;
    final pending = rows.firstWhere((r) => (r['reach'] as int) == 0,
        orElse: () => rows.first);
    final surahId = pending['surah_id'] as int;
    final forSurah = rows.where((r) => r['surah_id'] as int == surahId);
    return (
      surahId: surahId,
      ayahIds: [for (final r in forSurah) r['ayah_id'] as int],
      reachedVerses: {
        for (final r in forSurah)
          if ((r['reach'] as int) == 1) r['ayah_id'] as int,
      },
    );
  }
}
