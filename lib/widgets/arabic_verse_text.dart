import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Texte arabe d'un ou plusieurs versets, en Amiri RTL — factorisé car le
/// même bloc (police, sens, alignement) revient identique dans la feuille de
/// versets, la carte d'apprentissage et l'écran de lecture de sourate ;
/// seuls taille/hauteur/couleur varient.
class ArabicVerseText extends StatelessWidget {
  final String text;
  final double fontSize;
  final double height;
  final Color? color;
  final TextAlign textAlign;

  const ArabicVerseText({
    super.key,
    required this.text,
    this.fontSize = 24,
    this.height = 2.0,
    this.color,
    this.textAlign = TextAlign.right,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      textDirection: TextDirection.rtl,
      style: GoogleFonts.amiri(fontSize: fontSize, height: height, color: color),
    );
  }
}
