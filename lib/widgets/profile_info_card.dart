import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/strings.dart';
import '../models/user_config.dart';

class ProfileInfoCard extends StatelessWidget {
  final UserConfig config;
  final int elapsed;
  final int remaining;

  const ProfileInfoCard({
    super.key,
    required this.config,
    required this.elapsed,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _row(cs, Icons.calendar_today_outlined,
                S.dureeObjectif, S.joursDuration(config.revisionDays), 0),
            const Divider(height: 24),
            _row(cs, Icons.today_outlined,
                S.joursEcoules, S.joursDuration(elapsed), 80),
            const Divider(height: 24),
            _row(cs, Icons.timer_outlined,
                S.joursRestantsLabel, S.joursDuration(remaining), 160),
            const Divider(height: 24),
            _row(cs, Icons.menu_book_outlined,
                S.souratesMemoriees, '${config.selections.length}', 240),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _row(ColorScheme cs, IconData icon, String label, String value, int delayMs) {
    return Row(
      children: [
        Icon(icon, color: cs.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
        ),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
                fontSize: 15)),
      ],
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delayMs))
        .slideX(begin: 0.05);
  }
}
