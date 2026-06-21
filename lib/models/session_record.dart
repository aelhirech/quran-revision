class SessionRecord {
  final int? id;
  final DateTime date;
  final int unitsCompleted;
  final int totalUnits;
  final List<String> prayers; // prayer names

  const SessionRecord({
    this.id,
    required this.date,
    required this.unitsCompleted,
    required this.totalUnits,
    required this.prayers,
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String().substring(0, 10), // YYYY-MM-DD
        'units_completed': unitsCompleted,
        'total_units': totalUnits,
        'prayers': prayers.join(','),
      };

  factory SessionRecord.fromMap(Map<String, dynamic> m) => SessionRecord(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        unitsCompleted: m['units_completed'] as int,
        totalUnits: m['total_units'] as int,
        prayers: (m['prayers'] as String).split(','),
      );
}
