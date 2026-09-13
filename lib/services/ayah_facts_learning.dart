part of 'ayah_facts_service.dart';

/// Faits d'apprentissage (`type = 'learn'`) — voir [AyahFactsService] pour le
/// schéma partagé (`_open`/`_userId`, accessibles ici via `part of`).
class AyahFactsLearning {
  /// Marque plusieurs versets appris en un seul batch (une transaction, un
  /// aller-retour SQLite) — utilisé pour un bloc de versets (1/3/5) marqué
  /// d'un coup, pour ne pas risquer un bloc à moitié persisté si l'app est
  /// interrompue entre deux écritures individuelles.
  static Future<void> learnVerses(
      int surahId, List<int> ayahIds, Riwaya riwaya) async {
    if (ayahIds.isEmpty) return;
    final db = await AyahFactsService._open();
    final date = DateTime.now().toIso8601String().substring(0, 10);
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
          reach: true,
          checkedOut: true,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
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
  static Future<void> unlearnVerse(int surahId, int ayahId, Riwaya riwaya) async {
    final db = await AyahFactsService._open();
    await db.update('ayah_facts', {'reach': 0},
        where: 'surah_id = ? AND ayah_id = ? AND riwaya = ? AND type = ?',
        whereArgs: [surahId, ayahId, riwaya.name, AyahFactType.learn.name]);
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
  /// `RevisionEngine.distributeToRakaas`).
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
  /// dans l'écran de pratique ([learnVerses] écrit `checked_out = 1`) — sans
  /// ce filtre, pratiquer une autre sourate le même jour pouvait détourner
  /// le plan du jour vers elle (`ORDER BY surah_id` prend le plus petit id),
  /// et le check-out proposait alors de « désapprendre » des versets
  /// réellement acquis.
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
