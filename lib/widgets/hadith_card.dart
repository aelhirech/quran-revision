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
    final palette = context.palette;
    final text = S.locale == 'en' ? hadith.textEn : hadith.textFr;
    final source = S.locale == 'en' ? hadith.sourceEn : hadith.sourceFr;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_rounded, color: palette.goldDark, size: 16),
              const SizedBox(width: 6),
              Text(S.hadithDuJourLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: palette.goldDark,
                      letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 10),
          Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  color: palette.textPrimary)),
          const SizedBox(height: 8),
          Text(source,
              style: TextStyle(
                  fontSize: 11,
                  color: palette.textMuted,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.06);
  }
}
