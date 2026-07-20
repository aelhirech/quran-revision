import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
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
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: palette.onPrimary)),
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
                    style: TextStyle(
                        color: palette.goldDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                const SizedBox(height: 3),
                Text(
                  streak > 0 ? S.streakJours(streak) : S.aucuneSession,
                  style: GoogleFonts.lora(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$totalDays',
                  style: TextStyle(
                      color: palette.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 1)),
              Text(S.totalJoursLabel,
                  style: TextStyle(
                      color: palette.textMuted,
                      fontStyle: FontStyle.italic,
                      fontSize: 11)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.08);
  }
}
