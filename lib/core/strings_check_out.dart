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
  static String get checkOutHier => S._t('Hier', 'Yesterday');
  static String checkOutIlYaNJours(int n) =>
      S._t('Il y a $n jour${n > 1 ? 's' : ''}', '$n day${n > 1 ? 's' : ''} ago');
  static String get checkOutCloturerHier => S._t('Terminer hier', 'Finish yesterday');
  static String get checkOutCloturerJour => S._t('Terminer ce jour', 'Finish this day');

  // Check-out — « j'ai fait plus que prévu » (Phase 9)
  static String get checkOutReviseEnPlus =>
      S._t("J'ai révisé une sourate en plus", 'I revised one more surah');
  static String get checkOutSourateEnPlusTitre =>
      S._t('Ajouter une sourate révisée', 'Add a revised surah');
  static String get checkOutApprisEnPlusHint => S._t(
      'Le "+" ajoute un verset appris en plus aujourd\'hui.',
      'The "+" adds one more verse learned today.');

  // Check-out — volet apprentissage (Phase 9)
  static String get checkOutApprentissage =>
      S._t('Ce que tu as appris', 'What you learned');
  static String get checkOutApprentissageDesc => S._t(
      'Décoche un verset à continuer d\'apprendre : il sera reproposé demain.',
      'Uncheck a verse to keep learning: it will be proposed again tomorrow.');
  static String get checkOutDernierBloc =>
      S._t('Appris la dernière fois', 'Learned last time');
  static String get checkOutDernierBlocDesc => S._t(
      'Décoche un verset oublié : il redeviendra à apprendre.',
      'Uncheck a forgotten verse: it goes back to learning.');

  // Day close (US-14) — what the day brought, then the look ahead. Never a
  // reproach: what didn't hold simply comes back tomorrow.
  static String get clotureAujourdhui =>
      S._t('Ta journée est terminée', 'Your day is finished');
  static String get clotureHier => S._t('Hier est terminé', 'Yesterday is finished');
  static String get clotureJourEnAttente =>
      S._t('Ta journée en attente est terminée', 'Your pending day is finished');
  static String get bilanTitre => S._t("Ce qu'a apporté ta journée", 'What your day brought');
  static String bilanRevu(String noms) => S._t('Revu : $noms', 'Revised: $noms');
  static String bilanAppris(int n) => S._t(
      'Appris : $n verset${n > 1 ? 's' : ''}', 'Learned: $n verse${n > 1 ? 's' : ''}');
  static String get bilanReste => S._t(
      'Le reste revient demain, sans rien perdre.', 'The rest comes back tomorrow, nothing lost.');
  static String get devantTitre => S._t('Devant toi', 'Ahead of you');
  static String devantTour(int days) => S._t(
      'À ce rythme, aucune de tes sourates ne reste plus de $days jours sans être revue.',
      'At this pace, no surah of yours waits more than $days days without being revised.');
  static String devantApprentissage(String nom, int days) => S._t(
      'Si tu gardes ce rythme, $nom sera apprise dans environ $days jours.',
      'At this pace, $nom should be learned in about $days days.');
}
