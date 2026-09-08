import 'package:flutter/foundation.dart';
import 'riwaya.dart';
import 'sourate.dart';
import 'sourate_selection.dart';

/// Valeurs prédéfinies proposées dans les dropdowns de rythme (profil +
/// onboarding) — un "Personnalisé…" permet toujours de saisir une valeur libre.
const List<int> pagesPerDayPresets = [1, 2, 3, 4, 5];

/// Valeurs prédéfinies pour « combien de versets j'apprends aujourd'hui » —
/// pré-remplissage du check-in (« Illuminer ma journée »).
const List<int> versesToLearnPresets = [1, 3, 5, 10];

/// Défaut de [UserConfig.versesToLearnPerDay], nommé plutôt que répété en
/// littéral partout où une config peut être absente.
const int defaultVersesToLearnPerDay = 3;

class UserConfig {
  final List<SourateSelection> selections;
  final int pagesPerDay;

  /// Défaut proposé au check-in pour le nombre de versets à apprendre dans
  /// la journée. La valeur réellement retenue un jour donné vit dans
  /// `ayah_facts` (lignes `type='learn'` datées), pas ici — ce champ n'est
  /// qu'un pré-remplissage, comme [pagesPerDay] l'est pour la révision.
  final int versesToLearnPerDay;
  final DateTime startDate;
  final bool shuffleEnabled;
  final Riwaya riwaya;

  const UserConfig({
    required this.selections,
    required this.pagesPerDay,
    this.versesToLearnPerDay = defaultVersesToLearnPerDay,
    required this.startDate,
    this.shuffleEnabled = true,
    this.riwaya = Riwaya.hafs,
  });

  int get totalSelectedVerses =>
      selections.fold(0, (sum, s) => sum + s.verseCount);

  UserConfig copyWith({
    List<SourateSelection>? selections,
    int? pagesPerDay,
    int? versesToLearnPerDay,
    DateTime? startDate,
    bool? shuffleEnabled,
    Riwaya? riwaya,
  }) =>
      UserConfig(
        selections: selections ?? this.selections,
        pagesPerDay: pagesPerDay ?? this.pagesPerDay,
        versesToLearnPerDay: versesToLearnPerDay ?? this.versesToLearnPerDay,
        startDate: startDate ?? this.startDate,
        shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
        riwaya: riwaya ?? this.riwaya,
      );

  Map<String, dynamic> toJson() => {
        'selections': selections.map((s) => s.toJson()).toList(),
        'pagesPerDay': pagesPerDay,
        'versesToLearnPerDay': versesToLearnPerDay,
        'startDate': startDate.toIso8601String(),
        'shuffleEnabled': shuffleEnabled,
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
        versesToLearnPerDay:
            j['versesToLearnPerDay'] as int? ?? defaultVersesToLearnPerDay,
        startDate:
            DateTime.tryParse(j['startDate'] as String? ?? '') ?? DateTime.now(),
        shuffleEnabled: j['shuffleEnabled'] as bool? ?? true,
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
