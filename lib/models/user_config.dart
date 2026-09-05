import 'package:flutter/foundation.dart';
import 'riwaya.dart';
import 'sourate.dart';
import 'sourate_selection.dart';

/// Valeurs prédéfinies proposées dans les dropdowns de rythme (profil +
/// onboarding) — un "Personnalisé…" permet toujours de saisir une valeur libre.
const List<int> pagesPerDayPresets = [1, 2, 3, 4, 5];

class UserConfig {
  final List<SourateSelection> selections;
  final int pagesPerDay;
  final DateTime startDate;
  final bool shuffleEnabled;
  final bool adaptiveCycle;
  final Riwaya riwaya;

  const UserConfig({
    required this.selections,
    required this.pagesPerDay,
    required this.startDate,
    this.shuffleEnabled = true,
    this.adaptiveCycle = false,
    this.riwaya = Riwaya.hafs,
  });

  int get totalSelectedVerses =>
      selections.fold(0, (sum, s) => sum + s.verseCount);

  UserConfig copyWith({
    List<SourateSelection>? selections,
    int? pagesPerDay,
    DateTime? startDate,
    bool? shuffleEnabled,
    bool? adaptiveCycle,
    Riwaya? riwaya,
  }) =>
      UserConfig(
        selections: selections ?? this.selections,
        pagesPerDay: pagesPerDay ?? this.pagesPerDay,
        startDate: startDate ?? this.startDate,
        shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
        adaptiveCycle: adaptiveCycle ?? this.adaptiveCycle,
        riwaya: riwaya ?? this.riwaya,
      );

  Map<String, dynamic> toJson() => {
        'selections': selections.map((s) => s.toJson()).toList(),
        'pagesPerDay': pagesPerDay,
        'startDate': startDate.toIso8601String(),
        'shuffleEnabled': shuffleEnabled,
        'adaptiveCycle': adaptiveCycle,
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
        pagesPerDay: j['pagesPerDay'] as int? ?? 1,
        startDate:
            DateTime.tryParse(j['startDate'] as String? ?? '') ?? DateTime.now(),
        shuffleEnabled: j['shuffleEnabled'] as bool? ?? true,
        adaptiveCycle: j['adaptiveCycle'] as bool? ?? false,
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
          selections: const [], pagesPerDay: 1, startDate: DateTime.now());
    }
  }
}
