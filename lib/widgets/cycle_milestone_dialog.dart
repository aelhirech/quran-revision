import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/strings.dart';

/// Célébration "cycle bouclé" — affichée au check-out (Phase 6 Sprint 2,
/// seul moment où `cyclePosition` peut boucler ; avant, affichée à la fin
/// d'une session PlanScreen).
class CycleMilestoneDialog extends StatelessWidget {
  const CycleMilestoneDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56))
                .animate()
                .scale(
                  begin: const Offset(0.4, 0.4),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 16),
            Text(
              S.cycleTermineTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              S.cycleTermineBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(S.continuer,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.06),
    );
  }
}
