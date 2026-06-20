/// Centralise toutes les chaînes affichées dans l'app.
/// Changer [locale] en 'en' pour passer en anglais.
class S {
  static String locale = 'fr'; // 'fr' ou 'en'

  static String get appTitle => _t('Révision du Coran', 'Quran Revision');
  static String get planDuJour => _t('Plan du jour', 'Daily Plan');
  static String get recap => _t('Récap', 'Recap');
  static String get profil => _t('Profil', 'Profile');
  static String get recapitulatif => _t('Récapitulatif', 'Summary');
  static String get monProfil => _t('Mon profil', 'My Profile');

  // Home
  static String get priereImam => _t("Prières en tant qu'imam", 'Prayers as imam');
  static String get priereObligatoires => _t('Prières obligatoires', 'Obligatory prayers');
  static String get priereSureratoires => _t('Prières surérogatoires', 'Supererogatory prayers');
  static String get priereMasjid => _t('En entrant à la mosquée', 'Entering the mosque');
  static String get sEngager => _t("S'engager", 'Commit');
  static String get apercuBanniere => _t("Aperçu · Appuie sur S'engager pour commencer", "Preview · Tap Commit to start");
  static String get voirPlanDuJour => _t('Voir le plan du jour', 'See daily plan');
  static String get revisionEnCours => _t('Révision en cours', 'Revision in progress');
  static String get cycleEnCours => _t('Cycle en cours', 'Current cycle');
  static String get joursRestants => _t('jours restants', 'days remaining');
  static String get objectifAtteint => _t('Objectif atteint !', 'Goal reached!');
  static String get complete => _t('complété', 'complete');

  // Plan screen
  static String get planDuJourTitle => _t('Plan du jour', 'Daily Plan');
  static String get revisionComplete => _t('Révision complétée ✓', 'Revision complete ✓');
  static String get modifierPlan => _t('Modifier le plan', 'Edit plan');
  static String get alFatihaSeul => _t('Al-Fatiha (pas de sourate)', 'Al-Fatiha (no surah)');
  static String get versets => _t('versets', 'verses');
  static String get dansLesTemps => _t('✓ Dans les temps', '✓ On track');
  static String get prendsAvance => _t("⚠ Prends de l'avance", '⚠ Get ahead');

  // Recap
  static String get cycleActuel => _t('CYCLE ACTUEL', 'CURRENT CYCLE');
  static String get mesSourates => _t('Mes sourates', 'My surahs');
  static String get souratesLabel => _t('sourates', 'surahs');
  static String get versetsLabel => _t('versets', 'verses');
  static String get unitesLabel => _t('unités', 'units');
  static String get rakaasLabel => _t('rakaas', 'rakaas');

  // Profile
  static String get dureeObjectif => _t('Durée objectif', 'Target duration');
  static String get joursEcoules => _t('Jours écoulés', 'Days elapsed');
  static String get joursRestantsLabel => _t('Jours restants', 'Days remaining');
  static String get souratesMemoriees => _t('Sourates mémorisées', 'Memorized surahs');
  static String get reinitialiser => _t('Réinitialiser la configuration', 'Reset configuration');
  static String get reinitDesc => _t('Repart de zéro avec une nouvelle sélection', 'Start over with a new selection');
  static String get modifier => _t('Modifier', 'Edit');
  static String get annuler => _t('Annuler', 'Cancel');
  static String get sauver => _t('Sauver', 'Save');
  static String get langueLabel => _t('Langue', 'Language');
  static String get notificationsLabel => _t('Notifications', 'Notifications');
  static String get notifSubtitle => _t('Rappel matin et bilan soir', 'Morning reminder and evening recap');
  static String get reviserEn => _t('Réviser en ', 'Revise in ');
  static String get jours => _t('jours', 'days');
  static String get selectionnerLabel => _t('sélectionnées', 'selected');
  static String get rechercher => _t('Rechercher...', 'Search...');
  static String get reinitDialog => _t('Réinitialiser ?', 'Reset?');
  static String get reinitConfirm => _t('La progression du cycle sera perdue. Continue ?', 'Cycle progress will be lost. Continue?');

  // Onboarding
  static String get configInitiale => _t('Configuration initiale', 'Initial setup');
  static String get rechercherSourate => _t('Rechercher une sourate...', 'Search a surah...');
  static String get commencer => _t('Commencer la révision', 'Start revision');
  static String get selectSourates => _t('Sélectionne tes sourates', 'Select your surahs');

  // Notifications
  static String get notifMatinTitle => _t('Révision du Coran 🕌', 'Quran Revision 🕌');
  static String get notifMatinBody => _t('Planifie ta révision du jour', 'Plan your daily revision');
  static String get notifSoirTitle => _t('Bilan du jour 📖', 'Daily recap 📖');
  static String get notifSoirBody => _t('As-tu complété ta révision ?', 'Did you complete your revision?');

  // Hadiths
  static String get hadithDuJourLabel => _t('Hadith du jour', 'Hadith of the day');
  static String get intentionLabel => _t('Rappel avant de commencer', 'Reminder before you start');

  static String _t(String fr, String en) => locale == 'fr' ? fr : en;

  static String joursRestantsMsg(int n) =>
      locale == 'fr' ? '$n jours restants pour finir le cycle' : '$n days remaining to finish the cycle';

  static String unitesRakaas(int u, int r) =>
      locale == 'fr' ? '$u unités · $r rakaas' : '$u units · $r rakaas';

  static String posTotal(int p, int t) => '$p / $t';

  static String souratesCount(int n, int v) =>
      locale == 'fr' ? '$n sourates sélectionnées · $v versets' : '$n surahs selected · $v verses';

  static String joursDuration(int n) =>
      locale == 'fr' ? '$n jours' : '$n days';
}
