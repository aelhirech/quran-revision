part of '../onboarding_screen.dart';

class _CelebrationPage extends StatefulWidget {
  final Map<int, SourateSelection> selections;
  final int totalVerses;
  final Future<void> Function() onStart;

  const _CelebrationPage({
    required this.selections,
    required this.totalVerses,
    required this.onStart,
  });

  @override
  State<_CelebrationPage> createState() => _CelebrationPageState();
}

class _CelebrationPageState extends State<_CelebrationPage> {
  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await widget.onStart();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopScope(
      canPop: !_starting,
      child: Scaffold(
        backgroundColor: palette.cream,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                const Text('✨', style: TextStyle(fontSize: 56))
                    .animate()
                    .scale(
                        begin: const Offset(0.3, 0.3),
                        duration: 600.ms,
                        curve: Curves.elasticOut)
                    .then()
                    .shimmer(duration: 800.ms),
                const SizedBox(height: 20),
                Text(
                  S.bienvenueTitre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 12),
                Text(
                  S.bienvenueSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: palette.textPrimary.withValues(alpha: 0.7),
                      height: 1.6),
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                const SizedBox(height: 28),
                const OrnamentalDivider(),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: palette.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.gold.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    S.souratesCount(widget.selections.length, widget.totalVerses),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.goldDark),
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.15),
                const Spacer(flex: 4),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryCtaButton(
                    label: S.continuer,
                    onPressed: _starting ? null : _start,
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
