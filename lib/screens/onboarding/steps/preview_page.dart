part of '../onboarding_screen.dart';

/// Last step before the celebration (US-1 criterion 3): the REAL day-1 plan,
/// followed by the shape the user's day will take. Absorbed the former
/// `_RecapPage`, which held this slot while only repeating the surah/verse
/// counts the celebration shows right after.
///
/// [units] come from the very config `_confirm` persists (same `startDate`,
/// hence the same shuffle seed) — a look-alike rebuilt here would show an
/// order the app never serves.
///
/// Shows surahs/portions, not a rakaa layout: onboarding doesn't know the
/// day's prayers yet (that only happens at check-in) — faking prayers here
/// would contradict "real preview" (criterion adjustment confirmed by the
/// user at scoping, 2026-09-13).
class _PreviewPage extends StatelessWidget {
  final List<RevisionUnit> units;
  final bool paginationUnavailable;
  final VoidCallback onBack;
  final VoidCallback? onConfirm;

  const _PreviewPage({
    required this.units,
    required this.paginationUnavailable,
    required this.onBack,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            step: 4,
            total: _kOnboardingSteps,
            title: S.previewTitle,
            subtitle: S.previewSubtitle,
            onBack: onBack,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                if (paginationUnavailable)
                  const PaginationIndisponible()
                else
                  for (final unit in units)
                    UnitRow(
                      unit: unit,
                      subtitle: S.versetsCount(unit.verseCount),
                    ),
                const SizedBox(height: 24),
                const OrnamentalDivider(),
                const SizedBox(height: 20),
                Text(
                  S.journeeFormeTitre,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary),
                ),
                const SizedBox(height: 12),
                _DayShapeLine(icon: Icons.wb_twilight, label: S.journeeFormeMatin),
                _DayShapeLine(
                    icon: Icons.self_improvement, label: S.journeeFormeMilieu),
                _DayShapeLine(
                    icon: Icons.nightlight_round, label: S.journeeFormeSoir),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(label: S.commencer, onPressed: onConfirm),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayShapeLine extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DayShapeLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: palette.goldDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5, color: palette.textMuted, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
