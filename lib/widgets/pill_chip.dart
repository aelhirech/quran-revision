import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

/// Fully-rounded selectable pill chip: filled primary when selected,
/// outline otherwise. Consolidates the repeated ad-hoc chip pattern used
/// across onboarding, prayer selector, student profile bar, settings.
class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool dashed;

  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? palette.primary
                : (dashed ? palette.gold.withValues(alpha: 0.8) : palette.textPrimary.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? palette.onPrimary : palette.textPrimary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.lora(
                fontSize: 13,
                color: selected ? palette.onPrimary : palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
