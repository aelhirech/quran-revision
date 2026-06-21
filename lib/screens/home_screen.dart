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
  int _tahiyyatCount = 0;
  DailySession? _session;
  int _streak = 0;
  List<Prayer>? _lastPrayers;
  bool _isYesterday = false;

  /// Liste effective : prières sélectionnées + tahiyyatMasjid répété n fois.
  /// Les doublons sont intentionnels — chaque entrée à la mosquée est une prière séparée.
  List<Prayer> get _effectivePrayers => [
        ...Prayer.values.where((p) => !p.isTahiyyat && _prayersAlone.contains(p)),
        for (int i = 0; i < _tahiyyatCount; i++) Prayer.tahiyyatMasjid,
      ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final pauseDates = context.read<AppState>().pauseDates;
    final streak = await HistoryService.currentStreak(pauseDates: pauseDates);
    final recent = await HistoryService.recentSessions(limit: 1);
    if (!mounted) return;

    List<Prayer>? lastPrayers;
    bool isYesterday = false;
    if (recent.isNotEmpty) {
      final last = recent.first;
      final prayers = last.prayers
          .map((name) {
            try {
              return Prayer.values.byName(name);
            } catch (_) {
              return null;
            }
          })
          .whereType<Prayer>()
          .toList();
      if (prayers.isNotEmpty) {
        lastPrayers = prayers;
        final lastDate = last.date.toIso8601String().substring(0, 10);
        final yesterday = DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .substring(0, 10);
        isYesterday = lastDate == yesterday;
      }
    }
    setState(() {
      _streak = streak;
      _lastPrayers = lastPrayers;
      _isYesterday = isYesterday;
    });
  }

  void _applyLastPrayers() {
    if (_lastPrayers == null) return;
    // tahiyyatMasjid peut apparaître plusieurs fois — on compte les occurrences
    final tahiyyat = _lastPrayers!.where((p) => p.isTahiyyat).length;
    final others = _lastPrayers!.where((p) => !p.isTahiyyat).toSet();
    setState(() {
      _prayersAlone
        ..clear()
        ..addAll(others);
      _tahiyyatCount = tahiyyat;
    });
  }

  void _buildPlan(AppState state) {
    final prayers = _effectivePrayers;
    if (state.config == null || prayers.isEmpty) return;
    final session = RevisionEngine.buildDayPlan(
      config: state.config!,
      prayersAlone: prayers,
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

    final canCommit = _effectivePrayers.isNotEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // Pas de floating : SliverAppBar.large afficherait le titre deux fois
          // pendant l'animation de repli si floating était activé.
          SliverAppBar.large(
            title: Text(S.appTitle),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(S.priereSeul,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold))
                        .animate()
                        .fadeIn(delay: 150.ms),
                    if (_lastPrayers != null)
                      TextButton.icon(
                        onPressed: _applyLastPrayers,
                        icon: const Icon(Icons.history, size: 16),
                        label: Text(
                          _isYesterday ? S.commeHier : S.derniereSelection,
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ).animate().fadeIn(duration: 200.ms),
                  ],
                ),
                const SizedBox(height: 10),
                PrayerSelector(
                  selected: _prayersAlone,
                  onToggle: (p) => setState(() {
                    _prayersAlone.contains(p)
                        ? _prayersAlone.remove(p)
                        : _prayersAlone.add(p);
                  }),
                  tahiyyatCount: _tahiyyatCount,
                  onTahiyyatCountChanged: (n) =>
                      setState(() => _tahiyyatCount = n),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: canCommit
                        ? () {
                            _buildPlan(state);
                            if (_session != null) widget.onVoirPlan(_session!);
                          }
                        : null,
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
