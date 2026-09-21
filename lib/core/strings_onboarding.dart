part of 'strings.dart';

/// Onboarding wizard strings (intro, method, pace, reminders, celebration).
class SOnboarding {
  // Onboarding — intro
  static String get bismillah => 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
  static String get homeEpigraph => 'وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا';
  static String get introTitle =>
      S._t("Ce qui s'efface, ce n'est pas ta sincérité",
          "What fades isn't your sincerity");
  static String get introLine1 => S._t(
    "Tu portes déjà du Coran. Ce qui te manque n'est pas la volonté — c'est une structure qui décide, chaque jour, ce que tu dois revoir.",
    "You already carry some of the Quran. What you lack isn't willpower — it's a structure that decides, every day, what you should go over.",
  );
  static String get introLine2 => S._t(
    "Sans elle, un jour de faible énergie suffit à faire sauter la révision. Puis un autre.",
    "Without it, one low-energy day is enough to skip your revision. Then another.",
  );
  static String get introAction =>
      S._t("Comment l'app s'y prend", 'How the app handles it');

  // Onboarding — method (the three layers, US-1 criterion 1)
  static String get methodTitle =>
      S._t('Tu ne choisis plus', 'You stop choosing');
  static String get methodSubtitle => S._t(
      "Chaque jour, l'app décide à ta place la portion à réviser. Elle fait tourner trois choses en même temps.",
      "Every day, the app decides your portion for you. It keeps three things moving at once.");
  static String get methodLayerNewTitle => S._t('Le nouveau', 'The new');
  static String get methodLayerNewBody => S._t(
      "Ce que tu es en train d'apprendre, travaillé un peu chaque jour.",
      'What you are currently memorizing, worked on a little every day.');
  static String get methodLayerFreshTitle =>
      S._t('Le récent encore fragile', 'The recent, still fragile');
  static String get methodLayerFreshBody => S._t(
      "Ce que tu viens de mémoriser et qui se perd vite si on n'y revient pas.",
      'What you just memorized and lose quickly if you never come back to it.');
  static String get methodLayerOldTitle =>
      S._t("L'ancien qu'on fait tourner", 'The old, kept in rotation');
  static String get methodLayerOldBody => S._t(
      'Ce qui est acquis, revu par roulement pour qu\'aucune sourate ne reste de côté.',
      'What you hold solidly, revised in rotation so no surah is left aside.');
  static String get methodLegitimacy => S._t(
      "C'est la méthode des hafiz depuis des générations. L'app ne fait que la tenir à ta place.",
      'This is how hafiz have worked for generations. The app just keeps track of it for you.');
  static String get methodAction =>
      S._t('Choisir mes sourates', 'Choose my surahs');

  // Onboarding — tour duration at the pace step (US-1 criterion 2).
  // Never phrased as a date at which revision would be "done": revision
  // loops by nature, only memorization has a real end.
  static String tourDuree(int n) => S.locale == 'fr'
      ? 'Un tour complet de ta sélection : ${S.joursDuration(n)}'
      : 'One full round of your selection: ${S.joursDuration(n)}';
  static String tourGarantie(int n) => S.locale == 'fr'
      ? 'Aucune de tes sourates ne restera plus de ${S.joursDuration(n)} sans être revue.'
      : 'None of your surahs will go more than ${S.joursDuration(n)} without being revised.';

  // Onboarding — preview of the first day's plan (US-1)
  static String get previewTitle => S._t('Voici ton premier jour', "Here's your first day");
  static String get previewSubtitle => S._t(
      "D'après ta sélection et ton rythme, voici ce que l'app te proposera dès aujourd'hui.",
      "Based on your selection and pace, here's what the app will suggest for you right away.");

  // Onboarding — the shape of a day, announced on the last step (US-1 crit. 3)
  static String get journeeFormeTitre =>
      S._t('La forme de ta journée', 'The shape of your day');
  static String get journeeFormeMatin => S._t(
      "Le matin, tu t'engages sur ta portion du jour.",
      "In the morning, you commit to the day's portion.");
  static String get journeeFormeMilieu => S._t(
      'Tu la révises dans tes prières.', 'You revise it within your prayers.');
  static String get journeeFormeSoir => S._t(
      "Le soir, tu clôtures — ce qui n'a pas tenu revient demain.",
      "In the evening, you close out — whatever didn't hold comes back tomorrow.");
  // Onboarding — config
  static String get rechercherSourate => S._t('Rechercher une sourate...', 'Search a surah...');
  static String get commencer => S._t('Commencer la révision', 'Start revision');
  static String get selectSourates => S._t('Sélectionne tes sourates', 'Select your surahs');
  static String get toutSelectionner => S._t('Tout sélectionner', 'Select all');
  static String get toutDeselectionner => S._t('Tout désélectionner', 'Deselect all');
  static String get aleatoireLabel => S._t('Ordre aléatoire', 'Random order');
  static String get aleatoireSubtitle => S._t('Mélange les sourates à chaque nouveau cycle', 'Shuffles surahs each new cycle');
  static String hizb(int n) => 'Hizb $n';
  // Onboarding wizard
  static String get selectionRapide => S._t('Sélection rapide', 'Quick select');
  static String get toutLeCoran => S._t('Tout le Coran', 'Full Quran');
  static String get etapeSelection => S._t('Mes sourates', 'My surahs');
  static String get cycleObjectif => S._t('Objectif de cycle', 'Cycle goal');
  static String etapeN(int n, int total) => '$n / $total';
  static String get fractionTroisQuarts => S._t('3/4', '3/4');
  static String get fractionMoitie => S._t('1/2', '1/2');
  static String get fractionQuart => S._t('1/4', '1/4');
  static String get hizbCourt => S._t('Hizb', 'Hizb');

  // Onboarding wizard — rythme/objectif
  static String get etapeRythme => S._t('Ton rythme', 'Your pace');
  static String get rythmeQuestion =>
      S._t('À quel rythme veux-tu avancer ?', 'At what pace do you want to progress?');
  static String get souratesAReviser =>
      S._t('Sourates à réviser', 'Surahs to revise');
  static String get pagesCustomTitle => S._t('Pages par jour personnalisées', 'Custom pages per day');
  static String get pagesSuffix => S._t('pages', 'pages');

  // Onboarding wizard — rappels
  static String get etapeRappels => S._t('Rappels', 'Reminders');
  static String get rappelsTitle =>
      S._t('Ne rate plus une révision', 'Never miss a revision');
  static String get rappelsBody => S._t(
    'Un rappel le matin pour planifier ta journée, un bilan le soir pour ne rien oublier.',
    'A morning reminder to plan your day, an evening recap so nothing slips.',
  );
  static String get activerRappels => S._t('Activer les rappels', 'Enable reminders');
  static String get plusTard => S._t('Plus tard', 'Later');

  // Onboarding wizard — célébration
  static String get bienvenueTitre =>
      S._t('Ton parcours commence', 'Your journey begins');
  static String get bienvenueSubtitle => S._t(
    "Qu'Allah facilite ta révision et bénisse chaque verset.",
    'May Allah ease your revision and bless every verse.',
  );
}
