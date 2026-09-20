import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';

/// Shown when surahs are selected but the cycle came out empty — the only
/// possible cause is that the mushaf pagination failed to load. Saying so
/// beats a silent "0 / 0 pages", which reads like a finished cycle
/// (`CLAUDE.md`, "Règle du plan quotidien" §F).
///
/// Shared by the home screen and the onboarding day-1 step so the same
/// failure never gets two different wordings or two different looks.
class PaginationIndisponible extends StatelessWidget {
  const PaginationIndisponible({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: palette.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(S.paginationIndisponible,
                style: TextStyle(fontSize: 12, color: palette.textPrimary)),
          ),
        ],
      ),
    );
  }
}
