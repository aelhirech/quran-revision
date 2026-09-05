import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/revision_unit.dart';

/// Texte "Sourate · v.X–Y" partagé entre les lignes de check-in et
/// check-out — seule la couleur du nom varie (grisée si l'unité est
/// décochée en check-out, toujours pleine en check-in).
class UnitRangeLabel extends StatelessWidget {
  final RevisionUnit unit;
  final Color nameColor;

  const UnitRangeLabel({super.key, required this.unit, required this.nameColor});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: nameColor),
        children: [
          TextSpan(text: unit.sourate.nameFr),
          TextSpan(
            text: '  ·  v.${unit.verseStart}–${unit.verseEnd}',
            style: TextStyle(
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                fontSize: 11.5,
                color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}
