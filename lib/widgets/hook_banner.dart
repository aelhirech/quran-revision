import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../state/app_state.dart';

/// Factors the "seen once" visibility/dismiss wiring shared by the 4 US-1
/// contextual hooks (check-in, check-out, récap, réglages) — identical
/// across all 4 screens before this mixin, differing only in [hookId] and in
/// the [HookBanner] content each screen passes. A single [hookId] getter
/// backs both [loadHook] and [dismissHook], so the two can never drift apart
/// within one screen the way two independently-typed string literals could.
mixin HookVisibilityMixin<T extends StatefulWidget> on State<T> {
  String get hookId;
  bool showHook = false;

  Future<void> loadHook() async {
    final seen = await context.read<AppState>().hasSeenHook(hookId);
    if (!mounted || seen) return;
    setState(() => showHook = true);
  }

  Future<void> dismissHook() async {
    setState(() => showHook = false);
    await context.read<AppState>().markHookSeen(hookId);
  }
}

/// Dismissible "first visit" banner (US-1 criterion 5) — explains what a key
/// moment (check-in, check-out, récap, réglages) brings, shown once per
/// screen. Same gold-highlight style already used for informational blocks
/// elsewhere (`PlanScreen._summaryBar`, the check-in "À prioriser" card).
class HookBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onDismiss;

  const HookBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: 0.07),
        border: Border.all(color: palette.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.goldDark, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: palette.textPrimary)),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        fontSize: 12, color: palette.textMuted, height: 1.4)),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close, size: 16, color: palette.textMuted),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.08);
  }
}
