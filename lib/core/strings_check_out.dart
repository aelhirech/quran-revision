part of 'strings.dart';

/// Check-out strings.
class SCheckOut {
  static String get checkOutEyebrow => S._t('BILAN', 'REVIEW');
  static String get checkOutRattrapageEyebrow =>
      S._t('BILAN · RATTRAPAGE', 'REVIEW · CATCH-UP');
  static String get checkOutTitreHier => S._t('Hier, qu\'as-tu fait ?', 'What did you do yesterday?');
  static String get checkOutTitreCeJour => S._t(
      "Aujourd'hui, qu'as-tu fait ?", 'What did you do today?');
  static String get checkOutAujourdhui =>
      S._t("Aujourd'hui", 'Today');
  static String get checkOutTitreEnAttente =>
      S._t('Un jour est resté en attente', 'A day is still pending');
  static String get checkOutTitreAujourdhui => S._t('Et aujourd\'hui ?', 'What about today?');
  static String get checkOutHier => S._t('Hier', 'Yesterday');
  static String checkOutIlYaNJours(int n) =>
      S._t('Il y a $n jour${n > 1 ? 's' : ''}', '$n day${n > 1 ? 's' : ''} ago');
  static String get checkOutPartieOptionnelle =>
      S._t('Partie 2 · optionnelle', 'Part 2 · optional');
  static String get checkOutCloturerHier => S._t('Clôturer hier', 'Close out yesterday');
  static String get checkOutCloturerJour => S._t('Clôturer ce jour', 'Close out this day');
  static String get checkOutAjouterAujourdhui =>
      S._t('Ajouter aussi aujourd\'hui', 'Also add today');
  static String get checkOutAjouterDesc => S._t(
      'Optionnel — ces versets seront datés d\'aujourd\'hui.',
      'Optional — these verses will be dated today.');
  static String get checkOutValiderAujourdhui =>
      S._t('Valider aussi aujourd\'hui', 'Confirm today too');
  static String get checkOutTerminerSans => S._t('Terminer sans aujourd\'hui', 'Finish without today');

  // Check-out — « j'ai fait plus que prévu » (Phase 9)
  static String get checkOutReviseEnPlus =>
      S._t("J'ai révisé une sourate en plus", 'I revised one more surah');
  static String get checkOutSourateEnPlusTitre =>
      S._t('Ajouter une sourate révisée', 'Add a revised surah');
  static String get checkOutApprisEnPlusHint => S._t(
      'Le "+" ajoute un verset appris en plus aujourd\'hui.',
      'The "+" adds one more verse memorized today.');

  // Check-out — volet apprentissage (Phase 9)
  static String get checkOutApprentissage =>
      S._t('Ce que tu as appris', 'What you memorized');
  static String get checkOutApprentissageDesc => S._t(
      'Décoche un verset à continuer d\'apprendre : il sera reproposé demain.',
      'Uncheck a verse to keep learning: it will be proposed again tomorrow.');
  static String sourateApprise(String name) =>
      S._t('$name est mémorisée — elle rejoint ta révision ✓',
          '$name is memorized — it joins your revision ✓');
}
