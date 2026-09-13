import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../state/app_state.dart';
import '../widgets/day_plan_tab.dart';
import 'recap_screen.dart';
import 'profile_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Point d'entrée du moteur quotidien (Phase 6 Sprint 2) — à chaque
    // ouverture/reprise de l'app (voir cadrage "Moteur quotidien").
    final state = context.read<AppState>();
    state.ensureDayPlan();
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
  }

  void _onDestinationSelected(int i) => setState(() => _index = i);

  List<NavigationDestination> _destinations(BuildContext context) {
    context.watch<AppState>(); // rebuild on locale change
    return [
      NavigationDestination(
        icon: const Icon(Icons.mosque_outlined),
        selectedIcon: const Icon(Icons.mosque),
        label: S.planDuJour,
      ),
      NavigationDestination(
        icon: const Icon(Icons.bar_chart_outlined),
        selectedIcon: const Icon(Icons.bar_chart),
        label: S.recap,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: S.reglages,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
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
    );
  }
}
