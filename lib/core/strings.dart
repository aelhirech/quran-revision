/// Centralise toutes les chaînes affichées dans l'app.
/// Changer [locale] en 'en' pour passer en anglais.
class S {
  static String locale = 'fr'; // 'fr' ou 'en'

  static String get appTitle => _t('Révision du Coran', 'Quran Revision');
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
  static String get voirPlanDuJour => _t('Voir le plan du jour', 'See daily plan');
  static String get revisionEnCours => _t('Révision en cours', 'Revision in progress');
  static String get cycleEnCours => _t('Cycle en cours', 'Current cycle');
  static String get joursRestants => _t('jours restants', 'days remaining');
  static String get objectifAtteint => _t('Objectif atteint !', 'Goal reached!');
  static String get complete => _t('complété', 'complete');

  // Plan screen
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
  static String get rythmeLabel => _t('Rythme', 'Pace');
  static String get joursEcoules => _t('Jours écoulés', 'Days elapsed');
  static String get joursRestantsLabel => _t('Jours restants', 'Days remaining');
  static String get souratesMemoriees => _t('Sourates mémorisées', 'Memorized surahs');
  static String get reinitialiser => _t('Réinitialiser la configuration', 'Reset configuration');
  static String get reinitDesc => _t('Repart de zéro avec une nouvelle sélection', 'Start over with a new selection');
  static String get modifier => _t('Modifier', 'Edit');
  static String get modifierDuree => _t('Modifier le rythme', 'Edit pace');
  static String get modifierSourates => _t('Modifier les sourates', 'Edit surahs');
  static String get rythmeLabelCourt => _t('Rythme', 'Pace');
  static String get souratesLabelCourt => _t('Sourates', 'Surahs');
  static String get rythmeParDuree => _t('Par durée', 'By duration');
  static String get rythmeParLignes => _t('Par lignes/jour', 'By lines/day');
  static String get dureePersonnalisee => _t('Personnalisé…', 'Custom…');
  static String get dureeCustomTitle => _t('Durée personnalisée', 'Custom duration');
  static String get lignesCustomTitle => _t('Lignes par jour personnalisées', 'Custom lines per day');
  static String get joursSuffix => _t('jours', 'days');
  static String get lignesSuffix => _t('lignes', 'lines');
  static String get modifierPlanConfirm => _t('La progression de cette session sera perdue. Continuer ?', 'Your progress for this session will be lost. Continue?');
  static String get annuler => _t('Annuler', 'Cancel');
  static String get confirmer => _t('Confirmer', 'Confirm');
  static String get sauver => _t('Sauver', 'Save');
  static String get langueLabel => _t('Langue', 'Language');
  static String get riwayaLabel => _t('Riwaya', 'Riwaya');
  static String get riwayaSubtitle => _t('Parcours de révision actif', 'Active revision track');
  static String get switchRiwayaTitle => _t('Changer de parcours ?', 'Switch track?');
  static String get warshUnavailable => _t(
      "Le texte Warsh n'a pas pu être chargé sur cet appareil.",
      "Warsh text could not be loaded on this device.");
  static String get switchRiwayaConfirm => _t(
      "Hafs et Warsh sont deux parcours séparés (sourates, cycle, progression). Tu vas basculer vers l'autre parcours — le parcours actuel n'est pas perdu, tu pourras y revenir.",
      "Hafs and Warsh are two separate tracks (surahs, cycle, progress). You're about to switch to the other track — the current one isn't lost, you can come back to it.");
  static String get hafs => 'Hafs';
  static String get warsh => 'Warsh';
  static String get choisirRiwayaTitle => _t('Quelle riwaya veux-tu réviser ?', 'Which riwaya do you want to revise?');
  static String get choisirRiwayaSubtitle => _t(
      'Hafs et Warsh sont deux parcours séparés — sourates, cycle et progression indépendants. Tu pourras basculer plus tard dans Réglages.',
      'Hafs and Warsh are two separate tracks — independent surahs, cycle and progress. You can switch later in Settings.');
  static String get hafsDescription => _t('La transmission la plus répandue dans le monde', 'The most widespread transmission worldwide');
  static String get warshDescription => _t("La transmission de Nafi', répandue en Afrique du Nord et de l'Ouest", "Nafi's transmission, widespread in North and West Africa");
  static String get notificationsLabel => _t('Notifications', 'Notifications');
  static String get notifSubtitle => _t('Rappel matin et bilan soir', 'Morning reminder and evening recap');
  static String get reviserEn => _t('Réviser en ', 'Revise in ');
  static String get jours => _t('jours', 'days');
  static String get selectionnerLabel => _t('sélectionnées', 'selected');
  static String get rechercher => _t('Rechercher...', 'Search...');
  static String get reinitDialog => _t('Réinitialiser ?', 'Reset?');
  static String get reinitConfirm => _t('La progression du cycle sera perdue. Continue ?', 'Cycle progress will be lost. Continue?');

  // Onboarding — intro
  static String get bismillah => 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
  static String get homeEpigraph => 'وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا';
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
  static String get regrouperParJuz => _t('Grouper par Juz', 'Group by Juz');
  static String juz(int n) => 'Juz $n';
  static String get regrouperParHizb => _t('Grouper par Hizb', 'Group by Hizb');
  static String hizb(int n) => 'Hizb $n';
  // Onboarding wizard
  static String get selectionRapide => _t('Sélection rapide', 'Quick select');
  static String get toutLeCoran => _t('Tout le Coran', 'Full Quran');
  static String get etapeSelection => _t('Mes sourates', 'My surahs');
  static String get etapeRecap => _t('Récapitulatif', 'Summary');
  static String get cycleObjectif => _t('Objectif de cycle', 'Cycle goal');
  static String etapeN(int n, int total) => '$n / $total';
  static String get fractionTroisQuarts => _t('3/4', '3/4');
  static String get fractionMoitie => _t('1/2', '1/2');
  static String get fractionQuart => _t('1/4', '1/4');
  static String get hizbCourt => _t('Hizb', 'Hizb');

  // Onboarding wizard — rythme/objectif
  static String get etapeRythme => _t('Ton rythme', 'Your pace');
  static String get rythmeQuestion =>
      _t('À quel rythme veux-tu avancer ?', 'At what pace do you want to progress?');
  static String get rythmeTranquille => _t('Tranquille · 90j', 'Relaxed · 90d');
  static String get rythmeRegulier => _t('Régulier · 30j', 'Steady · 30d');
  static String get rythmeIntensif => _t('Intensif · 14j', 'Intensive · 14d');

  // Onboarding wizard — rappels
  static String get etapeRappels => _t('Rappels', 'Reminders');
  static String get rappelsTitle =>
      _t('Ne rate plus une révision', 'Never miss a revision');
  static String get rappelsBody => _t(
    'Un rappel le matin pour planifier ta journée, un bilan le soir pour ne rien oublier.',
    'A morning reminder to plan your day, an evening recap so nothing slips.',
  );
  static String get activerRappels => _t('Activer les rappels', 'Enable reminders');
  static String get plusTard => _t('Plus tard', 'Later');

  // Onboarding wizard — célébration
  static String get bienvenueTitre =>
      _t('Ton parcours commence', 'Your journey begins');
  static String get bienvenueSubtitle => _t(
    "Qu'Allah facilite ta révision et bénisse chaque verset.",
    'May Allah ease your revision and bless every verse.',
  );

  // Gamification — écran waouh
  static String get waouhIslamic => _t('ما شاء الله', 'ما شاء الله');
  static String get waouhSubtitle => _t("Qu'Allah vous bénisse dans votre révision", "May Allah bless your revision");
  static String get premierJour => _t("Premier jour — c'est parti !", "First day — let's go!");
  static String get nouveauPalier => _t('Nouveau palier atteint ! 🏅', 'New milestone reached! 🏅');

  // Commitment modal
  static String get engagementTitre => _t('Qu\'as-tu accompli ?', 'What did you accomplish?');
  static String get toutFait => _t('J\'ai tout fait', 'I did everything');
  static String get unePart => _t('J\'ai fait une partie', 'I did part of it');
  static String get rienFait => _t('Je n\'ai rien fait', 'I did nothing');
  static String get combienRakaas => _t('Combien de rakaas ?', 'How many rakaas?');
  static String get valider => _t('Valider', 'Confirm');

  // Mode focus mosquée
  static String get focusMosquee => _t('Mode mosquée', 'Mosque mode');
  static String get quitterFocus => _t('Quitter', 'Exit');

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

  static String lignesParJourValeur(int n) =>
      locale == 'fr' ? '$n lignes/jour' : '$n lines/day';

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

  // Hints interactions cachées
  static String get swipeSupprimer => _t('← Glisse une carte pour la supprimer', '← Swipe a card to delete it');

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

  // Cycle adaptatif
  static String get cycleAdaptatif => _t('Cycle adaptatif', 'Adaptive cycle');
  static String get cycleAdaptatifDesc => _t(
    "La durée s'ajuste selon tes sessions récentes",
    'Duration adjusts based on your recent sessions',
  );
  static String cycleEstime(int n) => _t('~$n jours estimés', '~$n days estimated');
  static String get cycleAdaptatifBase => _t('Basé sur les 14 dernières sessions', 'Based on the last 14 sessions');

  // Récap différencié
  static String get enRevision => _t('En révision', 'In revision');
  static String get memorisees => _t('Mémorisées', 'Memorized');
  static String get repartitionSourates => _t('Répartition', 'Breakdown');

  // Fraîcheur sourate (SRS léger)
  static String get fraicheurFroide => _t('Froide', 'Cold');
  static String get fraicheurGelee => _t('Très froide', 'Fading');
  static String get fraicheurRecente => _t('Récente', 'Recent');

  // Apprentissage multi-versets
  static String get versetsParBloc => _t('Versets par bloc', 'Verses per block');
  static String appuyerPourReveler(int n) => n == 1
      ? _t('Appuie pour révéler le verset', 'Tap to reveal the verse')
      : _t('Appuie pour révéler le bloc', 'Tap to reveal the block');
  static String marquerBlocAppris(int n) => n == 1
      ? _t('Marquer comme appris', 'Mark as learned')
      : _t('Marquer $n versets comme appris', 'Mark $n verses as learned');
  static String blocRange(int from, int to) => 'v.$from–$to';

  // Saisie manuelle [E]
  static String get saisirManuellement => _t('Saisir manuellement', 'Log manually');
  static String get saisieManuelle => _t('Saisie manuelle', 'Manual entry');
  static String get saisieManuelleDesc =>
      _t('Logger une révision sans plan automatique', 'Log a revision without an automatic plan');
  static String get unitesRevisees => _t('Unités révisées', 'Units revised');
  static String get loggerSession => _t('Logger la session', 'Log session');
  static String get sessionLoggee => _t('Session enregistrée ✓', 'Session logged ✓');

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

  // Tour guidé (onboarding avec surbrillance)
  static String get tourPasser => _t('Passer', 'Skip');
  static String get tourSuivant => _t('Suivant', 'Next');
  static String get tourTerminer => _t('Compris', 'Got it');

  static String get tourNavTitle => _t('Bienvenue !', 'Welcome!');
  static String get tourNavBody => _t(
    "Ton app a 4 sections : Réviser (ici), Apprendre, Récap et Profil.",
    'Your app has 4 sections: Revise (here), Learn, Recap and Profile.',
  );
  static String get tourApprendreTitle => _t('Apprendre', 'Learn');
  static String get tourApprendreBody => _t(
    'Mémorise verset par verset avec un mode caché/révélé, à ton rythme.',
    'Memorize verse by verse with a hide/reveal mode, at your own pace.',
  );
  static String get tourRecapTitle => _t('Récap', 'Recap');
  static String get tourRecapBody => _t(
    'Suis ta progression et repère les sourates qui commencent à refroidir.',
    'Track your progress and spot the surahs that are starting to cool down.',
  );
  static String get tourProfilTitle => _t('Profil', 'Profile');
  static String get tourProfilBody => _t(
    'Ajuste ton rythme ou tes sourates sélectionnées à tout moment.',
    'Adjust your pace or selected surahs at any time.',
  );
  static String get tourPrieresTitle => _t('Tes prières', 'Your prayers');
  static String get tourPrieresBody => _t(
    "Choisis les prières où tu récites seul aujourd'hui.",
    'Choose the prayers you recite alone today.',
  );
  static String get tourVoirPlanTitle => _t('Ton plan du jour', 'Your daily plan');
  static String get tourVoirPlanBody => _t(
    "Puis appuie ici pour générer et voir ce que tu as à réviser.",
    'Then tap here to generate and see what you have to revise.',
  );

  // Check-in / check-out (Phase 6 Sprint 2)
  static String get checkInEyebrow => _t('BISMILLAH', 'BISMILLAH');
  static String get checkInTitle => _t('Ta journée de révision', 'Your revision day');
  static String checkInVersesProposed(int n) => _t(
      '$n verset${n > 1 ? 's' : ''} proposé${n > 1 ? 's' : ''} aujourd\'hui',
      '$n verse${n > 1 ? 's' : ''} proposed today');
  static String get checkInAPrioriser => _t('À prioriser', 'To prioritize');
  static String get checkInVueDuJour => _t('Vue du jour', 'Today\'s view');
  static String get checkInAjouterSourate => _t('Ajouter une sourate', 'Add a surah');
  static String get checkInAjouterDesc =>
      _t('Même hors de ta sélection en cours.', 'Even outside your current selection.');
  static String get checkInValider => _t('Valider le check-in', 'Confirm check-in');
  static String get checkInVersetsInclus =>
      _t('Versets inclus aujourd\'hui', 'Verses included today');
  static String get checkInExtendHint => _t(
      'Le "+" ajoute le prochain verset à la portée du jour.',
      'The "+" adds the next verse to today\'s scope.');

  static String get checkOutEyebrow => _t('BILAN', 'REVIEW');
  static String get checkOutRattrapageEyebrow =>
      _t('BILAN · RATTRAPAGE', 'REVIEW · CATCH-UP');
  static String get checkOutTitreHier => _t('Hier, qu\'as-tu fait ?', 'What did you do yesterday?');
  static String get checkOutTitreEnAttente =>
      _t('Un jour est resté en attente', 'A day is still pending');
  static String get checkOutTitreAujourdhui => _t('Et aujourd\'hui ?', 'What about today?');
  static String get checkOutHier => _t('Hier', 'Yesterday');
  static String checkOutIlYaNJours(int n) =>
      _t('Il y a $n jour${n > 1 ? 's' : ''}', '$n day${n > 1 ? 's' : ''} ago');
  static String get checkOutPartieOptionnelle =>
      _t('Partie 2 · optionnelle', 'Part 2 · optional');
  static String checkOutVoirVersets(int n) =>
      _t('Voir les $n versets', 'See the $n verses');
  static String get checkOutARetravailler =>
      _t('Touche un verset à retravailler', 'Tap a verse to work on again');
  static String get checkOutCloturerHier => _t('Clôturer hier', 'Close out yesterday');
  static String get checkOutCloturerJour => _t('Clôturer ce jour', 'Close out this day');
  static String get checkOutAjouterAujourdhui =>
      _t('Ajouter aussi aujourd\'hui', 'Also add today');
  static String get checkOutAjouterDesc => _t(
      'Optionnel — ces versets seront datés d\'aujourd\'hui.',
      'Optional — these verses will be dated today.');
  static String get checkOutValiderAujourdhui =>
      _t('Valider aussi aujourd\'hui', 'Confirm today too');
  static String get checkOutTerminerSans => _t('Terminer sans aujourd\'hui', 'Finish without today');

  /// Légende "dernière révision" — texte discret plutôt qu'un badge
  /// chaud/froid coloré (décidé à la maquette Sprint 1, voir CHANGELOG).
  static const _staleSinceDays = 180;

  static String lastRevisionLabel(DateTime? lastRevised, DateTime today) {
    if (lastRevised == null) return _t('Jamais révisée', 'Never revised');
    final days = today.difference(lastRevised).inDays;
    if (days >= 365) return _t('Il y a plus d\'un an', 'Over a year ago');
    if (days >= _staleSinceDays) return _t('Il y a plus de 6 mois', 'Over 6 months ago');
    if (days >= 90) return _t('Il y a plus de 3 mois', 'Over 3 months ago');
    return _t('Révisée récemment', 'Recently revised');
  }

  /// À surveiller au check-in (section "À prioriser") — même seuil que le
  /// palier "plus de 6 mois" de [lastRevisionLabel], pas un second seuil
  /// indépendant à maintenir en synchro manuellement.
  static bool needsAttention(DateTime? lastRevised, DateTime today) =>
      lastRevised == null || today.difference(lastRevised).inDays >= _staleSinceDays;
}
