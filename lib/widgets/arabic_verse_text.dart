import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/reinforcement_engine.dart';

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

  /// Rank, among the space-separated words of [text], of a word to paint in
  /// [highlightColor].
  final int? highlightWord;
  final Color? highlightColor;

  const ArabicVerseText({
    super.key,
    required this.text,
    this.fontSize = 24,
    this.height = 2.0,
    this.color,
    this.textAlign = TextAlign.right,
    this.highlightWord,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final style =
        GoogleFonts.amiri(fontSize: fontSize, height: height, color: color);
    final highlightWord = this.highlightWord;
    if (highlightWord == null) {
      return Text(
        text,
        textAlign: textAlign,
        textDirection: TextDirection.rtl,
        style: style,
      );
    }
    final words = text.split(' ');
    final token = words[highlightWord];
    final word = withoutHizbSign(token);
    // The sign glued to the word keeps the colour of the text.
    final sign = token.substring(0, token.length - word.length);
    final before = [...words.take(highlightWord), sign].join(' ');
    final after = words.skip(highlightWord + 1).join(' ');
    return Text.rich(
      TextSpan(children: [
        if (before.isNotEmpty) TextSpan(text: before),
        TextSpan(text: word, style: TextStyle(color: highlightColor)),
        if (highlightWord < words.length - 1) TextSpan(text: ' $after'),
      ]),
      textAlign: textAlign,
      textDirection: TextDirection.rtl,
      style: style,
    );
  }
}
