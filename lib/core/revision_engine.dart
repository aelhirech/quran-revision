import 'dart:math' as math;

import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';

/// Résultat de [RevisionEngine.buildDayUnits] — quelles unités composent le
/// plan du jour, avant toute répartition en rakaas. Consommé à la fois par
/// [RevisionEngine.buildDayPlan] (répartition immédiate) et par le moteur
/// quotidien (Phase 6 Sprint 2, qui écrit ces unités dans `ayah_facts` sans
/// les répartir par prière).
class DaySelection {
  /// Une entrée = une seule position de cycle. La plupart du temps un
  /// groupe = 1 sourate = 1 unité, mais plusieurs courtes sourates qui
  /// partagent la même page réelle du mushaf forment un seul groupe de
  /// plusieurs unités (voir cadrage "regroupement par page partagée",
  /// 2026-09-05) : `AppState.checkOut` doit avancer `cyclePosition` par
  /// groupe complété, jamais par unité individuelle, sous peine de
  /// désynchroniser `cyclePosition` de `cycleTotal` (qui compte des groupes).
  final List<List<RevisionUnit>> groups;
  final int cyclePosition; // position normalisée (mod cycleTotal)
  final int cycleTotal;

  const DaySelection({
    required this.groups,
    required this.cyclePosition,
    required this.cycleTotal,
  });

  /// Vue aplatie de [groups] — pour tout consommateur (proposition dans
  /// `ayah_facts`, répartition en rakaas, aperçu check-out) à qui la
  /// frontière entre groupes ne dit rien.
  List<RevisionUnit> get units => [for (final g in groups) ...g];
}

/// Une sourate sélectionnée qui tient sur exactement 1 page réelle du
/// mushaf, avec le numéro de cette page — sert à [_groupSelectionsByPage] à
/// détecter quelles sourates sélectionnées partagent une même page.
class _SinglePageSelection {
  final SourateSelection selection;
  final int page;
  const _SinglePageSelection(this.selection, this.page);
}

/// Regroupe les sourates sélectionnées qui tiennent chacune sur exactement 1
/// page et partagent ce même numéro de page mushaf — l'utilisateur reçoit
/// toutes les sourates de la page en une fois plutôt qu'étalées sur plusieurs
/// jours artificiellement (ex. Al-Kawthar/Al-Ma'un/Quraysh, souvent sur la
/// même page). Ne regroupe jamais une sourate non sélectionnée par
/// l'utilisateur (choix de cadrage 2026-09-05). Fonction pure, indépendante
/// du budget pagesPerDay/de la position de cycle — testable isolément.
List<List<SourateSelection>> _groupSelectionsByPage(
  List<SourateSelection> surahList,
  Map<int, Map<int, int>> pageMetadata,
) {
  _SinglePageSelection? singlePageOf(SourateSelection selection) {
    final pages = pageMetadata[selection.sourate.id]?.values.toSet();
    if (pages == null || pages.length != 1) return null;
    return _SinglePageSelection(selection, pages.first);
  }

  final singlePage = surahList.map(singlePageOf).toList();
  final Map<int, List<int>> pageToIndices = {};
  for (int i = 0; i < surahList.length; i++) {
    final entry = singlePage[i];
    if (entry != null) pageToIndices.putIfAbsent(entry.page, () => []).add(i);
  }

  final Set<int> grouped = {};
  final List<List<SourateSelection>> groups = [];
  for (int i = 0; i < surahList.length; i++) {
    if (grouped.contains(i)) continue;
    final entry = singlePage[i];
    final indices = (entry != null ? pageToIndices[entry.page] : null) ?? [i];
    groups.add([for (final idx in indices) surahList[idx]]);
    grouped.addAll(indices);
  }
  return groups;
}

/// Seuil en-dessous duquel une sous-plage issue de la subdivision d'une unité
/// pour remplir des rakaas n'a plus de sens (voir [RevisionEngine._materialize]).
const double _minLinesPerSlot = 5.0;

class RevisionEngine {
  /// Détermine quelles unités composent le plan du jour basé sur un budget de
  /// pages/jour. Étapes 1-2 de l'ancien `buildDayPlan` monolithique,
  /// extraites pour être réutilisables par le moteur quotidien
  /// indépendamment de l'affichage prière-par-prière. [pageMetadata] (numéro
  /// de page mushaf par sourate/ayah) est un paramètre requis plutôt qu'un
  /// chargement interne — `lib/core/` reste Dart pur, zéro I/O (voir
  /// CLAUDE.md) ; l'appelant le fournit via `PageMetadataService`
  /// (`lib/services/`), qui charge et met en cache les vraies métadonnées.
  static Future<DaySelection> buildDayUnits({
    required UserConfig config,
    required int cyclePosition,
    required DateTime today,
    required Map<int, Map<int, int>> pageMetadata,
  }) async {
    final selections = config.selections;
    final int pagesPerDay = config.pagesPerDay;
    final bool shuffleEnabled = config.shuffleEnabled;

    // Créer la liste des sourates sélectionnées (potentiellement mélangée)
    final List<SourateSelection> surahList = List.from(selections);
    if (shuffleEnabled) {
      surahList.shuffle(math.Random(config.startDate.millisecondsSinceEpoch));
    }

    // Aucune sourate sélectionnée : rien à faire avancer dans le cycle
    if (surahList.isEmpty) {
      return const DaySelection(
        groups: [],
        cyclePosition: 0,
        cycleTotal: 0,
      );
    }

    final List<List<SourateSelection>> groups =
        _groupSelectionsByPage(surahList, pageMetadata);
    final int groupCount = groups.length;

    // Calculer la position actuelle dans le cycle (gérer le dépassement) —
    // indexe les groupes, pas les sourates individuelles.
    final int pos = cyclePosition % groupCount;

    // Accumuler les groupes du jour basé sur le budget de pages
    final List<List<RevisionUnit>> todayGroups = <List<RevisionUnit>>[];
    int remainingPages = pagesPerDay;

    // Parcourir les groupes en commençant par la position actuelle, en
    // enveloppant (retour à l'index 0) si le budget du jour n'est pas épuisé
    // avant la fin de la liste — sinon un budget pagesPerDay non multiple du
    // nombre de pages restantes gaspillerait le reliquat près de la fin du
    // cycle au lieu de continuer depuis le début de la sélection (bug trouvé
    // en revue de code). Borné à `groupCount` tours pour ne jamais reproposer
    // deux fois le même groupe le même jour (budget excédant toute la
    // sélection).
    for (int step = 0; step < groupCount && remainingPages > 0; step++) {
      final int i = (pos + step) % groupCount;
      final List<SourateSelection> group = groups[i];

      if (group.length > 1) {
        // Page partagée entre plusieurs sourates : atomique, coûte 1 page,
        // jamais découpée (par construction chaque membre tient déjà sur
        // cette unique page).
        todayGroups.add([
          for (final selection in group)
            RevisionUnit(
              sourate: selection.sourate,
              verseStart: selection.verseStart,
              verseEnd: selection.verseEnd,
              isWhole: selection.isWhole,
            ),
        ]);
        remainingPages -= 1;
        continue;
      }

      final SourateSelection selection = group.single;
      final Sourate sourate = selection.sourate;
      final Map<int, int>? surahPagesMap = pageMetadata[sourate.id];
      if (surahPagesMap == null || surahPagesMap.isEmpty) {
        // Pas de métadonnées disponibles pour cette sourate : passer à la suivante
        continue;
      }

      // Nombre de pages RÉELLES distinctes occupées par cette sourate — les
      // valeurs de la map sont des numéros de page absolus du mushaf (ex.
      // 601), pas un compte de pages : `reduce(math.max)` retournerait ce
      // numéro absolu et rendrait la branche "tient en entier" quasi
      // inatteignable pour un budget pagesPerDay réaliste (bug trouvé en
      // écrivant les tests de régression du sprint pages/jour).
      final int totalPages = surahPagesMap.values.toSet().length;

      if (remainingPages >= totalPages) {
        // La sourate entière tient dans le budget restant
        todayGroups.add([
          RevisionUnit(
            sourate: sourate,
            verseStart: selection.verseStart,
            verseEnd: selection.verseEnd,
            isWhole: selection.isWhole,
          ),
        ]);
        remainingPages -= totalPages;
      } else {
        // Seulement une partie de la sourate tient dans le budget restant
        // Nous devons calculer quels versets correspondent à remainingPages

        // Créer une map inverse : page -> liste des ayahs
        final Map<int, List<int>> pageToAyahs = <int, List<int>>{};
        surahPagesMap.forEach((int ayah, int page) {
          pageToAyahs.putIfAbsent(page, () => []).add(ayah);
        });

        // Prendre les 'remainingPages' premières pages
        final List<int> takenPages = pageToAyahs.keys.toList()..sort();
        final pagesToKeep = takenPages.take(remainingPages);

        final List<int> ayahsInPages = [
          for (final page in pagesToKeep) ...pageToAyahs[page]!,
        ];

        if (ayahsInPages.isNotEmpty) {
          todayGroups.add([
            RevisionUnit(
              sourate: sourate,
              verseStart: ayahsInPages.reduce(math.min),
              verseEnd: ayahsInPages.reduce(math.max),
              isWhole: false,
            ),
          ]);
        }

        // Le reste de la sourate sera traité demain (on sort de la boucle)
        break;
      }
    }

    return DaySelection(
      groups: todayGroups,
      cyclePosition: pos,
      cycleTotal: groupCount,
    );
  }

  /// Tous les groupes du cycle, dans l'ordre du cycle (shuffle déterministe
  /// puis regroupement par page partagée) — pas seulement ceux qui tiennent
  /// dans le budget d'un jour. `buildDayUnits` en consomme un préfixe à
  /// partir de `cyclePosition` ; `AppState.checkOut` a besoin de la liste
  /// entière pour continuer à compter au-delà de ce qui avait été proposé
  /// quand l'utilisateur déclare en avoir fait plus (cadrage 2026-09-07).
  ///
  /// Un groupe = une position de cycle (voir [DaySelection.groups]).
  static List<List<RevisionUnit>> cycleGroups({
    required UserConfig config,
    required Map<int, Map<int, int>> pageMetadata,
  }) {
    final List<SourateSelection> surahList = List.from(config.selections);
    if (config.shuffleEnabled) {
      surahList.shuffle(math.Random(config.startDate.millisecondsSinceEpoch));
    }
    if (surahList.isEmpty) return const [];
    return [
      for (final group in _groupSelectionsByPage(surahList, pageMetadata))
        [
          for (final selection in group)
            RevisionUnit(
              sourate: selection.sourate,
              verseStart: selection.verseStart,
              verseEnd: selection.verseEnd,
              isWhole: selection.isWhole,
            ),
        ],
    ];
  }

  /// Construit le plan complet du jour (sélection + répartition en rakaas)
  /// en un seul appel — composition pure de [buildDayUnits] +
  /// [distributeToRakaas], sans effet de bord.
  static Future<DailySession> buildDayPlan({
    required UserConfig config,
    required List<Prayer> prayersAlone,
    required int cyclePosition,
    required DateTime today,
    required Map<int, Map<int, int>> pageMetadata,
  }) async {
    final selection = await buildDayUnits(
      config: config,
      cyclePosition: cyclePosition,
      today: today,
      pageMetadata: pageMetadata,
    );
    final plan = distributeToRakaas(
      units: selection.units,
      prayersAlone: prayersAlone,
    );
    return DailySession(
      date: today,
      prayersAlone: prayersAlone,
      plan: plan,
      totalUnits: selection.units.length,
      cyclePosition: selection.cyclePosition,
      cycleTotal: selection.cycleTotal,
    );
  }

  /// Répartit des unités déjà choisies dans les rakaas des prières données —
  /// étapes 3-4 de l'ancien `buildDayPlan` monolithique. Pure : ne dépend que
  /// de ses arguments, réutilisable que les unités viennent de
  /// [buildDayUnits] (nouveau flux) ou des lignes `ayah_facts` déjà
  /// validées au check-in (Phase 6 Sprint 2 — PlanScreen ne génère plus son
  /// propre plan, il répartit celui déjà confirmé).
  /// [learningUnit] (optionnel) — les versets que l'utilisateur veut
  /// *apprendre* aujourd'hui : ils occupent la toute dernière rakaa récitée
  /// de la journée, la révision se répartissant sur les précédentes. Le
  /// budget de rakaas laissé à la révision est donc réduit d'une unité, sans
  /// quoi la dernière portion de révision serait simplement écrasée par
  /// l'apprentissage au lieu d'être redistribuée.
  static List<PrayerPlan> distributeToRakaas({
    required List<RevisionUnit> units,
    required List<Prayer> prayersAlone,
    RevisionUnit? learningUnit,
  }) {
    final totalSuratRakaas =
        prayersAlone.fold(0, (sum, p) => sum + p.suratRakaas);
    final hasLearning = learningUnit != null && totalSuratRakaas > 0;
    final pool = _UnitPool(
        _expandToRakaas(units, totalSuratRakaas - (hasLearning ? 1 : 0)));

    // Décompte des rakaas récitées restantes : la dernière (recitedLeft == 0
    // après décrément) est celle de l'apprentissage. Compter à rebours évite
    // d'avoir à retrouver "la dernière prière qui récite" en amont.
    int recitedLeft = totalSuratRakaas;
    final plan = <PrayerPlan>[];
    for (final prayer in prayersAlone) {
      pool.startPrayer();
      final rakaas = <RakaaAssignment>[];
      for (int r = 1; r <= prayer.rakaas; r++) {
        if (r > prayer.suratRakaas) {
          // Rakaa silencieuse (au-delà du nombre de rakaas récitées à voix haute) —
          // c'est la seule situation où une rakaa reste vide.
          rakaas.add(RakaaAssignment(rakaaNumber: r));
          continue;
        }
        recitedLeft--;
        if (hasLearning && recitedLeft == 0) {
          rakaas.add(RakaaAssignment(
              rakaaNumber: r, unit: learningUnit, isLearning: true));
          continue;
        }
        rakaas.add(RakaaAssignment(rakaaNumber: r, unit: pool.next()));
      }
      plan.add(PrayerPlan(prayer: prayer, rakaas: rakaas));
    }

    return plan;
  }

  /// Subdivise les unités pour remplir [targetCount] rakaas.
  ///
  /// Règles :
  /// 1. Un verset seul ou une sous-unité < [_minLinesPerSlot] lignes n'est pas subdivisé davantage.
  /// 2. Si après expansion on a encore moins d'unités que de rakaas,
  ///    les unités sont répétées cycliquement (plutôt que laisser des rakaas vides).
  static List<RevisionUnit> _expandToRakaas(
      List<RevisionUnit> units, int targetCount) {
    if (units.isEmpty || units.length >= targetCount) return units;

    // Répartit targetCount rakaas entre les unités, le plus également
    // possible, et matérialise chacune dans la foulée (une seule passe).
    final materialized = <RevisionUnit>[];
    int slotsLeft = targetCount;
    int unitsLeft = units.length;
    for (final unit in units) {
      final slots = (slotsLeft / unitsLeft).round().clamp(1, slotsLeft);
      slotsLeft -= slots;
      unitsLeft--;
      materialized.addAll(_materialize(unit, slots));
    }
    return _padCyclically(materialized, targetCount);
  }

  /// Découpe [unit] en [slots] plages de versets contiguës, ou la garde
  /// entière si la subdivision n'a pas de sens (verset unique, ou moins de
  /// [_minLinesPerSlot] lignes par plage résultante).
  static List<RevisionUnit> _materialize(RevisionUnit unit, int slots) {
    final canSplit = slots > 1 &&
        unit.verseCount > 1 &&
        unit.estimatedLines / slots >= _minLinesPerSlot;
    if (!canSplit) return [unit];
    return _splitRange(unit.sourate, unit.verseStart, unit.verseEnd, slots);
  }

  /// Découpe la plage [start]–[end] de [sourate] en [count] sous-plages
  /// contiguës (la dernière bornée à [end]) — logique partagée par
  /// [buildUnits] (découpage par limite de mots) et [_materialize]
  /// (subdivision en rakaas).
  static List<RevisionUnit> _splitRange(
      Sourate sourate, int start, int end, int count) {
    final versesPerPart = ((end - start + 1) / count).ceil();
    final result = <RevisionUnit>[];
    for (int i = 0; i < count; i++) {
      final s = start + i * versesPerPart;
      if (s > end) break;
      final e = (s + versesPerPart - 1).clamp(start, end);
      result.add(RevisionUnit(
        sourate: sourate,
        verseStart: s,
        verseEnd: e,
        isWhole: false,
      ));
    }
    return result;
  }

  /// Répète cycliquement [units] jusqu'à atteindre [targetCount] — jamais de
  /// rakaa vide faute d'unité fraîche à proposer (répétition cyclique).
  static List<RevisionUnit> _padCyclically(
      List<RevisionUnit> units, int targetCount) {
    if (units.isEmpty || units.length >= targetCount) return units;
    return List.generate(targetCount, (i) => units[i % units.length]);
  }

  static int advanceCycle({
    required int currentPosition,
    required int unitsCompleted,
    required int cycleTotal,
  }) {
    return (currentPosition + unitsCompleted) % cycleTotal;
  }

  /// Unités (échelle attendue par [advanceCycle]) et unités réellement
  /// couvertes par les [n] premières rakaas de [plan] (dans l'ordre) —
  /// utilisé pour la déclaration manuelle "une part fait" de `PlanScreen`, où
  /// l'utilisateur pense en rakaas récitées, pas en unités de cycle.
  static ({int units, List<RevisionUnit> coveredUnits}) coverageForFirstRakaas(
      List<PrayerPlan> plan, int n) {
    final seenLabels = <String>{};
    final coveredUnits = <RevisionUnit>[];
    int counted = 0;
    for (final pp in plan) {
      for (final r in pp.rakaas) {
        // La rakaa d'apprentissage n'est pas une unité de révision : elle ne
        // fait pas avancer le cycle et se confirme au check-out, pas ici.
        if (r.unit == null || r.isLearning) continue;
        if (counted >= n) break;
        counted++;
        seenLabels.add(r.unit!.label);
        coveredUnits.add(r.unit!);
      }
      if (counted >= n) break;
    }
    return (units: seenLabels.length, coveredUnits: coveredUnits);
  }
}

/// Distribue une liste d'unités déjà expansées (une par rakaa cible) rakaa
/// par rakaa, en respectant la règle "pas deux fois la même plage dans une
/// même prière" (S6-B assouplie) à trois niveaux de priorité :
/// 1. la prochaine unité pas encore consommée aujourd'hui et pas déjà
///    utilisée dans cette prière ;
/// 2. à défaut, une unité déjà consommée ailleurs aujourd'hui mais pas
///    encore dans cette prière ;
/// 3. en dernier recours, on répète — jamais de rakaa vide pour cette raison.
///
/// Le pool possède lui-même l'ensemble "déjà utilisé dans cette prière" —
/// [startPrayer] le réinitialise, [next] le met à jour — pour qu'aucun
/// appelant ne puisse casser la règle en oubliant de le faire.
class _UnitPool {
  _UnitPool(List<RevisionUnit> units) : _units = units.toList();

  final List<RevisionUnit> _units;
  int _consumed = 0;
  Set<RevisionUnit> _usedInPrayer = {};

  void startPrayer() => _usedInPrayer = {};

  RevisionUnit? next() {
    if (_units.isEmpty) return null;

    for (int k = _consumed; k < _units.length; k++) {
      if (!_usedInPrayer.contains(_units[k])) {
        if (k != _consumed) {
          final tmp = _units[_consumed];
          _units[_consumed] = _units[k];
          _units[k] = tmp;
        }
        final unit = _units[_consumed++];
        _usedInPrayer.add(unit);
        return unit;
      }
    }
    for (final u in _units) {
      if (!_usedInPrayer.contains(u)) {
        _usedInPrayer.add(u);
        return u;
      }
    }
    final unit = _units.first;
    _usedInPrayer.add(unit);
    return unit;
  }
}
