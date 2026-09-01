import 'dart:math';

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
/// ('revise'|'learn').
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
  /// derniers jours actifs les plus récents — pour `avgVersesPerDay`
  /// (moyenne sur jours actifs uniquement).
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

  /// Comme [recentDayVerseCounts], mais avec en plus le total de versets
  /// *proposés* ce jour-là (faits + pas faits) — dénominateur correct pour
  /// un pourcentage "journée" (`HistoryCard`/`RecapScreen`), à ne pas
  /// confondre avec `config.totalSelectedVerses` (tout le cycle, pas le
  /// jour) — bug identifié en retour TestFlight (2026-09-01) : le récap
  /// affichait `versets faits ce jour / total du cycle`, un pourcentage
  /// toujours proche de 0.
  static Future<Map<String, ({int done, int total})>> recentDayVerseStats(
      {int limit = 14, required Riwaya riwaya}) async {
    final done = await recentDayVerseCounts(limit: limit, riwaya: riwaya);
    if (done.isEmpty) return {};
    final db = await _open();
    final placeholders = List.filled(done.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT date, COUNT(*) as c FROM ayah_facts '
      'WHERE riwaya = ? AND type = ? AND date IN ($placeholders) '
      'GROUP BY date',
      [riwaya.name, AyahFactType.revise.name, ...done.keys],
    );
    final totals = {for (final row in rows) row['date'] as String: row['c'] as int};
    return {
      for (final date in done.keys)
        date: (done: done[date]!, total: totals[date] ?? done[date]!),
    };
  }

  // --- Apprentissage ---

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
  /// Utilisé par `LearnScreen`/`RecapScreen`.
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

  // --- Rituel check-in/check-out (Phase 6 Sprint 2) ---

  /// Date la plus ancienne, STRICTEMENT avant aujourd'hui, dont le jour de
  /// révision n'est pas encore scellé (`checked_out = 0`), ou `null` si
  /// aucune. Sert à geter le moteur quotidien : tant qu'un jour est en
  /// attente, on ne génère pas le plan du jour suivant — `cyclePosition`
  /// n'a pas encore avancé pour ce jour-là, un nouveau plan proposerait les
  /// mêmes versets une seconde fois. Le filtre `date < aujourd'hui` est
  /// nécessaire : sans lui, le plan du jour tout juste proposé (encore
  /// `checked_out = 0` puisque non scellé) se compterait lui-même comme "en
  /// attente" — un jour non check-outé reste modifiable jusqu'au soir, ce
  /// n'est pas un rattrapage (voir cadrage, "Verrouillage").
  static Future<String?> pendingDate({required Riwaya riwaya}) async {
    final db = await _open();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      'SELECT MIN(date) as d FROM ayah_facts '
      'WHERE riwaya = ? AND type = ? AND checked_out = 0 AND date < ?',
      [riwaya.name, AyahFactType.revise.name, today],
    );
    return rows.first['d'] as String?;
  }

  /// Écrit des unités de révision comme proposition du jour — `reach = 0,
  /// checked_out = 0`, pas encore confirmées. Utilisé à la fois par le
  /// moteur quotidien (plan initial) et par le check-in (ajout manuel d'une
  /// sourate/portion) : même écriture. [ConflictAlgorithm.ignore] — pas
  /// `replace` — la rend idempotente SANS écraser un `reach`/`cold` déjà
  /// posé sur un verset qui y figurait déjà (ex. deux appels concurrents à
  /// `ensureDayPlan`, ou un ré-ajout d'un verset déjà coché) ; `replace`
  /// remettrait silencieusement ces colonnes à leurs valeurs par défaut.
  static Future<void> proposeUnits(
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
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Retire une sourate/portion du plan du jour (check-in, bouton "×").
  static Future<void> removeFromDayPlan(
      String date, Riwaya riwaya, int surahId,
      {int? verseStart, int? verseEnd}) async {
    final db = await _open();
    if (verseStart == null || verseEnd == null) {
      await db.delete('ayah_facts',
          where: 'date = ? AND riwaya = ? AND surah_id = ? AND type = ?',
          whereArgs: [date, riwaya.name, surahId, AyahFactType.revise.name]);
    } else {
      await db.delete('ayah_facts',
          where:
              'date = ? AND riwaya = ? AND surah_id = ? AND ayah_id BETWEEN ? AND ? AND type = ?',
          whereArgs: [
            date,
            riwaya.name,
            surahId,
            verseStart,
            verseEnd,
            AyahFactType.revise.name
          ]);
    }
  }

  /// Comme [setReach], mais pour plusieurs unités en un seul aller-retour
  /// SQLite (`db.batch()`) — utilisé quand une manche PlanScreen complétée
  /// couvre plusieurs sourates/portions d'un coup (voir
  /// `AppState.markUnitsReached`).
  static Future<void> setReachForUnits(
      String date, Riwaya riwaya, List<RevisionUnit> units, bool reach) async {
    if (units.isEmpty) return;
    final db = await _open();
    final batch = db.batch();
    for (final unit in units) {
      batch.update('ayah_facts', {'reach': reach ? 1 : 0},
          where:
              'date = ? AND riwaya = ? AND surah_id = ? AND ayah_id BETWEEN ? AND ? AND type = ?',
          whereArgs: [
            date,
            riwaya.name,
            unit.sourate.id,
            unit.verseStart,
            unit.verseEnd,
            AyahFactType.revise.name
          ]);
    }
    await batch.commit(noResult: true);
  }

  /// Bascule `reach` ("fait"/"pas fait") pour une plage de versets — case à
  /// cocher du check-out, ou une rakaa cochée dans PlanScreen.
  static Future<void> setReach(String date, Riwaya riwaya, int surahId,
      int verseStart, int verseEnd, bool reach) async {
    final db = await _open();
    await db.update('ayah_facts', {'reach': reach ? 1 : 0},
        where:
            'date = ? AND riwaya = ? AND surah_id = ? AND ayah_id BETWEEN ? AND ? AND type = ?',
        whereArgs: [
          date,
          riwaya.name,
          surahId,
          verseStart,
          verseEnd,
          AyahFactType.revise.name
        ]);
  }

  /// Bascule `cold` ("à retravailler") pour un verset précis — écran détail
  /// du check-out, granularité verset (pas la sourate entière).
  static Future<void> setCold(String date, Riwaya riwaya, int surahId,
      int ayahId, bool cold) async {
    final db = await _open();
    await db.update('ayah_facts', {'cold': cold ? 1 : 0},
        where: 'date = ? AND riwaya = ? AND surah_id = ? AND ayah_id = ? AND type = ?',
        whereArgs: [date, riwaya.name, surahId, ayahId, AyahFactType.revise.name]);
  }

  /// `true` si tous les versets de la plage ont `reach = 1` ce jour-là —
  /// sert à AppState.checkOut pour compter combien des unités proposées par
  /// le moteur ont réellement été faites (voir doc de `checkOut`). `false`
  /// aussi bien si rien n'est fait que si la plage a été entièrement retirée
  /// au check-in ([removeFromDayPlan]) — voir [rangeExists] pour distinguer
  /// les deux.
  static Future<bool> isRangeReached(String date, Riwaya riwaya, int surahId,
      int verseStart, int verseEnd) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as total, SUM(reach) as reached FROM ayah_facts '
      'WHERE date = ? AND riwaya = ? AND surah_id = ? AND ayah_id BETWEEN ? AND ? AND type = ?',
      [date, riwaya.name, surahId, verseStart, verseEnd, AyahFactType.revise.name],
    );
    final total = rows.first['total'] as int? ?? 0;
    final reached = rows.first['reached'] as int? ?? 0;
    return total > 0 && total == reached;
  }

  /// `true` s'il reste au moins une ligne pour cette plage ce jour-là.
  /// Sert à AppState.checkOut à distinguer "retiré au check-in" (aucune
  /// ligne — à ignorer, pas un blocage) de "pas encore fait" (des lignes
  /// existent mais `reach = 0` — bloque le comptage, voir [isRangeReached]).
  static Future<bool> rangeExists(String date, Riwaya riwaya, int surahId,
      int verseStart, int verseEnd) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as total FROM ayah_facts '
      'WHERE date = ? AND riwaya = ? AND surah_id = ? AND ayah_id BETWEEN ? AND ? AND type = ?',
      [date, riwaya.name, surahId, verseStart, verseEnd, AyahFactType.revise.name],
    );
    return (rows.first['total'] as int? ?? 0) > 0;
  }

  /// Scelle une journée : `checked_out = 1` pour toutes ses lignes de
  /// révision. `reach`/`cold` doivent déjà être à jour (voir
  /// [setReach]/[setCold], appliqués au fil des interactions du check-out) —
  /// chaque bascule précédente est déjà durablement écrite, un simple UPDATE
  /// suffit donc ici, pas besoin d'empaqueter reach+cold+checked_out dans une
  /// même transaction.
  static Future<void> sealDay(String date, Riwaya riwaya) async {
    final db = await _open();
    await db.update('ayah_facts', {'checked_out': 1},
        where: 'date = ? AND riwaya = ? AND type = ?',
        whereArgs: [date, riwaya.name, AyahFactType.revise.name]);
  }

  /// Reconstruit le plan du jour en lignes groupées par sourate — une entrée
  /// par plage contiguë de versets écrite ce jour-là (`DayFactGroup`), pour
  /// l'affichage check-in/check-out et PlanScreen. Groupe en Dart plutôt
  /// qu'en SQL (même précédent que `learnedVersesBySourate`).
  static Future<List<DayFactGroup>> dayFacts(
      String date, Riwaya riwaya) async {
    final db = await _open();
    final rows = await db.query('ayah_facts',
        columns: ['surah_id', 'ayah_id', 'reach', 'cold'],
        where: 'date = ? AND riwaya = ? AND type = ?',
        whereArgs: [date, riwaya.name, AyahFactType.revise.name],
        orderBy: 'surah_id, ayah_id');
    final bySourate = <int, List<Map<String, Object?>>>{};
    for (final row in rows) {
      bySourate.putIfAbsent(row['surah_id'] as int, () => []).add(row);
    }
    return [
      for (final entry in bySourate.entries)
        DayFactGroup(
          surahId: entry.key,
          verseStart: entry.value.map((r) => r['ayah_id'] as int).reduce(min),
          verseEnd: entry.value.map((r) => r['ayah_id'] as int).reduce(max),
          reach: entry.value.every((r) => (r['reach'] as int) == 1),
          coldVerses: {
            for (final r in entry.value)
              if ((r['cold'] as int) == 1) r['ayah_id'] as int,
          },
        ),
    ];
  }
}

/// Une sourate/portion du plan du jour, reconstruite depuis `ayah_facts`
/// (voir [AyahFactsService.dayFacts]) — pas un objet persisté séparément.
class DayFactGroup {
  final int surahId;
  final int verseStart;
  final int verseEnd;
  final bool reach; // true seulement si toute la plage est reach=1
  final Set<int> coldVerses;

  const DayFactGroup({
    required this.surahId,
    required this.verseStart,
    required this.verseEnd,
    required this.reach,
    required this.coldVerses,
  });
}
