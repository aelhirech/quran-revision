part of '../onboarding_screen.dart';

class _RecapPage extends StatelessWidget {
  final Map<int, SourateSelection> selections;
  final int totalVerses;
  final VoidCallback onBack;
  final VoidCallback? onConfirm;

  const _RecapPage({
    required this.selections,
    required this.totalVerses,
    required this.onBack,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeader(
              step: 4,
              total: _kOnboardingSteps,
              title: S.etapeRecap,
              onBack: onBack,
            ),
            const SizedBox(height: 24),
            const OrnamentalDivider(),
            const SizedBox(height: 24),
            // Récap sélection
            _RecapCard(
              icon: Icons.menu_book_outlined,
              label: S.souratesCount(selections.length, totalVerses),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(label: S.commencer, onPressed: onConfirm),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
