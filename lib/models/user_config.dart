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

  factory UserConfig.fromJson(Map<String, dynamic> j) {
    try {
      return UserConfig(
        learnedSourates: (j['learnedSourates'] as List? ?? [])
            .map((s) => Sourate.fromJson(s as Map<String, dynamic>))
            .toList(),
        revisionDays: j['revisionDays'] as int? ?? 30,
        startDate: DateTime.tryParse(j['startDate'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return UserConfig(learnedSourates: const [], revisionDays: 30, startDate: DateTime.now());
    }
  }
}
