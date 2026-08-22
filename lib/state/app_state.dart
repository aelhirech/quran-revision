import 'package:flutter/foundation.dart';
import '../core/freshness_engine.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../models/riwaya.dart';
import '../models/user_config.dart';
import '../services/history_service.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  UserConfig? _config;
  int _cyclePosition;
  DailySession? _previewSession;
  DailySession? _todaySession;
  Set<String> _pauseDates;
  String _locale;
  Riwaya _riwaya;
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
        _cyclePosition = initialCyclePosition,
        _previewSession = initialPreviewSession,
        _todaySession = initialTodaySession,
        _pauseDates = Set.from(initialPauseDates),
        _checkedRakaas = initialCheckedRakaas.map((k, v) => MapEntry(k, Set.from(v))) {
    S.locale = locale;
  }

  UserConfig? get config => _config;
  int get cyclePosition => _cyclePosition;
  DailySession? get previewSession => _previewSession;
  DailySession? get todaySession => _todaySession;
  Set<String> get pauseDates => Set.unmodifiable(_pauseDates);
  Map<int, Set<int>> get checkedRakaas => _checkedRakaas;
  String get locale => _locale;
  Riwaya get riwaya => _riwaya;
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
    await StorageService.savePauseDates(_pauseDates);
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    _locale = locale;
    S.locale = locale;
    await StorageService.saveLocale(locale);
    notifyListeners();
  }

  Future<void> setRiwaya(Riwaya riwaya) async {
    _riwaya = riwaya;
    await StorageService.saveRiwaya(riwaya);
    notifyListeners();
  }

  Future<void> saveConfig(UserConfig config) async {
    _config = config;
    _cyclePosition = 0;
    _todaySession = null;
    _checkedRakaas = {};
    await StorageService.saveConfig(config);
    await StorageService.saveCyclePosition(0);
    await StorageService.clearTodaySession();
    await StorageService.clearPreviewSession();
    await StorageService.clearCheckedRakaas();
    notifyListeners();
  }

  Future<void> advanceCycle(int unitsCompleted, int cycleTotal) async {
    if (cycleTotal == 0) return;
    // Délègue le calcul à RevisionEngine — source unique de vérité pour la progression
    _cyclePosition = RevisionEngine.advanceCycle(
      currentPosition: _cyclePosition,
      unitsCompleted: unitsCompleted,
      cycleTotal: cycleTotal,
    );
    await StorageService.saveCyclePosition(_cyclePosition);
    notifyListeners();
  }

  Future<void> setPreviewSession(DailySession session) async {
    _previewSession = session;
    await StorageService.savePreviewSession(session);
    notifyListeners();
    // Charger la fraîcheur en arrière-plan — badges apparaissent dès que la DB répond
    // catchError : si la DB échoue, badges absents mais pas de crash
    refreshFreshness().catchError((_) {});
  }

  /// Recalcule la fraîcheur depuis l'historique des révisions par sourate.
  /// Appelé quand une session démarre et après chaque session complétée.
  Future<void> refreshFreshness({bool notify = true}) async {
    final dates = await HistoryService.lastRevisionDates();
    _freshness = FreshnessEngine.computeAll(dates, DateTime.now());
    if (notify) notifyListeners();
  }

  Future<void> engager() async {
    _todaySession = _previewSession;
    _previewSession = null;
    if (_todaySession != null) {
      await StorageService.saveTodaySession(_todaySession!);
    }
    await StorageService.clearPreviewSession();
    notifyListeners();
  }

  Future<void> clearPreview() async {
    _previewSession = null;
    await StorageService.clearPreviewSession();
    notifyListeners();
  }

  Future<void> clearTodaySession() async {
    _todaySession = null;
    _previewSession = null;
    _checkedRakaas = {};
    await StorageService.clearTodaySession();
    await StorageService.clearPreviewSession();
    await StorageService.clearCheckedRakaas();
    notifyListeners();
  }

  /// Coche/décoche une rakaa de la session du jour en cours et persiste
  /// immédiatement — évite de perdre la progression si l'app est relancée
  /// avant que la session soit marquée complète.
  Future<void> toggleChecked(int prayerIndex, int rakaaNumber) async {
    final set = _checkedRakaas.putIfAbsent(prayerIndex, () => {});
    if (!set.remove(rakaaNumber)) set.add(rakaaNumber);
    await StorageService.saveCheckedRakaas(_checkedRakaas);
    notifyListeners();
  }

  /// Recalcule la durée adaptive depuis l'historique.
  /// Appelé après chaque session et quand le toggle adaptatif est activé.
  Future<void> refreshAdaptiveCycle(int totalUnits, {bool notify = true}) async {
    if (_config?.adaptiveCycle != true || totalUnits <= 0) return;
    final avg = await HistoryService.avgUnitsPerDay();
    if (avg > 0) {
      _adaptiveCycleDays = (totalUnits / avg).ceil();
      if (notify) notifyListeners();
    }
  }

  Future<void> setAdaptiveCycle(bool enabled, {int totalUnits = 0}) async {
    if (_config == null) return;
    _config = _config!.copyWith(adaptiveCycle: enabled);
    await StorageService.saveConfig(_config!);
    if (enabled) await refreshAdaptiveCycle(totalUnits, notify: false);
    notifyListeners();
  }

  Future<void> setShuffleEnabled(bool enabled) async {
    if (_config == null) return;
    _config = _config!.copyWith(shuffleEnabled: enabled);
    await StorageService.saveConfig(_config!);
    notifyListeners();
  }

  Future<void> clearConfig() async {
    _config = null;
    _cyclePosition = 0;
    _todaySession = null;
    _previewSession = null;
    _pauseDates = {};
    _checkedRakaas = {};
    await StorageService.clear();
    notifyListeners();
  }
}
