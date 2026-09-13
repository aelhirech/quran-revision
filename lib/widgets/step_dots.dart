import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Numbered-dot progress indicator, shown in `CheckHero.extra` — shared
/// between `CheckOutScreen` (2 steps) and `CheckInScreen` (3 steps) instead
/// of duplicated per screen.
class StepDots extends StatelessWidget {
  final int count;
  final int current;

  const StepDots({super.key, required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget dot(bool active, String label) => Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? palette.gold : Colors.transparent,
            border: Border.all(color: palette.gold),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, color: palette.onPrimary)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++) ...[
          if (i > 0) Container(width: 24, height: 1, color: palette.gold),
          dot(i == current, '${i + 1}'),
        ],
      ],
    );
  }
}
