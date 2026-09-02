import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';
import '../models/riwaya.dart';
import '../models/session_record.dart';
import '../services/ayah_facts_service.dart';
import '../state/app_state.dart';
import '../widgets/dome_progress_card.dart';
import '../widgets/history_card.dart';
import '../widgets/ornamental_divider.dart';
import '../widgets/sourates_recap_card.dart';
import '../widgets/streak_card.dart';

class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  int _streak = 0;
  int _totalDays = 0;
  List<SessionRecord> _sessions = [];
  List<LearningProgress> _learningProgress = [];
  Set<String> _lastPauseDates = {};
  Riwaya? _lastRiwaya;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tourne une première fois juste après initState (couvre le chargement
    // initial), puis à chaque notification d'AppState.
    final pauseDates = context.read<AppState>().pauseDates;
    final riwaya = context.read<AppState>().riwaya;
    if (!setEquals(pauseDates, _lastPauseDates) || riwaya != _lastRiwaya) {
      _lastPauseDates = Set.from(pauseDates);
      _lastRiwaya = riwaya;
      _load(pauseDates);
    }
  }

  Future<void> _load(Set<String> pauseDates) async {
    final state = context.read<AppState>();
    final riwaya = state.riwaya;
    // Démarrage en parallèle, await typé sur chacun — évite les casts dynamiques
    final streakF = AyahFactsService.currentStreak(pauseDates: pauseDates, riwaya: riwaya);
    final totalF = AyahFactsService.totalActiveDays(riwaya: riwaya);
    final statsF = AyahFactsService.recentDayVerseStats(limit: 14, riwaya: riwaya);
    final progressF = AyahFactsService.loadMainLearningProgress(
        riwaya: riwaya, sourates: state.sourates);
    // Assure les badges de fraîcheur même si l'utilisateur arrive sur Récap
    // sans être passé par un plan du jour cette session.
    final freshnessF = state.refreshFreshness(notify: false);
    final streak = await streakF;
    final total = await totalF;
    final stats = await statsF;
    final progress = await progressF;
    await freshnessF;

    // totalUnits = versets proposés ce jour-là (pas le total du cycle) —
    // sinon le % quotidien reste écrasé près de 0 (bug retour TestFlight).
    final sessions = [
      for (final entry in stats.entries)
        SessionRecord(
          date: DateTime.parse(entry.key),
          unitsCompleted: entry.value.done,
          totalUnits: entry.value.total,
          prayers: const [],
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _streak = streak;
        _totalDays = total;
        _sessions = sessions;
        _learningProgress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    if (state.config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cycle = state.cycleSummary;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(S.recapitulatif),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: OrnamentalDivider(),
                ),
                StreakCard(streak: _streak, totalDays: _totalDays),
                const SizedBox(height: 16),
                _cycleCard(
                    cs, cycle.progress, cycle.pos, cycle.total, cycle.daysRemaining),
                const SizedBox(height: 16),
                _repartitionCard(cs, state),
                const SizedBox(height: 16),
                _statsRow(cs, state, cycle.total),
                const SizedBox(height: 16),
                HistoryCard(sessions: _sessions),
                const SizedBox(height: 16),
                SouratesRecapCard(
                  selections: state.config!.selections,
                  freshnessOf: state.freshnessFor,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cycleCard(ColorScheme cs, double progress, int pos, int total,
      int daysRemaining) {
    final percent = (progress * 100).round();
    final palette = context.palette;
    final onPrimary = palette.onPrimary;
    return DomeProgressCard(
      topRadius: 150,
      bottomRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(S.cycleActuel,
              style: TextStyle(
                  color: onPrimary.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$percent',
                  style: TextStyle(
                      color: onPrimary,
                      fontSize: 50,
                      fontWeight: FontWeight.w600,
                      height: 1)),
              Text('%',
                  style: TextStyle(color: palette.gold, fontSize: 22, fontWeight: FontWeight.w600)),
            ],
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),
          const SizedBox(height: 6),
          Text('$pos / $total ${S.unitesLabel}',
              style: TextStyle(color: onPrimary.withValues(alpha: 0.75), fontSize: 13, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: onPrimary.withValues(alpha: 0.18),
                color: palette.gold,
                minHeight: 3,
              ),
            ),
          ).animate().scaleX(
                begin: 0,
                alignment: Alignment.center,
                duration: 700.ms,
                curve: Curves.easeOut,
                delay: 200.ms,
              ),
          const SizedBox(height: 12),
          Text(
            daysRemaining > 0
                ? S.joursRestantsMsg(daysRemaining)
                : '🎉 ${S.objectifAtteint}',
            style: TextStyle(
                color: onPrimary.withValues(alpha: 0.75), fontSize: 13),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _repartitionCard(ColorScheme cs, AppState state) {
    final enRevision = state.config!.selections.length;
    final memorisees = _learningProgress.where((p) => p.isComplete).length;
    final enCours = _learningProgress.where((p) => !p.isComplete).length;

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.cardBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.repartitionSourates,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: cs.onSurface)),
          const SizedBox(height: 12),
          Row(
            children: [
              _repartitionChip(cs, enRevision, S.enRevision,
                  Icons.loop_outlined, cs.primary),
              const SizedBox(width: 8),
              _repartitionChip(cs, enCours, S.enCoursDApprentissage,
                  Icons.edit_note_outlined, cs.tertiary),
              const SizedBox(width: 8),
              _repartitionChip(cs, memorisees, S.memorisees,
                  Icons.check_circle_outline, cs.primary),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.08);
  }

  Widget _repartitionChip(ColorScheme cs, int count, String label,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text('$count',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(ColorScheme cs, AppState state, int unitTotal) {
    final selections = state.config!.selections;
    final totalVerses = selections.fold(0, (sum, s) => sum + s.verseCount);

    return Row(
      children: [
        _statChip(cs, '${selections.length}', S.souratesLabel,
            Icons.menu_book_outlined, 0),
        const SizedBox(width: 12),
        _statChip(cs, '$totalVerses', S.versetsLabel,
            Icons.format_list_numbered, 100),
        const SizedBox(width: 12),
        _statChip(cs, '$unitTotal', S.unitesLabel, Icons.grid_view, 200),
      ],
    );
  }

  Widget _statChip(
      ColorScheme cs, String value, String label, IconData icon, int delayMs) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: context.palette.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.palette.cardBorder),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: cs.primary, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: Duration(milliseconds: delayMs))
          .slideY(begin: 0.12),
    );
  }
}
