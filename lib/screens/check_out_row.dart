import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/revision_unit.dart';
import '../widgets/unit_range_label.dart';

/// Une sourate/portion du plan du jour dans [CheckOutScreen] — case "fait/
/// pas fait" à gauche, ouvre le détail (versets à retravailler) au tap sur
/// le libellé en dessous.
class CheckOutRow extends StatelessWidget {
  final RevisionUnit unit;
  final bool reach;
  final VoidCallback onToggle;
  final VoidCallback onDetail;

  const CheckOutRow({
    super.key,
    required this.unit,
    required this.reach,
    required this.onToggle,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceCardSolid,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: reach ? palette.primary : Colors.transparent,
                        border: Border.all(
                          color: reach ? palette.primary : palette.cardBorder,
                        ),
                      ),
                      child: reach
                          ? Icon(
                              Icons.check,
                              size: 15,
                              color: palette.onPrimary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: UnitRangeLabel(
                        unit: unit,
                        nameColor: reach
                            ? palette.textPrimary
                            : palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: onDetail,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(
                  children: [
                    Text(
                      S.checkOutVoirVersets(unit.verseCount),
                      style: TextStyle(fontSize: 11.5, color: palette.goldDark),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
