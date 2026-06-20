import 'package:flutter/foundation.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../models/user_config.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  UserConfig? _config;
  int _cyclePosition;
  DailySession? _previewSession;
  DailySession? _todaySession;
  String _locale;

  AppState(
    this._config, {
    String locale = 'fr',
    int initialCyclePosition = 0,
  })  : _locale = locale,
        _cyclePosition = initialCyclePosition {
    S.locale = locale;
  }

  UserConfig? get config => _config;
  int get cyclePosition => _cyclePosition;
  DailySession? get previewSession => _previewSession;
  DailySession? get todaySession => _todaySession;
  String get locale => _locale;

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
    notifyListeners();
  }

  Future<void> advanceCycle(int unitsCompleted, int cycleTotal) async {
    if (cycleTotal == 0) return;
    _cyclePosition = (_cyclePosition + unitsCompleted) % cycleTotal;
    await StorageService.saveCyclePosition(_cyclePosition);
    notifyListeners();
  }

  void setPreviewSession(DailySession session) {
    _previewSession = session;
    notifyListeners();
  }

  void engager() {
    _todaySession = _previewSession;
    _previewSession = null;
    notifyListeners();
  }

  void clearPreview() {
    _previewSession = null;
    notifyListeners();
  }

  void clearTodaySession() {
    _todaySession = null;
    _previewSession = null;
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
    await StorageService.clear();
    notifyListeners();
  }
}
