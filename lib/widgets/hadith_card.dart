import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/hadith_data.dart';
import '../core/strings.dart';

class HadithCard extends StatelessWidget {
  final Hadith hadith;

  const HadithCard({super.key, required this.hadith});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = S.locale == 'en' ? hadith.textEn : hadith.textFr;
    final source = S.locale == 'en' ? hadith.sourceEn : hadith.sourceFr;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_rounded, color: AppColors.green, size: 18),
              const SizedBox(width: 6),
              Text(S.hadithDuJourLabel,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 10),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, fontStyle: FontStyle.italic, height: 1.5)),
          const SizedBox(height: 8),
          Text(source,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.06);
  }
}
