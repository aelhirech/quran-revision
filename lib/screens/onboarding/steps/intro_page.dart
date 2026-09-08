part of '../onboarding_screen.dart';

class _IntroPage extends StatelessWidget {
  final VoidCallback onNext;
  const _IntroPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            Text(
              S.bismillah,
              style: GoogleFonts.amiri(fontSize: 22, color: palette.gold),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 26),
            Text(
              S.introTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
                height: 1.25,
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.08),
            const SizedBox(height: 16),
            const OrnamentalDivider(),
            const SizedBox(height: 24),
            Text(
              S.introLine1,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15.5,
                  fontStyle: FontStyle.italic,
                  color: palette.textPrimary.withValues(alpha: 0.7),
                  height: 1.7),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 14),
            Text(
              S.introLine2,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15.5,
                  fontStyle: FontStyle.italic,
                  color: palette.textPrimary.withValues(alpha: 0.7),
                  height: 1.7),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const Spacer(flex: 4),
            SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(label: S.introAction, onPressed: onNext),
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
