import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';

/// Summary bar of `PlanScreen` — in **real pages** since Phase 9 Sprint 2,
/// the same unit as the configured pace. Reads `cyclePosition`/`cycleTotal`
/// off the `DailySession` instead of re-deriving cycle progress locally.
class PlanSummaryBar extends StatelessWidget {
  final DailySession session;

  const PlanSummaryBar({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: 0.07),
        border: Border.all(color: palette.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.pagesRakaas(session.pagesToday, session.totalRakaas),
            style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${S.cycleEnCours} : ${session.cyclePosition} / ${session.cycleTotal}',
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: session.cycleTotal == 0
                        ? 0
                        : session.cyclePosition / session.cycleTotal,
                    minHeight: 3,
                    backgroundColor: palette.textPrimary.withValues(alpha: 0.1),
                    color: palette.gold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
