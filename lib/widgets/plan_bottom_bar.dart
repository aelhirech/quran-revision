import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import 'primary_cta_button.dart';

/// Bottom bar of `PlanScreen`: the "N / M rakaas" counter and the
/// "Close my day" button.
class PlanBottomBar extends StatelessWidget {
  final int checkedCount;
  final int totalRakaas;
  final bool showRakaaCount;
  final bool allDone;
  final VoidCallback onCloturer;

  const PlanBottomBar({
    super.key,
    required this.checkedCount,
    required this.totalRakaas,
    required this.showRakaaCount,
    required this.allDone,
    required this.onCloturer,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showRakaaCount) ...[
              Text('$checkedCount / $totalRakaas ${S.rakaasLabel}',
                  style: AppText.caption.copyWith(color: palette.textMuted)),
              const SizedBox(height: 8),
            ],
            SizedBox(height: 56, child: _completionButton()),
          ],
        ),
      ),
    );
  }

  /// "Close my day" — **always active** (2026-09-07 scoping decision):
  /// check-out is precisely the place to correct what wasn't done as well as
  /// what was done extra; locking it until every rakaa is checked would
  /// force a false check just to close the day. The celebration animation,
  /// though, only fires once everything is actually checked.
  Widget _completionButton() {
    final button = PrimaryCtaButton(
      onPressed: onCloturer,
      icon: allDone ? Icons.check_circle : Icons.nightlight_outlined,
      label: S.cloturerMaJournee,
    );

    if (!allDone) return button;

    return button
        .animate(key: const ValueKey('done'))
        .scale(
            begin: const Offset(0.92, 0.92),
            end: const Offset(1, 1),
            duration: 350.ms,
            curve: Curves.elasticOut)
        .shimmer(
            duration: 900.ms,
            color: Colors.white.withValues(alpha: 0.4),
            delay: 100.ms);
  }
}
