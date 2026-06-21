import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/strings.dart';
import '../models/sourate_selection.dart';

class SouratesRecapCard extends StatelessWidget {
  final List<SourateSelection> selections;

  const SouratesRecapCard({super.key, required this.selections});

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
                trailing: Text(
                  sel.isWhole
                      ? '${s.verses} ${S.versetsLabel}'
                      : '${sel.verseStart}–${sel.verseEnd} (${sel.verseCount} ${S.versetsLabel})',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
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
