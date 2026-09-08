/// Centralise toutes les chaînes affichées dans l'app.
/// Changer [locale] en 'en' pour passer en anglais.
class S {
  static String locale = 'fr'; // 'fr' ou 'en'

  static String get appTitle => _t('Révision du Coran', 'Quran Revision');
  static String get planDuJour => _t('Plan du jour', "Today's plan");
  static String get reglages => _t('Réglages', 'Settings');
  static String get reviserAujourdhui => _t("Réviser aujourd'hui", "Today's revision");
  static String get recap => _t('Récap', 'Recap');
  static String get recapitulatif => _t('Récapitulatif', 'Summary');

  // Home
  static String get priereObligatoires => _t('Obligatoires', 'Obligatory');
  static String get priereSureratoires => _t('Surérogatoires', 'Supererogatory');
  static String get priereMasjid => _t('Mosquée', 'Mosque');
  static String get tahiyyatCount => _t('Fois en mosquée', 'Mosque entries');
  static String get revisionEnCours => _t('Révision en cours', 'Revision in progress');
  static String get cycleEnCours => _t('Cycle en cours', 'Current cycle');

  // Plan screen
  static String get horsPrieresTitre =>
      _t('À réviser en dehors des prières', 'To revise outside prayers');
  static String get horsPrieresDesc => _t(
      "Ce contenu fait partie de ta journée, mais il ne rentrait pas dans les prières que tu as choisies.",
      'This is part of your day, but it did not fit in the prayers you picked.');
  static String get cloturerMaJournee =>
      _t('Clôturer ma journée', 'Close out my day');
  static String get refairePlan => _t('Refaire le plan', 'Rebuild plan');
  static String get alFatihaSeul => _t('Al-Fatiha (pas de sourate)', 'Al-Fatiha (no surah)');
  static String get versets => _t('versets', 'verses');

  // Recap
  static String get cycleActuel => _t('CYCLE ACTUEL', 'CURRENT CYCLE');
  static String get mesSourates => _t('Mes sourates', 'My surahs');
  static String get souratesLabel => _t('sourates', 'surahs');
  static String get versetsLabel => _t('versets', 'verses');
  static String get pagesLabel => _t('pages', 'pages');
  static String get rakaasLabel => _t('rakaas', 'rakaas');

  // Profile
  static String get joursEcoules => _t('Jours écoulés', 'Days elapsed');
  static String get souratesMemoriees => _t('Sourates mémorisées', 'Memorized surahs');
  static String get reinitialiser => _t('Réinitialiser la configuration', 'Reset configuration');
  static String get reinitDesc => _t('Repart de zéro avec une nouvelle sélection', 'Start over with a new selection');
  static String get modifierDuree => _t('Modifier le rythme', 'Edit pace');
  static String get rythmeLabelCourt => _t('Rythme', 'Pace');
  static String get dureePersonnalisee => _t('Personnalisé…', 'Custom…');
  static String get refairePlanConfirm => _t(
      'Tu choisiras de nouvelles prières et le plan sera réparti autrement. Ce que tu as déjà coché reste enregistré. Continuer ?',
      'You will pick your prayers again and the plan will be laid out differently. What you already ticked stays saved. Continue?');
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
  static String get rechercher => _t('Rechercher...', 'Search...');
  static String get reinitDialog => _t('Réinitialiser ?', 'Reset?');
  static String get reinitConfirm => _t('La progression du cycle sera perdue. Continue ?', 'Cycle progress will be lost. Continue?');

  // Onboarding — intro
  static String get bismillah => 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
  static String get homeEpigraph => 'وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا';
  static String get introTitle => _t('Révise le Coran chaque jour', 'Revise the Quran every day');
  static String get introLine1 => _t(
    'Dis à l\'app dans quelles prières tu récites — seul ou en imam — et elle répartit tes sourates sur chaque rakaa.',
    'Tell the app in which prayers you recite — alone or leading as imam — and it spreads your surahs across each rakaa.',
  );
  static String get introLine2 => _t(
    'Choisis les sourates à réviser, fixe un objectif, et l\'app s\'occupe du reste.',
    'Choose the surahs to revise, set a goal, and the app takes care of the rest.',
  );
  static String get introAction => _t('Configurer mes sourates', 'Set up my surahs');

  // Onboarding — config
  static String get rechercherSourate => _t('Rechercher une sourate...', 'Search a surah...');
  static String get commencer => _t('Commencer la révision', 'Start revision');
  static String get selectSourates => _t('Sélectionne tes sourates', 'Select your surahs');
  static String get toutSelectionner => _t('Tout sélectionner', 'Select all');
  static String get toutDeselectionner => _t('Tout désélectionner', 'Deselect all');
  static String get aleatoireLabel => _t('Ordre aléatoire', 'Random order');
  static String get aleatoireSubtitle => _t('Mélange les sourates à chaque nouveau cycle', 'Shuffles surahs each new cycle');
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
  static String get souratesAReviser =>
      _t('Sourates à réviser', 'Surahs to revise');
  static String get pagesParJourValeur => _t('pages/jour', 'pages/day');
  static String get pagesCustomTitle => _t('Pages par jour personnalisées', 'Custom pages per day');
  static String get pagesSuffix => _t('pages', 'pages');

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

  // Notifications
  static String get notifMatinTitle => _t('Révision du Coran 🕌', 'Quran Revision 🕌');
  static String get notifMatinBody => _t('Planifie ta révision du jour', 'Plan your daily revision');
  static String get notifSoirTitle => _t('Bilan du jour 📖', 'Daily recap 📖');
  static String get notifSoirBody => _t('As-tu complété ta révision ?', 'Did you complete your revision?');

  // Versets
  static String get versetsDeRakaa => _t('Versets de la rakaa', 'Verses for this rakaa');
  static String get voirLeTexte => _t('Voir le texte', 'View text');

  // Hadiths
  static String get hadithDuJourLabel => _t('Hadith du jour', 'Hadith of the day');

  static String _t(String fr, String en) => locale == 'fr' ? fr : en;

  static String pagesRakaas(int p, int r) =>
      '$p ${_pages(p)} · $r $rakaasLabel';

  static String souratesCount(int n, int v) =>
      locale == 'fr' ? '$n sourates sélectionnées · $v versets' : '$n surahs selected · $v verses';

  static String joursDuration(int n) =>
      locale == 'fr' ? '$n jours' : '$n days';

  // Apprentissage
  static String get enCoursDApprentissage => _t("En cours d'apprentissage", 'In progress');
  static String get commencerSourate => _t('Commencer une sourate', 'Start a surah');
  static String get afficherVerset => _t('Afficher le verset', 'Show verse');
  static String get masquerVerset => _t('Masquer', 'Hide');
  static String get sourateCompleted => _t('Sourate complétée ! 🎉', 'Surah completed! 🎉');
  static String supprimerApprentissageDe(String nom) =>
      _t("Supprimer l'apprentissage de $nom ?",
          'Delete the memorization of $nom?');
  static String get supprimerApprentissage => _t("Supprimer l'apprentissage", 'Remove learning');
  static String versetN(int n, int total) => _t('Verset $n / $total', 'Verse $n / $total');
  static String versetsAppris(int n, int total) => _t('$n / $total versets appris', '$n / $total verses learned');
  static String get versetsApprisLabel => _t('Versets appris', 'Learned verses');
  static String get longPressDesapprendre => _t('Maintiens un verset pour le désapprendre', 'Long-press a verse to unlearn it');
  static String get supprimer => _t('Supprimer', 'Delete');

  // Explication "pages"
  static String get pagesExplTitle =>
      _t('Pourquoi des pages ?', 'Why pages?');
  static String get pagesExplBody => _t(
    "Ton cycle se mesure en pages réelles du mushaf — la même unité que ton rythme quotidien. Tu sais donc toujours combien de pages il te reste à revoir avant d'avoir couvert toute ta sélection.",
    'Your cycle is measured in real mushaf pages — the same unit as your daily pace. So you always know how many pages are left before you have covered your whole selection.',
  );

  // Raccourci sélection prières
  static String get commeHier => _t('Comme hier', 'Same as yesterday');
  static String get derniereSelection => _t('Dernière sélection', 'Last selection');

  static String get ok => _t('OK', 'OK');

  // Récap différencié
  static String get enRevision => _t('En révision', 'In revision');
  static String get memorisees => _t('Mémorisées', 'Memorized');
  static String get repartitionSourates => _t('Répartition', 'Breakdown');

  // Fraîcheur (SRS léger, grain verset) — badge court (FreshnessBadge)
  static String get fraicheurJamais => _t('Jamais', 'Never');
  static String get fraicheurPartielle => _t('Partielle', 'Partial');
  static String get fraicheurRecente => _t('Récente', 'Recent');
  static String get fraicheur1Mois => _t('1 mois', '1 month');
  static String get fraicheur3Mois => _t('3 mois', '3 months');
  static String get fraicheur6Mois => _t('6 mois', '6 months');
  static String get fraicheur1An => _t('1 an', '1 year');

  // Fraîcheur — texte discret (check-in/check-out, même donnée que le badge
  // ci-dessus, rendu différent — décision maquette Sprint 1 conservée)
  static String get fraicheurJamaisLabel => _t('Jamais révisée', 'Never revised');
  static String get fraicheurPartielleLabel =>
      _t('Partiellement récente', 'Partially recent');
  static String get fraicheurRecenteLabel => _t('Révisée récemment', 'Recently revised');
  static String get fraicheur1MoisLabel => _t('Il y a plus d\'un mois', 'Over a month ago');
  static String get fraicheur3MoisLabel => _t('Il y a plus de 3 mois', 'Over 3 months ago');
  static String get fraicheur6MoisLabel => _t('Il y a plus de 6 mois', 'Over 6 months ago');
  static String get fraicheur1AnLabel => _t('Il y a plus d\'un an', 'Over a year ago');

  // Apprentissage multi-versets
  static String get versetsParBloc => _t('Versets par bloc', 'Verses per block');
  static String appuyerPourReveler(int n) => n == 1
      ? _t('Appuie pour révéler le verset', 'Tap to reveal the verse')
      : _t('Appuie pour révéler le bloc', 'Tap to reveal the block');
  static String marquerBlocAppris(int n) => n == 1
      ? _t('Marquer comme appris', 'Mark as learned')
      : _t('Marquer $n versets comme appris', 'Mark $n verses as learned');
  static String blocRange(int from, int to) => 'v.$from–$to';

  // Journée clôturée (état au repos de l'accueil)
  static String get journeeCloturee =>
      _t('Journée clôturée', 'Day closed out');
  static String get journeeClotureeSousTitre => _t(
      "Ta journée est scellée. Touche pour revenir dessus si besoin.",
      'Your day is sealed. Tap to go back over it if needed.');

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

  static String get tourNavTitle => _t('Plan du jour', "Today's plan");
  static String get tourNavBody => _t(
    'Tout part d’ici : ta journée de révision, prière par prière. Appuie sur les onglets pour visiter l’app — le tour te suit.',
    'Everything starts here: your revision day, prayer by prayer. Tap the tabs to explore the app — the tour follows you.',
  );
  static String get tourRecapTitle => _t('Récap', 'Recap');
  static String get tourRecapBody => _t(
    'Appuie sur cet onglet : tu y suis ta progression, ton apprentissage en cours, et les sourates qui commencent à refroidir.',
    'Tap this tab: it tracks your progress, your ongoing memorization, and the surahs that are starting to cool down.',
  );
  static String get tourReglagesTitle => _t('Réglages', 'Settings');
  static String get tourReglagesBody => _t(
    'Appuie sur cet onglet pour ajuster ton rythme ou tes sourates sélectionnées, à tout moment.',
    'Tap this tab to adjust your pace or selected surahs, at any time.',
  );
  static String get tourVoirPlanTitle => _t('Ton plan du jour', 'Your daily plan');
  static String get tourVoirPlanBody => _t(
    'Appuie ici chaque jour : tu confirmes ton rythme et tes prières, puis ton plan se répartit dans tes rakaas.',
    'Tap here every day: confirm your pace and your prayers, then your plan is spread across your rakaas.',
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

  // « Illuminer ma journée » (Phase 9) — rythme, apprentissage et prières
  // confirmés dans le même check-in que la liste de révision.
  static String get illuminerMaJournee =>
      _t('Illuminer ma journée avec le Coran', 'Light up my day with the Quran');
  static String get illuminerSousTitre => _t(
      'Confirme ton rythme, ce que tu apprends et tes prières du jour.',
      "Confirm your pace, what you're learning and today's prayers.");
  static String get checkInRythme => _t('Mon rythme', 'My pace');
  /// « page »/« pages » — identique en fr et en en, d'où le helper plutôt
  /// qu'un `_t` par forme.
  static String _pages(int n) => 'page${n > 1 ? 's' : ''}';

  /// « N page(s) / jour » — le pluriel n'était géré qu'ici alors que les
  /// Réglages affichaient la même valeur en concaténant à la main
  /// (« 1 pages/jour »).
  static String pagesParJour(int n) =>
      _t('$n ${_pages(n)} / jour', '$n ${_pages(n)} / day');
  static String get checkInApprentissage =>
      _t("Ce que j'apprends aujourd'hui", "What I'm learning today");
  static String get checkInApprentissageDesc => _t(
      'Ces versets seront récités dans ta dernière rakaa.',
      'These verses will be recited in your last rakaa.');
  static String get checkInChoisirSourate =>
      _t('Choisir une sourate à apprendre', 'Choose a surah to learn');
  static String get checkInAucunApprentissage =>
      _t("Je n'apprends rien aujourd'hui", "I'm not learning anything today");
  static String checkInVersetsAApprendre(int n) =>
      _t('$n verset${n > 1 ? 's' : ''}', '$n verse${n > 1 ? 's' : ''}');
  static String get checkInPrieres => _t('Mes prières du jour', "Today's prayers");
  static String get checkInPrieresDesc => _t(
      "Celles où c'est toi qui récites — seul ou en imam.",
      "The ones where you recite — alone or leading as imam.");
  static String get checkInPrieresManquantes =>
      _t('Choisis au moins une prière', 'Pick at least one prayer');
  static String get checkInLancerPlan => _t('Voir mon plan du jour', 'See my daily plan');
  static String get checkInVersetsInclus =>
      _t('Versets inclus aujourd\'hui', 'Verses included today');
  static String get checkInExtendHint => _t(
      'Le "+" ajoute le prochain verset à la portée du jour.',
      'The "+" adds the next verse to today\'s scope.');

  static String get checkOutEyebrow => _t('BILAN', 'REVIEW');
  static String get checkOutRattrapageEyebrow =>
      _t('BILAN · RATTRAPAGE', 'REVIEW · CATCH-UP');
  static String get checkOutTitreHier => _t('Hier, qu\'as-tu fait ?', 'What did you do yesterday?');
  static String get checkOutTitreCeJour => _t(
      "Aujourd'hui, qu'as-tu fait ?", 'What did you do today?');
  static String get checkOutAujourdhui =>
      _t("Aujourd'hui", 'Today');
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
  static String get checkOutAjouterErreur =>
      _t('Impossible de charger l\'aperçu du jour', 'Could not load today\'s preview');

  // Check-out — « j'ai fait plus que prévu » (Phase 9)
  static String get checkOutReviseEnPlus =>
      _t("J'ai révisé une sourate en plus", 'I revised one more surah');
  static String get checkOutSourateEnPlusTitre =>
      _t('Ajouter une sourate révisée', 'Add a revised surah');
  static String get checkOutApprisEnPlusHint => _t(
      'Le "+" ajoute un verset appris en plus aujourd\'hui.',
      'The "+" adds one more verse memorized today.');

  // Check-out — volet apprentissage (Phase 9)
  static String get checkOutApprentissage =>
      _t('Ce que tu as appris', 'What you memorized');
  static String get checkOutApprentissageDesc => _t(
      'Décoche un verset à continuer d\'apprendre : il sera reproposé demain.',
      'Uncheck a verse to keep learning: it will be proposed again tomorrow.');
  static String sourateApprise(String name) =>
      _t('$name est mémorisée — elle rejoint ta révision ✓',
          '$name is memorized — it joins your revision ✓');

  // Plan du jour — rakaa d'apprentissage
  static String get rakaaApprentissage => _t('Apprentissage', 'Learning');
}
