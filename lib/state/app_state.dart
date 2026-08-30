import 'package:flutter/foundation.dart';
import '../core/freshness_engine.dart';
import '../core/quran_data.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
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
  DailySession? _previewSession;
  DailySession? _todaySession;
  Set<String> _pauseDates;
  String _locale;
  Riwaya _riwaya;
  final bool warshAvailable;
  bool _hasSeenTour;
  List<Sourate> _sourates;
  // Rakaas cochées dans la session du jour (prayerIndex → n° de rakaas),
  // persistées pour ne pas perdre la progression au redémarrage de l'app.
  Map<int, Set<int>> _checkedRakaas;
  // Durée de cycle calculée depuis l'historique (mode adaptatif uniquement)
  int? _adaptiveCycleDays;
  // Fraîcheur par sourate (sourateId → niveau)
  Map<int, FreshnessLevel> _freshness = {};

  AppState(
    this._config, {
    String locale = 'fr',
    Riwaya riwaya = Riwaya.hafs,
    this.warshAvailable = true,
    bool initialHasSeenTour = false,
    int initialCyclePosition = 0,
    DailySession? initialPreviewSession,
    DailySession? initialTodaySession,
    Set<String> initialPauseDates = const {},
    Map<int, Set<int>> initialCheckedRakaas = const {},
  })  : _locale = locale,
        // `riwaya` must stay a public named arg for callers — `this._riwaya`
        // would make the constructor arg private.
        // ignore: prefer_initializing_formals
        _riwaya = riwaya,
        _hasSeenTour = initialHasSeenTour,
        _sourates = _souratesFor(riwaya),
        _cyclePosition = initialCyclePosition,
        _previewSession = initialPreviewSession,
        _todaySession = initialTodaySession,
        _pauseDates = Set.from(initialPauseDates),
        _checkedRakaas = initialCheckedRakaas.map((k, v) => MapEntry(k, Set.from(v))) {
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
  DailySession? get previewSession => _previewSession;
  DailySession? get todaySession => _todaySession;
  Set<String> get pauseDates => Set.unmodifiable(_pauseDates);
  Map<int, Set<int>> get checkedRakaas => _checkedRakaas;
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

  /// Retourne le niveau de fraîcheur d'une sourate. Null = jamais calculé.
  FreshnessLevel? freshnessFor(int sourateId) => _freshness[sourateId];

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
  /// parcours indépendant (config, cycle, sessions, progression, historique
  /// séparés) — rien n'est traduit d'un parcours vers l'autre. Si le
  /// parcours cible n'a jamais été configuré, `config` redevient `null` et
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
    final previewSessionF = StorageService.loadPreviewSession(_riwaya);
    final todaySessionF = StorageService.loadTodaySession(_riwaya);
    final pauseDatesF = StorageService.loadPauseDates(_riwaya);
    final checkedRakaasF = StorageService.loadCheckedRakaas(_riwaya);
    _config = await configF;
    _cyclePosition = await cyclePositionF;
    _previewSession = await previewSessionF;
    _todaySession = await todaySessionF;
    _pauseDates = await pauseDatesF;
    _checkedRakaas = await checkedRakaasF;
    _sourates = _souratesFor(_riwaya);
    _adaptiveCycleDays = null;
    await refreshFreshness(notify: false);
    if (_config?.adaptiveCycle == true) {
      await refreshAdaptiveCycle(_config!.totalSelectedVerses, notify: false);
    }
  }

  /// Ne remet le cycle à zéro que si les sourates sélectionnées ont vraiment
  /// changé — un simple ajustement du rythme (durée, lignes/jour) ne doit pas
  /// effacer la progression ni la session du jour en cours.
  Future<void> saveConfig(UserConfig config) async {
    final selectionsChanged =
        _config == null || !_sameSelections(_config!.selections, config.selections);
    _config = config;
    await StorageService.saveConfig(config, _riwaya);
    if (selectionsChanged) {
      _cyclePosition = 0;
      _todaySession = null;
      await StorageService.saveCyclePosition(0, _riwaya);
      await StorageService.clearTodaySession(_riwaya);
      await StorageService.clearPreviewSession(_riwaya);
      await _resetCheckedRakaas();
    }
    notifyListeners();
  }

  bool _sameSelections(List<SourateSelection> a, List<SourateSelection> b) {
    if (a.length != b.length) return false;
    String key(SourateSelection s) =>
        '${s.sourate.id}:${s.verseStart}:${s.verseEnd}';
    return a.map(key).toSet().containsAll(b.map(key));
  }

  Future<void> advanceCycle(int unitsCompleted, int cycleTotal) async {
    if (cycleTotal == 0) return;
    // Délègue le calcul à RevisionEngine — source unique de vérité pour la progression
    _cyclePosition = RevisionEngine.advanceCycle(
      currentPosition: _cyclePosition,
      unitsCompleted: unitsCompleted,
      cycleTotal: cycleTotal,
    );
    await StorageService.saveCyclePosition(_cyclePosition, _riwaya);
    notifyListeners();
  }

  Future<void> setPreviewSession(DailySession session) async {
    _previewSession = session;
    await StorageService.savePreviewSession(session, _riwaya);
    notifyListeners();
    // Charger la fraîcheur en arrière-plan — badges apparaissent dès que la DB répond
    // catchError : si la DB échoue, badges absents mais pas de crash
    refreshFreshness().catchError((_) {});
  }

  /// Recalcule la fraîcheur depuis l'historique des révisions par sourate.
  /// Appelé quand une session démarre et après chaque session complétée.
  Future<void> refreshFreshness({bool notify = true}) async {
    final dates = await AyahFactsService.lastRevisionDatesPerSourate(riwaya: _riwaya);
    _freshness = FreshnessEngine.computeAll(dates, DateTime.now());
    if (notify) notifyListeners();
  }

  Future<void> engager() async {
    _todaySession = _previewSession;
    _previewSession = null;
    if (_todaySession != null) {
      await StorageService.saveTodaySession(_todaySession!, _riwaya);
    }
    await StorageService.clearPreviewSession(_riwaya);
    notifyListeners();
  }

  Future<void> clearPreview() async {
    _previewSession = null;
    await StorageService.clearPreviewSession(_riwaya);
    notifyListeners();
  }

  Future<void> clearTodaySession() async {
    _todaySession = null;
    _previewSession = null;
    await StorageService.clearTodaySession(_riwaya);
    await StorageService.clearPreviewSession(_riwaya);
    await _resetCheckedRakaas();
    notifyListeners();
  }

  Future<void> _resetCheckedRakaas() async {
    _checkedRakaas = {};
    await StorageService.clearCheckedRakaas(_riwaya);
  }

  /// Coche/décoche une rakaa de la session du jour en cours et persiste
  /// immédiatement — évite de perdre la progression si l'app est relancée
  /// avant que la session soit marquée complète. `notifyListeners` se déclenche
  /// avant l'écriture disque pour que la coche s'affiche sans attendre le
  /// round-trip SharedPreferences.
  Future<void> toggleChecked(int prayerIndex, int rakaaNumber) async {
    final set = _checkedRakaas.putIfAbsent(prayerIndex, () => {});
    if (!set.remove(rakaaNumber)) set.add(rakaaNumber);
    notifyListeners();
    await StorageService.saveCheckedRakaas(_checkedRakaas, _riwaya);
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
    _previewSession = null;
    _pauseDates = {};
    _checkedRakaas = {};
    await StorageService.clearConfigOnly(_riwaya);
    notifyListeners();
  }
}
