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
                    S.methodTitle,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                      height: 1.25,
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
                  const SizedBox(height: 12),
                  Text(
                    S.methodSubtitle,
                    style: TextStyle(
                        fontSize: 14.5, color: palette.textMuted, height: 1.6),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                  const SizedBox(height: 28),
                  _MethodLayer(
                    index: 1,
                    title: S.methodLayerNewTitle,
                    body: S.methodLayerNewBody,
                  ),
                  const SizedBox(height: 14),
                  _MethodLayer(
                    index: 2,
                    title: S.methodLayerFreshTitle,
                    body: S.methodLayerFreshBody,
                  ),
                  const SizedBox(height: 14),
                  _MethodLayer(
                    index: 3,
                    title: S.methodLayerOldTitle,
                    body: S.methodLayerOldBody,
                  ),
                  const SizedBox(height: 26),
                  Text(
                    S.methodLegitimacy,
                    style: TextStyle(
                      fontSize: 13.5,
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
              child: PrimaryCtaButton(label: S.methodAction, onPressed: onNext),
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
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary)),
              const SizedBox(height: 4),
              Text(body,
                  style: TextStyle(
                      fontSize: 13.5,
                      color: palette.textMuted,
                      height: 1.5)),
            ],
          ),
        ),
      ],
    ).animate()
        .fadeIn(delay: (100 * (index + 1)).ms, duration: 400.ms)
        .slideY(begin: 0.06);
  }
}
