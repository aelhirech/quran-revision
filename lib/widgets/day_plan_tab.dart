import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../models/revision_unit.dart';
import '../screens/home_screen.dart';
import '../screens/plan_screen.dart';
import '../services/ayah_facts_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import '../widgets/manual_session_sheet.dart';

/// Gère la logique de routing du tab "Plan du jour" :
///   - Aucune session    → HomeScreen (sélection des prières)
///   - Session en aperçu → PlanScreen en mode preview
///   - Session engagée   → PlanScreen en mode actif
class DayPlanTab extends StatelessWidget {
  const DayPlanTab({super.key});

  Future<void> _onComplete(BuildContext context, AppState state,
      int unitsCompleted, List<RevisionUnit> coveredUnits) async {
    final allUnits = RevisionEngine.buildUnits(state.config!.selections);
    final cycleTotal = allUnits.length;
    final cycleWraps =
        cycleTotal > 0 && (state.cyclePosition + unitsCompleted) >= cycleTotal;

    // Capturer l'instant une seule fois — évite un décalage de date si minuit passe
    final now = DateTime.now();
    final sessionDate = now.toIso8601String().substring(0, 10);

    // Ne marque comme "revus" (fraîcheur/streak) que les versets réellement
    // couverts par ce qui a été déclaré/coché — pas tout le plan du jour.
    // Écritures indépendantes (table ayah_facts, prefs "dernières prières")
    // lancées en parallèle.
    final recordFactsF = AyahFactsService.recordRevisedUnits(
        sessionDate, state.riwaya, coveredUnits);
    final saveLastPrayersF = StorageService.saveLastSessionPrayers(
        now, state.todaySession!.prayersAlone, state.riwaya);
    await Future.wait([
      state.advanceCycle(unitsCompleted, cycleTotal),
      recordFactsF,
      saveLastPrayersF,
    ]);
    await Future.wait([
      state.refreshAdaptiveCycle(state.config!.totalSelectedVerses, notify: false),
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
    final allUnits = RevisionEngine.buildUnits(state.config!.selections);
    final units = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualSessionSheet(maxUnits: allUnits.length.clamp(1, 999)),
    );
    if (units != null && context.mounted) {
      await _onManualSession(context, state, units, allUnits);
    }
  }

  Future<void> _onManualSession(BuildContext context, AppState state,
      int units, List<RevisionUnit> allUnits) async {
    if (units <= 0 || state.config == null) return;
    final cycleTotal = allUnits.length;
    // Pas de plan détaillé par rakaa pour la saisie manuelle — les unités
    // couvertes sont dérivées du cycle à partir de la position actuelle,
    // même hypothèse d'ordre de consommation que RevisionEngine.buildDayPlan/
    // advanceCycle. Nécessaire pour alimenter ayah_facts (streak, fraîcheur) :
    // avant Phase 6, HistoryService.recordSession écrivait déjà une ligne
    // pour ce chemin (le streak en dépendait), en perdre l'équivalent ici
    // casserait silencieusement le streak pour qui n'utilise que la saisie
    // manuelle.
    final pos = cycleTotal == 0 ? 0 : state.cyclePosition % cycleTotal;
    final coveredUnits = [
      for (int i = 0; i < units && cycleTotal > 0; i++)
        allUnits[(pos + i) % cycleTotal],
    ];
    final sessionDate = DateTime.now().toIso8601String().substring(0, 10);
    await AyahFactsService.recordRevisedUnits(
        sessionDate, state.riwaya, coveredUnits);
    await state.advanceCycle(units, cycleTotal);
    await state.refreshAdaptiveCycle(state.config!.totalSelectedVerses,
        notify: false);
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
        onComplete: (unitsCompleted, coveredUnits) =>
            _onComplete(context, state, unitsCompleted, coveredUnits),
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
