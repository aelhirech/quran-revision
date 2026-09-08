part of '../onboarding_screen.dart';

class _NotificationsPage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _NotificationsPage({required this.onBack, required this.onNext});

  @override
  State<_NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<_NotificationsPage> {
  bool _working = false;

  Future<void> _enable() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await NotificationService.enable();
    } finally {
      if (mounted) setState(() => _working = false);
    }
    if (!mounted) return;
    widget.onNext();
  }

  Future<void> _skip() async {
    await NotificationService.disable();
    if (!mounted) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StepHeader(
              step: 3,
              total: _kOnboardingSteps,
              title: S.etapeRappels,
              onBack: widget.onBack,
            ),
            const Spacer(flex: 2),
            Icon(Icons.notifications_active_outlined, size: 64, color: palette.gold)
                .animate()
                .scale(
                    begin: const Offset(0.6, 0.6),
                    duration: 400.ms,
                    curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Text(
              S.rappelsTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 12),
            Text(
              S.rappelsBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: palette.textPrimary.withValues(alpha: 0.7),
                  height: 1.5),
            ).animate().fadeIn(delay: 180.ms, duration: 300.ms),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(
                label: S.activerRappels,
                onPressed: _working ? null : _enable,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _working ? null : _skip,
              child: Text(S.plusTard, style: TextStyle(color: palette.textMuted)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
