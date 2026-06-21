import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';

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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.greenContainer,
                      child: Text('${s.id}',
                          style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.nameFr,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          Text(s.nameAr,
                              style: TextStyle(
                                  fontSize: 14, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    if (progress.isComplete)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.greenContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('✓ Complet',
                            style: TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      )
                    else
                      Text(S.versetN(progress.nextVerse, s.verses),
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.progress,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 6),
                Text(S.versetsAppris(progress.learnedCount, s.verses),
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
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
