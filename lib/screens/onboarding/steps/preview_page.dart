part of '../onboarding_screen.dart';

/// Last step before the celebration (US-1 criterion 3): the story of a day of
/// use (US-17), then the REAL day-1 plan. Absorbed the former
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
  final bool showDayStory;
  final VoidCallback onBack;
  final VoidCallback? onConfirm;

  const _PreviewPage({
    required this.units,
    required this.paginationUnavailable,
    required this.showDayStory,
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
            title: SOnboarding.previewTitle,
            subtitle: SOnboarding.previewSubtitle,
            onBack: onBack,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                if (showDayStory) ...[
                  const _DayStory(),
                  const SizedBox(height: 4),
                  const OrnamentalDivider(),
                  const SizedBox(height: 20),
                ],
                Text(
                  SOnboarding.planJour1Titre,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary),
                ),
                const SizedBox(height: 12),
                if (paginationUnavailable)
                  const PaginationIndisponible()
                else
                  for (final unit in units)
                    UnitRow(
                      unit: unit,
                      subtitle: S.versetsCount(unit.verseCount),
                    ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(label: SOnboarding.commencer, onPressed: onConfirm),
            ),
          ),
        ],
      ),
    );
  }
}
