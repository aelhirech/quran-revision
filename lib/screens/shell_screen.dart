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

class _ShellScreenState extends State<ShellScreen> with WidgetsBindingObserver {
  int _index = 0;
  // Rising-edge tracking (US-1 crit. 6), never the level: once the user has
  // moved to a tab of their own choosing, the same notification (e.g.
  // typing in Settings' search) must never send them back there.
  bool _lastCheckoutDone = false;
  bool _lastRecapSeen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Point d'entrée du moteur quotidien (Phase 6 Sprint 2) — à chaque
    // ouverture/reprise de l'app (voir cadrage "Moteur quotidien").
    final state = context.read<AppState>();
    _lastCheckoutDone = state.guideDone('checkout_done');
    _lastRecapSeen = state.guideDone('recap_seen');
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Chains Récap then Réglages once, right after the FIRST check-out
    // (US-1 crit. 6) — only on each flag's rising edge, never its level: a
    // manual tab switch afterward must never be overridden by this
    // notification again.
    final state = context.read<AppState>();
    final checkoutDone = state.guideDone('checkout_done');
    final recapSeen = state.guideDone('recap_seen');
    if (checkoutDone && !_lastCheckoutDone && !recapSeen) {
      _index = 1;
    } else if (checkoutDone && recapSeen && !_lastRecapSeen) {
      _index = 2;
    }
    _lastCheckoutDone = checkoutDone;
    _lastRecapSeen = recapSeen;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Resuming from the background (US-3 crit. 5): `ShellScreen` stays
  /// mounted as long as the OS doesn't kill the app, so `initState` never
  /// replays on its own when the user comes back the next day without
  /// restarting the app — without this hook, `pendingDate` would stay stuck
  /// on yesterday's state and `DayPlanTab`'s catch-up would never fire until
  /// a cold restart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppState>().ensureDayPlan();
    }
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
