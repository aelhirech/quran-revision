import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';
import '../models/riwaya.dart';
import '../models/session_record.dart';
import '../services/ayah_facts_service.dart';
import '../state/app_state.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/cycle_progress_card.dart';
import '../widgets/history_card.dart';
import '../widgets/learning_progress_card.dart';
import '../widgets/ornamental_divider.dart';
import '../widgets/sourates_recap_card.dart';
import '../widgets/streak_card.dart';
import 'learn_surah_screen.dart';

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
  DaySelection? _daySelection;

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
    final progressF = state.learningProgressList();
    // Assure les badges de fraîcheur même si l'utilisateur arrive sur Récap
    // sans être passé par un plan du jour cette session.
    final freshnessF = state.refreshFreshness(notify: false);
    final daySelectionF = state.getDaySelectionForToday();
    final streak = await streakF;
    final total = await totalF;
    final stats = await statsF;
    final progress = await progressF;
    await freshnessF;
    final daySelection = await daySelectionF;

    // totalUnits = versets proposés ce jour-là (pas le total du cycle) —
    // sinon le % quotidien reste écrasé près de 0 (bug retour TestFlight).
    final sessions = [
      for (final entry in stats.entries)
        SessionRecord(
          date: DateTime.parse(entry.key),
          unitsCompleted: entry.value.done,
          totalUnits: entry.value.total,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _streak = streak;
        _totalDays = total;
        _sessions = sessions;
        _learningProgress = progress;
        _daySelection = daySelection;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    if (state.config == null || _daySelection == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cycle = _daySelection!;

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
                CycleProgressCard(
                  progress: cycle.cycleTotal > 0
                      ? cycle.cyclePosition / cycle.cycleTotal
                      : 0.0,
                  pos: cycle.cyclePosition,
                  total: cycle.cycleTotal,
                  label: S.cycleActuel,
                  topRadius: 150,
                ),
                const SizedBox(height: 16),
                _repartitionCard(cs, state),
                const SizedBox(height: 16),
                _statsRow(cs, state, cycle.cycleTotal),
                const SizedBox(height: 16),
                HistoryCard(sessions: _sessions),
                const SizedBox(height: 16),
                ..._learningSection(cs),
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

  /// Sourates en cours de mémorisation (Phase 9 — reprend le contenu de
  /// l'onglet « Apprendre », supprimé) : le Récap est désormais la vue
  /// d'ensemble unique révision + apprentissage. Démarrer une sourate se
  /// fait au check-in ; ici on suit sa progression et on pratique verset par
  /// verset (`LearnSurahScreen`).
  List<Widget> _learningSection(ColorScheme cs) {
    final inProgress = _learningProgress.where((p) => !p.isComplete).toList();
    if (inProgress.isEmpty) return const [];
    return [
      Text(S.enCoursDApprentissage,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface))
          .animate()
          .fadeIn(),
      const SizedBox(height: 12),
      for (final (i, p) in inProgress.indexed)
        LearningProgressCard(
          progress: p,
          index: i,
          onTap: () => _openSourate(p),
          onDismiss: () => _deleteLearning(p),
        ),
      const SizedBox(height: 16),
    ];
  }

  Future<void> _openSourate(LearningProgress p) async {
    // `LearnSurahScreen` se referme de lui-même en renvoyant `true` quand le
    // dernier verset vient d'être appris — on ne sonde la bascule
    // apprentissage → révision que dans ce cas, pas à chaque aller-retour.
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LearnSurahScreen(progress: p)),
    );
    if (!mounted) return;
    if (completed == true) {
      final handed = await context.read<AppState>().handOffLearnedSurahs();
      if (!mounted) return;
      for (final s in handed) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.sourateApprise(s.nameFr))));
      }
    }
    await _load(context.read<AppState>().pauseDates);
  }

  Future<void> _deleteLearning(LearningProgress p) async {
    final state = context.read<AppState>();
    final confirmed = await confirmDialog(
      context,
      title: S.supprimerApprentissage,
      message: S.supprimerApprentissageDe(p.sourate.nameFr),
      confirmLabel: S.supprimer,
      danger: true,
    );
    if (!mounted || !confirmed) return;
    await AyahFactsService.deleteLearnFacts(p.sourate.id, state.riwaya);
    if (mounted) await _load(state.pauseDates);
  }

  Widget _repartitionCard(ColorScheme cs, AppState state) {
    final enRevision = state.config!.selections.length;
    final memorisees = _learningProgress.memorisedCount;
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

  Widget _statsRow(ColorScheme cs, AppState state, int cycleTotal) {
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
        _statChip(cs, '$cycleTotal', S.pagesLabel,
            Icons.auto_stories_outlined, 200),
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
