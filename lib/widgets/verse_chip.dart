import 'package:flutter/material.dart';

/// Petit badge carré (30×30) utilisé pour représenter un verset dans les
/// écrans détail du check-in/check-out (numéro, chip "+" pour étendre,
/// bookmark pour "à retravailler") — même forme, seul le contenu/la couleur
/// change selon l'état.
class VerseChip extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color? fillColor;
  final VoidCallback? onTap;

  const VerseChip({
    super.key,
    required this.child,
    required this.borderColor,
    this.fillColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: fillColor ?? Colors.transparent,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(9), child: content);
  }
}
