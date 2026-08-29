import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/riwaya.dart';
import '../models/session_record.dart';

/// Historique de révision — un parcours indépendant par riwaya (Hafs et
/// Warsh ont chacun leur propre streak/historique, voir [Riwaya]).
class HistoryService {
  static Database? _db;

  static Future<Database> _open() async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'history.db'),
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            units_completed INTEGER NOT NULL,
            total_units INTEGER NOT NULL,
            prayers TEXT NOT NULL,
            riwaya TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sourate_sessions (
            date TEXT NOT NULL,
            sourate_id INTEGER NOT NULL,
            riwaya TEXT NOT NULL,
            PRIMARY KEY (date, sourate_id, riwaya)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sourate_sessions (
              date TEXT NOT NULL,
              sourate_id INTEGER NOT NULL,
              PRIMARY KEY (date, sourate_id)
            )
          ''');
        }
        if (oldVersion < 3) {
          // Hafs et Warsh deviennent deux parcours indépendants — l'historique
          // existant était implicitement Hafs (Warsh n'était qu'un affichage
          // alternatif du même texte avant ce changement).
          await db.execute(
              "ALTER TABLE sessions ADD COLUMN riwaya TEXT NOT NULL DEFAULT 'hafs'");
          await db.execute('''
            CREATE TABLE sourate_sessions_new (
              date TEXT NOT NULL,
              sourate_id INTEGER NOT NULL,
              riwaya TEXT NOT NULL,
              PRIMARY KEY (date, sourate_id, riwaya)
            )
          ''');
          await db.execute('''
            INSERT INTO sourate_sessions_new (date, sourate_id, riwaya)
            SELECT date, sourate_id, 'hafs' FROM sourate_sessions
          ''');
          await db.execute('DROP TABLE sourate_sessions');
          await db.execute(
              'ALTER TABLE sourate_sessions_new RENAME TO sourate_sessions');
        }
      },
    );
    return _db!;
  }

  static Future<void> recordSession(SessionRecord record, Riwaya riwaya) async {
    final db = await _open();
    final map = record.toMap();
    // Une seule entrée par (jour, riwaya)
    await db.delete('sessions',
        where: 'date = ? AND riwaya = ?', whereArgs: [map['date'], riwaya.name]);
    await db.insert('sessions', {...map, 'riwaya': riwaya.name});
  }

  static Future<List<SessionRecord>> recentSessions(
      {int limit = 30, required Riwaya riwaya}) async {
    final db = await _open();
    final rows = await db.query('sessions',
        where: 'riwaya = ?',
        whereArgs: [riwaya.name],
        orderBy: 'date DESC',
        limit: limit);
    return rows.map(SessionRecord.fromMap).toList();
  }

  /// Nombre de jours consécutifs avec au moins une session (streak).
  /// Les [pauseDates] (YYYY-MM-DD) sont ignorées sans casser la série.
  static Future<int> currentStreak(
      {Set<String> pauseDates = const {}, required Riwaya riwaya}) async {
    final sessions = await recentSessions(limit: 365, riwaya: riwaya);
    if (sessions.isEmpty) return 0;

    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final yesterdayStr = today
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    final dates =
        sessions.map((s) => s.date.toIso8601String().substring(0, 10)).toSet();

    // Le streak est vivant si aujourd'hui a une session, est en pause,
    // ou si hier a une session.
    final canStart = dates.contains(todayStr) ||
        pauseDates.contains(todayStr) ||
        dates.contains(yesterdayStr);
    if (!canStart) return 0;

    int streak = 0;
    int skippedInARow = 0;
    DateTime cursor = today;

    // On remonte jour par jour : les jours de pause sont sautés (cap à 30 d'affilée)
    while (skippedInARow < 30) {
      final key = cursor.toIso8601String().substring(0, 10);
      if (dates.contains(key)) {
        streak++;
        skippedInARow = 0;
      } else if (pauseDates.contains(key)) {
        skippedInARow++;
      } else {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static Future<int> totalSessionDays({required Riwaya riwaya}) async {
    final db = await _open();
    final result = await db.rawQuery(
        'SELECT COUNT(DISTINCT date) as c FROM sessions WHERE riwaya = ?',
        [riwaya.name]);
    return result.first['c'] as int? ?? 0;
  }

  /// Enregistre quelles sourates ont été révisées lors d'une session.
  /// Une seule entrée par (date, sourate_id, riwaya) — idempotent grâce à PRIMARY KEY.
  static Future<void> recordSourateHistory(
      String date, List<int> sourateIds, Riwaya riwaya) async {
    if (sourateIds.isEmpty) return;
    final db = await _open();
    final batch = db.batch();
    for (final id in sourateIds) {
      batch.insert(
        'sourate_sessions',
        {'date': date, 'sourate_id': id, 'riwaya': riwaya.name},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Retourne la dernière date de révision par sourate, pour la riwaya donnée.
  /// Sourates jamais révisées sont absentes du résultat.
  static Future<Map<int, DateTime>> lastRevisionDates(
      {required Riwaya riwaya}) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT sourate_id, MAX(date) as last_date FROM sourate_sessions '
      'WHERE riwaya = ? GROUP BY sourate_id',
      [riwaya.name],
    );
    return {
      for (final row in rows)
        row['sourate_id'] as int: DateTime.parse(row['last_date'] as String),
    };
  }

  /// Moyenne des unités complétées par session sur les [lastN] dernières sessions.
  /// Retourne 0.0 si aucune session disponible.
  static Future<double> avgUnitsPerDay(
      {int lastN = 14, required Riwaya riwaya}) async {
    final sessions = await recentSessions(limit: lastN, riwaya: riwaya);
    if (sessions.isEmpty) return 0.0;
    final total = sessions.fold(0, (sum, s) => sum + s.unitsCompleted);
    return total / sessions.length;
  }
}
