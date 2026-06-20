import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/revision_engine.dart';
import '../models/session_record.dart';
import '../screens/home_screen.dart';
import '../screens/plan_screen.dart';
import '../services/history_service.dart';
import '../state/app_state.dart';

/// Gère la logique de routing du tab "Plan du jour" :
///   - Aucune session    → HomeScreen (sélection des prières)
///   - Session en aperçu → PlanScreen en mode preview
///   - Session engagée   → PlanScreen en mode actif
class DayPlanTab extends StatelessWidget {
  const DayPlanTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.todaySession != null) {
      return PlanScreen(
        key: ValueKey(state.todaySession),
        session: state.todaySession!,
        onComplete: (unitsCompleted) {
          final allUnits =
              RevisionEngine.buildUnits(state.config!.selections);
          state.advanceCycle(unitsCompleted, allUnits.length);
          HistoryService.recordSession(SessionRecord(
            date: DateTime.now(),
            unitsCompleted: unitsCompleted,
            totalUnits: allUnits.length,
            prayers: state.todaySession!.prayersAlone
                .map((p) => p.name)
                .toList(),
          ));
          state.clearTodaySession();
        },
        onChangePlan: () => state.clearTodaySession(),
      );
    }

    if (state.previewSession != null) {
      return PlanScreen(
        key: ValueKey(state.previewSession),
        session: state.previewSession!,
        isPreview: true,
        onEngager: () => state.engager(),
        onChangePlan: () => state.clearPreview(),
      );
    }

    return HomeScreen(
      onVoirPlan: (session) => state.setPreviewSession(session),
    );
  }
}
