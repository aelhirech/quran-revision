part of '../onboarding_screen.dart';

/// Simple title/subtitle header for pages outside the numbered stepper —
/// Demo and Preview, like Intro/Riwaya before them, don't count towards
/// `_kOnboardingSteps` and so skip the `_StepHeader` progress bar.
class _OnboardingHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _OnboardingHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 13.5, color: palette.textMuted, height: 1.5)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

/// Shared layout for an unnumbered onboarding step made of a header, a
/// scrollable list, and one CTA button — Demo and Preview (US-1) are
/// otherwise identical shells around different content.
class _OnboardingListStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final String ctaLabel;
  final VoidCallback onCta;

  const _OnboardingListStep({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.ctaLabel,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OnboardingHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: children,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(label: ctaLabel, onPressed: onCta),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  const _StepHeader({
    required this.step,
    required this.total,
    required this.title,
    this.subtitle,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: cs.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer)),
              ),
              Text(S.etapeN(step, total),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                subtitle!,
                key: ValueKey(subtitle),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8)),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: step / total,
              backgroundColor:
                  cs.onPrimaryContainer.withValues(alpha: 0.2),
              color: context.palette.gold,
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
