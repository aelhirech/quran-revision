part 'strings_onboarding.dart';
part 'strings_guide.dart';
part 'strings_check_in.dart';
part 'strings_check_out.dart';

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
  static String versetsCount(int n) =>
      locale == 'fr' ? '$n verset${n > 1 ? 's' : ''}' : '$n verse${n > 1 ? 's' : ''}';
  static String get pagesLabel => _t('pages', 'pages');
  static String get rakaasLabel => _t('rakaas', 'rakaas');

  // Profile
  static String get joursEcoules => _t('Jours écoulés', 'Days elapsed');
  static String get souratesMemoriees => _t('Sourates mémorisées', 'Memorized surahs');
  static String get reinitialiser => _t('Réinitialiser la configuration', 'Reset configuration');
  static String get reinitDesc => _t('Repart de zéro avec une nouvelle sélection', 'Start over with a new selection');
  static String get configBloqueeJourEnAttente => _t(
      'Une journée précédente attend encore sa clôture — termine-la avant de changer ta configuration.',
      'A previous day is still waiting to be closed out — finish it before changing your setup.');
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
  static String get rappelMatinLabel => _t('Rappel du matin', 'Morning reminder');
  static String get rappelSoirLabel => _t('Rappel du soir', 'Evening reminder');
  static String get reviserEn => _t('Réviser en ', 'Revise in ');
  static String get rechercher => _t('Rechercher...', 'Search...');
  static String get reinitDialog => _t('Réinitialiser ?', 'Reset?');
  static String get reinitConfirm => _t('La progression du cycle sera perdue. Continue ?', 'Cycle progress will be lost. Continue?');




  // Notifications
  static String get notifMatinTitle => _t('Révision du Coran 🕌', 'Quran Revision 🕌');
  static String get notifMatinBody => _t('Planifie ta révision du jour', 'Plan your daily revision');
  static String get notifSoirTitle => _t('Bilan du jour 📖', 'Daily recap 📖');
  static String get notifSoirBody => _t('As-tu complété ta révision ?', 'Did you complete your revision?');
  static String get notifMinuitTitle => _t('Journée pas encore clôturée', 'Day not closed out yet');
  static String get notifMinuitBody =>
      _t('Clôture ta journée pour faire avancer ton cycle.', 'Close out your day to keep your cycle moving.');

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
  static String get complet => _t('✓ Complet', '✓ Complete');
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
  static String get paginationIndisponible => _t(
      "Impossible de découper tes sourates en pages : les données du mushaf n'ont pas pu être chargées. Redémarre l'app ; si le problème persiste, réinstalle-la.",
      'Your surahs cannot be split into pages: the mushaf data failed to load. Restart the app; if it persists, reinstall it.');
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

  /// « page »/« pages » — identique en fr et en en, d'où le helper plutôt
  /// qu'un `_t` par forme.
  static String _pages(int n) => 'page${n > 1 ? 's' : ''}';

  /// « N page(s) / jour » — le pluriel n'était géré qu'ici alors que les
  /// Réglages affichaient la même valeur en concaténant à la main
  /// (« 1 pages/jour »).
  static String pagesParJour(int n) =>
      _t('$n ${_pages(n)} / jour', '$n ${_pages(n)} / day');


  // Plan du jour — rakaa d'apprentissage
  static String get rakaaApprentissage => _t('Apprentissage', 'Learning');
}
