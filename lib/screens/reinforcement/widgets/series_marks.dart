import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

/// One diamond per question: filled if it held, hollow if missed, faint if
/// still to come. [current] is ringed.
class SeriesMarks extends StatelessWidget {
  final List<bool> held;
  final int total;
  final int? current;

  const SeriesMarks(
      {super.key, required this.held, required this.total, this.current});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [for (var i = 0; i < total; i++) _mark(palette, i)],
    );
  }

  Widget _mark(AppPalette palette, int i) {
    final answered = i < held.length;
    return Transform.rotate(
      angle: math.pi / 4,
      // Same box with or without the ring, so the row never shifts when the
      // current question moves.
      child: Container(
        width: 15,
        height: 15,
        alignment: Alignment.center,
        decoration: i == current
            ? BoxDecoration(
                border: Border.all(color: palette.textPrimary, width: 1.5))
            : null,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: answered && held[i] ? palette.gold : null,
            border: Border.all(
                color: answered ? palette.gold : palette.cardBorder,
                width: 1.5),
          ),
        ),
      ),
    );
  }
}
