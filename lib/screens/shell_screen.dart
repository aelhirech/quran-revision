import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../state/app_state.dart';
import '../widgets/day_plan_tab.dart';
import '../widgets/spotlight_tour.dart';
import 'recap_screen.dart';
import 'profile_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  bool _showTour = false;

  /// Étape courante du tour, tenue ici et non dans [SpotlightOverlay] : c'est
  /// cet écran qui décide quel onglet est affiché sous le halo, et l'étape
  /// courante et l'onglet doivent avancer ensemble.
  ///
  /// Le tour s'enchaîne par « Suivant » : hors du halo, le voile absorbe les
  /// taps, donc les onglets ne sont pas atteignables pendant le tour et les
  /// textes n'invitent pas à les toucher.
  int _tourStep = 0;

  @override
  void initState() {
    super.initState();
    // Point d'entrée du moteur quotidien (Phase 6 Sprint 2) — à chaque
    // ouverture/reprise de l'app (voir cadrage "Moteur quotidien").
    final state = context.read<AppState>();
    final dayPlanReady = state.ensureDayPlan();
    // `freshnessFor` (Phase 8 Sprint 1) retourne toujours un niveau concret,
    // jamais `null` — tant qu'aucun refresh n'a eu lieu, `_lastRevisionByAyah`
    // est vide et toute sourate lirait à tort "jamais révisée" (badge rouge)
    // plutôt que de rester simplement non affichée comme avant. Sans cet
    // appel, ce chargement ne partait implicitement que de `RecapScreen`
    // (un onglet non lié), avec un risque réel de notifier après le plan du
    // jour et donc de flasher un badge erroné le temps que les deux requêtes
    // se résolvent — le démarrer ici, en parallèle, réduit la fenêtre de
    // course plutôt que de la laisser dépendre d'un écran sans rapport.
    state.refreshFreshness(notify: false);
    _maybeStartTour(dayPlanReady);
  }

  Future<void> _maybeStartTour(Future<void> dayPlanReady) async {
    // `pendingDate`/`todaySession` ne valent quelque chose qu'une fois le
    // moteur quotidien résolu — sans cette attente, le garde ci-dessous lit
    // toujours l'état d'avant chargement et le tour démarre sous le
    // check-out de rattrapage qu'il est censé éviter.
    await dayPlanReady;
    if (!mounted) return;
    final state = context.read<AppState>();
    // Le tour ne cible que des widgets de HomeScreen (aucune session encore
    // engagée) — pas de sens à le montrer si l'utilisateur a déjà un plan.
    // Un jour en attente non plus : `DayPlanTab` pousse alors le check-out
    // par-dessus et n'affiche même pas le CTA que la dernière étape vise.
    if (state.todaySession != null || state.pendingDate != null) return;
    if (!state.hasSeenTour) setState(() => _showTour = true);
  }

  Future<void> _dismissTour() async {
    setState(() => _showTour = false);
    await context.read<AppState>().markTourSeen();
  }

  /// Les 3 premières étapes présentent un onglet et sont donc indexées comme
  /// lui ; la dernière ramène sur l'onglet 0 pour pointer le CTA d'accueil,
  /// qui n'est mesurable que si son onglet est bien affiché (`IndexedStack`
  /// construit les autres mais ne les met jamais en page).
  static const _tourCtaStep = 3;

  void _goToTourStep(int step) {
    setState(() {
      _tourStep = step;
      _index = step < _tourCtaStep ? step : 0;
    });
  }

  List<TourStep> get _tourSteps => [
        TourStep(
          targetKey: TourKeys.tabPlan,
          title: S.tourNavTitle,
          body: S.tourNavBody,
          padding: 14,
        ),
        TourStep(
          targetKey: TourKeys.tabRecap,
          title: S.tourRecapTitle,
          body: S.tourRecapBody,
          padding: 14,
        ),
        TourStep(
          targetKey: TourKeys.tabReglages,
          title: S.tourReglagesTitle,
          body: S.tourReglagesBody,
          padding: 14,
        ),
        TourStep(
          targetKey: TourKeys.voirPlanButton,
          title: S.tourVoirPlanTitle,
          body: S.tourVoirPlanBody,
        ),
      ];

  void _onDestinationSelected(int i) => setState(() => _index = i);

  List<NavigationDestination> _destinations(BuildContext context) {
    context.watch<AppState>(); // rebuild on locale change
    // La clé du tour est posée sur les DEUX icônes de chaque onglet :
    // `NavigationDestination` n'en monte qu'une à la fois (sélectionnée ou
    // non), donc pas de GlobalKey en double, mais la cible resterait
    // introuvable sur l'onglet actif si seule `icon` était clée.
    return [
      NavigationDestination(
        icon: KeyedSubtree(
            key: TourKeys.tabPlan, child: const Icon(Icons.mosque_outlined)),
        selectedIcon:
            KeyedSubtree(key: TourKeys.tabPlan, child: const Icon(Icons.mosque)),
        label: S.planDuJour,
      ),
      NavigationDestination(
        icon: KeyedSubtree(
            key: TourKeys.tabRecap, child: const Icon(Icons.bar_chart_outlined)),
        selectedIcon: KeyedSubtree(
            key: TourKeys.tabRecap, child: const Icon(Icons.bar_chart)),
        label: S.recap,
      ),
      NavigationDestination(
        icon: KeyedSubtree(
            key: TourKeys.tabReglages,
            child: const Icon(Icons.settings_outlined)),
        selectedIcon: KeyedSubtree(
            key: TourKeys.tabReglages, child: const Icon(Icons.settings)),
        label: S.reglages,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _index,
            children: const [
              DayPlanTab(),
              RecapScreen(),
              ProfileScreen(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.cardBorder)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _onDestinationSelected,
              destinations: _destinations(context),
            ),
          ).animate().slideY(
                begin: 1,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOut,
              ),
        ),
        if (_showTour)
          SpotlightOverlay(
            steps: _tourSteps,
            index: _tourStep,
            onNext: () => _goToTourStep(_tourStep + 1),
            onDone: _dismissTour,
            // La dernière étape pointe « Illuminer ma journée » : le tap
            // atteint le vrai bouton et ouvre le check-in par-dessus tout —
            // laisser le tour derrière n'aurait plus de sens.
            onTargetTap: _tourStep == _tourCtaStep ? _dismissTour : null,
          ),
      ],
    );
  }
}
