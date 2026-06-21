import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/session_record.dart';

class HistoryService {
  static Database? _db;

  static Future<Database> _open() async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'history.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          units_completed INTEGER NOT NULL,
          total_units INTEGER NOT NULL,
          prayers TEXT NOT NULL
        )
      '''),
    );
    return _db!;
  }

  static Future<void> recordSession(SessionRecord record) async {
    final db = await _open();
    // Une seule entrée par jour
    await db.delete('sessions', where: 'date = ?', whereArgs: [record.toMap()['date']]);
    await db.insert('sessions', record.toMap());
  }

  static Future<List<SessionRecord>> recentSessions({int limit = 30}) async {
    final db = await _open();
    final rows = await db.query('sessions',
        orderBy: 'date DESC', limit: limit);
    return rows.map(SessionRecord.fromMap).toList();
  }

  /// Nombre de jours consécutifs avec au moins une session (streak).
  /// Les [pauseDates] (YYYY-MM-DD) sont ignorées sans casser la série.
  static Future<int> currentStreak({Set<String> pauseDates = const {}}) async {
    final sessions = await recentSessions(limit: 365);
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

  static Future<int> totalSessionDays() async {
    final db = await _open();
    final result = await db.rawQuery('SELECT COUNT(DISTINCT date) as c FROM sessions');
    return result.first['c'] as int? ?? 0;
  }

  /// Moyenne des unités complétées par session sur les [lastN] dernières sessions.
  /// Retourne 0.0 si aucune session disponible.
  static Future<double> avgUnitsPerDay({int lastN = 14}) async {
    final sessions = await recentSessions(limit: lastN);
    if (sessions.isEmpty) return 0.0;
    final total = sessions.fold(0, (sum, s) => sum + s.unitsCompleted);
    return total / sessions.length;
  }
}
