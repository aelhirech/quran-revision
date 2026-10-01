import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/day_close.dart';
import '../models/learning_progress.dart';
import '../state/app_state.dart';
import 'ornamental_divider.dart';

/// Home screen once today is sealed (US-14): what the day brought (looking
/// back), then the round duration and the learning deadline (looking ahead).
/// Shown every closed day, not only the first one — the "ahead at check-out"
/// rule of CLAUDE.md § Direction narrative, held by state rather than by a
/// one-time guide.
class DayClosedSummary extends StatefulWidget {
  /// Plays the entrance animation: true right after sealing, false when the
  /// home screen is simply reopened on an already-closed day.
  final bool entrance;

  /// From the caller's hoisted selection (`AppState.roundDaysOf`): reading
  /// `daySelection` again here would rebuild the whole cycle a second time.
  final int? roundDays;

  const DayClosedSummary({super.key, required this.roundDays, this.entrance = false});

  @override
  State<DayClosedSummary> createState() => _DayClosedSummaryState();
}

class _DayClosedSummaryState extends State<DayClosedSummary> {
  DayRecap? _recap;
  LearningProgress? _learning;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reloaded on every AppState notify: reopening and correcting the
    // check-out must update the recap, and nothing cached could know that.
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final (recap, learning) =
        await (state.dayRecap(state.todayStr), state.learningInProgress()).wait;
    if (!mounted) return;
    setState(() {
      _recap = recap;
      _learning = learning;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final palette = context.palette;
    final recap = _recap;
    if (recap == null) return const SizedBox.shrink();

    final roundDays = widget.roundDays;
    final learning = _learning;
    final learningDays =
        learning?.daysToFinish(state.config?.versesToLearnPerDay ?? 0) ?? 0;
    final back = [
      if (recap.revised.isNotEmpty)
        SCheckOut.bilanRevu(recap.revised.map((s) => s.nameFr).join(', ')),
      if (recap.learnedVerses > 0) SCheckOut.bilanAppris(recap.learnedVerses),
      if (recap.leftover) SCheckOut.bilanReste,
    ];
    final ahead = [
      if (roundDays != null) SCheckOut.devantTour(roundDays),
      if (learning != null && learningDays > 0)
        SCheckOut.devantApprentissage(learning.sourate.nameFr, learningDays),
    ];
    if (back.isEmpty && ahead.isEmpty) return const SizedBox.shrink();

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: palette.surfaceCardSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (back.isNotEmpty) ..._section(palette, SCheckOut.bilanTitre, back),
          if (back.isNotEmpty && ahead.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Center(child: OrnamentalDivider(lineWidth: 20)),
            const SizedBox(height: 14),
          ],
          if (ahead.isNotEmpty) ..._section(palette, SCheckOut.devantTitre, ahead),
        ],
      ),
    );
    if (!widget.entrance) return card;
    return card
        .animate()
        .fadeIn(delay: 300.ms, duration: 700.ms)
        .slideY(begin: 0.06, curve: Curves.easeOutCubic);
  }

  List<Widget> _section(AppPalette palette, String title, List<String> lines) => [
        Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: palette.goldDark)),
        const SizedBox(height: 8),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(line,
                style: TextStyle(fontSize: 14, height: 1.45, color: palette.textPrimary)),
          ),
      ];
}
