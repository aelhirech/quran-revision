import 'package:flutter/foundation.dart';
import 'riwaya.dart';
import 'sourate.dart';
import 'sourate_selection.dart';

/// Valeurs prédéfinies proposées dans les dropdowns de rythme (profil +
/// onboarding) — un "Personnalisé…" permet toujours de saisir une valeur libre.
const List<int> durationPresets = [7, 14, 21, 30, 60, 90, 180, 365];
const List<int> linesPerDayPresets = [5, 10, 15, 20, 30, 40, 60];

class UserConfig {
  final List<SourateSelection> selections;
  final int revisionDays;
  final DateTime startDate;
  final bool shuffleEnabled;
  final bool adaptiveCycle;
  final bool paceByLines;
  final int targetLinesPerDay;
  final Riwaya riwaya;

  const UserConfig({
    required this.selections,
    required this.revisionDays,
    required this.startDate,
    this.shuffleEnabled = true,
    this.adaptiveCycle = false,
    this.paceByLines = false,
    this.targetLinesPerDay = 15,
    this.riwaya = Riwaya.hafs,
  });

  List<Sourate> get learnedSourates => selections.map((s) => s.sourate).toList();

  int get totalSelectedVerses =>
      selections.fold(0, (sum, s) => sum + s.verseCount);

  // Révision intelligente uniquement — le cycle est toujours basé sur revisionDays.
  int effectiveDays(int totalVerses) => revisionDays;

  UserConfig copyWith({
    List<SourateSelection>? selections,
    int? revisionDays,
    DateTime? startDate,
    bool? shuffleEnabled,
    bool? adaptiveCycle,
    bool? paceByLines,
    int? targetLinesPerDay,
    Riwaya? riwaya,
  }) =>
      UserConfig(
        selections: selections ?? this.selections,
        revisionDays: revisionDays ?? this.revisionDays,
        startDate: startDate ?? this.startDate,
        shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
        adaptiveCycle: adaptiveCycle ?? this.adaptiveCycle,
        paceByLines: paceByLines ?? this.paceByLines,
        targetLinesPerDay: targetLinesPerDay ?? this.targetLinesPerDay,
        riwaya: riwaya ?? this.riwaya,
      );

  Map<String, dynamic> toJson() => {
        'selections': selections.map((s) => s.toJson()).toList(),
        'revisionDays': revisionDays,
        'startDate': startDate.toIso8601String(),
        'shuffleEnabled': shuffleEnabled,
        'adaptiveCycle': adaptiveCycle,
        'paceByLines': paceByLines,
        'targetLinesPerDay': targetLinesPerDay,
        'riwaya': riwaya.name,
      };

  factory UserConfig.fromJson(Map<String, dynamic> j) {
    try {
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
        adaptiveCycle: j['adaptiveCycle'] as bool? ?? false,
        paceByLines: j['paceByLines'] as bool? ?? false,
        targetLinesPerDay: j['targetLinesPerDay'] as int? ?? 15,
        riwaya: Riwaya.values.firstWhere(
            (r) => r.name == j['riwaya'],
            orElse: () => Riwaya.hafs),
      );
    } catch (e) {
      assert(() {
        debugPrint('[UserConfig] fromJson error: $e');
        return true;
      }());
      return UserConfig(
          selections: const [], revisionDays: 30, startDate: DateTime.now());
    }
  }
}
