// Calcul du streak (jours consécutifs d'activité) — module pur, extrait de
// l'ancien HistoryService.currentStreak pour rester testable sans SQLite et
// réutilisable par AyahFactsService.

class StreakEngine {
  /// Nombre de jours consécutifs avec au moins une activité, en remontant
  /// depuis aujourd'hui. Les [pauseDates] (YYYY-MM-DD) sont ignorées sans
  /// casser la série. [activeDates] et [pauseDates] sont au format YYYY-MM-DD.
  static int compute({
    required Set<String> activeDates,
    required Set<String> pauseDates,
    required DateTime today,
  }) {
    if (activeDates.isEmpty) return 0;

    final todayStr = today.toIso8601String().substring(0, 10);
    final yesterdayStr = today
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    // Le streak est vivant si aujourd'hui a une activité, est en pause,
    // ou si hier a une activité.
    final canStart = activeDates.contains(todayStr) ||
        pauseDates.contains(todayStr) ||
        activeDates.contains(yesterdayStr);
    if (!canStart) return 0;

    int streak = 0;
    int skippedInARow = 0;
    DateTime cursor = today;

    // On remonte jour par jour : les jours de pause sont sautés (cap à 30 d'affilée)
    while (skippedInARow < 30) {
      final key = cursor.toIso8601String().substring(0, 10);
      if (activeDates.contains(key)) {
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
}
