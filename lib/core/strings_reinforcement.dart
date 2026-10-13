part of 'strings.dart';

/// Reinforcement tab strings.
class SReinforcement {
  static String get onglet => S._t('Renforcement', 'Strengthen');
  static String get serieDuJour => S._t('Série du jour', "Today's series");
  static String get serieDuJourDesc => S._t(
      "Des questions sur ce que tu portes. L'app choisit, tu réponds.",
      'Questions on what you carry. The app picks, you answer.');
  static String get commencer => S._t('Commencer', 'Start');
  static String get choisirSourate =>
      S._t('Choisir une sourate', 'Pick a surah');
  static String serieSur(String nom) => S._t('Série sur $nom', 'Series on $nom');
  static String sourateVerset(String nom, int verset) =>
      S._t('$nom · verset $verset', '$nom · verse $verset');
  static String get quelleSuite =>
      S._t('Quelle est la suite ?', 'What comes next?');
  static String progression(int nombre, int total) =>
      S._t('$nombre sur $total', '$nombre of $total');
  static String passageDans(String sourate, int verset) => S._t(
      'Ce passage est dans $sourate, verset $verset.',
      'This passage is in $sourate, verse $verset.');
  static String get laSuite =>
      S._t("La suite, dans l'ordre", 'What follows, in order');
  static String get finSerieNote => S._t(
      'Ton tour de révision ne change pas : seule ta récitation le fait avancer.',
      'Your revision round does not change: only your recitation moves it forward.');
  static String get fermer => S._t('Fermer', 'Close');
  static String get modeMelange => S._t('Mélange', 'Mix');
  static String get modeVersets => S._t('Versets', 'Verses');
  static String get modeTraduction => S._t('Traduction', 'Meaning');
  static String get queVeutDire => S._t(
      'Que veut dire le mot en or ?', 'What does the golden word mean?');
  static String get quelMot =>
      S._t('Quel mot porte ce sens ?', 'Which word carries this meaning?');
  static String motSens(String mot, String sens) =>
      S._t('$mot : $sens', '$mot: $sens');
  static String get sourceMots => S._t(
      'Sens : Dr Usama Nonnenmacher, CoranMot',
      'Meanings: Dr Usama Nonnenmacher, CoranMot');
  static String get selectionTropPetite => S._t(
      'Ta sélection est trop petite pour composer une série. Ajoute une sourate dans les Réglages.',
      'Your selection is too small to build a series. Add a surah in Settings.');
}
