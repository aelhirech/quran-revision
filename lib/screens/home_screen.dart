import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../state/app_state.dart';
import '../models/daily_session.dart';
import '../core/prayer_l10n.dart';
import '../models/prayer.dart';

class HomeScreen extends StatefulWidget {
  final void Function(DailySession) onVoirPlan;

  const HomeScreen({super.key, required this.onVoirPlan});

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
                _progressCard(cs, progress, state.cyclePosition % cycleTotal,
                    cycleTotal, state),
                const SizedBox(height: 24),
                Text(S.priereImam,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold))
                    .animate()
                    .fadeIn(delay: 150.ms),
                const SizedBox(height: 10),
                _prayerSelector(cs),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _prayersAlone.isEmpty
                        ? null
                        : () {
                            _buildPlan(state);
                            if (_session != null) {
                              widget.onVoirPlan(_session!);
                            }
                          },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(S.voirPlanDuJour,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(ColorScheme cs, double progress, int pos, int total,
      AppState state) {
    final daysElapsed =
        DateTime.now().difference(state.config!.startDate).inDays;
    final daysRemaining =
        (state.config!.revisionDays - daysElapsed).clamp(0, 9999);
    final percent = (progress * 100).round();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, AppColors.greenLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.cycleEnCours,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$pos / $total unités',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$percent%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -1)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(S.complete,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: Colors.white,
              minHeight: 6,
            ),
          ).animate().scaleX(
                begin: 0,
                alignment: Alignment.centerLeft,
                duration: 800.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 10),
          Text(
            daysRemaining > 0
                ? '$daysRemaining ${S.joursRestants}'
                : S.objectifAtteint,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.06);
  }

  Widget _prayerSelector(ColorScheme cs) {
    final fard = Prayer.values.where((p) => p.isFard).toList();
    final sunna = Prayer.values
        .where((p) => !p.isFard && !p.isTahiyyat)
        .toList();
    final tahiyyat = Prayer.values.where((p) => p.isTahiyyat).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chipGroup(S.priereObligatoires, fard, cs),
        const SizedBox(height: 12),
        _chipGroup(S.priereSureratoires, sunna, cs),
        const SizedBox(height: 12),
        _chipGroup(S.priereMasjid, tahiyyat, cs),
      ],
    );
  }

  Widget _chipGroup(String label, List<Prayer> prayers, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: prayers.map((p) {
            final selected = _prayersAlone.contains(p);
            return GestureDetector(
              onTap: () => setState(() {
                selected ? _prayersAlone.remove(p) : _prayersAlone.add(p);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? cs.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? cs.primary : AppColors.cardBorder,
                    width: 1.5,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.check, color: Colors.white, size: 14),
                      ),
                    Text(
                      '${p.displayName}  ${p.rakaas}r',
                      style: TextStyle(
                        color: selected ? Colors.white : cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}


