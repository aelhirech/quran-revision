part of 'app_state.dart';

extension AppStateReinforcement on AppState {
  /// Read-only inputs of a series: carried verses, and today's among them.
  Future<({Map<int, Set<int>> carried, Set<(int, int)> today})>
      reinforcementInputs() async {
    if (_config == null) {
      return (carried: <int, Set<int>>{}, today: <(int, int)>{});
    }
    final learningF = learningProgressList();
    final unitsF = dayUnits();
    final carried = ReinforcementEngine.carriedVerses(
        selections: _config!.selections, learning: await learningF);
    final today = {
      for (final unit in await unitsF)
        for (final verse in unit.verses)
          if (carried[unit.sourate.id]?.contains(verse) ?? false)
            (unit.sourate.id, verse),
    };
    return (carried: carried, today: today);
  }
}
