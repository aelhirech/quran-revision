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
import '../widgets/manual_session_sheet.dart';

/// Gère la logique de routing du tab "Plan du jour" :
///   - Aucune session    → HomeScreen (sélection des prières)
///   - Session en aperçu → PlanScreen en mode preview
///   - Session engagée   → PlanScreen en mode actif
class DayPlanTab extends StatelessWidget {
  const DayPlanTab({super.key});

  Future<void> _onComplete(BuildContext context, AppState state,
      int unitsCompleted, Set<int> sourateIds) async {
    final allUnits = RevisionEngine.buildUnits(state.config!.selections);
    final cycleTotal = allUnits.length;
    final cycleWraps =
        cycleTotal > 0 && (state.cyclePosition + unitsCompleted) >= cycleTotal;

    // Capturer l'instant une seule fois — évite un décalage de date si minuit passe
    final now = DateTime.now();
    final sessionDate = now.toIso8601String().substring(0, 10);

    // Les 3 écritures sont indépendantes (prefs cyclePosition, table
    // sessions, table sourate_sessions) — lancées en parallèle. Les deux
    // rafraîchissements qui suivent lisent chacun l'une de ces écritures et
    // doivent donc attendre qu'elle soit posée (refreshAdaptiveCycle après
    // recordSession, sinon la moyenne reste en retard d'une session comme la
    // saisie manuelle le fait déjà correctement ; refreshFreshness après
    // recordSourateHistory).
    final recordSessionF = HistoryService.recordSession(
        SessionRecord(
          date: now,
          unitsCompleted: unitsCompleted,
          totalUnits: cycleTotal,
          prayers:
              state.todaySession!.prayersAlone.map((p) => p.name).toList(),
        ),
        state.riwaya);
    // Ne marque comme "revues" (fraîcheur) que les sourates réellement
    // couvertes par ce qui a été déclaré/coché — pas tout le plan du jour.
    final recordSourateHistoryF = HistoryService.recordSourateHistory(
        sessionDate, sourateIds.toList(), state.riwaya);
    await Future.wait([
      state.advanceCycle(unitsCompleted, cycleTotal),
      recordSessionF,
      recordSourateHistoryF,
    ]);
    await Future.wait([
      state.refreshAdaptiveCycle(cycleTotal, notify: false),
      state.refreshFreshness(notify: false),
    ]);

    if (cycleWraps && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _CycleMilestoneDialog(),
      );
    }

    await state.clearTodaySession();
  }

  Future<void> _showManualSheet(BuildContext context, AppState state) async {
    if (state.config == null) return;
    final cycleTotal = RevisionEngine.buildUnits(state.config!.selections).length;
    final units = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualSessionSheet(maxUnits: cycleTotal.clamp(1, 999)),
    );
    if (units != null && context.mounted) {
      await _onManualSession(context, state, units, cycleTotal);
    }
  }

  Future<void> _onManualSession(
      BuildContext context, AppState state, int units, int cycleTotal) async {
    if (units <= 0 || state.config == null) return;
    final now = DateTime.now();
    await HistoryService.recordSession(
        SessionRecord(
          date: now,
          unitsCompleted: units,
          totalUnits: cycleTotal,
          prayers: const [],
        ),
        state.riwaya);
    await state.advanceCycle(units, cycleTotal);
    await state.refreshAdaptiveCycle(cycleTotal, notify: false);
    await state.refreshFreshness(notify: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.sessionLoggee),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.todaySession != null) {
      return PlanScreen(
        key: ValueKey(state.todaySession),
        session: state.todaySession!,
        freshnessOf: state.freshnessFor,
        onComplete: (unitsCompleted, sourateIds) =>
            _onComplete(context, state, unitsCompleted, sourateIds),
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
      onSaisirManuel: () => _showManualSheet(context, state),
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
