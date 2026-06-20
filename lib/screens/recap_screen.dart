import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../state/app_state.dart';

class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    if (state.config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final units = RevisionEngine.buildUnits(state.config!.learnedSourates);
    final total = units.length;
    final pos = state.cyclePosition % (total == 0 ? 1 : total);
    final progress = total == 0 ? 0.0 : pos / total;

    final daysElapsed =
        DateTime.now().difference(state.config!.startDate).inDays;
    final daysRemaining =
        (state.config!.revisionDays - daysElapsed).clamp(0, 9999);

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
                _cycleCard(cs, progress, pos, total, daysRemaining),
                const SizedBox(height: 16),
                _statsRow(cs, state, units.length),
                const SizedBox(height: 16),
                _souratesCard(cs, state),
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
            color: cs.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.cycleActuel,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$percent%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -1)),
              Padding(
                padding: const EdgeInsets.only(bottom: 7, left: 8),
                child: Text('· $pos / $total ${S.unitesLabel}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75), fontSize: 15)),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),
          const SizedBox(height: 18),
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
                duration: 700.ms,
                curve: Curves.easeOut,
                delay: 200.ms,
              ),
          const SizedBox(height: 12),
          Text(
            daysRemaining > 0
                ? S.joursRestantsMsg(daysRemaining)
                : '🎉 ${S.objectifAtteint}',
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _statsRow(ColorScheme cs, AppState state, int unitTotal) {
    final sourates = state.config!.learnedSourates;
    final totalVerses = sourates.fold(0, (sum, s) => sum + s.verses);

    return Row(
      children: [
        _statChip(cs, '${sourates.length}', S.souratesLabel, Icons.menu_book_outlined, 0),
        const SizedBox(width: 12),
        _statChip(cs, '$totalVerses', S.versetsLabel, Icons.format_list_numbered, 100),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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

  Widget _souratesCard(ColorScheme cs, AppState state) {
    final sourates = state.config!.learnedSourates;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(S.mesSourates,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      fontSize: 15)),
            ),
            ...sourates.asMap().entries.map((e) {
              final s = e.value;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  child: Text('${s.id}', style: const TextStyle(fontSize: 10)),
                ),
                title: Text(s.nameFr,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(s.nameAr),
                trailing: Text('${s.verses} ${S.versetsLabel}',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 12)),
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 300 + e.key * 40))
                  .slideX(begin: 0.05);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }
}

