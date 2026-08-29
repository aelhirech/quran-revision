import 'quran_text_asset.dart';

/// Texte arabe du Coran selon la riwaya Warsh (transmission de Nafi').
/// Source : QUL (Tarteel AI), script Warsh — la numérotation des versets
/// est celle authentique de l'édition Warsh (6214 versets), différente de
/// celle de Hafs (6236 versets) : les deux riwayat sont deux parcours
/// indépendants dans l'app, jamais traduits l'un vers l'autre.
class WarshService {
  static final QuranTextAsset _asset = QuranTextAsset('assets/quran/warsh.json');

  static Future<void> initialize() => _asset.initialize();

  static String getVerse(int surahNumber, int verseNumber) =>
      _asset.getVerse(surahNumber, verseNumber);

  static Map<int, int> get verseCounts => _asset.verseCounts;
  static Map<int, int> get wordCounts => _asset.wordCounts;
}
