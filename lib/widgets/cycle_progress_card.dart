import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import 'dome_progress_card.dart';

class CycleProgressCard extends StatelessWidget {
  final double progress;
  final int pos;
  final int total;
  final int daysRemaining;
  final int streak;

  const CycleProgressCard({
    super.key,
    required this.progress,
    required this.pos,
    required this.total,
    required this.daysRemaining,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onPrimary = palette.onPrimary;
    final percent = (progress * 100).round();

    return DomeProgressCard(
      topRadius: 170,
      bottomRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(S.cycleEnCours,
              style: GoogleFonts.lora(
                  color: onPrimary.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$percent',
                  style: TextStyle(
                      color: onPrimary,
                      fontSize: 52,
                      fontWeight: FontWeight.w600,
                      height: 1)),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('%',
                    style: TextStyle(
                        color: palette.gold, fontSize: 24, fontWeight: FontWeight.w600)),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _showUnitesInfo(context),
            child: Text(
              '$pos / $total ${S.unitesLabel} · '
              '${daysRemaining > 0 ? '$daysRemaining ${S.joursRestants}' : S.objectifAtteint}',
              style: GoogleFonts.lora(
                  color: onPrimary.withValues(alpha: 0.75),
                  fontStyle: FontStyle.italic,
                  fontSize: 13),
            ),
          ),
          const SizedBox(height: 14),
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
                duration: 800.ms,
                curve: Curves.easeOut,
              ),
          if (streak > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.gold.withValues(alpha: 0.6)),
              ),
              child: Text(S.streakJours(streak),
                  style: TextStyle(
                      color: onPrimary.withValues(alpha: 0.9),
                      fontSize: 12)),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.06);
  }

  void _showUnitesInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.unitesExplTitle),
        content: Text(S.unitesExplBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.ok),
          ),
        ],
      ),
    );
  }
}
