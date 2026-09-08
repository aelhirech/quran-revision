part of '../onboarding_screen.dart';

class _RhythmPage extends StatelessWidget {
  final int pagesPerDay;
  final ValueChanged<int> onPagesPerDayChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _RhythmPage({
    required this.pagesPerDay,
    required this.onPagesPerDayChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
              trailing: PresetDropdown(
                value: pagesPerDay,
                presets: pagesPerDayPresets,
                labelBuilder: (n) => '$n ${S.pagesParJourValeur}',
                customDialogTitle: S.pagesCustomTitle,
                customSuffix: S.pagesSuffix,
                color: cs.onSurface,
                onChanged: onPagesPerDayChanged,
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 12),
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
