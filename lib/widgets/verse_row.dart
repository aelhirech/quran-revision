import 'package:flutter/material.dart';
import 'arabic_verse_text.dart';
import 'index_badge.dart';

/// Un verset affiché = un badge numéroté + son texte arabe — factorisé car ce
/// même besoin ("afficher le Coran entre ayah_start et ayah_end") revenait en
/// plusieurs implémentations quasi identiques (feuille de versets, carte
/// d'apprentissage, écran de lecture) avec un chiffre arabe-indic en fin de
/// texte plutôt qu'un badge (retour utilisateur : redondant, préférer un seul
/// indicateur visuel).
class VerseRow extends StatelessWidget {
  final int number;
  final String text;
  final double fontSize;

  /// Shown dimmed, without joining what's being memorized/revised — the
  /// verse right before a learning range, offered only as a recall aid.
  final bool isContext;

  const VerseRow({
    super.key,
    required this.number,
    required this.text,
    this.fontSize = 22,
    this.isContext = false,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IndexBadge(text: '$number', size: 26),
        const SizedBox(width: 10),
        Expanded(child: ArabicVerseText(text: text, fontSize: fontSize)),
      ],
    );
    return isContext ? Opacity(opacity: 0.55, child: row) : row;
  }
}
