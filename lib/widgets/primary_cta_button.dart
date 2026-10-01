import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Big CTA button pinned to the bottom of a screen. Light mode gets a hard
/// offset gold drop-shadow; dark mode gets a soft mint glow instead.
class PrimaryCtaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  const PrimaryCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shadow = palette.isDark
        ? [
            BoxShadow(
              color: palette.ctaShadow.withValues(alpha: 0.24),
              blurRadius: 28,
            ),
          ]
        : [
            BoxShadow(
              color: palette.ctaShadow,
              offset: const Offset(3, 3),
            ),
          ];

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // No shadow when disabled: the light theme's hard gold offset showed
        // through the translucent disabled fill and read as an active button.
        boxShadow: onPressed == null ? null : shadow,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            // Shrinks a long label to fit rather than cutting it: next to the
            // StepFooter's back button, "Voir mon plan du jour" lost its end.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(letterSpacing: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
