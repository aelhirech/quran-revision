import 'package:flutter/material.dart';
import '../core/hadith_data.dart';
import '../core/strings.dart';

class PreviewBanner extends StatelessWidget {
  const PreviewBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = intentionHadith;
    final text = S.locale == 'en' ? h.textEn : h.textFr;
    final source = S.locale == 'en' ? h.sourceEn : h.sourceFr;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, color: cs.primary, size: 16),
              const SizedBox(width: 8),
              Text(S.apercuBanniere,
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Icon(Icons.format_quote_rounded, color: cs.primary, size: 16),
              const SizedBox(width: 6),
              Text(S.intentionLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: cs.onPrimaryContainer,
                  height: 1.5)),
          const SizedBox(height: 6),
          Text(source,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
