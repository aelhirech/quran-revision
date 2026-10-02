/// `YYYY-MM-DD` key of [date] — the date format of `ayah_facts.date` and of
/// every day-keyed preference.
String dayKey(DateTime date) => date.toIso8601String().substring(0, 10);

/// Whole days from local date [date] (`YYYY-MM-DD`) to [now] (default: the
/// current day): 0 = today, 1 = yesterday. Computed on UTC midnights so a
/// daylight-saving switch (a 23 h or 25 h day) never shifts the count.
int daysAgo(String date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime.parse(date);
  return DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(day.year, day.month, day.day))
      .inDays;
}
