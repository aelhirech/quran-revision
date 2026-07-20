import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Dome/mihrab-silhouette hero card: very large top corners tapering to
/// small bottom corners, filled with the theme's primary color.
class DomeProgressCard extends StatelessWidget {
  final double topRadius;
  final double bottomRadius;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DomeProgressCard({
    super.key,
    required this.topRadius,
    this.bottomRadius = 20,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 32, 24, 20),
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topRadius),
          topRight: Radius.circular(topRadius),
          bottomLeft: Radius.circular(bottomRadius),
          bottomRight: Radius.circular(bottomRadius),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: palette.onPrimary),
        child: child,
      ),
    );
  }
}
