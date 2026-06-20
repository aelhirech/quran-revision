import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/revision_engine.dart';
import '../main.dart';
import '../models/daily_session.dart';
import '../models/prayer.dart';
import 'plan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<Prayer> _prayersAlone = {};
  DailySession? _session;

  void _buildPlan(AppState state) {
    if (state.config == null || _prayersAlone.isEmpty) return;
    final session = RevisionEngine.buildDayPlan(
      config: state.config!,
      prayersAlone: Prayer.values
          .where((p) => _prayersAlone.contains(p))
          .toList(),
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

    final units = RevisionEngine.buildUnits(state.config!.learnedSourates);
    final cycleTotal = units.length;
    final progress = cycleTotal == 0
        ? 0.0
        : (state.cyclePosition % cycleTotal) / cycleTotal;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Révision du Coran'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Réinitialiser',
            onPressed: () => state.advanceCycle(0, cycleTotal),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _progressCard(cs, progress, state.cyclePosition % cycleTotal,
                cycleTotal, state),
            const SizedBox(height: 20),
            Text('Prières seules aujourd\'hui',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _prayerSelector(cs),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _prayersAlone.isEmpty
                    ? null
                    : () {
                        _buildPlan(state);
                        if (_session != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlanScreen(
                                session: _session!,
                                onComplete: (units) =>
                                    state.advanceCycle(units, cycleTotal),
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Voir mon plan du jour',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressCard(ColorScheme cs, double progress, int pos, int total,
      AppState state) {
    final daysElapsed =
        DateTime.now().difference(state.config!.startDate).inDays;
    final daysRemaining =
        (state.config!.revisionDays - daysElapsed).clamp(0, 9999);
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cycle en cours',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer)),
                Text('$pos / $total unités',
                    style: TextStyle(color: cs.onPrimaryContainer)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: cs.onPrimaryContainer.withOpacity(0.2),
              color: cs.primary,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Text(
              daysRemaining > 0
                  ? 'Il te reste $daysRemaining jours pour finir ce cycle'
                  : 'Objectif atteint ! Lance un nouveau cycle',
              style:
                  TextStyle(color: cs.onPrimaryContainer, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prayerSelector(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Prayer.values.map((p) {
        final selected = _prayersAlone.contains(p);
        return FilterChip(
          label: Text('${p.nameFr} (${p.rakaas}r)'),
          selected: selected,
          onSelected: (_) => setState(() {
            selected ? _prayersAlone.remove(p) : _prayersAlone.add(p);
          }),
          selectedColor: cs.primaryContainer,
          checkmarkColor: cs.primary,
        );
      }).toList(),
    );
  }
}
