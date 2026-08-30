import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/strings.dart';
import '../models/revision_unit.dart';
import '../screens/check_in_screen.dart';
import '../screens/check_out_screen.dart';
import '../screens/home_screen.dart';
import '../screens/plan_screen.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import '../widgets/manual_session_sheet.dart';

/// Gère la logique de routing du tab "Réviser" :
///   - Jour en attente (non scellé) → popup CheckOutScreen (rattrapage)
///   - Plan du jour généré, pas encore vu → popup CheckInScreen
///   - Prières choisies pour la manche → PlanScreen (répartition en rakaas)
///   - Sinon                          → HomeScreen (choix des prières)
///
/// Depuis Phase 6 Sprint 2, PlanScreen ne génère plus son propre plan : il
/// répartit les unités déjà validées au check-in (voir cadrage, "Moteur
/// quotidien — source unique de vérité"). Check-in et check-out sont tous
/// deux des popups poussés en plein écran (`Navigator.push`), jamais des
/// corps d'onglet directement — CheckOutScreen appelle `Navigator.pop()` en
/// se fermant, ça ne fonctionnerait pas s'il était rendu en place.
class DayPlanTab extends StatefulWidget {
  const DayPlanTab({super.key});

  @override
  State<DayPlanTab> createState() => _DayPlanTabState();
}

class _DayPlanTabState extends State<DayPlanTab> {
  bool _checkInShown = false;
  bool _checkOutShown = false;

  /// Manche PlanScreen complétée : marque les unités couvertes comme
  /// "faites" (`reach=1`). N'avance plus `cyclePosition` — c'est le
  /// check-out qui le fait, une fois par jour scellé (voir AppState.checkOut).
  Future<void> _onComplete(BuildContext context, AppState state,
      int unitsCompleted, List<RevisionUnit> coveredUnits) async {
    final prayersAlone = state.todaySession!.prayersAlone;
    await state.markUnitsReached(coveredUnits);
    // Indépendantes — lancées en parallèle plutôt qu'en série.
    await Future.wait([
      state.refreshAdaptiveCycle(state.config!.totalSelectedVerses, notify: false),
      state.refreshFreshness(notify: false),
      StorageService.saveLastSessionPrayers(DateTime.now(), prayersAlone, state.riwaya),
    ]);
    await state.clearTodaySession();
  }

  Future<void> _showManualSheet(BuildContext context, AppState state) async {
    if (state.config == null) return;
    final dayUnits = await state.dayUnits();
    if (dayUnits.isEmpty || !context.mounted) return;
    final units = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualSessionSheet(maxUnits: dayUnits.length),
    );
    if (units != null && context.mounted) {
      await _onManualSession(context, state, units, dayUnits);
    }
  }

  /// Saisie manuelle : marque les [units] premières unités du plan du jour
  /// déjà validé au check-in comme "faites" — même hypothèse d'ordre que
  /// PlanScreen (les unités du plan, dans l'ordre où le check-in les liste).
  Future<void> _onManualSession(BuildContext context, AppState state,
      int units, List<RevisionUnit> dayUnits) async {
    if (units <= 0) return;
    final covered = dayUnits.take(units).toList();
    await state.markUnitsReached(covered);
    await Future.wait([
      state.refreshAdaptiveCycle(state.config!.totalSelectedVerses, notify: false),
      state.refreshFreshness(notify: true),
    ]);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.sessionLoggee),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _maybeShowCheckOut(AppState state) {
    if (state.pendingDate == null || _checkOutShown) return;
    _checkOutShown = true;
    final date = state.pendingDate!;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CheckOutScreen(date: date),
        ),
      );
      _checkOutShown = false;
    });
  }

  void _maybeShowCheckIn(AppState state) {
    if (!state.justCheckedIn || _checkInShown) return;
    _checkInShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const CheckInScreen(),
        ),
      );
      _checkInShown = false;
      // Que le popup ait été validé ou fermé (retour), pas de sens à le
      // réafficher pour le même plan généré aujourd'hui.
      if (mounted) await context.read<AppState>().acknowledgeCheckIn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.pendingDate != null) {
      // Le popup de rattrapage est poussé en plein écran (voir
      // _maybeShowCheckOut) ; en dessous, un simple indicateur de
      // chargement le temps qu'il s'affiche.
      _maybeShowCheckOut(state);
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _maybeShowCheckIn(state);

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

    return HomeScreen(
      onVoirPlan: (prayersAlone) => state.buildTodaySession(prayersAlone),
      onSaisirManuel: () => _showManualSheet(context, state),
    );
  }
}
