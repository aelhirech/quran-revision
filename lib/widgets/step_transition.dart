import 'package:flutter/material.dart';

/// Step content of the check-in/check-out: a fade with a slight slide each
/// time [step] changes. Meant to fill an `Expanded` (hence `StackFit.expand`
/// while the two steps overlap).
class StepTransition extends StatelessWidget {
  final int step;
  final Widget child;

  const StepTransition({super.key, required this.step, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      // The outgoing step leaves faster, so both are not half-visible on top
      // of each other mid-transition.
      reverseDuration: const Duration(milliseconds: 120),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.04, 0), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(step), child: child),
    );
  }
}
