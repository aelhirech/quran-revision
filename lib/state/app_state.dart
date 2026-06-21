import 'package:flutter/foundation.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
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
  // Durée de cycle calculée depuis l'historique (mode adaptatif uniquement)
  int? _adaptiveCycleDays;

  AppState(
    this._config, {
    String locale = 'fr',
    int initialCyclePosition = 0,
    DailySession? initialPreviewSession,
    DailySession? initialTodaySession,
    Set<String> initialPauseDates = const {},
  })  : _locale = locale,
        _cyclePosition = initialCyclePosition,
        _previewSession = initialPreviewSession,
        _todaySession = initialTodaySession,
        _pauseDates = Set.from(initialPauseDates) {
    S.locale = locale;
  }

  UserConfig? get config => _config;
  int get cyclePosition => _cyclePosition;
  DailySession? get previewSession => _previewSession;
  DailySession? get todaySession => _todaySession;
  Set<String> get pauseDates => Set.unmodifiable(_pauseDates);
  String get locale => _locale;
  /// Retourne la durée adaptive uniquement si le mode est activé.
  int? get adaptiveCycleDays =>
      _config?.adaptiveCycle == true ? _adaptiveCycleDays : null;

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

  Future<void> saveConfig(UserConfig config) async {
    _config = config;
    _cyclePosition = 0;
    _todaySession = null;
    await StorageService.saveConfig(config);
    await StorageService.saveCyclePosition(0);
    await StorageService.clearTodaySession();
    await StorageService.clearPreviewSession();
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
    await StorageService.clearTodaySession();
    await StorageService.clearPreviewSession();
    notifyListeners();
  }

  /// Recalcule la durée adaptive depuis l'historique.
  /// Appelé après chaque session et quand le toggle adaptatif est activé.
  Future<void> refreshAdaptiveCycle(int totalUnits) async {
    if (_config?.adaptiveCycle != true || totalUnits <= 0) return;
    final avg = await HistoryService.avgUnitsPerDay();
    if (avg > 0) {
      _adaptiveCycleDays = (totalUnits / avg).ceil();
      notifyListeners();
    }
  }

  Future<void> setAdaptiveCycle(bool enabled, {int totalUnits = 0}) async {
    if (_config == null) return;
    _config = _config!.copyWith(adaptiveCycle: enabled);
    await StorageService.saveConfig(_config!);
    if (enabled) await refreshAdaptiveCycle(totalUnits);
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
    await StorageService.clear();
    notifyListeners();
  }
}
