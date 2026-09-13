import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/revision_unit.dart';
import '../models/sourate.dart';
import 'unit_range_label.dart';

/// Card for a surah/portion — range label + subtitle, an arabic badge on the
/// left, an optional trailing action (remove, swap...) and an optional
/// footer (preset chips). Used by check-in (a "×" or "swap" trailing action)
/// and by the end-of-onboarding preview (read-only, no action, no tap) —
/// [trailingIcon]/[onTrailing]/[onTap] are therefore all optional rather than
/// duplicated into a separate read-only variant.
class UnitRow extends StatelessWidget {
  final RevisionUnit unit;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData? trailingIcon;
  final VoidCallback? onTrailing;
  final Widget? footer;

  const UnitRow({
    super.key,
    required this.unit,
    required this.subtitle,
    this.onTap,
    this.trailingIcon,
    this.onTrailing,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surfaceCardSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _arabicInitial(palette, unit.sourate),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UnitRangeLabel(unit: unit, nameColor: palette.textPrimary),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style: TextStyle(fontSize: 11, color: palette.textMuted)),
                  ],
                ),
              ),
              if (trailingIcon != null)
                IconButton(
                  onPressed: onTrailing,
                  icon: Icon(trailingIcon, size: 16, color: palette.textMuted),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            footer!,
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: content,
            ),
    );
  }
}

Widget _arabicInitial(AppPalette palette, Sourate s) => Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: palette.gold.withValues(alpha: 0.55), width: 2),
      ),
      child: Text(s.nameAr.characters.first,
          style: GoogleFonts.amiri(fontSize: 16, color: palette.goldDark)),
    );
