import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';

/// Guided accompaniment on a real gesture (US-1 sprint B) — replaces the old
/// dismissible [HookBanner]/`HookVisibilityMixin`. Same gold-highlight visual
/// language, but no close icon: a step is only ever marked done by the real
/// gesture it accompanies (`AppState.markGuideDone`), never by tapping the
/// banner away. [actionLabel]/[onAction] are only for a step whose completion
/// gesture IS the banner itself (no other button exists for it elsewhere on
/// screen) — most steps omit them and rely on the screen's own primary
/// action (validating a check-in, opening the verse sheet, sealing a
/// check-out) to call `markGuideDone`.
class GuideStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const GuideStep({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: 0.07),
        border: Border.all(color: palette.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: palette.goldDark, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: palette.textPrimary)),
                    const SizedBox(height: 4),
                    Text(body,
                        style: TextStyle(
                            fontSize: 12, color: palette.textMuted, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(actionLabel!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.goldDark)),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.08);
  }
}
