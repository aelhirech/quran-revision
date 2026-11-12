part of 'app_state.dart';

// ─── Order of the round (US-26) ───────────────────────────────────────────
//
// Drawn when a round starts (wrap at check-out, shuffle toggled, selection
// changed) and stored in `UserConfig.tourOrder`; `buildCycle` only reads it.

extension AppStateTour on AppState {
  /// The order a round would get today, from this riwaya's revision history.
  /// Public for the onboarding, whose day-1 preview must show the order it
  /// will save.
  List<int> computeTourOrder(
          List<SourateSelection> selections, bool shuffle, Random random) =>
      TourOrder.compute(
        selections: selections,
        shuffle: shuffle,
        lastRevisionByAyah: _lastRevisionByAyah,
        today: DateTime.now(),
        random: random,
      );

  /// [config] with a round order freshly drawn. Reloads the history first:
  /// ShellScreen's load at startup is not awaited, and a draw must never run
  /// on a stale or empty history.
  Future<UserConfig> _withNewTourOrder(UserConfig config) async {
    await refreshFreshness(notify: false);
    return config.copyWith(
      tourOrder:
          computeTourOrder(config.selections, config.shuffleEnabled, _random),
    );
  }

  /// Starts a round of [config] with a freshly drawn order, cursor at 0.
  /// [config] is only adopted once drawn: a failed history read leaves the
  /// previous config whole.
  Future<void> _startNewTour(UserConfig config) async {
    _config = await _withNewTourOrder(config);
    _cyclePosition = 0;
    await StorageService.saveConfig(_config!, _riwaya);
    await StorageService.saveCyclePosition(0, _riwaya);
  }

  /// Toggling the shuffle starts a new round, drawn in the new mode.
  ///
  /// Returns `false` (config left untouched) under the same [pendingDate]
  /// guard as [saveConfig]: the round order changes just as it does on a
  /// selection change, so flipping this mid-pending-day would corrupt that
  /// day's seal the same way an unguarded selection change would.
  Future<bool> setShuffleEnabled(bool enabled) async {
    if (_config == null || _config!.shuffleEnabled == enabled) return true;
    if (_pendingDate != null) return false;
    await _startNewTour(_config!.copyWith(shuffleEnabled: enabled));
    _todaySession = null;
    _notify();
    return true;
  }
}
