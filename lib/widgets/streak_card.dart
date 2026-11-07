import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';

class StreakCard extends StatelessWidget {
  final int streak;
  final int totalDays;

  const StreakCard({super.key, required this.streak, required this.totalDays});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.gold.withValues(alpha: 0.55)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Transform.rotate(
            angle: 0.7854, // 45deg
            child: Container(
              width: 44,
              height: 44,
              color: palette.gold,
              child: Center(
                child: Transform.rotate(
                  angle: -0.7854,
                  child: Text('$streak',
                      style: AppText.cardTitle.copyWith(color: palette.onPrimary)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.streakLabel.toUpperCase(),
                    style: AppText.sectionTitle.copyWith(color: palette.goldDark)),
                const SizedBox(height: 3),
                Text(
                  streak > 0 ? S.streakJours(streak) : S.aucuneSession,
                  style: AppText.cardTitle.copyWith(color: palette.textPrimary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$totalDays',
                  style: AppText.cardTitle.copyWith(color: palette.primary, height: 1)),
              Text(S.totalJoursLabel,
                  style: AppText.caption
                      .copyWith(color: palette.textMuted)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.08);
  }
}
