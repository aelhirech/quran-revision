import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/revision_engine.dart';
import '../main.dart';
import '../models/daily_session.dart';
import 'home_screen.dart';
import 'plan_screen.dart';
import 'recap_screen.dart';
import 'profile_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  void _switchTo(int i) => setState(() => _index = i);

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.mosque_outlined),
      selectedIcon: Icon(Icons.mosque),
      label: 'Plan du jour',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Récap',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _DayPlanTab(onSwitchTab: _switchTo),
          const RecapScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: cs.surface,
        indicatorColor: cs.primaryContainer,
        destinations: _destinations,
      ).animate().slideY(
            begin: 1,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOut,
          ),
    );
  }
}

class _DayPlanTab extends StatelessWidget {
  final void Function(int) onSwitchTab;

  const _DayPlanTab({required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Révision en cours (engagé)
    if (state.todaySession != null) {
      return PlanScreen(
        key: ValueKey(state.todaySession),
        session: state.todaySession!,
        onComplete: (unitsCompleted) {
          final allUnits =
              RevisionEngine.buildUnits(state.config!.learnedSourates);
          state.advanceCycle(unitsCompleted, allUnits.length);
          state.clearTodaySession();
        },
        onChangePlan: () => state.clearTodaySession(),
      );
    }

    // Plan en preview (pas encore engagé)
    if (state.previewSession != null) {
      return PlanScreen(
        key: ValueKey(state.previewSession),
        session: state.previewSession!,
        isPreview: true,
        onEngager: () => state.engager(),
        onChangePlan: () => state.clearPreview(),
      );
    }

    // Sélection des prières
    return HomeScreen(
      onVoirPlan: (DailySession session) => state.setPreviewSession(session),
    );
  }
}
