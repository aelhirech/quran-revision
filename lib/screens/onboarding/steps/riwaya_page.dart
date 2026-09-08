part of '../onboarding_screen.dart';

class _RiwayaPage extends StatelessWidget {
  final void Function(Riwaya) onSelect;
  const _RiwayaPage({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Text(
              S.choisirRiwayaTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
                height: 1.25,
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
            const SizedBox(height: 12),
            Text(
              S.choisirRiwayaSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: palette.textPrimary.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            const SizedBox(height: 32),
            _RiwayaChoiceCard(
              label: S.hafs,
              description: S.hafsDescription,
              onTap: () => onSelect(Riwaya.hafs),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 14),
            _RiwayaChoiceCard(
              label: S.warsh,
              description: S.warshDescription,
              onTap: () => onSelect(Riwaya.warsh),
            ).animate().fadeIn(delay: 280.ms, duration: 400.ms).slideY(begin: 0.1),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

class _RiwayaChoiceCard extends StatelessWidget {
  final String label;
  final String description;
  final VoidCallback onTap;

  const _RiwayaChoiceCard({
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary)),
            const SizedBox(height: 6),
            Text(description,
                style: TextStyle(fontSize: 13, color: palette.textMuted)),
          ],
        ),
      ),
    );
  }
}
