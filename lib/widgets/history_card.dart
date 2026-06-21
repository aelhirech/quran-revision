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
    // Map date string → session pour lookup O(1)
    final byDate = {
      for (final s in sessions) s.date.toIso8601String().substring(0, 10): s
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(S.semaineDerniereLabel,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ),
          _weekGrid(context, cs, byDate),
          const SizedBox(height: 8),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(S.aucuneSession,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            )
          else
            ...sessions.take(7).map((s) => _row(context, cs, s)),
          const SizedBox(height: 8),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.08);
  }

  Widget _weekGrid(
      BuildContext context, ColorScheme cs, Map<String, SessionRecord> byDate) {
    final today = DateTime.now();
    final dayLabels = S.joursSemaine;
    // Lundi = 1 … Dimanche = 7, donc index dans dayLabels = weekday - 1
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.asMap().entries.map((entry) {
          final day = entry.value;
          final key = day.toIso8601String().substring(0, 10);
          final session = byDate[key];
          final isToday = key == today.toIso8601String().substring(0, 10);
          final dayLabelIndex = (day.weekday - 1) % 7;
          return _dayCell(cs, dayLabels[dayLabelIndex], day.day, session, isToday);
        }).toList(),
      ),
    );
  }

  Widget _dayCell(ColorScheme cs, String label, int dayNum,
      SessionRecord? session, bool isToday) {
    final pct = session == null
        ? null
        : (session.totalUnits == 0
            ? 0.0
            : session.unitsCompleted / session.totalUnits);

    Color circleColor;
    Color textColor;
    if (pct == null) {
      circleColor = isToday
          ? cs.primary.withValues(alpha: 0.12)
          : cs.surface;
      textColor = isToday ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.4);
    } else if (pct >= 0.8) {
      circleColor = AppColors.greenContainer;
      textColor = AppColors.green;
    } else {
      circleColor = cs.primaryContainer.withValues(alpha: 0.6);
      textColor = cs.onPrimaryContainer;
    }

    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: cs.primary, width: 2)
                : null,
          ),
          child: Center(
            child: Text('$dayNum',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, ColorScheme cs, SessionRecord s) {
    final dayStr =
        '${s.date.day.toString().padLeft(2, '0')}/${s.date.month.toString().padLeft(2, '0')}';
    final pct = s.totalUnits == 0 ? 0.0 : s.unitsCompleted / s.totalUnits;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: pct >= 0.8
                  ? AppColors.greenContainer
                  : cs.surface,
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
                    backgroundColor: cs.surface,
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
