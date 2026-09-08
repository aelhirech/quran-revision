import 'package:flutter/foundation.dart';
import '../core/freshness_engine.dart';
import '../core/quran_data.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../models/ayah_fact.dart';
import '../models/daily_session.dart';
import '../models/learning_progress.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../models/riwaya.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';
import '../services/ayah_facts_service.dart';
import '../services/hafs_service.dart';
import '../services/page_metadata_service.dart';
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
  // Date (YYYY-MM-DD) dont on sait qu'elle est scellée — PAS un booléen :
  // un `bool` resterait vrai après le passage de minuit avec l'app
  // résidente, et l'accueil afficherait « Journée clôturée » avec un CTA
  // inerte sur une journée neuve, sans autre issue que tuer l'app.
  String? _closedDate;
  Set<String> _pauseDates;
  String _locale;
  Riwaya _riwaya;
  final bool warshAvailable;
  bool _hasSeenTour;
  List<Sourate> _sourates;
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
  /// La journée d'aujourd'hui a-t-elle déjà été clôturée ? Depuis que
  /// « Clôturer ma journée » scelle le jour courant sans attendre le
  /// lendemain (Phase 9 Sprint 2), l'accueil doit pouvoir le dire — sinon il
  /// réinviterait à « illuminer » une journée déjà close. Dérivé
  /// d'`ayah_facts` (`checked_out`), jamais tenu en parallèle, et comparé à
  /// la date du jour pour qu'un changement de date le périme tout seul.
  bool get todayClosed => _closedDate == todayStr;

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

  /// Date du jour au format `YYYY-MM-DD` — clé de toutes les lignes
  /// `ayah_facts` d'aujourd'hui. Publique depuis la Phase 9 Sprint 2 :
  /// `DayPlanTab` en a besoin pour pousser le check-out sur aujourd'hui, et
  /// la recalculer côté UI recréerait une seconde source de vérité.
  String get todayStr =>
      DateTime.now().toIso8601String().substring(0, 10);

  bool get isPausedToday => _pauseDates.contains(todayStr);

  Future<void> togglePauseToday() async {
    final today = todayStr;
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
    _todaySession = null;
    _pendingDate = null;
    // `ensureDayPlan` returns early when the track has no config, so it
    // would leave a stale closed-day flag from the previous riwaya.
    _closedDate = null;
    await refreshFreshness(notify: false);
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

  Future<void> setShuffleEnabled(bool enabled) async {
    if (_config == null) return;
    _config = _config!.copyWith(shuffleEnabled: enabled);
    await StorageService.saveConfig(_config!, _riwaya);
    notifyListeners();
  }

  Future<void> clearConfig() async {
    _closedDate = null;
    _config = null;
    _cyclePosition = 0;
    _todaySession = null;
    _pendingDate = null;
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

  /// Unités du plan du jour (date passée, `todayStr` par défaut), telles que
  /// validées au check-in — reconstruites depuis `ayah_facts`, jamais
  /// recalculées indépendamment (voir cadrage).
  Future<List<RevisionUnit>> dayUnits({String? date}) async {
    final groups = await AyahFactsService.dayFacts(date ?? todayStr, _riwaya);
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
    final groups = await AyahFactsService.dayFacts(date ?? todayStr, _riwaya);
    return [
      for (final g in groups)
        if (_unitFor(g) case final unit?)
          (unit: unit, needsWorkVerses: g.needsWorkVerses),
    ];
  }

  /// Sélection du jour, pure (aucune écriture) — encapsule l'appel à
  /// `RevisionEngine.buildDayUnits` avec les mêmes paramètres partout
  /// (position gelée, jour ancré à minuit) pour que
  /// [ensureDayPlan]/[buildTodaySession]/[checkOut]/[previewTodayUnits] ne
  /// puissent pas diverger entre eux. [today] est TOUJOURS ancré à minuit
  /// (`DateTime.parse` d'une date `YYYY-MM-DD`), jamais `DateTime.now()` :
  /// la même date doit produire la même sélection qu'elle soit calculée à la
  /// génération du plan ou plus tard au check-out, sinon `daysElapsed`
  /// dérive avec l'heure de la journée et les deux appels ne comptent plus
  /// les mêmes unités (bug trouvé en revue de code).
  /// The cycle no longer depends on the date at all: it is a pure function of
  /// the selection, the pace and the cursor. Every caller reads it here so the
  /// day plan, the check-out and the KPIs can never diverge.
  DaySelection get _selection => RevisionEngine.buildDayUnits(
        config: _config!,
        cyclePosition: _cyclePosition,
        pageMetadata: PageMetadataService.pageMetadataFor(_riwaya),
      );

  /// Aperçu pur (aucune écriture) de ce que le moteur quotidien proposerait
  /// s'il tournait maintenant — utilisé par le check-out multi-jours (Partie
  /// 2, "ajouter aussi aujourd'hui") pour montrer un aperçu avant de sceller.
  /// Même appel que [ensureDayPlan] fait réellement, exposé ici pour que les
  /// écrans n'importent jamais `RevisionEngine` directement.
  Future<List<RevisionUnit>> previewTodayUnits() async {
    if (_config == null) return const [];
    return _selection.units;
  }

  /// Position/total du cycle en cours (nombre de groupes `RevisionEngine`),
  /// à afficher (bandeau HomeScreen, carte cycle RecapScreen) — dérivés de la
  /// même [_selectionForAsync] que le plan du jour (`DailySession`,
  /// PlanScreen), pour que les 3 écrans ne recalculent plus chacun leur
  /// propre `RevisionEngine.buildDayUnits(...)` (source de divergence
  /// silencieuse, retour TestFlight 2026-09-01 sur les chiffres du
  /// récapitulatif).
  Future<DaySelection> getDaySelectionForToday() async => _selection;

  /// Point d'entrée du moteur quotidien — à appeler à l'ouverture/reprise de
  /// l'app (voir ShellScreen). Gated sur un éventuel jour en attente
  /// STRICTEMENT antérieur à aujourd'hui (voir `AyahFactsService.pendingDate`) :
  /// tant qu'il n'est pas scellé, aucun nouveau plan n'est généré (sinon
  /// `cyclePosition` n'aurait pas encore avancé pour ce jour-là, et le
  /// nouveau plan proposerait les mêmes versets une seconde fois).
  ///
  /// Depuis la Phase 9, propose aussi les versets à **apprendre** du jour
  /// (sourate déjà en cours, `config.versesToLearnPerDay` versets) — le
  /// check-in confirme ou ajuste les deux propositions, il ne les crée pas.
  Future<void> ensureDayPlan({bool notify = true}) async {
    if (_config == null) return;
    final today = todayStr;
    // Deux lectures indépendantes — démarrées ensemble, comme le bloc
    // ci-dessous : c'est le chemin d'ouverture de l'app.
    final pendingF = AyahFactsService.pendingDate(riwaya: _riwaya);
    final sealedF = AyahFactsService.isDaySealed(today, _riwaya);
    _pendingDate = await pendingF;
    _closedDate = await sealedF ? today : null;
    if (_pendingDate == null) {
      // Lectures indépendantes démarrées ensemble plutôt qu'en série — c'est
      // le chemin d'ouverture de l'app (ShellScreen.initState).
      final existingF = AyahFactsService.dayFacts(today, _riwaya);
      final learnPlanF = AyahFactsService.learnPlanFor(today, _riwaya);
      final activePrayersF = StorageService.loadActivePrayers(_riwaya);
      // Le plan du jour n'est généré qu'une fois par jour — la proposition
      // d'apprentissage est gatée sur ce même moment, pas seulement sur
      // « aucune ligne learn aujourd'hui » : sinon « Je n'apprends rien
      // aujourd'hui » (check-in) serait silencieusement annulé à la
      // prochaine ouverture de l'app, qui reproposerait la même portion.
      // Cas limite connu : sans aucune sourate en révision, `proposeUnits`
      // n'écrit rien, la journée reste vue comme neuve et le refus est
      // reproposé à chaque ouverture — sans conséquence sur les données.
      if ((await existingF).isEmpty) {
        await AyahFactsService.proposeUnits(
            today, _riwaya, _selection.units);
        if (await learnPlanF == null) {
          final inProgress = await learningInProgress();
          if (inProgress != null) {
            await _proposeLearning(
                inProgress.sourate, _config!.versesToLearnPerDay,
                progress: inProgress);
          }
        }
      }
      // Reprend la manche en cours si l'app a redémarré après un début de
      // check-in/PlanScreen le même jour (prières déjà choisies).
      final activePrayers = await activePrayersF;
      if (activePrayers != null && activePrayers.isNotEmpty) {
        await buildTodaySession(activePrayers, notify: false);
      }
    }
    if (notify) notifyListeners();
  }

  // ─── Apprentissage du jour (Phase 9) ─────────────────────────────────────
  //
  // Même modèle que la révision : les versets à apprendre sont des lignes
  // `ayah_facts` datées (`type='learn'`, `reach=0` visé → `reach=1` acquis),
  // jamais un état tenu en parallèle. La dernière rakaa du plan du jour les
  // fait réciter, le check-out confirme lesquels sont réellement acquis.

  /// Sourates dont la mémorisation est commencée mais pas terminée —
  /// reconstruites depuis `ayah_facts` (`type='learn'`).
  Future<List<LearningProgress>> learningProgressList() async =>
      AyahFactsService.loadMainLearningProgress(
          riwaya: _riwaya, sourates: _sourates);

  /// Sourate en cours d'apprentissage, ou `null`. Une seule à la fois en
  /// pratique (c'est le check-in qui en démarre une), mais changer de
  /// sourate en cours de route en laisse plusieurs inachevées : on retient
  /// la **plus récemment démarrée**, celle sur laquelle l'utilisateur
  /// travaille aujourd'hui — pas la première que renvoie SQLite, dont
  /// l'ordre ne veut rien dire.
  Future<LearningProgress?> learningInProgress() async {
    LearningProgress? latest;
    for (final p in await learningProgressList()) {
      if (p.isComplete) continue;
      if (latest == null || p.startDate.isAfter(latest.startDate)) latest = p;
    }
    return latest;
  }

  /// Prochains [count] versets non encore acquis de [sourate], proposés pour
  /// aujourd'hui — règle partagée avec l'écran de pratique
  /// (`LearningProgress.nextBlock`). [progress] évite une relecture quand
  /// l'appelant vient déjà de charger la progression de cette sourate.
  Future<void> _proposeLearning(Sourate sourate, int count,
      {LearningProgress? progress}) async {
    final resolved = progress ??
        LearningProgress(
          sourate: sourate,
          learnedVerses: await AyahFactsService.learnedVersesForSourate(
              riwaya: _riwaya, surahId: sourate.id),
          startDate: DateTime.now(),
        );
    await AyahFactsService.proposeLearnVerses(
        todayStr, _riwaya, sourate.id, resolved.nextBlock(count));
  }

  /// Portion à apprendre aujourd'hui (dernière rakaa du plan du jour), ou
  /// `null` si l'utilisateur n'apprend rien en ce moment. **Dérivée à la
  /// demande**, jamais mise en cache dans un champ : c'est exactement l'état
  /// parallèle à `ayah_facts` que CLAUDE.md interdit (précédent
  /// `_checkedRakaas`) — un cache aurait dû être rafraîchi par les 4 écrivains
  /// de lignes `learn`, dont `deleteLearnFacts` appelé depuis le Récap.
  Future<RevisionUnit?> todayLearningUnit() async {
    final plan = await learningPlanFor(todayStr);
    if (plan == null) return null;
    // `learnPlanFor` trie par `ayah_id`, donc first/last sont bien min/max.
    return RevisionUnit(
      sourate: plan.sourate,
      verseStart: plan.ayahIds.first,
      verseEnd: plan.ayahIds.last,
      isWhole: plan.ayahIds.first == 1 &&
          plan.ayahIds.last == plan.sourate.verses,
    );
  }

  /// Check-in : quelle sourate apprendre aujourd'hui et combien de versets.
  /// [sourate] `null` = ne rien apprendre aujourd'hui. [count] devient aussi
  /// le nouveau défaut proposé les jours suivants
  /// (`UserConfig.versesToLearnPerDay`).
  Future<void> setLearningForToday(Sourate? sourate, int count) async {
    if (_config == null) return;
    if (count != _config!.versesToLearnPerDay) {
      _config = _config!.copyWith(versesToLearnPerDay: count);
      await StorageService.saveConfig(_config!, _riwaya);
    }
    // Seules les lignes encore `reach=0` sont effacées — un verset déjà
    // acquis aujourd'hui ne disparaît pas parce qu'on réajuste la portion.
    await AyahFactsService.clearDayProposal(todayStr, _riwaya,
        type: AyahFactType.learn);
    if (sourate != null) await _proposeLearning(sourate, count);
    notifyListeners();
  }

  /// Check-in (et ligne « Rythme » des Réglages) : ajuste le budget de
  /// pages/jour et régénère la proposition de révision du jour en conséquence
  /// (les lignes déjà `reach=1` sont conservées, voir
  /// `AyahFactsService.clearDayProposal`).
  ///
  /// **Sauf si la journée est déjà clôturée** : depuis « Clôturer ma journée »
  /// (Phase 9 Sprint 2), aujourd'hui peut être scellé alors qu'il est encore
  /// aujourd'hui. Y réécrire une proposition fraîche (`checked_out = 0`)
  /// rouvrirait un jour déjà compté — il redeviendrait « en attente » demain,
  /// et son second check-out ferait avancer le cycle une seconde fois sur du
  /// contenu déjà crédité. Le nouveau rythme est persisté quand même : il
  /// s'appliquera au plan de demain.
  Future<void> setPagesPerDay(int pagesPerDay) async {
    if (_config == null || _config!.pagesPerDay == pagesPerDay) return;
    _config = _config!.copyWith(pagesPerDay: pagesPerDay);
    await StorageService.saveConfig(_config!, _riwaya);
    if (!todayClosed) {
      final today = todayStr;
      await AyahFactsService.clearDayProposal(today, _riwaya);
      await AyahFactsService.proposeUnits(
          today, _riwaya, _selection.units);
      // Une manche déjà répartie en rakaas porterait des unités qui viennent
      // d'être effacées de la table — ses cases cochées reviendraient en
      // arrière sans explication. On la referme, comme `saveConfig` le fait
      // quand la sélection de sourates change.
      _todaySession = null;
      await StorageService.clearActivePrayers(_riwaya);
    }
    notifyListeners();
  }

  /// Ajoute une sourate/portion au plan du jour depuis le check-in.
  /// [date] par défaut aujourd'hui (check-in). Le check-out la passe
  /// explicitement pour déclarer une sourate **révisée en plus** ce jour-là :
  /// même écriture, l'unité rejoint simplement le plan d'une journée passée,
  /// où le "fait par défaut" du check-out la confirmera à la clôture. Comme
  /// tout ajout hors-sélection, elle alimente historique et fraîcheur mais
  /// ne fait pas avancer `cyclePosition` au-delà de ce que le moteur avait
  /// proposé (voir [checkOut]).
  Future<void> addToDayPlan(RevisionUnit unit, {String? date}) async {
    await AyahFactsService.proposeUnits(date ?? todayStr, _riwaya, [unit]);
    notifyListeners();
  }

  /// Check-out : déclarer un verset **appris en plus** le jour [date] —
  /// ajoute le prochain verset non encore acquis de la sourate en cours
  /// d'apprentissage à la portion de ce jour. Sans effet s'il n'y a pas de
  /// portion ce jour-là, ou si la sourate est déjà entièrement mémorisée.
  Future<void> extendLearningForDate(String date) async {
    final plan = await learningPlanFor(date);
    if (plan == null) return;
    final learned = await AyahFactsService.learnedVersesForSourate(
        riwaya: _riwaya, surahId: plan.sourate.id);
    final taken = {...learned, ...plan.ayahIds};
    for (int v = 1; v <= plan.sourate.verses; v++) {
      if (taken.contains(v)) continue;
      await AyahFactsService.proposeLearnVerses(
          date, _riwaya, plan.sourate.id, [v]);
      break;
    }
    notifyListeners();
  }

  /// Retire une sourate du plan du jour depuis le check-in.
  Future<void> removeFromDayPlan(int surahId) async {
    await AyahFactsService.removeFromDayPlan(todayStr, _riwaya, surahId);
    notifyListeners();
  }

  /// Étend d'un verset la portée d'une sourate du plan du jour (chip "+" de
  /// l'écran détail du check-in).
  Future<void> extendDayPlanVerse(int surahId, int newVerse) async {
    final s = _sourateById(surahId);
    if (s == null) return;
    await AyahFactsService.proposeUnits(todayStr, _riwaya,
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
    // Trois lectures indépendantes (sélection du cycle, unités du jour,
    // portion à apprendre) démarrées ensemble plutôt qu'en série.
    final selection = _selection;
    final unitsF = dayUnits();
    final learningF = todayLearningUnit();
    final units = await unitsF;
    final plan = RevisionEngine.distributeToRakaas(
      units: units,
      prayersAlone: prayersAlone,
      learningUnit: await learningF,
    );
    // Units the layout could not place. Only possible when there are more
    // units than reciting rakaas — in that case `distributeToRakaas` assigns
    // them whole, so comparing by value is exact. When it subdivides instead
    // (fewer units than rakaas), nothing is ever left out.
    final assigned = {
      for (final pp in plan)
        for (final r in pp.rakaas)
          if (r.unit != null && !r.isLearning) r.unit!,
    };
    final outside = [
      for (final u in units)
        if (!assigned.contains(u)) u,
    ];
    _todaySession = DailySession(
      date: DateTime.now(),
      prayersAlone: prayersAlone,
      plan: plan,
      // Sur les unités réellement retenues (`dayUnits()`, donc après édition
      // au check-in), pas sur la proposition d'origine de `selection`.
      pagesToday: RevisionEngine.pagesOf(
          units, PageMetadataService.pageMetadataFor(_riwaya)),
      cyclePosition: selection.cyclePosition,
      cycleTotal: selection.cycleTotal,
      outsidePrayers: outside,
    );
    // `saveActivePrayers` = reprendre la manche en cours après un
    // redémarrage ; `saveLastSessionPrayers` = alimenter « reprendre les
    // prières d'hier » au prochain check-in. Écrit ici, au moment où les
    // prières sont choisies, plutôt qu'à la fin d'une manche « complétée » —
    // depuis la Phase 9 Sprint 2 il n'y a plus de complétion de manche, la
    // journée se termine au check-out (voir `PlanScreen.onCloturer`).
    await Future.wait([
      StorageService.saveActivePrayers(prayersAlone, _riwaya),
      StorageService.saveLastSessionPrayers(
          DateTime.now(), prayersAlone, _riwaya),
    ]);
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
    await AyahFactsService.setReachForUnits(date ?? todayStr, _riwaya, units, reach);
  }

  /// Bascule "fait/pas fait" pour une rakaa de PlanScreen — remplace
  /// l'ancien état en mémoire/SharedPreferences (`_checkedRakaas`) par une
  /// écriture directe dans `ayah_facts` pour aujourd'hui (voir [setUnitReach]
  /// pour une date arbitraire). Si [unit] est assigné à plusieurs rakaas de
  /// la manche (pénurie de matière, cf. `RevisionEngine._padCyclically`),
  /// cocher l'une coche automatiquement les autres — `reach` est une vérité
  /// par verset/jour, pas par rakaa, comportement voulu.
  /// [learning] cible la rakaa d'apprentissage (lignes `type='learn'`) au
  /// lieu de la révision — c'est le même geste ("j'ai fait cette rakaa") sur
  /// les deux natures de contenu.
  Future<void> toggleTodayUnitReach(RevisionUnit unit, bool reach,
      {bool learning = false}) async {
    if (!learning) return setUnitReach(todayStr, unit, reach);
    // La portion à apprendre n'est pas forcément contiguë (un verset du
    // milieu peut avoir été appris en avance, ou désappris) : on écrit la
    // liste exacte des versets proposés, pas la plage `BETWEEN` qui
    // engloberait des versets sans ligne en base.
    final plan = await learningPlanFor(todayStr);
    if (plan == null) return;
    await markLearnVerses(todayStr, plan.sourate.id, plan.ayahIds, reach);
    notifyListeners();
  }

  /// Statut `reach` d'aujourd'hui pour chaque unité unique de [units] — une
  /// seule requête ([AyahFactsService.reachedVersesToday]), le résultat
  /// exact par plage étant recalculé en Dart (pas par sourate comme
  /// [dayUnitsWithStatus], qui agrégerait à tort deux plages distinctes de la
  /// même sourate assignées à des rakaas différents). Consommé par
  /// PlanScreen pour l'état "coché" de chaque rakaa.
  Future<Map<RevisionUnit, bool>> reachStatusFor(Iterable<RevisionUnit> units,
      {bool learning = false}) async {
    final reachedByVerse = await AyahFactsService.reachedVersesToday(
        todayStr, _riwaya,
        type: learning ? AyahFactType.learn : AyahFactType.revise);
    // Côté apprentissage, la vérité est la liste des versets réellement
    // proposés — pas tous ceux de la plage : une portion à trous
    // ([2, 4, 5]) ne serait sinon jamais considérée comme faite, le verset 3
    // n'ayant aucune ligne à passer à `reach = 1`.
    final learnVerses =
        learning ? (await learningPlanFor(todayStr))?.ayahIds : null;
    bool isReached(RevisionUnit unit) {
      final verses = learnVerses ??
          List.generate(unit.verseCount, (i) => unit.verseStart + i);
      return verses.isNotEmpty &&
          verses.every(
              (v) => reachedByVerse[unit.sourate.id]?.contains(v) ?? false);
    }

    return {for (final unit in units.toSet()) unit: isReached(unit)};
  }

  /// Bascule "à retravailler" pour un verset précis — écran détail du
  /// check-out, granularité verset (pas la sourate entière).
  Future<void> setVerseNeedsWork(
      String date, int surahId, int ayahId, bool needsWork) async {
    await AyahFactsService.setNeedsWork(date, _riwaya, surahId, ayahId, needsWork);
    notifyListeners();
  }

  /// Bascule "fait/pas fait" pour une sourate/portion du check-out — ou, si
  /// [learning], pour une portion à apprendre (`type='learn'`).
  Future<void> setUnitReach(String date, RevisionUnit unit, bool reach,
      {bool learning = false}) async {
    await AyahFactsService.setReach(date, _riwaya, unit.sourate.id,
        unit.verseStart, unit.verseEnd, reach,
        type: learning ? AyahFactType.learn : AyahFactType.revise);
    notifyListeners();
  }

  /// Portion à apprendre proposée le jour [date] (check-out d'un jour en
  /// attente, ou aujourd'hui via [todayLearningUnit]), résolue en `Sourate` —
  /// `null` si l'utilisateur n'apprenait rien ce jour-là. Les versets sont
  /// rendus tels quels (liste, pas une plage) : la portion d'un jour n'est
  /// pas forcément contiguë si un verset du milieu a été appris en avance.
  /// `reachedVerses` du service n'est pas remonté — le check-out coche tout
  /// par défaut, comme côté révision.
  Future<({Sourate sourate, List<int> ayahIds})?> learningPlanFor(
      String date) async {
    final plan = await AyahFactsService.learnPlanFor(date, _riwaya);
    final sourate = plan == null ? null : _sourateById(plan.surahId);
    if (plan == null || sourate == null || plan.ayahIds.isEmpty) return null;
    return (sourate: sourate, ayahIds: plan.ayahIds);
  }

  /// Confirme (ou annule) l'acquisition de versets appris le jour [date] —
  /// check-out, en deux batchs (appris / à continuer). Annuler écrit
  /// explicitement `reach = 0` plutôt que de s'abstenir : la ligne peut déjà
  /// être à 1 (rakaa d'apprentissage cochée dans PlanScreen), voir CLAUDE.md
  /// § « Modèle de données central ».
  Future<void> markLearnVerses(
      String date, int surahId, List<int> ayahIds, bool learned) async {
    await AyahFactsService.setReachForVerses(
        date, _riwaya, surahId, ayahIds, learned,
        type: AyahFactType.learn);
  }

  /// Toute sourate entièrement mémorisée bascule automatiquement dans la
  /// sélection de révision et quitte l'apprentissage — « à la fin de
  /// l'apprentissage d'une sourate celle-ci devient à réviser » (cadrage
  /// Phase 9). Remplace l'ancien bouton manuel « Ajouter à la révision » de
  /// l'onglet Apprendre (supprimé). Retourne les sourates qui viennent de
  /// basculer, pour que l'appelant puisse le signaler à l'utilisateur.
  /// Appelé au check-out (avec `notify: false`, qui notifie lui-même une
  /// seule fois pour toute l'opération) et au retour de l'écran de pratique.
  ///
  /// La sourate rejoint `selections` **sans** passer par [saveConfig], qui
  /// remettrait `cyclePosition` à 0 : une sourate fraîchement mémorisée
  /// s'ajoute au cycle en cours, elle n'invalide pas la position déjà
  /// atteinte dans les autres.
  Future<List<Sourate>> handOffLearnedSurahs({bool notify = true}) async {
    if (_config == null) return const [];
    final handed = <Sourate>[];
    for (final p in await learningProgressList()) {
      // Déjà basculée lors d'un check-out précédent : ni ré-ajoutée, ni
      // re-signalée. C'est ce test — et non la suppression des faits
      // `learn` — qui rend la bascule idempotente : ces faits sont la trace
      // de mémorisation qui alimente « Sourates mémorisées » (Récap,
      // Réglages), les effacer remettrait ce compteur à 0 pour toujours.
      if (!p.isComplete ||
          _config!.selections.any((s) => s.sourate.id == p.sourate.id)) {
        continue;
      }
      _config = _config!.copyWith(
          selections: [..._config!.selections, SourateSelection.whole(p.sourate)]);
      await StorageService.saveConfig(_config!, _riwaya);
      handed.add(p.sourate);
    }
    if (notify && handed.isNotEmpty) notifyListeners();
    return handed;
  }

  /// How many cycle PAGES day [date] actually completed, starting from
  /// `selection.cyclePosition` — this is what advances the cursor (the full
  /// business rule lives on [checkOut] and in `CLAUDE.md`).
  ///
  /// Counting does not stop at what the engine had proposed: it carries on
  /// into the NEXT pages of the cycle, so declaring extra work moves the
  /// cursor. A page beyond the proposal only counts if the user actually
  /// declared it that day, otherwise the cursor would skip never-revised
  /// content.
  Future<int> _completedPagesFor(String date, DaySelection selection) async {
    final cycle = RevisionEngine.buildCycle(
      config: _config!,
      pageMetadata: PageMetadataService.pageMetadataFor(_riwaya),
    );
    final proposedCount = selection.groups.length;
    int pagesCompleted = 0;
    for (int step = 0; step < cycle.length; step++) {
      final group = cycle[(selection.cyclePosition + step) % cycle.length];
      bool anyExists = false;
      for (final unit in group) {
        final status = await AyahFactsService.rangeStatus(
            date, _riwaya, unit.sourate.id, unit.verseStart, unit.verseEnd);
        if (!status.exists) continue; // retirée au check-in — ne bloque pas
        anyExists = true;
        // Unité présente mais pas faite : le groupe, et toute la suite, bloque.
        if (!status.reached) return pagesCompleted;
      }
      if (!anyExists) {
        // Aucune ligne pour ce groupe. Dans la proposition du jour, c'est un
        // retrait au check-in : ni compté ni bloquant. Au-delà, c'est
        // simplement du contenu non fait : le cycle s'arrête là.
        if (step < proposedCount) continue;
        return pagesCompleted;
      }
      pagesCompleted++;
    }
    return pagesCompleted;
  }

  /// Scelle la journée [date] (check-out) : verrouille ses lignes et fait
  /// avancer le cycle une seule fois pour toute la journée, à partir des
  /// GROUPES proposés par le moteur qui ont effectivement `reach=1` (dans
  /// l'ordre — même logique que la déclaration partielle historique de
  /// PlanScreen : un ajout hors-sélection au check-in alimente l'historique/
  /// la fraîcheur mais ne fait pas avancer `cyclePosition` au-delà de ce que
  /// le moteur avait initialement proposé ce jour-là — le cadrage n'a pas
  /// tranché de règle plus précise pour les ajouts hors-cycle, voir
  /// CHANGELOG). `cyclePosition` avance par GROUPE complété
  /// (`DaySelection.groups`), pas par unité individuelle : plusieurs courtes
  /// sourates qui partagent la même page réelle du mushaf forment un seul
  /// groupe/une seule position de cycle (voir cadrage "regroupement par page
  /// partagée", 2026-09-05) — les compter une par une désynchroniserait
  /// `cyclePosition` de `cycleTotal` (qui compte des groupes). Au sein d'un
  /// groupe, une unité entièrement retirée au check-in ([removeFromDayPlan])
  /// n'a plus aucune ligne en base : elle est ignorée (ni comptée ni
  /// bloquante) — seule une unité *présente* mais non faite bloque le groupe
  /// (et arrête le comptage des groupes suivants), sans quoi elle romprait à
  /// tort le comptage des groupes suivants réellement complétés (bug trouvé
  /// en revue de code). Un groupe dont TOUTES les unités ont été retirées est
  /// lui-même ignoré (ni compté ni bloquant), pour la même raison.
  ///
  /// **Idempotent sur le cycle** (Phase 9 Sprint 2) : re-clôturer une journée
  /// déjà scellée réécrit les `reach` corrigés mais ne fait plus avancer
  /// `cyclePosition` — voir le commentaire dans le corps. Retourne `true` si
  /// le cycle vient de boucler (milestone à afficher côté écran).
  Future<bool> checkOut(String date) async {
    if (_config == null) return false;
    // Passe moteur (CPU pur) et lecture SQLite indépendantes — démarrées
    // ensemble plutôt qu'en série.
    final sealedF = AyahFactsService.isDaySealed(date, _riwaya);
    final selection = _selection;
    // Une journée déjà scellée peut être re-clôturée : « Clôturer ma journée »
    // (Phase 9 Sprint 2) n'empêche pas de relancer une manche derrière, et le
    // check-out qui suivrait scellerait le même jour une seconde fois. Les
    // corrections de `reach` continuent de s'écrire normalement, mais le
    // cycle ne doit avancer qu'une seule fois pour un jour donné — sinon le
    // curseur sauterait du contenu jamais révisé, exactement ce que le
    // garde-fou de [_completedPagesFor] cherche à éviter.
    final pagesCompleted =
        await sealedF ? 0 : await _completedPagesFor(date, selection);
    final cycleWraps = pagesCompleted > 0 &&
        selection.cycleTotal > 0 &&
        (_cyclePosition + pagesCompleted) >= selection.cycleTotal;
    _pendingDate = null;
    _closedDate = date;
    _todaySession = null;
    // Écritures indépendantes (table ayah_facts, prefs, cycle) — lancées en
    // parallèle plutôt qu'en série.
    await Future.wait([
      AyahFactsService.sealDay(date, _riwaya),
      refreshFreshness(notify: false),
      StorageService.clearActivePrayers(_riwaya),
      advanceCycle(pagesCompleted, selection.cycleTotal, notify: false),
    ]);
    // Après le scellement seulement : une sourate dont le dernier verset
    // vient d'être confirmé appris rejoint la révision (voir
    // [handOffLearnedSurahs]).
    await handOffLearnedSurahs(notify: false);
    notifyListeners(); // seul notify de toute l'opération
    return cycleWraps;
  }
}
