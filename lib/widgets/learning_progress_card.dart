import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';

/// One compact Recap line per surah being learned (US-23 crit. 3).
class LearningProgressCard extends StatelessWidget {
  final LearningProgress progress;
  final Future<void> Function() onDismiss;

  const LearningProgressCard({
    super.key,
    required this.progress,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final s = progress.sourate;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(s.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: palette.danger.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.delete_outline, color: palette.danger),
        ),
        // The deletion is confirmed and done by the caller (US-12), which
        // reloads the list: the tile itself never leaves on its own.
        confirmDismiss: (_) async {
          await onDismiss();
          return false;
        },
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.nameFr,
                    style: AppText.body.copyWith(
                        fontWeight: FontWeight.w600, color: palette.textPrimary)),
                const SizedBox(height: 2),
                Text(S.versetsAppris(progress.learnedCount, s.verses),
                    style: AppText.caption.copyWith(color: palette.textMuted)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.progress,
                    minHeight: 3,
                    backgroundColor: palette.textPrimary.withValues(alpha: 0.1),
                    color: palette.gold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
