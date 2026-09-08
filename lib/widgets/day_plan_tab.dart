import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prayer.dart';
import '../screens/check_in_screen.dart';
import '../screens/check_out_screen.dart';
import '../screens/home_screen.dart';
import '../screens/plan_screen.dart';
import '../state/app_state.dart';

/// Gère la logique de routing de l'onglet "Plan du jour" :
///   - Jour en attente (non scellé) → popup CheckOutScreen (rattrapage)
///   - Prières choisies pour la manche → PlanScreen (répartition en rakaas)
///   - Sinon                          → HomeScreen (« Illuminer ma journée »)
///
/// Depuis Phase 6 Sprint 2, PlanScreen ne génère plus son propre plan : il
/// répartit les unités déjà validées au check-in (voir cadrage, "Moteur
/// quotidien — source unique de vérité"). Depuis la Phase 9, le check-in
/// n'est plus poussé automatiquement à l'ouverture de l'app mais déclenché
/// par le bouton « Illuminer ma journée avec le Coran » ; il renvoie les
/// prières du jour, à partir desquelles la répartition en rakaas est faite.
/// Check-in et check-out restent des popups poussés en plein écran
/// (`Navigator.push`), jamais des corps d'onglet directement — CheckOutScreen
/// appelle `Navigator.pop()` en se fermant, ça ne fonctionnerait pas s'il
/// était rendu en place.
class DayPlanTab extends StatefulWidget {
  const DayPlanTab({super.key});

  @override
  State<DayPlanTab> createState() => _DayPlanTabState();
}

class _DayPlanTabState extends State<DayPlanTab> {
  bool _checkOutShown = false;

  /// Pousse le check-out sur [date]. Deux entrées, un seul écran : le
  /// rattrapage automatique d'un jour en attente ([_maybeShowCheckOut]) et le
  /// bouton « Clôturer ma journée » de PlanScreen, qui scelle aujourd'hui
  /// sans attendre le lendemain (Phase 9 Sprint 2).
  Future<void> _openCheckOut(String date) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CheckOutScreen(date: date),
        ),
      );

  /// « Clôturer ma journée » depuis PlanScreen. Rebâtit la manche au retour si
  /// la journée n'a PAS été scellée (retour arrière) : le check-out peut avoir
  /// ajouté une sourate révisée en plus ou étendu la portion à apprendre, et
  /// PlanScreen tient son état de rakaas localement, donc il resterait affiché
  /// sur un plan qui ne contient rien de ce qui vient d'être déclaré.
  Future<void> _closeDay(AppState state, String date) async {
    await _openCheckOut(date);
    if (!mounted) return;
    final session = state.todaySession;
    if (session != null) await state.buildTodaySession(session.prayersAlone);
  }

  void _maybeShowCheckOut(AppState state) {
    if (state.pendingDate == null || _checkOutShown) return;
    _checkOutShown = true;
    final date = state.pendingDate!;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _openCheckOut(date);
      _checkOutShown = false;
    });
  }

  /// « Illuminer ma journée » : ouvre le check-in et, s'il est validé,
  /// répartit le plan du jour dans les rakaas des prières choisies. Fermer
  /// le popup sans valider (retour arrière) ne construit aucune manche —
  /// les ajustements faits dedans (rythme, sourates, apprentissage) sont
  /// déjà persistés dans `ayah_facts`/la config de toute façon.
  Future<void> _openCheckIn(AppState state) async {
    final prayers = await Navigator.of(context, rootNavigator: true).push<List<Prayer>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CheckInScreen(),
      ),
    );
    if (prayers == null || prayers.isEmpty || !mounted) return;
    await state.buildTodaySession(prayers);
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

    final session = state.todaySession;
    if (session != null) {
      // Date figée à la construction du plan, pas relue au moment du tap :
      // l'app laissée ouverte au passage de minuit clôturerait sinon la
      // journée neuve (vide) au lieu de celle qui vient d'être révisée.
      final sessionDate = session.date.toIso8601String().substring(0, 10);
      return PlanScreen(
        key: ValueKey(session),
        session: session,
        freshnessOf: state.freshnessFor,
        onCloturer: () => _closeDay(state, sessionDate),
        onChangePlan: () => state.clearTodaySession(),
      );
    }

    return HomeScreen(
      onIlluminer: () => _openCheckIn(state),
      onRouvrirCloture: () => _openCheckOut(state.todayStr),
    );
  }
}
