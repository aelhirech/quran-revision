import 'quran_text_asset.dart';

/// Texte arabe du Coran selon la riwaya Hafs (transmission de 'Asim).
/// Source : QUL (Tarteel AI), script QPC Hafs — texte publié par le King
/// Fahd Complex for the Printing of the Holy Quran (attribution confirmée
/// sur la page de la ressource QUL).
class HafsService {
  static final QuranTextAsset _asset = QuranTextAsset('assets/quran/hafs.json');

  static Future<void> initialize() => _asset.initialize();

  static String getVerse(int surahNumber, int verseNumber) =>
      _asset.getVerse(surahNumber, verseNumber);

  static Map<int, int> get verseCounts => _asset.verseCounts;
  static Map<int, int> get wordCounts => _asset.wordCounts;
}
