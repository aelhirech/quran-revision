import 'sourate.dart';

class UserConfig {
  final List<Sourate> learnedSourates;
  final int revisionDays;
  final DateTime startDate;

  const UserConfig({
    required this.learnedSourates,
    required this.revisionDays,
    required this.startDate,
  });

  Map<String, dynamic> toJson() => {
        'learnedSourates': learnedSourates.map((s) => s.toJson()).toList(),
        'revisionDays': revisionDays,
        'startDate': startDate.toIso8601String(),
      };

  factory UserConfig.fromJson(Map<String, dynamic> j) => UserConfig(
        learnedSourates: (j['learnedSourates'] as List)
            .map((s) => Sourate.fromJson(s))
            .toList(),
        revisionDays: j['revisionDays'],
        startDate: DateTime.parse(j['startDate']),
      );
}
