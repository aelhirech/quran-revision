part of '../onboarding_screen.dart';

class _RhythmPage extends StatelessWidget {
  final int pagesPerDay;

  /// Days one full round of the selection takes at [pagesPerDay] — 0 while
  /// nothing is selected yet, in which case no promise is shown.
  final int cycleDays;
  final ValueChanged<int> onPagesPerDayChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _RhythmPage({
    required this.pagesPerDay,
    required this.cycleDays,
    required this.onPagesPerDayChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeader(
              step: 2,
              total: _kOnboardingSteps,
              title: S.etapeRythme,
              subtitle: S.rythmeQuestion,
              onBack: onBack,
            ),
            const SizedBox(height: 24),
            _RecapCard(
              icon: Icons.calendar_today_outlined,
              label: S.cycleObjectif,
              trailing: PagesPerDayDropdown(
                value: pagesPerDay,
                color: cs.onSurface,
                onChanged: onPagesPerDayChanged,
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 16),
            // A round, never a finish line: revision loops by nature, so this
            // is phrased as a duration and a guarantee — never as a date by
            // which the user would be "done" revising (US-1 criterion 2).
            if (cycleDays > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.tourDuree(cycleDays),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      S.tourGarantie(cycleDays),
                      style: TextStyle(
                          fontSize: 13,
                          color: palette.textMuted,
                          height: 1.5),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 250.ms),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(label: S.continuer, onPressed: onNext),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
