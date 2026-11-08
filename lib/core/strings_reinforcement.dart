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
  static String reviendront(int n) => n == 1
      ? S._t('1 question reviendra dans une prochaine série.',
          '1 question will come back in a later series.')
      : S._t('$n questions reviendront dans une prochaine série.',
          '$n questions will come back in a later series.');
  static String passeAuNiveau(String nom, int niveau) =>
      S._t('$nom passe au niveau $niveau.', '$nom moves up to level $niveau.');
  static String revientAuNiveau(String nom, int niveau) => S._t(
      '$nom revient au niveau $niveau.', '$nom goes back to level $niveau.');
  static String get modeMelange => S._t('Mélange', 'Mix');
  static String get modeVersets => S._t('Versets', 'Verses');
  static String get modeTraduction => S._t('Traduction', 'Meaning');
  static String get queVeutDire => S._t(
      'Que veut dire le mot en or ?', 'What does the golden word mean?');
  static String get quelMot =>
      S._t('Quel mot porte ce sens ?', 'Which word carries this meaning?');
  static String get motSensSep => S._t(' : ', ': ');
  static String motDemande(String mot) =>
      S._t('mot demandé : $mot', 'asked word: $mot');
  static String get sourceMots => S._t(
      'Sens : Dr Usama Nonnenmacher, CoranMot',
      'Meanings: Dr Usama Nonnenmacher, CoranMot');
  static String aRisque(int n) => n == 1
      ? S._t("1 sourate à risque d'oublier", '1 surah at risk of being forgotten')
      : S._t("$n sourates à risque d'oublier",
          '$n surahs at risk of being forgotten');
  static String get aucuneARisque => S._t("Aucune sourate à risque d'oublier.",
      'No surah at risk of being forgotten.');
  static String niveau(int level) => level == 0
      ? S._t('Pas encore jouée', 'Not played yet')
      : S._t('Niveau $level', 'Level $level');
  static String get risqueOublier =>
      S._t("Risque d'oublier", 'At risk of being forgotten');
  static String get derniereRevision =>
      S._t('Dernière révision', 'Last revision');
  static String get lancerSerieSur => S._t(
      'Lancer une série sur cette sourate', 'Start a series on this surah');
  static String get selectionTropPetite => S._t(
      'Ta sélection est trop petite pour composer une série. Ajoute une sourate dans les Réglages.',
      'Your selection is too small to build a series. Add a surah in Settings.');
}
