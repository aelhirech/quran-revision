import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../core/day_dates.dart';
import '../core/streak_engine.dart';
import '../models/ayah_fact.dart';
import '../models/learning_progress.dart';
import '../models/revision_unit.dart';
import '../models/riwaya.dart';
import '../models/sourate.dart';

part 'ayah_facts_learning.dart';
part 'ayah_facts_ritual.dart';

/// Table de faits par verset (Phase 6) — remplace l'ancien HistoryService
/// (`sessions`/`sourate_sessions`, granularité sourate) et le rôle "profil
/// principal" de l'ancien LearningService (`Set<int>` par sourate en
/// SharedPreferences). Un fait = un verset, un jour, un type
/// ('revise'|'learn').
///
/// Ce fichier porte le schéma partagé (`_open`/`_db`/`_userId`) et les
/// requêtes de révision. Les faits d'apprentissage et le rituel
/// check-in/check-out vivent dans [AyahFactsLearning]/[AyahFactsRitual]
/// (`part`/`part of` de cette même bibliothèque — ils partagent donc
/// `_open`/`_userId` sans les dupliquer, la visibilité `_` de Dart étant par
/// bibliothèque, pas par classe).
class AyahFactsService {
  static const _userId = 'local';
  static Database? _db;

  static Future<Database> _open() async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'history.db'),
      version: 5,
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
        // `oldVersion >= 4` est nécessaire, pas juste `oldVersion < 5` seul :
        // sqflite n'appelle `onUpgrade` qu'une seule fois par ouverture, avec
        // l'`oldVersion` d'origine — un appareil encore sur schéma < 4 passe
        // par les deux blocs `if` dans le même appel. Le bloc `< 4` ci-dessus
        // vient alors de créer `ayah_facts` via `_createAyahFacts`, qui
        // produit déjà `needs_work` (jamais `cold`) : ré-exécuter l'`ALTER
        // TABLE ADD COLUMN` planterait ("duplicate column name"), et le
        // backfill lèverait "no such column: cold". Cette migration ne doit
        // tourner que sur un appareil qui avait réellement la colonne `cold`
        // en base (bug trouvé en revue de code Phase 8 Sprint 1).
        if (oldVersion >= 4 && oldVersion < 5) {
          // Renommage `cold` → `needs_work` (collision de vocabulaire avec
          // le concept "freshness" introduit ce sprint, sans rapport entre
          // les deux — voir docs/CHANGELOG.md). ADD COLUMN + backfill plutôt
          // que RENAME COLUMN : reste compatible avec les versions de SQLite
          // embarquées sur d'anciens appareils Android (RENAME COLUMN
          // nécessite SQLite ≥ 3.25, pas garanti partout). L'ancienne colonne
          // `cold` reste en base, orpheline mais inoffensive.
          await db.execute(
              'ALTER TABLE ayah_facts ADD COLUMN needs_work INTEGER NOT NULL DEFAULT 0');
          await db.execute('UPDATE ayah_facts SET needs_work = cold');
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
        needs_work  INTEGER NOT NULL DEFAULT 0,
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
    // Couvre le filtre de currentStreak/totalActiveDays (riwaya + type +
    // reach), `date` en dernière colonne pour que leur DISTINCT/COUNT le
    // trouve dans l'index. recentDayVerseStats, elle, ne filtre plus sur
    // `reach` (elle l'agrège) : l'index reste couvrant sur ses colonnes, mais
    // son GROUP BY date paie un tri.
    await db.execute(
        'CREATE INDEX idx_ayah_facts_active ON ayah_facts(riwaya, type, reach, date)');
  }

  // --- Révision ---

  /// Dernière date de révision par verset (`MAX(date)` groupé par sourate +
  /// verset, versets jamais révisés absents du résultat) — alimente
  /// `FreshnessEngine.computeForRange` via `AppState.refreshFreshness`. Un
  /// `MAX` par sourate (ancien besoin de `lastRevisionDatesPerSourate`,
  /// supprimée) se dérive trivialement de ce résultat si nécessaire.
  static Future<Map<int, Map<int, DateTime>>> lastRevisionDatesPerVerse(
      {required Riwaya riwaya}) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT surah_id, ayah_id, MAX(date) as last_date FROM ayah_facts '
      'WHERE riwaya = ? AND type = ? AND reach = 1 GROUP BY surah_id, ayah_id',
      [riwaya.name, AyahFactType.revise.name],
    );
    final result = <int, Map<int, DateTime>>{};
    for (final row in rows) {
      final surahId = row['surah_id'] as int;
      result.putIfAbsent(surahId, () => {})[row['ayah_id'] as int] =
          DateTime.parse(row['last_date'] as String);
    }
    return result;
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

  /// Par jour actif (date ISO), les [limit] plus récents : combien de versets
  /// ont été *faits* (`done`) et combien avaient été *proposés* ce jour-là
  /// (`total`, faits ou non). `total` est le dénominateur correct d'un
  /// pourcentage "journée" (`HistoryCard`/`RecapScreen`), à ne pas confondre
  /// avec `config.totalSelectedVerses` (tout le cycle, pas le jour) — bug
  /// identifié en retour TestFlight (2026-09-01) : le récap affichait
  /// `versets faits ce jour / total du cycle`, un pourcentage toujours proche
  /// de 0. Jours actifs uniquement : un jour où rien n'a été fait est absent
  /// du résultat plutôt que rendu à 0/N.
  static Future<Map<String, ({int done, int total})>> recentDayVerseStats(
      {int limit = 14, required Riwaya riwaya}) async {
    // Conditional aggregation gives both numbers in one pass.
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT date, COUNT(*) as total, SUM(reach) as done FROM ayah_facts '
      'WHERE riwaya = ? AND type = ? '
      'GROUP BY date HAVING done > 0 ORDER BY date DESC LIMIT ?',
      [riwaya.name, AyahFactType.revise.name, limit],
    );
    return {
      for (final row in rows)
        row['date'] as String: (
          done: (row['done'] as int?) ?? 0,
          total: (row['total'] as int?) ?? 0,
        ),
    };
  }

  /// Revision volume (US-15 Recap): verses revised over the sliding last 7
  /// days, and the weekly average over the last 8 weeks. A verse revised on
  /// two days counts twice, as in [recentDayVerseStats].
  static Future<({int last7Days, int weeklyAverage})> revisionPace(
      DateTime today, Riwaya riwaya) async {
    String dayKey(int offset) =>
        DateTime(today.year, today.month, today.day - offset)
            .toIso8601String()
            .substring(0, 10);
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT SUM(CASE WHEN date >= ? THEN 1 ELSE 0 END) as last7, '
      'COUNT(*) as last56, MIN(date) as first_date FROM ayah_facts '
      'WHERE riwaya = ? AND type = ? AND reach = 1 AND date >= ? AND date <= ?',
      [dayKey(6), riwaya.name, AyahFactType.revise.name, dayKey(55), dayKey(0)],
    );
    final row = rows.first;
    final firstDate = row['first_date'] as String?;
    if (firstDate == null) return (last7Days: 0, weeklyAverage: 0);
    // Divide by the weeks actually covered, not always 8: someone who
    // started 10 days ago would otherwise look slow, against the app's thesis.
    final weeks = ((daysAgo(firstDate, now: today) + 1) / 7).ceil().clamp(1, 8);
    return (
      last7Days: row['last7'] as int,
      weeklyAverage: ((row['last56'] as int) / weeks).round(),
    );
  }
}
