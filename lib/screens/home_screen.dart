import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/hadith_data.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../services/history_service.dart';
import '../state/app_state.dart';
import '../widgets/cycle_progress_card.dart';
import '../widgets/hadith_card.dart';
import '../widgets/prayer_selector.dart';

class HomeScreen extends StatefulWidget {
  final void Function(DailySession) onVoirPlan;

  const HomeScreen({super.key, required this.onVoirPlan});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<Prayer> _prayersAlone = {};
  DailySession? _session;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    HistoryService.currentStreak().then((v) {
      if (mounted) setState(() => _streak = v);
    });
  }

  void _buildPlan(AppState state) {
    if (state.config == null || _prayersAlone.isEmpty) return;
    final session = RevisionEngine.buildDayPlan(
      config: state.config!,
      prayersAlone: Prayer.values.where((p) => _prayersAlone.contains(p)).toList(),
      cyclePosition: state.cyclePosition,
      today: DateTime.now(),
    );
    setState(() => _session = session);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    if (state.config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final units = RevisionEngine.buildUnits(state.config!.selections);
    final cycleTotal = units.length;
    final pos = state.cyclePosition % (cycleTotal == 0 ? 1 : cycleTotal);
    final progress = cycleTotal == 0 ? 0.0 : pos / cycleTotal;
    final daysElapsed =
        DateTime.now().difference(state.config!.startDate).inDays;
    final daysRemaining =
        (state.config!.revisionDays - daysElapsed).clamp(0, 9999);

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(S.appTitle),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
            floating: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                CycleProgressCard(
                  progress: progress,
                  pos: pos,
                  total: cycleTotal,
                  daysRemaining: daysRemaining,
                  streak: _streak,
                ),
                const SizedBox(height: 16),
                HadithCard(hadith: hadithDuJour(DateTime.now())),
                const SizedBox(height: 24),
                Text(S.priereImam,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold))
                    .animate()
                    .fadeIn(delay: 150.ms),
                const SizedBox(height: 10),
                PrayerSelector(
                  selected: _prayersAlone,
                  onToggle: (p) => setState(() {
                    _prayersAlone.contains(p)
                        ? _prayersAlone.remove(p)
                        : _prayersAlone.add(p);
                  }),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _prayersAlone.isEmpty
                        ? null
                        : () {
                            _buildPlan(state);
                            if (_session != null) widget.onVoirPlan(_session!);
                          },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(S.voirPlanDuJour,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
