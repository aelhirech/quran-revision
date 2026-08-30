import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../core/streak_engine.dart';
import '../models/ayah_fact.dart';
import '../models/learning_progress.dart';
import '../models/revision_unit.dart';
import '../models/riwaya.dart';
import '../models/sourate.dart';

/// Table de faits par verset (Phase 6) — remplace l'ancien HistoryService
/// (`sessions`/`sourate_sessions`, granularité sourate) et le rôle "profil
/// principal" de l'ancien LearningService (`Set<int>` par sourate en
/// SharedPreferences). Un fait = un verset, un jour, un type
/// ('revise'|'learn'). Les profils élèves ne passent pas par ce service —
/// ils gardent StudentService/LearningProgress inchangés.
class AyahFactsService {
  static const _userId = 'local';
  static Database? _db;

  static Future<Database> _open() async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'history.db'),
      version: 4,
      onCreate: (db, _) async {
        await _createAyahFacts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          // Phase 6 : sessions/sourate_sessions (granularité sourate)
          // remplacées par ayah_facts (granularité verset). Décidé sans
          // backfill — pas d'utilisateur réel en production à ce jour, voir
          // docs/CHANGELOG.md (cadrage Phase 6).
          await db.execute('DROP TABLE IF EXISTS sessions');
          await db.execute('DROP TABLE IF EXISTS sourate_sessions');
          await _createAyahFacts(db);
        }
      },
    );
    return _db!;
  }

  static Future<void> _createAyahFacts(Database db) async {
    await db.execute('''
      CREATE TABLE ayah_facts (
        user_id     TEXT NOT NULL,
        date        TEXT NOT NULL,
        riwaya      TEXT NOT NULL,
        surah_id    INTEGER NOT NULL,
        ayah_id     INTEGER NOT NULL,
        type        TEXT NOT NULL,
        reach       INTEGER NOT NULL DEFAULT 0,
        cold        INTEGER NOT NULL DEFAULT 0,
        checked_out INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_ayah_facts_date ON ayah_facts(date)');
    await db.execute(
        'CREATE INDEX idx_ayah_facts_verse ON ayah_facts(riwaya, surah_id, ayah_id)');
    // Une même plage de versets peut apparaître plusieurs fois dans le plan
    // du jour (répétition cyclique de RevisionEngine, §5.1 doc technique) —
    // sans cette clé unique, une sourate répétée dans 2 rakaas insérerait 2
    // lignes dupliquées pour le même verset/jour et fausserait les comptages.
    await db.execute(
        'CREATE UNIQUE INDEX idx_ayah_facts_unique ON ayah_facts(date, riwaya, surah_id, ayah_id, type)');
    // Couvre le filtre commun à currentStreak/totalActiveDays/recentDayVerseCounts
    // (riwaya + type + reach), avec date en dernière colonne pour satisfaire
    // aussi le ORDER BY date de recentDayVerseCounts sans scan supplémentaire.
    await db.execute(
        'CREATE INDEX idx_ayah_facts_active ON ayah_facts(riwaya, type, reach, date)');
  }

  // --- Révision ---

  /// Enregistre les versets révisés à la date [date] — éclate chaque unité en
  /// une ligne par verset (verseStart..verseEnd), `type='revise', reach=1,
  /// checked_out=1` (pas de notion de jour ouvert tant que le rituel
  /// check-in/check-out n'existe pas — Sprint 2). Idempotent grâce à l'index
  /// unique : une même plage réutilisée deux fois le même jour ne produit
  /// qu'une ligne par verset.
  static Future<void> recordRevisedUnits(
      String date, Riwaya riwaya, List<RevisionUnit> units) async {
    if (units.isEmpty) return;
    final db = await _open();
    final batch = db.batch();
    for (final unit in units) {
      for (int v = unit.verseStart; v <= unit.verseEnd; v++) {
        batch.insert(
          'ayah_facts',
          AyahFact(
            userId: _userId,
            date: date,
            riwaya: riwaya,
            surahId: unit.sourate.id,
            ayahId: v,
            type: AyahFactType.revise,
            reach: true,
            checkedOut: true,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Dernière date de révision par sourate (un verset révisé vaut pour toute
  /// sa sourate) — remplace `HistoryService.lastRevisionDates`, même contrat
  /// consommé par `AppState.refreshFreshness`.
  static Future<Map<int, DateTime>> lastRevisionDatesPerSourate(
      {required Riwaya riwaya}) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT surah_id, MAX(date) as last_date FROM ayah_facts '
      'WHERE riwaya = ? AND type = ? AND reach = 1 GROUP BY surah_id',
      [riwaya.name, AyahFactType.revise.name],
    );
    return {
      for (final row in rows)
        row['surah_id'] as int: DateTime.parse(row['last_date'] as String),
    };
  }

  static Future<int> currentStreak(
      {Set<String> pauseDates = const {}, required Riwaya riwaya}) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT DISTINCT date FROM ayah_facts WHERE riwaya = ? AND type = ? AND reach = 1',
      [riwaya.name, AyahFactType.revise.name],
    );
    final activeDates = rows.map((r) => r['date'] as String).toSet();
    return StreakEngine.compute(
        activeDates: activeDates, pauseDates: pauseDates, today: DateTime.now());
  }

  static Future<int> totalActiveDays({required Riwaya riwaya}) async {
    final db = await _open();
    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT date) as c FROM ayah_facts WHERE riwaya = ? AND type = ? AND reach = 1',
      [riwaya.name, AyahFactType.revise.name],
    );
    return result.first['c'] as int? ?? 0;
  }

  /// Moyenne de versets révisés par jour actif, sur les [lastN] derniers
  /// jours actifs (remplace l'ancienne moyenne "unités par session" — nommée
  /// explicitement "verses" pour ne pas la confondre avec une unité
  /// RevisionEngine, dont la taille varie par sourate).
  static Future<double> avgVersesPerDay(
      {int lastN = 14, required Riwaya riwaya}) async {
    final counts = await recentDayVerseCounts(limit: lastN, riwaya: riwaya);
    if (counts.isEmpty) return 0.0;
    final total = counts.values.fold(0, (sum, c) => sum + c);
    return total / counts.length;
  }

  /// Nombre de versets révisés par jour (date ISO → compte), les [limit]
  /// derniers jours actifs les plus récents — pour `HistoryCard`/`RecapScreen`.
  static Future<Map<String, int>> recentDayVerseCounts(
      {int limit = 14, required Riwaya riwaya}) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT date, COUNT(*) as c FROM ayah_facts '
      'WHERE riwaya = ? AND type = ? AND reach = 1 '
      'GROUP BY date ORDER BY date DESC LIMIT ?',
      [riwaya.name, AyahFactType.revise.name, limit],
    );
    return {for (final row in rows) row['date'] as String: row['c'] as int};
  }

  // --- Apprentissage (profil principal uniquement — les élèves restent sur
  // StudentService/LearningProgress, inchangé) ---

  static Future<void> learnVerse(int surahId, int ayahId, Riwaya riwaya) async {
    await learnVerses(surahId, [ayahId], riwaya);
  }

  /// Marque plusieurs versets appris en un seul batch (une transaction, un
  /// aller-retour SQLite) — utilisé pour un bloc de versets (1/3/5) marqué
  /// d'un coup, pour ne pas risquer un bloc à moitié persisté si l'app est
  /// interrompue entre deux écritures individuelles.
  static Future<void> learnVerses(
      int surahId, List<int> ayahIds, Riwaya riwaya) async {
    if (ayahIds.isEmpty) return;
    final db = await _open();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final batch = db.batch();
    for (final ayahId in ayahIds) {
      batch.insert(
        'ayah_facts',
        AyahFact(
          userId: _userId,
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

  static Future<void> unlearnVerse(int surahId, int ayahId, Riwaya riwaya) async {
    final db = await _open();
    await db.delete('ayah_facts',
        where: 'surah_id = ? AND ayah_id = ? AND riwaya = ? AND type = ?',
        whereArgs: [surahId, ayahId, riwaya.name, AyahFactType.learn.name]);
  }

  static Future<Map<int, Set<int>>> learnedVersesBySourate(
      {required Riwaya riwaya}) async {
    final db = await _open();
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

  /// Date de première ligne `learn` par sourate (`MIN(date)` groupé) — sert
  /// de `startDate` approximatif pour `LearningProgress`.
  static Future<Map<int, DateTime>> learnStartDatesBySourate(
      {required Riwaya riwaya}) async {
    final db = await _open();
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
  /// Utilisé par `LearnScreen`/`RecapScreen` (les élèves restent sur
  /// `StudentService`/`LearningProgress` persisté, inchangé).
  static Future<List<LearningProgress>> loadMainLearningProgress({
    required Riwaya riwaya,
    required List<Sourate> sourates,
  }) async {
    final versesBySourate = await learnedVersesBySourate(riwaya: riwaya);
    final startDates = await learnStartDatesBySourate(riwaya: riwaya);
    final byId = {for (final s in sourates) s.id: s};
    final result = <LearningProgress>[];
    for (final entry in versesBySourate.entries) {
      final sourate = byId[entry.key];
      if (sourate == null) continue;
      result.add(LearningProgress(
        sourate: sourate,
        learnedVerses: entry.value,
        startDate: startDates[entry.key] ?? DateTime.now(),
      ));
    }
    return result;
  }

  /// Supprime tous les faits d'apprentissage d'une sourate — hand-off
  /// apprentissage→révision (remplace `LearningService.remove`).
  static Future<void> deleteLearnFacts(int surahId, Riwaya riwaya) async {
    final db = await _open();
    await db.delete('ayah_facts',
        where: 'surah_id = ? AND riwaya = ? AND type = ?',
        whereArgs: [surahId, riwaya.name, AyahFactType.learn.name]);
  }
}
