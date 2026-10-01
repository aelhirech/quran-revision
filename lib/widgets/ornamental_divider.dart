import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';

/// Small centered line-diamond-line motif used under titles.
class OrnamentalDivider extends StatelessWidget {
  final double lineWidth;
  final double gap;
  final Color? color;

  /// Draws itself from the center on first build — the sober marker of a
  /// rare moment (US-13 milestone, US-14 day close), in place of an emoji.
  final bool draw;

  const OrnamentalDivider(
      {super.key, this.lineWidth = 32, this.gap = 8, this.color, this.draw = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.gold;
    final motif = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: lineWidth, height: 1, color: c),
        SizedBox(width: gap),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 6, height: 6, color: c),
        ),
        SizedBox(width: gap),
        Container(width: lineWidth, height: 1, color: c),
      ],
    );
    if (!draw) return motif;
    return motif
        .animate()
        .scaleX(begin: 0, duration: 800.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 800.ms);
  }
}
