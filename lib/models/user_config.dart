import 'sourate.dart';

class UserConfig {
  final List<Sourate> learnedSourates;
  final int revisionDays;
  final DateTime startDate;
  final bool shuffleEnabled;
  final int? versesPerDay;

  const UserConfig({
    required this.learnedSourates,
    required this.revisionDays,
    required this.startDate,
    this.shuffleEnabled = true,
    this.versesPerDay,
  });

  /// Jours effectifs : calculé depuis versesPerDay si disponible, sinon revisionDays.
  int effectiveDays(int totalVerses) {
    if (versesPerDay != null && versesPerDay! > 0) {
      return (totalVerses / versesPerDay!).ceil().clamp(1, 9999);
    }
    return revisionDays;
  }

  UserConfig copyWith({
    List<Sourate>? learnedSourates,
    int? revisionDays,
    DateTime? startDate,
    bool? shuffleEnabled,
    int? versesPerDay,
    bool clearVersesPerDay = false,
  }) =>
      UserConfig(
        learnedSourates: learnedSourates ?? this.learnedSourates,
        revisionDays: revisionDays ?? this.revisionDays,
        startDate: startDate ?? this.startDate,
        shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
        versesPerDay: clearVersesPerDay ? null : (versesPerDay ?? this.versesPerDay),
      );

  Map<String, dynamic> toJson() => {
        'learnedSourates': learnedSourates.map((s) => s.toJson()).toList(),
        'revisionDays': revisionDays,
        'startDate': startDate.toIso8601String(),
        'shuffleEnabled': shuffleEnabled,
        'versesPerDay': versesPerDay,
      };

  factory UserConfig.fromJson(Map<String, dynamic> j) {
    try {
      return UserConfig(
        learnedSourates: (j['learnedSourates'] as List? ?? [])
            .map((s) => Sourate.fromJson(s as Map<String, dynamic>))
            .toList(),
        revisionDays: j['revisionDays'] as int? ?? 30,
        startDate:
            DateTime.tryParse(j['startDate'] as String? ?? '') ?? DateTime.now(),
        shuffleEnabled: j['shuffleEnabled'] as bool? ?? true,
        versesPerDay: j['versesPerDay'] as int?,
      );
    } catch (_) {
      return UserConfig(
          learnedSourates: const [], revisionDays: 30, startDate: DateTime.now());
    }
  }
}
