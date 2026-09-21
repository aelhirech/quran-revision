part of 'strings.dart';

/// Daily check-in strings.
class SCheckIn {
  // Check-in / check-out (Phase 6 Sprint 2)
  static String get checkInEyebrow => S._t('BISMILLAH', 'BISMILLAH');
  static String get checkInTitle => S._t('Ta journée de révision', 'Your revision day');
  static String checkInVersesProposed(int n) => S._t(
      '$n verset${n > 1 ? 's' : ''} proposé${n > 1 ? 's' : ''} aujourd\'hui',
      '$n verse${n > 1 ? 's' : ''} proposed today');
  static String get checkInVueDuJour => S._t('Vue du jour', 'Today\'s view');
  static String get checkInAjouterSourate => S._t('Ajouter une sourate', 'Add a surah');
  static String get suivant => S._t('Suivant', 'Next');
  static String get retour => S._t('Retour', 'Back');

  // « Illuminer ma journée » (Phase 9) — rythme, apprentissage et prières
  // confirmés dans le même check-in que la liste de révision.
  static String get illuminerMaJournee =>
      S._t('Illuminer ma journée avec le Coran', 'Light up my day with the Quran');
  static String get illuminerSousTitre => S._t(
      'Confirme ton rythme, ce que tu apprends et tes prières du jour.',
      "Confirm your pace, what you're learning and today's prayers.");
  static String get checkInRythme => S._t('Mon rythme', 'My pace');
  static String get checkInApprentissage =>
      S._t("Ce que j'apprends aujourd'hui", "What I'm learning today");
  static String get checkInApprentissageDesc => S._t(
      'Ces versets seront récités dans ta dernière rakaa.',
      'These verses will be recited in your last rakaa.');
  static String get checkInChoisirSourate =>
      S._t('Choisir une sourate à apprendre', 'Choose a surah to learn');
  static String get checkInAucunApprentissage =>
      S._t("Je n'apprends rien aujourd'hui", "I'm not learning anything today");
  static String checkInVersetsAApprendre(int n) =>
      S._t('$n verset${n > 1 ? 's' : ''}', '$n verse${n > 1 ? 's' : ''}');
  static String get checkInPrieres => S._t('Mes prières du jour', "Today's prayers");
  static String get checkInPrieresDesc => S._t(
      "Celles où c'est toi qui récites — seul ou en imam.",
      "The ones where you recite — alone or leading as imam.");
  static String get checkInPrieresManquantes =>
      S._t('Choisis au moins une prière', 'Pick at least one prayer');
  static String get checkInLancerPlan => S._t('Voir mon plan du jour', 'See my daily plan');
  static String get checkInVersetsInclus =>
      S._t('Versets inclus aujourd\'hui', 'Verses included today');
  static String get checkInExtendHint => S._t(
      'Le "+" ajoute le prochain verset à la portée du jour.',
      'The "+" adds the next verse to today\'s scope.');
}
