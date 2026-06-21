import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/strings.dart';

class DailyVerseInfoCard extends StatelessWidget {
  const DailyVerseInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            child: Icon(Icons.auto_stories, color: cs.onPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.versetParJourTitle,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: cs.onPrimaryContainer)),
                const SizedBox(height: 2),
                Text(S.versetParJourDesc,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.75))),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.06);
  }
}
