import 'package:flutter/foundation.dart';
import 'sourate.dart';
import 'sourate_selection.dart';

class UserConfig {
  final List<SourateSelection> selections;
  final int revisionDays;
  final DateTime startDate;
  final bool shuffleEnabled;
  final int? versesPerDay;
  final bool adaptiveCycle;

  const UserConfig({
    required this.selections,
    required this.revisionDays,
    required this.startDate,
    this.shuffleEnabled = true,
    this.versesPerDay,
    this.adaptiveCycle = false,
  });

  /// Compatibilité : liste des sourates entières sélectionnées.
  List<Sourate> get learnedSourates => selections.map((s) => s.sourate).toList();

  int get totalSelectedVerses =>
      selections.fold(0, (sum, s) => sum + s.verseCount);

  int effectiveDays(int totalVerses) {
    if (versesPerDay != null && versesPerDay! > 0) {
      return (totalVerses / versesPerDay!).ceil().clamp(1, 9999);
    }
    return revisionDays;
  }

  UserConfig copyWith({
    List<SourateSelection>? selections,
    int? revisionDays,
    DateTime? startDate,
    bool? shuffleEnabled,
    int? versesPerDay,
    bool clearVersesPerDay = false,
    bool? adaptiveCycle,
  }) =>
      UserConfig(
        selections: selections ?? this.selections,
        revisionDays: revisionDays ?? this.revisionDays,
        startDate: startDate ?? this.startDate,
        shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
        versesPerDay:
            clearVersesPerDay ? null : (versesPerDay ?? this.versesPerDay),
        adaptiveCycle: adaptiveCycle ?? this.adaptiveCycle,
      );

  Map<String, dynamic> toJson() => {
        'selections': selections.map((s) => s.toJson()).toList(),
        'revisionDays': revisionDays,
        'startDate': startDate.toIso8601String(),
        'shuffleEnabled': shuffleEnabled,
        'versesPerDay': versesPerDay,
        'adaptiveCycle': adaptiveCycle,
      };

  factory UserConfig.fromJson(Map<String, dynamic> j) {
    try {
      // Rétrocompatibilité : ancien format avec learnedSourates
      List<SourateSelection> selections;
      if (j.containsKey('selections')) {
        selections = (j['selections'] as List)
            .map((s) => SourateSelection.fromJson(s as Map<String, dynamic>))
            .toList();
      } else {
        selections = (j['learnedSourates'] as List? ?? [])
            .map((s) => SourateSelection.whole(
                Sourate.fromJson(s as Map<String, dynamic>)))
            .toList();
      }
      return UserConfig(
        selections: selections,
        revisionDays: j['revisionDays'] as int? ?? 30,
        startDate:
            DateTime.tryParse(j['startDate'] as String? ?? '') ?? DateTime.now(),
        shuffleEnabled: j['shuffleEnabled'] as bool? ?? true,
        versesPerDay: j['versesPerDay'] as int?,
        adaptiveCycle: j['adaptiveCycle'] as bool? ?? false,
      );
    } catch (e) {
      // Retour à une config vide plutôt qu'un crash. Le log permet de détecter
      // un bug de parsing sans impacter l'utilisateur.
      assert(() { debugPrint('[UserConfig] fromJson error: $e'); return true; }());
      return UserConfig(
          selections: const [], revisionDays: 30, startDate: DateTime.now());
    }
  }
}
