import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
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

  Future<void> _onComplete(
      BuildContext context, AppState state, int unitsCompleted) async {
    final allUnits = RevisionEngine.buildUnits(state.config!.selections);
    final cycleTotal = allUnits.length;
    final cycleWraps =
        cycleTotal > 0 && (state.cyclePosition + unitsCompleted) >= cycleTotal;

    // Capturer l'instant une seule fois — évite un décalage de date si minuit passe
    final now = DateTime.now();
    final sessionDate = now.toIso8601String().substring(0, 10);

    // Sourates couvertes dans cette session — pour le SRS
    final sessionSourateIds = state.todaySession!.plan
        .expand((pp) => pp.rakaas)
        .where((r) => r.unit != null)
        .map((r) => r.unit!.sourate.id)
        .toSet()
        .toList();

    await state.advanceCycle(unitsCompleted, cycleTotal);
    await state.refreshAdaptiveCycle(cycleTotal, notify: false);
    await HistoryService.recordSession(SessionRecord(
      date: now,
      unitsCompleted: unitsCompleted,
      totalUnits: cycleTotal,
      prayers:
          state.todaySession!.prayersAlone.map((p) => p.name).toList(),
    ));
    await HistoryService.recordSourateHistory(sessionDate, sessionSourateIds);
    await state.refreshFreshness(notify: false);

    if (cycleWraps && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _CycleMilestoneDialog(),
      );
    }

    await state.clearTodaySession();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.todaySession != null) {
      return PlanScreen(
        key: ValueKey(state.todaySession),
        session: state.todaySession!,
        freshnessOf: state.freshnessFor,
        onComplete: (unitsCompleted) =>
            _onComplete(context, state, unitsCompleted),
        onChangePlan: () => state.clearTodaySession(),
      );
    }

    if (state.previewSession != null) {
      return PlanScreen(
        key: ValueKey(state.previewSession),
        session: state.previewSession!,
        freshnessOf: state.freshnessFor,
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

class _CycleMilestoneDialog extends StatelessWidget {
  const _CycleMilestoneDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56))
                .animate()
                .scale(
                  begin: const Offset(0.4, 0.4),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 16),
            Text(
              S.cycleTermineTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              S.cycleTermineBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(S.continuer,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.06),
    );
  }
}
