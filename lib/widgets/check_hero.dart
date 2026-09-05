import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Bandeau "hero" partagé entre `CheckInScreen` et `CheckOutScreen` — même
/// structure (eyebrow, titre, badge à bordure) pour les deux ; `extra` est le
/// seul point de variation (step dots multi-jours de `CheckOutScreen`,
/// absent en check-in).
class CheckHero extends StatelessWidget {
  final String eyebrow;
  final Widget? extra;
  final String title;
  final String badge;

  const CheckHero({
    super.key,
    required this.eyebrow,
    this.extra,
    required this.title,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Text(eyebrow,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: palette.onPrimary.withValues(alpha: 0.65))),
          if (extra != null) ...[
            const SizedBox(height: 10),
            extra!,
          ],
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w600, color: palette.onPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: palette.onPrimary.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badge,
                style: TextStyle(fontSize: 10, color: palette.onPrimary.withValues(alpha: 0.82))),
          ),
        ],
      ),
    );
  }
}
