import 'package:flutter/material.dart';
import '../core/app_colors.dart';

enum IndexBadgeState { unselected, selected, done }

/// Square (radius 10) index badge for sourate/rakaa/verse numbers.
class IndexBadge extends StatelessWidget {
  final String text;
  final IndexBadgeState state;
  final double size;
  final IconData? doneIcon;

  const IndexBadge({
    super.key,
    required this.text,
    this.state = IndexBadgeState.unselected,
    this.size = 30,
    this.doneIcon = Icons.check,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Color bg;
    Color border;
    Color fg;
    switch (state) {
      case IndexBadgeState.selected:
        bg = palette.primary;
        border = palette.primary;
        fg = palette.onPrimary;
        break;
      case IndexBadgeState.done:
        bg = palette.primary.withValues(alpha: 0.08);
        border = palette.primary.withValues(alpha: 0.4);
        fg = palette.primary;
        break;
      case IndexBadgeState.unselected:
        bg = Colors.transparent;
        border = palette.gold.withValues(alpha: 0.6);
        fg = palette.goldDark;
        break;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      alignment: Alignment.center,
      child: state == IndexBadgeState.done && doneIcon != null
          ? Icon(doneIcon, size: size * 0.45, color: fg)
          : Text(text, style: TextStyle(fontSize: size * 0.37, color: fg)),
    );
  }
}
