import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/session_record.dart';

class HistoryCard extends StatelessWidget {
  final List<SessionRecord> sessions;

  const HistoryCard({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(S.historique,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    fontSize: 15)),
          ),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(S.aucuneSession,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            )
          else
            ...sessions.take(7).map((s) => _row(context, s)),
          const SizedBox(height: 8),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.08);
  }

  Widget _row(BuildContext context, SessionRecord s) {
    final cs = Theme.of(context).colorScheme;
    final dayStr =
        '${s.date.day.toString().padLeft(2, '0')}/${s.date.month.toString().padLeft(2, '0')}';
    final pct = s.totalUnits == 0 ? 0.0 : s.unitsCompleted / s.totalUnits;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: pct >= 0.8 ? AppColors.greenContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(dayStr,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: pct >= 0.8 ? AppColors.green : cs.onSurfaceVariant)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.unitsCompleted} / ${s.totalUnits} ${S.unitesLabel}',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: cs.onSurface)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 4,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: pct >= 0.8 ? AppColors.green : cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${(pct * 100).round()}%',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: pct >= 0.8 ? AppColors.green : cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
