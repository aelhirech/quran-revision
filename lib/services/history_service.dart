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

  /// Nombre de jours consécutifs avec au moins une session (streak)
  static Future<int> currentStreak() async {
    final sessions = await recentSessions(limit: 365);
    if (sessions.isEmpty) return 0;

    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final yesterdayStr = today.subtract(const Duration(days: 1))
        .toIso8601String().substring(0, 10);

    // Le streak ne compte que si on a une session aujourd'hui ou hier
    final dates = sessions.map((s) => s.date.toIso8601String().substring(0, 10)).toSet();
    if (!dates.contains(todayStr) && !dates.contains(yesterdayStr)) return 0;

    int streak = 0;
    DateTime cursor = dates.contains(todayStr)
        ? today
        : today.subtract(const Duration(days: 1));

    while (true) {
      final key = cursor.toIso8601String().substring(0, 10);
      if (!dates.contains(key)) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static Future<int> totalSessionDays() async {
    final db = await _open();
    final result = await db.rawQuery('SELECT COUNT(DISTINCT date) as c FROM sessions');
    return result.first['c'] as int? ?? 0;
  }
}
