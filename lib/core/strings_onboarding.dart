part of 'strings.dart';

/// Onboarding wizard strings (intro, method, pace, reminders, celebration).
class SOnboarding {
  // Onboarding — intro
  static String get bismillah => 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
  static String get homeEpigraph => 'وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا';
  static String get introTitle =>
      S._t("Si tu oublies, ce n'est pas un manque de sincérité",
          "If you forget, it's not for lack of sincerity");
  static String get introLine1 => S._t(
    "Tu connais déjà une partie du Coran. Tu ne manques pas de volonté. Il te manque un plan qui décide, chaque jour, ce que tu dois revoir.",
    "You already know part of the Quran. You don't lack willpower. You lack a plan that decides, every day, what to go over.",
  );
  static String get introLine2 => S._t(
    "Sans plan, un jour de fatigue suffit pour sauter ta révision. Puis un autre.",
    "Without a plan, one tired day is enough to skip your revision. Then another.",
  );
  static String get introAction =>
      S._t("Comment l'app s'y prend", 'How the app handles it');

  // Onboarding — method (the three layers, US-1 criterion 1)
  static String get methodTitle =>
      S._t('Tu ne choisis plus', 'You stop choosing');
  static String get methodSubtitle => S._t(
      "Chaque jour, l'app choisit pour toi ce que tu révises. Elle fait avancer trois choses en même temps.",
      'Every day, the app picks what you revise. It moves three things forward at once.');
  static String get methodLayerNewTitle =>
      S._t('Ce que tu apprends', "What you're learning");
  static String get methodLayerNewBody => S._t(
      'Tu en travailles un peu chaque jour.',
      'You work on a little of it every day.');
  static String get methodLayerFreshTitle =>
      S._t("Ce que tu viens d'apprendre", 'What you just learned');
  static String get methodLayerFreshBody => S._t(
      "Ça s'oublie vite si tu n'y reviens pas.",
      "It's quickly forgotten if you don't come back to it.");
  static String get methodLayerOldTitle =>
      S._t('Ce que tu connais déjà', 'What you already know');
  static String get methodLayerOldBody => S._t(
      "Revu régulièrement, pour qu'aucune sourate ne reste de côté.",
      'Revised regularly, so no surah is left aside.');
  static String get methodLegitimacy => S._t(
      "C'est la méthode des hafiz depuis des générations. L'app s'en occupe pour toi.",
      'This is how hafiz have worked for generations. The app takes care of it for you.');
  static String get methodAction =>
      S._t('Choisir mes sourates', 'Choose my surahs');

  // Onboarding — tour duration at the pace step (US-1 criterion 2).
  // Never phrased as a date at which revision would be "done": revision
  // loops by nature, only memorization has a real end.
  static String tourDuree(int n) => S.locale == 'fr'
      ? 'Un tour complet de tes sourates : ${S.joursDuration(n)}'
      : 'One full round of your surahs: ${S.joursDuration(n)}';
  static String tourGarantie(int n) => S.locale == 'fr'
      ? 'Aucune de tes sourates ne restera plus de ${S.joursDuration(n)} sans être revue.'
      : 'None of your surahs will go more than ${S.joursDuration(n)} without being revised.';

  // Onboarding — preview of the first day's plan (US-1)
  static String get previewTitle => S._t('Voici ton premier jour', "Here's your first day");
  static String get previewSubtitle => S._t(
      "Ta journée avec l'app, c'est quatre gestes.",
      'Your day with the app is four gestures.');

  // Onboarding — the story of a day of use, on the last step (US-17)
  static String get recitMatinTitre => S._t('Le matin', 'In the morning');
  static String get recitMatinCorps => S._t(
      "L'app a déjà préparé ton plan du jour : les pages à réviser, les versets à apprendre. Tu confirmes, ou tu changes.",
      "The app has already prepared today's plan: the pages to revise, the verses to learn. You confirm, or you adjust.");
  static String get recitPrieresTitre =>
      S._t('Dans tes prières', 'In your prayers');
  static String get recitPrieresCorps => S._t(
      'Ton plan est réparti dans tes rakaas. Sur chaque ligne, ce bouton ouvre le texte à réciter.',
      'Your plan is spread across your rakaas. On each line, this button opens the text to recite.');
  static String get recitEcouteTitre => S._t(
      'Avant de prier, ou quand tu veux', 'Before praying, or whenever you like');
  static String get recitEcouteCorps => S._t(
      "Écoute le passage en boucle et répète-le jusqu'à le connaître.",
      'Listen to the passage on a loop and repeat it until you know it.');
  static String get recitSoirTitre => S._t('Le soir', 'In the evening');
  static String get recitSoirCorps => S._t(
      'Tu confirmes ce que tu as réussi. Le reste revient demain, tout seul.',
      'You confirm what you got right. The rest comes back tomorrow, on its own.');
  static String get planJour1Titre =>
      S._t('Ton plan du jour', "Today's plan");
  // Onboarding — config
  static String get rechercherSourate => S._t('Rechercher une sourate...', 'Search a surah...');
  static String get commencer => S._t('Commencer la révision', 'Start revision');
  static String get selectSourates => S._t('Sélectionne tes sourates', 'Select your surahs');
  static String get toutSelectionner => S._t('Tout sélectionner', 'Select all');
  static String get toutDeselectionner => S._t('Tout désélectionner', 'Deselect all');
  static String get aleatoireLabel => S._t('Ordre aléatoire', 'Random order');
  static String get aleatoireSubtitle => S._t('Mélange tes sourates à chaque nouveau tour', 'Shuffles your surahs each new round');
  static String hizb(int n) => 'Hizb $n';
  // Onboarding wizard
  static String get selectionRapide => S._t('Sélection rapide', 'Quick select');
  static String get toutLeCoran => S._t('Tout le Coran', 'Full Quran');
  static String get etapeSelection => S._t('Mes sourates', 'My surahs');
  static String get cycleObjectif => S._t('Rythme', 'Pace');
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
      S._t('Ta révision commence', 'Your revision begins');
  static String get bienvenueSubtitle => S._t(
    "Qu'Allah facilite ta révision et bénisse chaque verset.",
    'May Allah ease your revision and bless every verse.',
  );
}
