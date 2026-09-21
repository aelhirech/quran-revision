part of 'strings.dart';

/// Guided accompaniment strings (GuideStep banners).
class SGuide {
  // Guided accompaniment on real gestures (US-1 sprint B, criteria 4-6) —
  // GuideStep, shown until the real gesture it names actually happens
  // (AppState.markGuideDone), never dismissed by tapping the banner itself.
  static String get guideCheckinStep0Title =>
      S._t('Ta portion du jour, déjà décidée', "Today's portion, already decided");
  static String guideCheckinStep0Body(int streak, int pagesDone) => S._t(
      "Voici ce que l'app propose pour toi — le nouveau, le récent encore fragile, l'ancien qu'elle fait tourner. Tu regardes déjà $pagesDone pages, $streak jours de régularité.",
      "Here's what the app proposes for you — the new, the recently learned still fragile, the old it keeps in rotation. You're already at $pagesDone pages, $streak days of consistency.");
  static String get guideCheckinStep1Title =>
      S._t("Ce que tu apprends aujourd'hui", "What you're learning today");
  static String get guideCheckinStep1Body => S._t(
      "Ces versets rejoindront ta dernière rakaa. Rien d'obligatoire : « je n'apprends rien aujourd'hui » reste toujours possible.",
      "These verses join your last rakaa. Nothing is mandatory: \"I'm not learning anything today\" always stays an option.");
  static String get guideCheckinStep2Title =>
      S._t('Tes prières deviennent ta checklist', 'Your prayers become your checklist');
  static String get guideCheckinStep2Body => S._t(
      "Choisis les prières où c'est toi qui récites — l'app y répartit tout ce qui précède, prêt à cocher rakaa par rakaa.",
      "Pick the prayers where you're the one reciting — the app spreads everything above across them, ready to check off rakaa by rakaa.");
  static String get guideVersesTitle => S._t('Le texte est toujours accessible', 'The text is always within reach');
  static String get guideVersesBody => S._t(
      "L'icône livre, sur chaque rakaa, ouvre les versets à réciter — jamais besoin de sortir de l'app.",
      "The book icon, on every rakaa, opens the verses to recite — no need to ever leave the app.");
  static String get guideCheckoutTitle => S._t(
      "C'est ce moment qui fait avancer ton cycle", "This is what moves your cycle forward");
  static String guideCheckoutCycleBody(int days) => S._t(
      "Confirme ce que tu as réellement fait — c'est cette confirmation qui fait avancer ton cycle. À ce rythme, aucune de tes sourates ne reste plus de $days jours sans être revue.",
      "Confirm what you actually did — this confirmation is what moves your cycle forward. At this pace, no surah of yours waits more than $days days without being revised.");
  static String guideCheckoutLearningBody(int days) => S._t(
      "Si tu tiens ce rythme, cette sourate sera mémorisée dans environ $days jours.",
      'At this pace, this surah should be memorized in about $days days.');
  static String get guideCheckoutBody => S._t(
      "Confirme ce que tu as réellement fait aujourd'hui — cette confirmation, pas la simple coche pendant la prière, fait progresser ta révision.",
      "Confirm what you actually did today — this confirmation, not just ticking boxes during prayer, is what moves your revision forward.");
  static String get guideNotFinishedTitle =>
      S._t("Ta journée n'est pas encore finie", "Your day isn't over yet");
  static String get guideNotFinishedBody => S._t(
      'Le bouton « Clôturer ma journée » reste ouvert — reviens ce soir pour confirmer ce que tu as fait.',
      'The "Close out my day" button stays open — come back tonight to confirm what you did.');
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
      "Suis ta progression, ton apprentissage en cours, et la fraîcheur de chaque sourate — tout au même endroit.",
      "Track your progress, your ongoing memorization, and how fresh each surah is — all in one place.");
  static String get guideContinuer => S._t('Continuer', 'Continue');
  static String get guideSettingsTitle => S._t('Ajuste à tout moment', 'Adjust anytime');
  static String get guideSettingsBody => S._t(
      "Langue, riwaya, sourates, rythme, rappels : change tes réglages ici quand tu veux, sans repasser par l'onboarding.",
      "Language, riwaya, surahs, pace, reminders: change your settings here whenever you want, no need to go through onboarding again.");
  static String get guideTermine => S._t("J'ai compris", 'Got it');
}
