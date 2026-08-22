import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/freshness_engine.dart';
import '../core/strings.dart';
import '../models/sourate_selection.dart';
import '../screens/surah_reader_screen.dart';
import 'freshness_badge.dart';

class SouratesRecapCard extends StatelessWidget {
  final List<SourateSelection> selections;
  final FreshnessLevel? Function(int sourateId)? freshnessOf;

  const SouratesRecapCard({
    super.key,
    required this.selections,
    this.freshnessOf,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(S.mesSourates,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      fontSize: 15)),
            ),
            ...selections.asMap().entries.map((e) {
              final sel = e.value;
              final s = sel.sourate;
              final freshness = freshnessOf?.call(s.id);
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  child: Text('${s.id}', style: const TextStyle(fontSize: 10)),
                ),
                title: Text(s.nameFr,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(s.nameAr),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (freshness != null) ...[
                      FreshnessBadge(level: freshness),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      sel.isWhole
                          ? '${s.verses} ${S.versetsLabel}'
                          : '${sel.verseStart}–${sel.verseEnd} (${sel.verseCount} ${S.versetsLabel})',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SurahReaderScreen(selection: sel),
                )),
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 300 + e.key * 40))
                  .slideX(begin: 0.05);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }
}
