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
  final String? translation;

  const VerseRow({
    super.key,
    required this.number,
    required this.text,
    this.fontSize = 22,
    this.translation,
  });

  @override
  Widget build(BuildContext context) {
    final translation = this.translation;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IndexBadge(text: '$number', size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ArabicVerseText(text: text, fontSize: fontSize),
              if (translation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    translation,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
