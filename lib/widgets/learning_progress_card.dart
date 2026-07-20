import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';
import 'index_badge.dart';

class LearningProgressCard extends StatelessWidget {
  final LearningProgress progress;
  final int index;
  final VoidCallback onTap;
  final Future<void> Function() onDismiss;

  const LearningProgressCard({
    super.key,
    required this.progress,
    required this.index,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;
    final s = progress.sourate;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(s.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.red),
        ),
        confirmDismiss: (_) async {
          await onDismiss();
          return false;
        },
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: palette.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.cardBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IndexBadge(text: '${s.id}', size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.nameFr,
                              style: GoogleFonts.lora(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: palette.textPrimary)),
                          Text(s.nameAr,
                              style: GoogleFonts.amiri(
                                  fontSize: 16, color: palette.textPrimary)),
                        ],
                      ),
                    ),
                    if (progress.isComplete)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('✓ Complet',
                            style: TextStyle(
                                color: palette.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      )
                    else
                      Text(S.versetN(progress.nextVerse, s.verses),
                          style: TextStyle(
                              color: palette.textMuted, fontSize: 12)),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: palette.textMuted),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.progress,
                    minHeight: 3,
                    backgroundColor: palette.textPrimary.withValues(alpha: 0.1),
                    color: palette.gold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(S.versetsAppris(progress.learnedCount, s.verses),
                    style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: palette.textMuted)),
              ],
            ),
          ).animate()
              .fadeIn(delay: Duration(milliseconds: 80 * index))
              .slideY(begin: 0.06),
        ),
      ),
    );
  }
}
