import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// A mosaic tile: its shape and tint say the Quiz level, from 0 (not played
/// yet, an empty star outline) to 4. A tile at risk of being forgotten shows the orange star in a
/// ring instead, whatever its level (choice of 2026-11-08). A surah being
/// learned shows a gold star outline filled from the bottom up to
/// [learningFraction] (US-32), never the orange star.
class MosaicTileShape extends StatelessWidget {
  final int level;
  final bool atRisk;
  final double size;
  final double? learningFraction;

  const MosaicTileShape({
    super.key,
    required this.level,
    required this.atRisk,
    required this.size,
    this.learningFraction,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _TilePainter(
      level: level,
      atRisk: atRisk,
      learningFraction: learningFraction,
      palette: context.palette,
    ),
  );
}

class _TilePainter extends CustomPainter {
  final int level;
  final bool atRisk;
  final double? learningFraction;
  final AppPalette palette;

  const _TilePainter({
    required this.level,
    required this.atRisk,
    required this.learningFraction,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 * 0.95;
    final fill = Paint();

    final fraction = learningFraction;
    if (fraction != null) {
      final starRadius = radius * 0.9;
      final star = _star(center, starRadius);
      // The fraction runs over the star's own height, not the canvas: the
      // bounds would otherwise fall outside the star and both ends look alike.
      final bottom = center.dy + starRadius;
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          0,
          bottom - 2 * starRadius * fraction,
          size.width,
          size.height,
        ),
      );
      canvas.drawPath(star, fill..color = palette.gold);
      canvas.restore();
      canvas.drawPath(star, _stroke(palette.gold, radius));
      return;
    }

    if (atRisk) {
      fill.color = palette.risk;
      canvas.drawCircle(center, radius * 0.92, _stroke(palette.risk, radius));
      canvas.drawPath(_star(center, radius * 0.62), fill);
      return;
    }

    fill.color = palette.levelTints[level];
    switch (level) {
      // An empty star waiting to be filled (US-32): levelTints[0] is unused.
      case 0:
        canvas.drawPath(
          _star(center, radius * 0.9),
          _stroke(palette.goldDark, radius),
        );
      case 1:
        canvas.drawPath(_diamond(center, radius), fill);
      case 2:
        canvas.drawPath(_star(center, radius), fill);
      case 3:
        final hollow = _star(center, radius)
          ..addOval(Rect.fromCircle(center: center, radius: radius * 0.34))
          ..fillType = PathFillType.evenOdd;
        canvas.drawPath(hollow, fill);
      default:
        canvas.drawPath(_star(center, radius), fill);
        canvas.drawCircle(center, radius * 0.34, Paint()..color = palette.gold);
    }
  }

  Paint _stroke(Color color, double radius) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = radius * 0.14;

  Path _diamond(Offset center, double radius) => Path()
    ..moveTo(center.dx, center.dy - radius)
    ..lineTo(center.dx + radius, center.dy)
    ..lineTo(center.dx, center.dy + radius)
    ..lineTo(center.dx - radius, center.dy)
    ..close();

  // The eight-pointed star of two overlapping squares (khatam): its inner
  // vertices sit where the squares' edges cross.
  Path _star(Offset center, double radius) {
    final inner = radius * cos(pi / 4) / cos(pi / 8);
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final r = i.isEven ? radius : inner;
      final angle = -pi / 2 + i * pi / 8;
      final point = center + Offset(cos(angle), sin(angle)) * r;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_TilePainter old) =>
      old.level != level ||
      old.atRisk != atRisk ||
      old.learningFraction != learningFraction ||
      old.palette != palette;
}
