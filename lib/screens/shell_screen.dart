import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../state/app_state.dart';
import '../widgets/day_plan_tab.dart';
import '../widgets/spotlight_tour.dart';
import 'learn_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _maybeStartTour();
  }

  Future<void> _maybeStartTour() async {
    final state = context.read<AppState>();
    // Le tour ne cible que des widgets de HomeScreen (aucune session encore
    // engagée) — pas de sens à le montrer si l'utilisateur a déjà un plan.
    if (state.todaySession != null || state.previewSession != null) return;
    if (!state.hasSeenTour && mounted) setState(() => _showTour = true);
  }

  Future<void> _dismissTour() async {
    setState(() => _showTour = false);
    await context.read<AppState>().markTourSeen();
  }

  List<TourStep> get _tourSteps => [
        TourStep(
          targetKey: TourKeys.navBar,
          title: S.tourNavTitle,
          body: S.tourNavBody,
        ),
        TourStep(
          targetKey: TourKeys.navBar,
          title: S.tourApprendreTitle,
          body: S.tourApprendreBody,
        ),
        TourStep(
          targetKey: TourKeys.navBar,
          title: S.tourRecapTitle,
          body: S.tourRecapBody,
        ),
        TourStep(
          targetKey: TourKeys.navBar,
          title: S.tourProfilTitle,
          body: S.tourProfilBody,
        ),
        TourStep(
          targetKey: TourKeys.prayerSelector,
          title: S.tourPrieresTitle,
          body: S.tourPrieresBody,
        ),
        TourStep(
          targetKey: TourKeys.voirPlanButton,
          title: S.tourVoirPlanTitle,
          body: S.tourVoirPlanBody,
        ),
      ];

  List<NavigationDestination> _destinations(BuildContext context) {
    context.watch<AppState>(); // rebuild on locale change
    return [
      NavigationDestination(
        icon: const Icon(Icons.mosque_outlined),
        selectedIcon: const Icon(Icons.mosque),
        label: S.reviser,
      ),
      NavigationDestination(
        icon: const Icon(Icons.auto_stories_outlined),
        selectedIcon: const Icon(Icons.auto_stories),
        label: S.apprendre,
      ),
      NavigationDestination(
        icon: const Icon(Icons.bar_chart_outlined),
        selectedIcon: const Icon(Icons.bar_chart),
        label: S.recap,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: S.profil,
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
              LearnScreen(),
              RecapScreen(),
              ProfileScreen(),
            ],
          ),
          bottomNavigationBar: KeyedSubtree(
            key: TourKeys.navBar,
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.cardBorder)),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: _destinations(context),
              ),
            ).animate().slideY(
                  begin: 1,
                  end: 0,
                  duration: 400.ms,
                  curve: Curves.easeOut,
                ),
          ),
        ),
        if (_showTour)
          SpotlightOverlay(steps: _tourSteps, onDone: _dismissTour),
      ],
    );
  }
}
