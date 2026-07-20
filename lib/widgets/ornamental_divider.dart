import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Small centered line-diamond-line motif used under titles.
class OrnamentalDivider extends StatelessWidget {
  final double lineWidth;
  final double gap;
  final Color? color;

  const OrnamentalDivider({super.key, this.lineWidth = 32, this.gap = 8, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.gold;
    return Row(
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
  }
}
