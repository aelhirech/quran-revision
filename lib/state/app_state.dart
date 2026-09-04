import 'package:flutter/foundation.dart';
import '../core/freshness_engine.dart';
import '../core/quran_data.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/riwaya.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';
import '../services/ayah_facts_service.dart';
import '../services/hafs_service.dart';
import '../services/storage_service.dart';
import '../services/warsh_service.dart';

class AppState extends ChangeNotifier {
  UserConfig? _config;
  int _cyclePosition;
  DailySession? _todaySession;
  // Date (YYYY-MM-DD) du jour de révision non encore scellé le plus ancien,
  // ou null — voir `ensureDayPlan`. Tant qu'elle est non-null, le moteur
  // quotidien ne génère pas de nouveau plan (voir cadrage Phase 6, "Moteur
  // quotidien — source unique de vérité").
  String? _pendingDate;
  // true juste après que `ensureDayPlan` ait proposé un nouveau plan — sert
  // à afficher le popup de check-in une seule fois par jour généré, pas à
  // chaque reprise de l'app. Transitoire (pas persisté) : si l'app est tuée
  // avant l'accusé de réception, le popup ne réapparaît pas — sans gravité,
  // le plan reste modifiable depuis PlanScreen.
  bool _justCheckedIn = false;
  Set<String> _pauseDates;
  String _locale;
  Riwaya _riwaya;
  final bool warshAvailable;
  bool _hasSeenTour;
  List<Sourate> _sourates;
  // Durée de cycle calculée depuis l'historique (mode adaptatif uniquement)
  int? _adaptiveCycleDays;
  // Dernière date de révision par verset (surahId → ayahId → date), grain le
  // plus fin disponible — voir `refreshFreshness`/`freshnessFor`.
  // FreshnessEngine.computeForRange classe à la demande sur la plage exacte
  // demandée (sourate entière ou sélection partielle), pas de Map précalculée
  // par sourate : la plage change selon l'appelant (RecapCard = sélection,
  // PlanScreen/check-in = unité du jour, potentiellement subdivisée).
  Map<int, Map<int, DateTime>> _lastRevisionByAyah = {};

  AppState(
    this._config, {
    String locale = 'fr',
    Riwaya riwaya = Riwaya.hafs,
    this.warshAvailable = true,
    bool initialHasSeenTour = false,
    int initialCyclePosition = 0,
    Set<String> initialPauseDates = const {},
  })  : _locale = locale,
        // `riwaya` must stay a public named arg for callers — `this._riwaya`
        // would make the constructor arg private.
        // ignore: prefer_initializing_formals
        _riwaya = riwaya,
        _hasSeenTour = initialHasSeenTour,
        _sourates = _souratesFor(riwaya),
        _cyclePosition = initialCyclePosition,
        _pauseDates = Set.from(initialPauseDates) {
    S.locale = locale;
  }

  static List<Sourate> _souratesFor(Riwaya riwaya) => buildSourates(
        verseCounts:
            riwaya == Riwaya.warsh ? WarshService.verseCounts : HafsService.verseCounts,
        wordCounts:
            riwaya == Riwaya.warsh ? WarshService.wordCounts : HafsService.wordCounts,
      );

  UserConfig? get config => _config;
  int get cyclePosition => _cyclePosition;
  DailySession? get todaySession => _todaySession;
  String? get pendingDate => _pendingDate;
  bool get justCheckedIn => _justCheckedIn;
  Set<String> get pauseDates => Set.unmodifiable(_pauseDates);
  String get locale => _locale;
  Riwaya get riwaya => _riwaya;
  bool get hasSeenTour => _hasSeenTour;

  Future<void> markTourSeen() async {
    if (_hasSeenTour) return;
    _hasSeenTour = true;
    await StorageService.setTourSeen();
    notifyListeners();
  }
  /// Sourates du parcours actif, avec comptes de versets/mots corrects pour
  /// la riwaya active (Hafs 6236 versets au total, Warsh 6214 — les comptes
  /// par sourate diffèrent en conséquence). À utiliser à la place de
  /// `quran_data.dart`'s data brute partout où une liste de sourates est
  /// nécessaire.
  List<Sourate> get sourates => _sourates;
  /// Retourne la durée adaptive uniquement si le mode est activé.
  int? get adaptiveCycleDays =>
      _config?.adaptiveCycle == true ? _adaptiveCycleDays : null;

  /// Niveau de fraîcheur d'une sourate/sélection sur sa plage exacte de
  /// versets [verseStart]..[verseEnd] (pas `1..sourate.verses`) — voir
  /// `FreshnessEngine.computeForRange`.
  FreshnessLevel freshnessFor(int sourateId, int verseStart, int verseEnd) =>
      FreshnessEngine.computeForRange(
        lastRevisionByAyah: _lastRevisionByAyah[sourateId] ?? const {},
        verseStart: verseStart,
        verseEnd: verseEnd,
        today: DateTime.now(),
      );

  String get _todayStr =>
      DateTime.now().toIso8601String().substring(0, 10);

  bool get isPausedToday => _pauseDates.contains(_todayStr);

  Future<void> togglePauseToday() async {
    final today = _todayStr;
    if (_pauseDates.contains(today)) {
      _pauseDates.remove(today);
    } else {
      _pauseDates.add(today);
    }
    await StorageService.savePauseDates(_pauseDates, _riwaya);
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    _locale = locale;
    S.locale = locale;
    await StorageService.saveLocale(locale);
    notifyListeners();
  }

  /// Bascule le parcours actif (Hafs <-> Warsh). Chaque riwaya est un
  /// parcours indépendant (config, cycle, plan du jour, progression,
  /// historique séparés) — rien n'est traduit d'un parcours vers l'autre. Si
  /// le parcours cible n'a jamais été configuré, `config` redevient `null` et
  /// l'app retombe naturellement sur l'onboarding (voir main.dart).
  /// Retourne `false` sans rien changer si la riwaya demandée n'a pas pu
  /// être chargée au démarrage (texte Warsh indisponible) — évite de planter
  /// sur `WarshService.verseCounts` en essayant de construire les sourates.
  Future<bool> setRiwaya(Riwaya riwaya) async {
    if (riwaya == _riwaya) return true;
    if (riwaya == Riwaya.warsh && !warshAvailable) return false;
    _riwaya = riwaya;
    await StorageService.saveRiwaya(riwaya);
    await _loadTrackState();
    notifyListeners();
    return true;
  }

  Future<void> _loadTrackState() async {
    // Lectures indépendantes démarrées en parallèle — un seul aller-retour
    // au lieu de plusieurs en série (même principe qu'au boot, main.dart).
    final configF = StorageService.loadConfig(_riwaya);
    final cyclePositionF = StorageService.loadCyclePosition(_riwaya);
    final pauseDatesF = StorageService.loadPauseDates(_riwaya);
    _config = await configF;
    _cyclePosition = await cyclePositionF;
    _pauseDates = await pauseDatesF;
    _sourates = _souratesFor(_riwaya);
    _adaptiveCycleDays = null;
    _todaySession = null;
    _pendingDate = null;
    _justCheckedIn = false;
    await refreshFreshness(notify: false);
    if (_config?.adaptiveCycle == true) {
      await refreshAdaptiveCycle(_config!.totalSelectedVerses, notify: false);
    }
    await ensureDayPlan(notify: false);
  }

  /// Ne remet le cycle à zéro que si les sourates sélectionnées ont vraiment
  /// changé — un simple ajustement du rythme (durée, lignes/jour) ne doit pas
  /// effacer la progression ni le plan du jour en cours.
  Future<void> saveConfig(UserConfig config) async {
    final selectionsChanged =
        _config == null || !_sameSelections(_config!.selections, config.selections);
    _config = config;
    await StorageService.saveConfig(config, _riwaya);
    if (selectionsChanged) {
      _cyclePosition = 0;
      _todaySession = null;
      await StorageService.saveCyclePosition(0, _riwaya);
    }
    notifyListeners();
  }

  bool _sameSelections(List<SourateSelection> a, List<SourateSelection> b) {
    if (a.length != b.length) return false;
    String key(SourateSelection s) =>
        '${s.sourate.id}:${s.verseStart}:${s.verseEnd}';
    return a.map(key).toSet().containsAll(b.map(key));
  }

  /// Fait avancer `cyclePosition` — délègue le calcul à `RevisionEngine`,
  /// source unique de vérité pour la progression. Depuis Phase 6 Sprint 2,
  /// n'est appelée que par [checkOut] (une fois par jour scellé), plus à
  /// chaque manche PlanScreen.
  Future<void> advanceCycle(int unitsCompleted, int cycleTotal,
      {bool notify = true}) async {
    if (cycleTotal == 0) return;
    _cyclePosition = RevisionEngine.advanceCycle(
      currentPosition: _cyclePosition,
      unitsCompleted: unitsCompleted,
      cycleTotal: cycleTotal,
    );
    await StorageService.saveCyclePosition(_cyclePosition, _riwaya);
    if (notify) notifyListeners();
  }

  /// Recharge les dernières dates de révision par verset depuis l'historique
  /// — voir [freshnessFor]. Appelé quand une session démarre et après chaque
  /// session complétée.
  Future<void> refreshFreshness({bool notify = true}) async {
    _lastRevisionByAyah = await AyahFactsService.lastRevisionDatesPerVerse(riwaya: _riwaya);
    if (notify) notifyListeners();
  }

  Future<void> clearTodaySession() async {
    _todaySession = null;
    await StorageService.clearActivePrayers(_riwaya);
    notifyListeners();
  }

  /// Recalcule la durée adaptive depuis l'historique. [totalVerses] et
  /// `AyahFactsService.avgVersesPerDay` doivent rester sur la même échelle
  /// (versets, depuis Phase 6 — pas des unités RevisionEngine, dont la taille
  /// varie par sourate). Appelé après chaque session et quand le toggle
  /// adaptatif est activé.
  Future<void> refreshAdaptiveCycle(int totalVerses, {bool notify = true}) async {
    if (_config?.adaptiveCycle != true || totalVerses <= 0) return;
    final avg = await AyahFactsService.avgVersesPerDay(riwaya: _riwaya);
    if (avg > 0) {
      _adaptiveCycleDays = (totalVerses / avg).ceil();
      if (notify) notifyListeners();
    }
  }

  Future<void> setAdaptiveCycle(bool enabled, {int totalVerses = 0}) async {
    if (_config == null) return;
    _config = _config!.copyWith(adaptiveCycle: enabled);
    await StorageService.saveConfig(_config!, _riwaya);
    if (enabled) await refreshAdaptiveCycle(totalVerses, notify: false);
    notifyListeners();
  }

  Future<void> setShuffleEnabled(bool enabled) async {
    if (_config == null) return;
    _config = _config!.copyWith(shuffleEnabled: enabled);
    await StorageService.saveConfig(_config!, _riwaya);
    notifyListeners();
  }

  Future<void> clearConfig() async {
    _config = null;
    _cyclePosition = 0;
    _todaySession = null;
    _pendingDate = null;
    _justCheckedIn = false;
    _pauseDates = {};
    await StorageService.clearConfigOnly(_riwaya);
    notifyListeners();
  }

  // ─── Rituel check-in/check-out (Phase 6 Sprint 2) ────────────────────────
  //
  // Le moteur quotidien est la seule source du plan du jour : il écrit les
  // unités proposées directement dans `ayah_facts` (voir cadrage,
  // "Moteur quotidien — source unique de vérité"). Le check-in édite ces
  // lignes, PlanScreen les affiche/répartit en rakaas, le check-out les
  // scelle et fait avancer le cycle. Plus de `previewSession`/`todaySession`
  // persistés séparément.

  Sourate? _sourateById(int id) {
    for (final s in _sourates) {
      if (s.id == id) return s;
    }
    return null;
  }

  RevisionUnit? _unitFor(DayFactGroup g) {
    final s = _sourateById(g.surahId);
    if (s == null) return null;
    return RevisionUnit(
      sourate: s,
      verseStart: g.verseStart,
      verseEnd: g.verseEnd,
      isWhole: g.verseStart == 1 && g.verseEnd == s.verses,
    );
  }

  /// Unités du plan du jour (date passée, `_todayStr` par défaut), telles que
  /// validées au check-in — reconstruites depuis `ayah_facts`, jamais
  /// recalculées indépendamment (voir cadrage).
  Future<List<RevisionUnit>> dayUnits({String? date}) async {
    final groups = await AyahFactsService.dayFacts(date ?? _todayStr, _riwaya);
    return groups.map(_unitFor).whereType<RevisionUnit>().toList();
  }

  /// Comme [dayUnits], avec les versets flagués "à retravailler" de chaque
  /// unité (`needsWorkVerses`) — c'est cette version que consomme
  /// CheckOutScreen. Ne renvoie plus `reach` (Sprint 7) : CheckOutScreen
  /// affiche tout comme "fait" par défaut, indépendamment de la valeur
  /// persistée (voir Backlog "Check-out : reach fait par défaut",
  /// 2026-09-04) — le `reach` en base ne sert plus qu'à [checkOut] lui-même.
  Future<List<({RevisionUnit unit, Set<int> needsWorkVerses})>> dayUnitsWithStatus(
      {String? date}) async {
    final groups = await AyahFactsService.dayFacts(date ?? _todayStr, _riwaya);
    return [
      for (final g in groups)
        if (_unitFor(g) case final unit?)
          (unit: unit, needsWorkVerses: g.needsWorkVerses),
    ];
  }

  /// Sélection du jour, pure (aucune écriture) — encapsule l'appel à
  /// `RevisionEngine.selectDayUnits` avec les mêmes paramètres partout
  /// (position gelée, jour ancré à minuit, cycle adaptatif) pour que
  /// [ensureDayPlan]/[buildTodaySession]/[checkOut]/[previewTodayUnits] ne
  /// puissent pas diverger entre eux. [today] est TOUJOURS ancré à minuit
  /// (`DateTime.parse` d'une date `YYYY-MM-DD`), jamais `DateTime.now()` :
  /// la même date doit produire la même sélection qu'elle soit calculée à la
  /// génération du plan ou plus tard au check-out, sinon `daysElapsed`
  /// dérive avec l'heure de la journée et les deux appels ne comptent plus
  /// les mêmes unités (bug trouvé en revue de code).
  DaySelection _selectionFor(String date) => RevisionEngine.selectDayUnits(
        config: _config!,
        cyclePosition: _cyclePosition,
        today: DateTime.parse(date),
        effectiveDaysOverride: adaptiveCycleDays,
      );

  /// Aperçu pur (aucune écriture) de ce que le moteur quotidien proposerait
  /// s'il tournait maintenant — utilisé par le check-out multi-jours (Partie
  /// 2, "ajouter aussi aujourd'hui") pour montrer un aperçu avant de sceller.
  /// Même appel que [ensureDayPlan] fait réellement, exposé ici pour que les
  /// écrans n'importent jamais `RevisionEngine` directement.
  List<RevisionUnit> previewTodayUnits() {
    if (_config == null) return const [];
    return _selectionFor(_todayStr).units;
  }

  /// Position/total du cycle en cours (nombre d'unités RevisionEngine) et
  /// jours restants avant la date cible, à afficher (bandeau HomeScreen,
  /// carte cycle RecapScreen) — dérivés de la même [_selectionFor] que le
  /// plan du jour (`DailySession`, PlanScreen), pour que les 3 écrans ne
  /// recalculent plus chacun leur propre `RevisionEngine.buildUnits(...)`
  /// (source de divergence silencieuse, retour TestFlight 2026-09-01 sur
  /// les chiffres du récapitulatif). `daysRemaining` ici peut tomber à 0
  /// ("objectif atteint") contrairement à celui de `DaySelection`/
  /// `DailySession`, qui reste toujours >= 1 pour ne jamais diviser par
  /// zéro dans le moteur quotidien (voir `RevisionEngine.dailyTarget`) —
  /// deux usages distincts (affichage vs moteur), donc deux valeurs
  /// distinctes malgré la même origine. Nommé `cycleSummary` (pas
  /// `cycleProgress`) pour ne pas entrer en collision avec
  /// `DailySession.cycleProgress` (un `double`, sémantique différente).
  ({int pos, int total, double progress, int daysRemaining}) get cycleSummary {
    final config = _config;
    if (config == null) {
      return (pos: 0, total: 0, progress: 0.0, daysRemaining: 0);
    }
    final selection = _selectionFor(_todayStr);
    final total = selection.cycleTotal;
    final pos = selection.cyclePosition;
    final daysElapsed = DateTime.now().difference(config.startDate).inDays;
    final effectiveDays =
        adaptiveCycleDays ?? config.effectiveDays(config.totalSelectedVerses);
    return (
      pos: pos,
      total: total,
      progress: total == 0 ? 0.0 : pos / total,
      daysRemaining: (effectiveDays - daysElapsed).clamp(0, 9999),
    );
  }

  /// Point d'entrée du moteur quotidien — à appeler à l'ouverture/reprise de
  /// l'app (voir ShellScreen). Gated sur un éventuel jour en attente
  /// STRICTEMENT antérieur à aujourd'hui (voir `AyahFactsService.pendingDate`) :
  /// tant qu'il n'est pas scellé, aucun nouveau plan n'est généré (sinon
  /// `cyclePosition` n'aurait pas encore avancé pour ce jour-là, et le
  /// nouveau plan proposerait les mêmes versets une seconde fois).
  Future<void> ensureDayPlan({bool notify = true}) async {
    if (_config == null) return;
    _pendingDate = await AyahFactsService.pendingDate(riwaya: _riwaya);
    if (_pendingDate == null) {
      final today = _todayStr;
      final existing = await AyahFactsService.dayFacts(today, _riwaya);
      if (existing.isEmpty) {
        await AyahFactsService.proposeUnits(
            today, _riwaya, _selectionFor(today).units);
        _justCheckedIn = true;
      }
      // Reprend la manche en cours si l'app a redémarré après un début de
      // check-in/PlanScreen le même jour (prières déjà choisies).
      final activePrayers = await StorageService.loadActivePrayers(_riwaya);
      if (activePrayers != null && activePrayers.isNotEmpty) {
        await buildTodaySession(activePrayers, notify: false);
      }
    }
    if (notify) notifyListeners();
  }

  Future<void> acknowledgeCheckIn() async {
    if (!_justCheckedIn) return;
    _justCheckedIn = false;
    notifyListeners();
  }

  /// Ajoute une sourate/portion au plan du jour depuis le check-in.
  Future<void> addToDayPlan(RevisionUnit unit) async {
    await AyahFactsService.proposeUnits(_todayStr, _riwaya, [unit]);
    notifyListeners();
  }

  /// Retire une sourate du plan du jour depuis le check-in.
  Future<void> removeFromDayPlan(int surahId) async {
    await AyahFactsService.removeFromDayPlan(_todayStr, _riwaya, surahId);
    notifyListeners();
  }

  /// Étend d'un verset la portée d'une sourate du plan du jour (chip "+" de
  /// l'écran détail du check-in).
  Future<void> extendDayPlanVerse(int surahId, int newVerse) async {
    final s = _sourateById(surahId);
    if (s == null) return;
    await AyahFactsService.proposeUnits(_todayStr, _riwaya,
        [RevisionUnit(sourate: s, verseStart: newVerse, verseEnd: newVerse, isWhole: false)]);
    notifyListeners();
  }

  /// Construit (ou reconstruit) le plan du jour réparti en rakaas pour les
  /// prières données — répartit les unités déjà validées au check-in
  /// ([dayUnits]), ne les régénère pas. Persiste la sélection de prières
  /// pour survivre à un redémarrage de l'app avant la fin de la manche.
  Future<void> buildTodaySession(List<Prayer> prayersAlone,
      {bool notify = true}) async {
    if (_config == null || prayersAlone.isEmpty) return;
    final selection = _selectionFor(_todayStr);
    final units = await dayUnits();
    final plan =
        RevisionEngine.distributeToRakaas(units: units, prayersAlone: prayersAlone);
    _todaySession = DailySession(
      date: DateTime.now(),
      prayersAlone: prayersAlone,
      plan: plan,
      totalUnits: units.length,
      cyclePosition: selection.cyclePosition,
      cycleTotal: selection.cycleTotal,
      daysRemaining: selection.daysRemaining,
    );
    await StorageService.saveActivePrayers(prayersAlone, _riwaya);
    if (notify) notifyListeners();
  }

  /// Marque `reach` (par défaut `true`) en batch pour [units] — soit une
  /// manche PlanScreen complétée (date implicite : aujourd'hui, `reach`
  /// toujours vrai), soit la clôture d'un CheckOutScreen ([date] explicite) :
  /// `reach: true` pour confirmer "fait par défaut", `reach: false` pour
  /// annuler explicitement une unité déjà à `reach=1` (ex. cochée par erreur
  /// plus tôt dans PlanScreen) — voir CLAUDE.md § « Modèle de données
  /// central » : annuler une progression repasse `reach` à 0, jamais un
  /// simple no-op. N'avance jamais `cyclePosition` elle-même (voir
  /// [checkOut]) ; pas de `notifyListeners` ici, laissé aux appelants qui
  /// enchaînent d'autres écritures avant de notifier une seule fois pour
  /// toute l'opération.
  Future<void> markUnitsReached(List<RevisionUnit> units,
      {String? date, bool reach = true}) async {
    await AyahFactsService.setReachForUnits(date ?? _todayStr, _riwaya, units, reach);
  }

  /// Bascule "fait/pas fait" pour une rakaa de PlanScreen — remplace
  /// l'ancien état en mémoire/SharedPreferences (`_checkedRakaas`) par une
  /// écriture directe dans `ayah_facts` pour aujourd'hui (voir [setUnitReach]
  /// pour une date arbitraire). Si [unit] est assigné à plusieurs rakaas de
  /// la manche (pénurie de matière, cf. `RevisionEngine._padCyclically`),
  /// cocher l'une coche automatiquement les autres — `reach` est une vérité
  /// par verset/jour, pas par rakaa, comportement voulu.
  Future<void> toggleTodayUnitReach(RevisionUnit unit, bool reach) =>
      setUnitReach(_todayStr, unit, reach);

  /// Statut `reach` d'aujourd'hui pour chaque unité unique de [units] — une
  /// seule requête ([AyahFactsService.reachedVersesToday]), le résultat
  /// exact par plage étant recalculé en Dart (pas par sourate comme
  /// [dayUnitsWithStatus], qui agrégerait à tort deux plages distinctes de la
  /// même sourate assignées à des rakaas différents). Consommé par
  /// PlanScreen pour l'état "coché" de chaque rakaa.
  Future<Map<RevisionUnit, bool>> reachStatusFor(
      Iterable<RevisionUnit> units) async {
    final reachedByVerse =
        await AyahFactsService.reachedVersesToday(_todayStr, _riwaya);
    return {
      for (final unit in units.toSet())
        unit: List.generate(unit.verseCount, (i) => unit.verseStart + i)
            .every((v) => reachedByVerse[unit.sourate.id]?.contains(v) ?? false),
    };
  }

  /// Bascule "à retravailler" pour un verset précis — écran détail du
  /// check-out, granularité verset (pas la sourate entière).
  Future<void> setVerseNeedsWork(
      String date, int surahId, int ayahId, bool needsWork) async {
    await AyahFactsService.setNeedsWork(date, _riwaya, surahId, ayahId, needsWork);
    notifyListeners();
  }

  /// Bascule "fait/pas fait" pour une sourate/portion du check-out.
  Future<void> setUnitReach(String date, RevisionUnit unit, bool reach) async {
    await AyahFactsService.setReach(date, _riwaya, unit.sourate.id,
        unit.verseStart, unit.verseEnd, reach);
    notifyListeners();
  }

  /// Scelle la journée [date] (check-out) : verrouille ses lignes et fait
  /// avancer le cycle une seule fois pour toute la journée, à partir des
  /// unités proposées par le moteur qui ont effectivement `reach=1` (dans
  /// l'ordre — même logique que la déclaration partielle historique de
  /// PlanScreen : un ajout hors-sélection au check-in alimente l'historique/
  /// la fraîcheur mais ne fait pas avancer `cyclePosition` au-delà de ce que
  /// le moteur avait initialement proposé ce jour-là — le cadrage n'a pas
  /// tranché de règle plus précise pour les ajouts hors-cycle, voir
  /// CHANGELOG). Une unité entièrement retirée au check-in ([removeFromDayPlan])
  /// n'a plus aucune ligne en base : elle est ignorée (ni comptée ni
  /// bloquante), sans quoi elle romprait à tort le comptage des unités
  /// suivantes réellement faites (bug trouvé en revue de code). Retourne
  /// `true` si le cycle vient de boucler (milestone à afficher côté écran).
  Future<bool> checkOut(String date) async {
    if (_config == null) return false;
    final selection = _selectionFor(date);
    int unitsCompleted = 0;
    for (final unit in selection.units) {
      final exists = await AyahFactsService.rangeExists(
          date, _riwaya, unit.sourate.id, unit.verseStart, unit.verseEnd);
      if (!exists) continue; // retirée au check-in — ne bloque pas le comptage
      final reached = await AyahFactsService.isRangeReached(
          date, _riwaya, unit.sourate.id, unit.verseStart, unit.verseEnd);
      if (!reached) break;
      unitsCompleted++;
    }
    final cycleWraps = selection.cycleTotal > 0 &&
        (_cyclePosition + unitsCompleted) >= selection.cycleTotal;
    _pendingDate = null;
    _todaySession = null;
    // Écritures indépendantes (table ayah_facts, prefs, cycle) — lancées en
    // parallèle plutôt qu'en série.
    await Future.wait([
      AyahFactsService.sealDay(date, _riwaya),
      refreshAdaptiveCycle(_config!.totalSelectedVerses, notify: false),
      refreshFreshness(notify: false),
      StorageService.clearActivePrayers(_riwaya),
      advanceCycle(unitsCompleted, selection.cycleTotal, notify: false),
    ]);
    notifyListeners(); // seul notify de toute l'opération
    return cycleWraps;
  }
}
