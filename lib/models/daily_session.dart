import 'prayer.dart';
import 'revision_unit.dart';

class RakaaAssignment {
  final int rakaaNumber;
  final RevisionUnit? unit; // null = Al-Fatiha uniquement

  const RakaaAssignment({required this.rakaaNumber, this.unit});

  Map<String, dynamic> toJson() => {
        'rakaaNumber': rakaaNumber,
        'unit': unit?.toJson(),
      };

  factory RakaaAssignment.fromJson(Map<String, dynamic> j) => RakaaAssignment(
        rakaaNumber: j['rakaaNumber'] as int,
        unit: j['unit'] == null
            ? null
            : RevisionUnit.fromJson(j['unit'] as Map<String, dynamic>),
      );
}

class PrayerPlan {
  final Prayer prayer;
  final List<RakaaAssignment> rakaas;

  const PrayerPlan({required this.prayer, required this.rakaas});

  Map<String, dynamic> toJson() => {
        'prayer': prayer.name,
        'rakaas': rakaas.map((r) => r.toJson()).toList(),
      };

  factory PrayerPlan.fromJson(Map<String, dynamic> j) => PrayerPlan(
        prayer: Prayer.values.byName(j['prayer'] as String),
        rakaas: (j['rakaas'] as List)
            .map((r) => RakaaAssignment.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

class DailySession {
  final DateTime date;
  final List<Prayer> prayersAlone;
  final List<PrayerPlan> plan;
  final int totalUnits;
  final int cyclePosition;
  final int cycleTotal;
  final int daysRemaining;

  const DailySession({
    required this.date,
    required this.prayersAlone,
    required this.plan,
    required this.totalUnits,
    required this.cyclePosition,
    required this.cycleTotal,
    required this.daysRemaining,
  });

  int get totalRakaas =>
      prayersAlone.fold(0, (sum, p) => sum + p.rakaas);

  double get cycleProgress => cycleTotal == 0 ? 0 : cyclePosition / cycleTotal;

  bool get isOnTrack {
    if (daysRemaining <= 0) return false;
    final needed = (cycleTotal - cyclePosition) / daysRemaining;
    return totalUnits >= needed;
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'prayersAlone': prayersAlone.map((p) => p.name).toList(),
        'plan': plan.map((p) => p.toJson()).toList(),
        'totalUnits': totalUnits,
        'cyclePosition': cyclePosition,
        'cycleTotal': cycleTotal,
        'daysRemaining': daysRemaining,
      };

  factory DailySession.fromJson(Map<String, dynamic> j) => DailySession(
        date: DateTime.parse(j['date'] as String),
        prayersAlone: (j['prayersAlone'] as List)
            .map((p) => Prayer.values.byName(p as String))
            .toList(),
        plan: (j['plan'] as List)
            .map((p) => PrayerPlan.fromJson(p as Map<String, dynamic>))
            .toList(),
        totalUnits: j['totalUnits'] as int,
        cyclePosition: j['cyclePosition'] as int,
        cycleTotal: j['cycleTotal'] as int,
        daysRemaining: j['daysRemaining'] as int,
      );
}
