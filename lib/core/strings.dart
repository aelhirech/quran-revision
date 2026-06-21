/// Centralise toutes les chaînes affichées dans l'app.
/// Changer [locale] en 'en' pour passer en anglais.
class S {
  static String locale = 'fr'; // 'fr' ou 'en'

  static String get appTitle => _t('Révision du Coran', 'Quran Revision');
  static String get planDuJour => _t('Plan du jour', 'Daily Plan');
  static String get reviser => _t('Réviser', 'Revise');
  static String get reviserAujourdhui => _t("Réviser aujourd'hui", "Today's revision");
  static String get recap => _t('Récap', 'Recap');
  static String get profil => _t('Profil', 'Profile');
  static String get recapitulatif => _t('Récapitulatif', 'Summary');
  static String get monProfil => _t('Mon profil', 'My Profile');

  // Home
  static String get priereSeul => _t('Prières récitées seul', 'Prayers performed alone');
  static String get priereObligatoires => _t('Obligatoires', 'Obligatory');
  static String get priereSureratoires => _t('Surérogatoires', 'Supererogatory');
  static String get priereMasjid => _t('Mosquée', 'Mosque');
  static String get tahiyyatCount => _t('Fois en mosquée', 'Mosque entries');
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
  static String get modifierDuree => _t('Modifier la durée', 'Edit duration');
  static String get modifierSourates => _t('Modifier les sourates', 'Edit surahs');
  static String get modifierPlanConfirm => _t('La progression de cette session sera perdue. Continuer ?', 'Your progress for this session will be lost. Continue?');
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

  // Onboarding — intro
  static String get introTitle => _t('Révise le Coran chaque jour', 'Revise the Quran every day');
  static String get introLine1 => _t(
    'Dis à l\'app quelles prières tu fais seul, et elle répartit tes sourates sur chaque rakaa.',
    'Tell the app which prayers you perform alone, and it distributes your surahs across each rakaa.',
  );
  static String get introLine2 => _t(
    'Choisis les sourates à réviser, fixe un objectif, et l\'app s\'occupe du reste.',
    'Choose the surahs to revise, set a goal, and the app takes care of the rest.',
  );
  static String get introAction => _t('Configurer mes sourates', 'Set up my surahs');

  // Onboarding — config
  static String get configInitiale => _t('Configuration initiale', 'Initial setup');
  static String get rechercherSourate => _t('Rechercher une sourate...', 'Search a surah...');
  static String get commencer => _t('Commencer la révision', 'Start revision');
  static String get selectSourates => _t('Sélectionne tes sourates', 'Select your surahs');
  static String get toutSelectionner => _t('Tout sélectionner', 'Select all');
  static String get toutDeselectionner => _t('Tout désélectionner', 'Deselect all');
  static String get aleatoireLabel => _t('Ordre aléatoire', 'Random order');
  static String get aleatoireSubtitle => _t('Mélange les unités à chaque nouveau cycle', 'Shuffles units each new cycle');
  static String get parDuree => _t('Par durée', 'By duration');
  static String get parVersetsJour => _t('Versets/jour', 'Verses/day');
  static String get joursEstimes => _t('jours estimés', 'estimated days');
  static String get regrouperParJuz => _t('Grouper par Juz', 'Group by Juz');
  static String juz(int n) => 'Juz $n';
  static String get regrouperParHizb => _t('Grouper par Hizb', 'Group by Hizb');
  static String hizb(int n) => 'Hizb $n';
  static String versetsParJour(int n) => _t('$n versets/jour', '$n verses/day');

  // Notifications
  static String get notifMatinTitle => _t('Révision du Coran 🕌', 'Quran Revision 🕌');
  static String get notifMatinBody => _t('Planifie ta révision du jour', 'Plan your daily revision');
  static String get notifSoirTitle => _t('Bilan du jour 📖', 'Daily recap 📖');
  static String get notifSoirBody => _t('As-tu complété ta révision ?', 'Did you complete your revision?');

  // Versets
  static String get versetsDeRakaa => _t('Versets de la rakaa', 'Verses for this rakaa');
  static String verset(int n) => _t('Verset $n', 'Verse $n');

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

  // Apprentissage
  static String get apprendre => _t('Apprendre', 'Learn');
  static String get apprentissage => _t('Apprentissage', 'Learning');
  static String get enCoursDApprentissage => _t("En cours d'apprentissage", 'In progress');
  static String get commencerSourate => _t('Commencer une sourate', 'Start a surah');
  static String get aucuneSourateEnCours => _t('Aucune sourate en cours', 'No surah in progress');
  static String get aucuneSourateDesc => _t('Choisis une sourate à mémoriser', 'Choose a surah to memorize');
  static String get versetSuivant => _t('Verset suivant', 'Next verse');
  static String get versetPrecedent => _t('Verset précédent', 'Previous verse');
  static String get marquerAppris => _t('Marquer comme appris', 'Mark as learned');
  static String get versetAppris => _t('Appris ✓', 'Learned ✓');
  static String get afficherVerset => _t('Afficher le verset', 'Show verse');
  static String get masquerVerset => _t('Masquer', 'Hide');
  static String get ajouterAlaRevision => _t('Ajouter à la révision', 'Add to revision');
  static String get sourateCompleted => _t('Sourate complétée ! 🎉', 'Surah completed! 🎉');
  static String get ajouterDesc => _t('Tu peux maintenant ajouter cette sourate à ta liste de révision.', 'You can now add this surah to your revision list.');
  static String get supprimerApprentissage => _t("Supprimer l'apprentissage", 'Remove learning');
  static String versetN(int n, int total) => _t('Verset $n / $total', 'Verse $n / $total');
  static String versetsAppris(int n, int total) => _t('$n / $total versets appris', '$n / $total verses learned');
  static String get versetsApprisLabel => _t('Versets appris', 'Learned verses');
  static String get longPressDesapprendre => _t('Maintiens un verset pour le désapprendre', 'Long-press a verse to unlearn it');
  static String get versetParJourTitle => _t('1 verset par jour', '1 verse per day');
  static String get versetParJourDesc => _t("Mémorise un verset chaque jour et l'app suit ta progression", 'Memorize one verse each day and the app tracks your progress');
  static String get dejaInRevision => _t('est déjà dans ta révision', 'is already in your revision');
  static String get ajouteARevision => _t('ajoutée à la révision ✓', 'added to revision ✓');
  static String get supprimer => _t('Supprimer', 'Delete');

  // Profils élèves
  static String get moi => _t('Moi', 'Me');
  static String get ajouterEleve => _t('Élève', 'Student');
  static String get supprimerEleve => _t("Supprimer l'élève", 'Remove student');
  static String get supprimerEleveConfirm => _t('Supprimer la progression de', 'Delete progress for');
  static String get nomEleve => _t("Prénom de l'élève", "Student's name");
  static String get ajouterEleveHint => _t('Ex : Ibrahim, Sara…', 'E.g. Ibrahim, Sara…');
  static String get ajouter => _t('Ajouter', 'Add');

  // Hints interactions cachées
  static String get swipeSupprimer => _t('← Glisse une carte pour la supprimer', '← Swipe a card to delete it');
  static String get longPressEleveHint => _t('Maintiens un profil pour le supprimer', 'Long-press a profile to delete it');

  // Explication "unités"
  static String get unitesExplTitle => _t("C'est quoi une unité ?", 'What is a unit?');
  static String get unitesExplBody => _t(
    "Une unité est une portion de Coran assignée à une rakaa : soit une sourate entière, soit un groupe de versets. Chaque rakaa du plan du jour récite une unité différente.",
    "A unit is a portion of Quran assigned to one rakaa: either a full surah or a group of verses. Each rakaa in the daily plan recites a different unit.",
  );

  // Raccourci sélection prières
  static String get commeHier => _t('Comme hier', 'Same as yesterday');
  static String get derniereSelection => _t('Dernière sélection', 'Last selection');

  // Résumé post-session
  static String get felicitationsRevision => _t('Révision complétée 🎉', 'Revision complete 🎉');
  static String get resumeSessionLabel => _t('Récapitulatif de la session', 'Session summary');
  static String get terminer => _t('Terminer', 'Done');
  static String get ok => _t('OK', 'OK');

  // Mode pause
  static String get pauseLabel => _t('Pause aujourd\'hui', 'Pause today');
  static String get pauseDesc => _t('Ne compte pas comme un jour manqué dans la série', 'Won\'t count as a missed day in your streak');
  static String get pauseActive => _t('Pause activée pour aujourd\'hui', 'Pause active for today');

  // Historique semaine
  static List<String> get joursSemaine =>
      locale == 'fr'
          ? ['L', 'M', 'M', 'J', 'V', 'S', 'D']
          : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static String get semaineDerniereLabel => _t('7 derniers jours', 'Last 7 days');

  // Milestone cycle terminé
  static String get cycleTermineTitle => _t('Cycle terminé !', 'Cycle complete!');
  static String get cycleTermineBody => _t(
    'Tu as révisé toutes tes sourates. Le prochain cycle commence maintenant.',
    'You have revised all your surahs. The next cycle starts now.',
  );
  static String get continuer => _t('Continuer', 'Continue');

  // Streak / gamification
  static String streakJours(int n) =>
      locale == 'fr' ? '$n jour${n > 1 ? 's' : ''} de suite' : '$n day${n > 1 ? 's' : ''} in a row';
  static String get totalJoursLabel => _t('jours de révision', 'revision days');
  static String get streakLabel => _t('Série', 'Streak');
  static String get historique => _t('Historique', 'History');
  static String get aucuneSession => _t('Aucune session enregistrée', 'No sessions recorded yet');
}
