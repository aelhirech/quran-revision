part of '../onboarding_screen.dart';

/// The method, right after the diagnosis of `_IntroPage` (US-1 criterion 1):
/// the app decides the day's portion, by keeping three layers turning at
/// once. Named in plain language on purpose — introducing unfamiliar
/// vocabulary is the very problem this screen exists to cure — and the
/// legitimacy is stated once, never repeated elsewhere.
class _MethodPage extends StatelessWidget {
  final VoidCallback onNext;
  const _MethodPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scrollable instead of Spacer-padded: this is the wordiest page
            // of the wizard, and it must survive a small screen or a large
            // accessibility text scale without overflowing.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 48, bottom: 16),
                children: [
                  Text(
                    SOnboarding.methodTitle,
                    style: AppText.screenTitle.copyWith(color: palette.textPrimary),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
                  const SizedBox(height: 12),
                  Text(
                    SOnboarding.methodSubtitle,
                    style: AppText.body.copyWith(color: palette.textMuted, height: 1.6),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                  const SizedBox(height: 28),
                  _MethodLayer(
                    index: 1,
                    title: SOnboarding.methodLayerNewTitle,
                    body: SOnboarding.methodLayerNewBody,
                  ),
                  const SizedBox(height: 14),
                  _MethodLayer(
                    index: 2,
                    title: SOnboarding.methodLayerFreshTitle,
                    body: SOnboarding.methodLayerFreshBody,
                  ),
                  const SizedBox(height: 14),
                  _MethodLayer(
                    index: 3,
                    title: SOnboarding.methodLayerOldTitle,
                    body: SOnboarding.methodLayerOldBody,
                  ),
                  const SizedBox(height: 26),
                  Text(
                    SOnboarding.methodLegitimacy,
                    style: AppText.caption.copyWith(
                      fontStyle: FontStyle.italic,
                      color: palette.goldDark,
                      height: 1.6,
                    ),
                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(label: SOnboarding.methodAction, onPressed: onNext),
            ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _MethodLayer extends StatelessWidget {
  final int index;
  final String title;
  final String body;

  const _MethodLayer({
    required this.index,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IndexBadge(text: '$index'),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppText.cardTitle.copyWith(color: palette.textPrimary)),
              const SizedBox(height: 4),
              Text(body,
                  style: AppText.body.copyWith(color: palette.textMuted, height: 1.5)),
            ],
          ),
        ),
      ],
    ).animate()
        .fadeIn(delay: (100 * (index + 1)).ms, duration: 400.ms)
        .slideY(begin: 0.06);
  }
}
