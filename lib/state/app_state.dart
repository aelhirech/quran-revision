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

part 'app_state_dayplan.dart';
part 'app_state_checkout.dart';
part 'app_state_learning.dart';

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

  /// `notifyListeners()` is `@protected` (only callable from instance members
  /// of a `ChangeNotifier` subclass) — the domain extensions in
  /// `app_state_*.dart` are not instance members, so they call this instead.
  void _notify() => notifyListeners();

  Sourate? _sourateById(int id) {
    for (final s in _sourates) {
      if (s.id == id) return s;
    }
    return null;
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
}
