part of 'strings.dart';

/// Guided accompaniment strings (GuideStep banners).
class SGuide {
  // Guided accompaniment on real gestures (US-1 sprint B, criteria 4-6) —
  // GuideStep, shown until the real gesture it names actually happens
  // (AppState.markGuideDone), never dismissed by tapping the banner itself.
  static String get guideCheckinStep0Title =>
      S._t('Ton plan du jour, déjà prêt', "Today's plan, ready for you");
  static String guideCheckinStep0Body(int streak, int pagesDone) => S._t(
      "Voici ce que l'app te propose : ce que tu apprends, ce que tu viens d'apprendre et ce que tu connais déjà. Tu en es à $pagesDone pages, et $streak jours de suite.",
      "Here's what the app proposes: what you're learning, what you just learned and what you already know. You're at $pagesDone pages, and $streak days in a row.");
  static String get guideCheckinStep1Title =>
      S._t("Ce que tu apprends aujourd'hui", "What you're learning today");
  static String get guideCheckinStep1Body => S._t(
      "Si tu choisis des prières, ces versets rejoindront ta dernière rakaa. Rien d'obligatoire : « je n'apprends rien aujourd'hui » reste toujours possible.",
      "If you choose prayers, these verses join your last rakaa. Nothing is mandatory: \"I'm not learning anything today\" always stays an option.");
  static String get guideCheckinStep2Title =>
      S._t('Tes prières deviennent ta checklist', 'Your prayers become your checklist');
  static String get guideCheckinStep2Body => S._t(
      "Choisis les prières où c'est toi qui récites — l'app y répartit tout ce qui précède, prêt à cocher rakaa par rakaa.",
      "Pick the prayers where you're the one reciting — the app spreads everything above across them, ready to check off rakaa by rakaa.");
  static String get guideVersesTitle => S._t('Le texte est toujours accessible', 'The text is always within reach');
  static String get guideVersesBody => S._t(
      "L'icône livre, sur chaque rakaa, ouvre les versets à réciter — jamais besoin de sortir de l'app.",
      "The book icon, on every rakaa, opens the verses to recite — no need to ever leave the app.");
  static String get guideVersesBodySansPriere => S._t(
      "L'icône livre, sur chaque ligne, ouvre le texte des versets, sans sortir de l'app.",
      "The book icon on each line opens the verses' text, without leaving the app.");
  static String get guideAudioTitle =>
      S._t('Écoute, puis répète', 'Listen, then repeat');
  static String get guideAudioBody => S._t(
      'Le bouton lecture joue ce passage en boucle. Écoute-le avant de le réciter en prière.',
      'The play button loops this passage. Listen to it before reciting it in prayer.');
  static String get guideCheckoutTitle => S._t(
      "C'est ce moment qui fait avancer ton tour", 'This is what moves your round forward');
  // The look-ahead sentence itself is shared with the home screen's day
  // close (US-14): one wording, never two drifting copies.
  static String guideCheckoutCycleBody(int days) => S._t(
      'Confirme ce que tu as vraiment fait. ${SCheckOut.devantTour(days)}',
      'Confirm what you actually did. ${SCheckOut.devantTour(days)}');
  static String get guideCheckoutBody => S._t(
      "Confirme ce que tu as vraiment fait aujourd'hui. C'est ça qui fait avancer ta révision, pas les coches pendant la prière.",
      "Confirm what you actually did today. That's what moves your revision forward, not the ticks during prayer.");
  static String get guideNotFinishedTitle =>
      S._t("Ta journée n'est pas encore terminée", "Your day isn't finished yet");
  static String get guideNotFinishedBody => S._t(
      'Le bouton « Terminer ma journée » reste là. Reviens ce soir pour confirmer ce que tu as fait.',
      'The "Finish my day" button stays here. Come back tonight to confirm what you did.');
  // US-1 sprint C — once-only banner proving a verse left unchecked at
  // check-out comes back on its own (crit. 7). Deliberately does not promise
  // a context verse: the plan UI does not display one yet.
  static String get guideReturnProofTitle =>
      S._t('Ce verset est revenu tout seul', 'This verse came back on its own');
  static String guideReturnProofBody(
      String surahName, int verseNumber, int extraCount) {
    final base = S._t(
        '$surahName, v.$verseNumber : l\'app te le repropose sans que tu aies rien eu à noter.',
        '$surahName, v.$verseNumber: the app is proposing it again without you having to note anything.');
    if (extraCount <= 0) return base;
    return '$base ${S._t('(et $extraCount autre${extraCount > 1 ? 's' : ''})', '(and $extraCount more)')}';
  }
  static String get guideRecapTitle => S._t('Ta vue d\'ensemble', 'Your overview');
  static String get guideRecapBody => S._t(
      "Toutes tes sourates d'un coup d'œil, ce que tu apprends, et celles à risque d'oublier : tout au même endroit.",
      "All your surahs at a glance, what you're learning, and the ones at risk of forgetting: all in one place.");
  static String get guideContinuer => S._t('Continuer', 'Continue');
  static String get guideSettingsTitle => S._t('Ajuste à tout moment', 'Adjust anytime');
  static String get guideSettingsBody => S._t(
      "Langue, riwaya, sourates, rythme, rappels : change tes réglages ici quand tu veux, sans refaire les premiers réglages.",
      'Language, riwaya, surahs, pace, reminders: change your settings here whenever you want, no need to redo the first setup.');
  static String get guideTermine => S._t("J'ai compris", 'Got it');
}
