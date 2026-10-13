# Changelog — Quran Revision App

> Backlog en attente + décisions encore actives utiles aux prochains sprints. L'historique détaillé des sprints livrés (features, bugs corrigés, refactors) vit dans `git log`, pas ici. Pour *comment* le code fonctionne aujourd'hui (architecture, moteurs métier, écrans), voir `docs/DOCUMENTATION_TECHNIQUE.md`. Pour le modèle de données `ayah_facts` et l'algorithme du plan quotidien (vocabulaire, invariants, cas limites), voir `CLAUDE.md` — ce fichier ne les reformule plus, seulement ce qui n'y est pas déjà couvert.

---

## Décisions actives à connaître

Ne garde que ce qui reste réellement à respecter en touchant ce code. Un choix produit fait puis défait, ou un bug déjà corrigé sans piège résiduel, vit dans `git log` — pas ici.

**Modèle de données**
- Migration SQLite 2026-08-30 (introduction d'`ayah_facts`) faite **sans backfill**, décision prise faute d'utilisateurs réels à l'époque. Ne pas reproduire sans redemander confirmation si l'app a de vrais utilisateurs au moment d'un futur changement de schéma.
- Profils élèves multi-utilisateurs (`StudentProfile`/`StudentService`/`StudentProfileBar`) supprimés en entier le 2026-09-01 sur retour utilisateur explicite (app mono-utilisateur). Ne pas réintroduire sans besoin confirmé.
- Le "fait" par défaut au check-out (`CheckOutScreen`) ne s'applique **qu'à cet écran** — jamais à `AyahFactsService.proposeUnits` ni à `PlanScreen`/`toggleTodayUnitReach`, qui doivent garder `reach=0` tant que rien n'a été coché en priant. Les confondre ferait afficher "déjà fait" avant même d'avoir prié.
- `todayClosed` a deux sources distinctes : `AyahFactsService.isDaySealed` (lignes `revise` réelles, seul garde-fou anti double-comptage du cycle) et `last_sealed_date` (`StorageService`, flag d'affichage uniquement pour les journées sans ligne à sceller — apprentissage seul, ou tout retiré au check-in). Ne jamais faire dépendre le comptage du cycle de la seconde.

**Cycle / `RevisionEngine`**
- Le mélange du cycle est un tri par clé stable par sourate (`_shuffleKey`), jamais un `List.shuffle` — insérer une sourate ne doit déplacer aucune autre (sinon pages sautées/reproposées pendant que `cyclePosition` reste en place). Verrouillé par test dans `revision_engine_test.dart`. Basculer le mélange on/off, en revanche, remet `cyclePosition` à 0 comme un changement de sélection.
- Ce qui ne tient pas dans les prières (règle D) est retourné par `distributeToRakaas` (`{plan, outside}`) — ne jamais redériver "hors prières" par différence d'ensembles dans `AppState` : `RevisionUnit.==` porte sur la plage de versets, donc une unité subdivisée n'est jamais égale à sa mère et fausse tout le calcul.
- Cocher une rakaa peut en cocher une autre automatiquement quand `_padCyclically` fait apparaître deux fois la même plage de versets dans la journée — `reach` est une vérité par verset/jour, pas par rakaa.
- Agréger plusieurs groupes de cycle se fait par **union** de pages, jamais par somme (deux groupes peuvent partager une page physique).
- **`pagesPerDay` compte des vraies pages du mushaf, pas des entrées de cycle (2026-09-26)** : avant cette date, le rythme quotidien prenait un nombre fixe d'*entrées* (`RevisionEngine.buildDayUnits`), pas toujours équivalent à une page réelle (fragment privé plus petit qu'une page, ou page frontière partagée par deux entrées consécutives) — l'onboarding annonçait « 1 page/jour » alors que ~0,7 page réelle était consommée en moyenne, contredisant l'accueil (« 85 pages ») qui, lui, comptait déjà en vraies pages via `DaySelection.realPages`. `RevisionEngine._takeEntriesForPages` (nouveau, partagé par `buildDayUnits` et `DaySelection.cycleDays`) prend maintenant des entrées jusqu'à couvrir AU MOINS `pagesPerDay` pages réelles distinctes — jamais une fraction d'entrée : un jour peut donc couvrir plus ou moins de pages que le budget exact (voir `CLAUDE.md` § Règle du plan quotidien, partie B, invariant 7). Ne jamais revenir à un décompte par entrées pour `pagesPerDay`/`cycleDays` — verrouillé par `test/core/revision_engine_test.dart` (groupe `DaySelection.cycleDays`).

**UI / lecture**
- **Portion de la vue Coran (US-11, US-18 — 2026-10-13)** : la portion vit dans le `State` de
  `VerseBottomSheet` (`_portion`, jamais persistée), parce que le curseur et la liste de versets
  doivent lire le même état. `VerseAudioBar` la reçoit par `portion`/`onPortionChanged`.
  - **Ne jamais relire `widget.portion` dans la barre au moment d'un geste** : un ±1 appelle
    `onChanged` puis `onChangeEnd` avant tout rebuild, `widget.portion` y vaut encore l'ancienne
    portion. `_startLoop`, `_playsPortion` et `_followPortionIfPlaying` la prennent en argument.
    Après un démarrage, le rattrapage relit `widget.portion` **après la frame**
    (`addPostFrameCallback`), pour la même raison.
  - La boucle en cours est portée par le handler, `QuranAudioHandler.currentLoop` (récitateur,
    sourate, début, fin — `null` après `stop`), jamais recopiée dans la barre : une boucle
    « appartient » à la vue si même récitateur, même sourate et plage incluse dans la plage
    affichée, ce qui reconnaît une sous-portion après réouverture.
  - La boucle ne suit un changement de portion que si **cette** boucle joue, et jamais après un
    démarrage raté : relancer une requête injouable (hors ligne + récitateur non téléchargé)
    bouclait sans fin, bug trouvé en `/code-review`. Relance au relâché du curseur ou au ±1
    seulement, jamais à chaque pixel (`playLoop` remplace toute la playlist). Le texte, lui, suit
    en direct.
  - L'en-tête garde la plage d'origine. Aucun verset de contexte n'est affiché (retiré par US-18).
- **Traduction dans la vue Coran (US-19, 2026-10-13)** :
  - Les deux fichiers de `assets/quran/translations/` sont les éditions Tanzil (`fr.hamidullah`,
    `en.sahih`), embarquées **sans aucune modification**. Tanzil les limite à l'**usage non
    commercial** : à réexaminer avant toute version payante ou toute publicité. Mise à jour par
    nouveau téléchargement, jamais par retouche.
  - Les traductions suivent la numérotation Hafs. Le bouton n'existe qu'en Hafs
    (`VerseBottomSheet`) : ne jamais appeler `TranslationService.verse` avec un verset Warsh.
  - L'affichage (`_showTranslation`) vit dans le `State` de la feuille, jamais persisté. Le
    bouton et la ligne de source restent **dans l'en-tête** : un sliver ajouté avant la barre
    audio recréerait son état pendant l'écoute.
- **`QuranAudioHandler.playLoop` n'attend jamais `_player.play()` (2026-09-29)** : dans
  `just_audio`, ce `Future` ne se termine qu'à la pause/l'arrêt. L'attendre gardait `_starting`
  vrai pendant toute l'écoute (bouton bloqué sur le spinner, et `_followPortionIfPlaying` jamais
  exécuté). Son erreur est donc loguée dans le handler, plus remontée à la barre.
- **File de téléchargement audio (US-10 Sprint B, 2026-10-05)** :
  - La file (`AudioDownloadService.pending`, persistée par `AudioPrefs`) ne retient que les
    **demandes** (`'reciterId'` ou `'reciterId:surahId'`), jamais ce qui est stocké : le disque
    reste la seule vérité. Une demande ne sort de la file que quand tout est sur disque.
  - Une seule boucle tourne (`resumePending`). Un appel pendant qu'elle tourne programme un
    passage de plus, jamais une boucle parallèle : c'est ce qui relance une sourate coupée par
    l'arrière-plan iOS.
  - Pas de Wi-Fi ou disque plein arrêtent la file (`blockedBy`). Une sourate en échec réseau est
    sautée et gardée : un fichier manquant chez KSU ne doit pas bloquer tout le reste.
  - La règle réseau est revérifiée avant chaque verset téléchargé (pas une fois au départ).
  - Un verset n'est écrit que si la réponse est de type `audio/*` (2026-10-12) : un portail
    captif répond `200` avec du HTML. KSU sert `audio/mpeg` sur tous ses dossiers ; si ce type
    change un jour, tous les téléchargements seront sautés — regarder là en premier.
  - `deleteReciter` attend la fin du verset en cours avant d'effacer : effacer sous lui ferait
    échouer son renommage, lu comme « disque plein ».
  - Préférences audio (récitateur, file, données mobiles) : `AudioPrefs`, jamais
    `StorageService` (déjà au plafond de taille).

- **Clôture de journée (US-13/US-14, 2026-10-01)** :
  - `AppState.checkOut` renvoie un `SealOutcome` (`lib/models/day_close.dart`). C'est l'**unique**
    source des jalons : jamais un second calcul de « tour bouclé » ou de « sourate mémorisée »
    côté écran.
  - Le bilan de l'accueil (`dayRecap`) se relit toujours depuis `ayah_facts`, jamais mis en
    cache, sinon une clôture corrigée afficherait l'ancien bilan.
  - La transition de clôture est un état d'affichage de `DayPlanTab` (`_justClosedDate`, 4 s),
    pas d'`AppState`. Elle ne joue ni après un jalon, ni à la réouverture d'une journée déjà
    scellée.
- **Début de tour (US-15, 2026-10-01)** : `CycleProgressCard` affiche « Nouveau tour » et
  « N pages en garde » quand `pos == 0 && total > 0`, et cet affichage prime sur `showTotal`.
  Ce n'est pas une fuite de la règle US-1 crit. 4 : des pages en garde sont de l'acquis, pas le
  poids restant.

- **Cartes et pas d'étapes (US-15 Sprint B, 2026-10-01)** :
  - Le style des `Card` vient du `cardTheme` (`app_theme.dart`, marge nulle comprise). Ne pas
    le recopier widget par widget : une copie locale ne suit plus le thème quand il change.
    Une nouvelle carte `surfaceCard` + rayon 16 + `cardBorder` s'écrit `Card(...)`, jamais
    `Container(decoration: …)` (nettoyage du 2026-10-02 : 11 copies retirées). Si elle contient
    un `InkWell`, il va **dans** la `Card` : posé au-dessus, son onde est peinte sous le fond.
    Restent en `Container`, volontairement : les cartes `surfaceCardSolid` et
    `SouratesRecapCard` (rayon 20).
- **Clé de jour (2026-10-02)** : `dayKey(DateTime)` (`core/day_dates.dart`) est la seule façon
  d'écrire une date `YYYY-MM-DD` (format de `ayah_facts.date` et des préférences par jour).
  Ne pas réécrire `toIso8601String().substring(0, 10)` à la main.
  - Le check-in et le check-out passent d'une étape à l'autre par `StepFooter` et
    `StepTransition`. Une nouvelle étape dans l'un de ces deux écrans les réutilise.
  - `PrimaryCtaButton` réduit un libellé trop long au lieu de le couper, et n'a plus d'ombre
    quand il est désactivé.
- **Onglet Renforcement (US-20, 2026-10-13)** :
  - L'onglet et l'écran de série ne créditent rien et n'écrivent rien : ni `ayah_facts`, ni
    préférence, ni champ d'`AppState`. Reconnaître un passage n'est pas le réciter. Ce qu'une
    série retient (les passages posés, pour ne pas les reposer) vit dans le `State` de l'onglet,
    le temps de la session.
  - Un verset ne se coupe qu'aux signes de pause du mushaf (`ReinforcementEngine.passagesOf`).
    L'écran n'ajoute que des « … » : devant le passage posé s'il ne commence pas son verset,
    derrière tout passage qui ne le termine pas. Jamais devant un choix.
  - Les onglets se désignent par constantes (`_recapTab`, `_settingsTab` dans `ShellScreen`),
    jamais par un indice écrit en dur : insérer un onglet décale ceux qui le suivent.
  - Un passage se reconnaît par `Passage.id` (sourate, verset, rang), jamais par `identical` ni
    par un triplet réécrit à la main : le moteur, l'onglet et l'écran doivent parler du même.
  - Une carte de choix n'est pas découpée (`clipBehavior`) : les signes coraniques hauts
    dépassent leur ligne et seraient rognés. L'onde de l'appui prend sa forme par
    `InkWell.customBorder`.
  - Une carte dont la bordure change d'état part de `cardShape(palette)` (`app_theme.dart`) et
    de `copyWith(side: …)`, sans réécrire le rayon.
- **Questions de mots (US-22 Sprint C, 2026-10-13)** :
  - `assets/quran/wbw/fr.coranmot.tsv` est l'export de la table `allwords` de CoranMot (Dr Usama
    Nonnenmacher), embarqué **sans aucune modification**. Trois conditions d'usage : projet
    islamique, aucune modification, source citée. Les sens ne sont donc jamais retouchés, triés
    ni filtrés, même longs ou crus, et la ligne `SReinforcement.sourceMots` reste sous chaque
    réponse. Mise à jour par nouvel export, jamais par retouche.
  - Un sens est rattaché à un mot par son rang dans le verset, rien d'autre. Un verset qui n'a
    pas un sens par mot n'est jamais interrogé : sept versets aujourd'hui (2:181, 8:6, 13:37,
    15:7, 27:20, 36:22, 37:130), liste verrouillée par `word_gloss_service_test.dart`. Changer
    la source du texte arabe peut changer cette liste.
  - Les sens suivent la numérotation Hafs et n'existent qu'en français : le sélecteur de mode
    n'apparaît que si `WordGlossService.availableFor(S.locale, riwaya)`. Ne jamais appeler
    `WordGlossService.glosses` avec un verset Warsh.
  - L'écran de série repère le choix appuyé par son rang parmi les choix, et la bonne réponse par
    `SeriesQuestion.answerIndex` : un seul état pour les deux types de questions. Un mot se
    reconnaît par `WordChoice.id` (sourate, verset, rang du mot dans le verset), comme un passage
    par `Passage.id`.
  - L'onglet garde les mots posés (`_lastWords`) à part des passages posés (`_lastPrompts`) : le
    troisième champ n'y désigne pas la même chose. Une série d'un seul type ne touche pas la
    mémoire de l'autre.
  - Le mot en or est désigné par son rang parmi les mots du texte **affiché** : l'écran ajoute 1
    quand le passage est précédé de « … ». Le « … » (`_shown`) et ce décalage lisent le même
    prédicat, `_leads(passage)` : changer l'un sans l'autre dorerait le mot voisin, et aucun test
    ne le dirait (écran vérifié sous Windows seulement).
  - Le tirage partagé (`ReinforcementEngine._draw`) reçoit des candidats **déjà restreints** à la
    sourate demandée : c'est chaque appelant qui restreint, pour ne pas analyser toute la
    sélection quand la série porte sur une sourate.

**Cadrage produit encore valide**
- « Prières où il est imam » = prières où c'est lui qui récite (seul ou en dirigeant) — un simple élargissement de libellé, pas un filtre d'exclusion ni une pondération de répartition.
- L'apprentissage n'a plus d'onglet dédié : la sourate à apprendre est choisie au check-in, récitée dans la **dernière rakaa** du plan, confirmée au check-out.
- Le hand-off "sourate mémorisée → révision" est automatique et passe par `AppState.addSelectionKeepingCycle`, **jamais** `saveConfig` (qui remettrait `cyclePosition` à 0).
- « Faire plus » (sourate en plus, verset en plus) fait avancer le cycle au-delà de la proposition du jour — mais seulement si l'utilisateur l'a explicitement déclaré ce jour-là ; le curseur reste ordonné, déclarer un groupe plus loin dans la rotation ne crédite pas ceux qui le précèdent.
- **Accompagnement guidé (`AppState.guideDone`/`markGuideDone`, US-1 sprint B, remplace l'ancien `hasSeenHook`/`HookBanner`)** : un id n'est marqué que par le callback du GESTE RÉEL qu'il accompagne (check-in validé, verset ouvert, check-out scellé, action du `GuideStep`) — jamais par le simple affichage d'une carte ni par une croix de fermeture. Toute nouvelle étape guidée doit suivre cette règle, pas réintroduire un dismiss passif.
- Heures de rappel matin/soir (`StorageService.loadMorningTime`/`loadEveningTime`) sont des préférences **globales**, jamais préfixées par riwaya et jamais rechargées dans `_loadTrackState` — un réglage de notification n'a rien à voir avec le parcours de révision actif.
- **`needs_work` retiré de tout le code applicatif (US-3, 2026-09-21)** : la colonne `ayah_facts.needs_work` reste dans le schéma SQLite (DEFAULT 0, jamais migrée/droppée sans utilisateurs réels) mais plus aucun code Dart ne l'écrit ni ne la lit — `AyahFactsRitual.setNeedsWork`/`lastRevisionFlags`, `AppState.setVerseNeedsWork`/`lastRevisionFlagsFor` et le toggle bookmark de `VerseBottomSheet` ont disparu. Le check-out est désormais **verset par verset** (`CheckOutRow`/`VerseToggleChips`, `Set<(int surahId, int ayahId)>`), plus par sourate/portion entière — un seul geste (décocher un verset précis) couvre révision et apprentissage. Ne jamais réintroduire de colonne/flag parallèle pour un besoin de correction fine : `reach` par verset suffit.

**Cycle / `RevisionEngine`**
- **Verset revenu + contexte (US-3 crit. 4, 2026-09-21)** : `RevisionEngine.contextVerseFor(surahId, ayahId, selections)` — pure, Dart — renvoie le verset `n-1` d'un verset donné **s'il reste dans la plage sélectionnée par l'utilisateur** (jamais hors plage, invariant E.3), `null` sinon. `AyahFactsRitual.returningVerses`/`AppState.returningVersesContext` identifient les versets laissés `reach=0` à un check-out **scellé** (`checked_out=1`) et redevenus candidats du plan du jour. Consommé par `PlanScreen` (US-1 sprint C, 2026-09-21) pour le message « ce verset est revenu seul », affiché une fois via l'étape guidée `return_proof_seen`.

**Infra / divers**
- `sqflite_common_ffi` est en dépendance de **prod**, pas dev-only : `main.dart` bascule dessus derrière `if (Platform.isWindows)`, une condition runtime que Dart ne tree-shake pas — léger surcoût de taille binaire mobile assumé pour pouvoir tester sur cette machine sans device.
- Fraîcheur par verset (2026-09-04) : seuils changés délibérément (30j remplace l'ancien badge 7j ; paliers `neverRevised`/`sixMonths`/`oneYear` remplacent le seuil unique 180j). Pas tranché à l'identique partout — à ajuster sur retour utilisateur, pas à traiter comme un bug.
- Tests `sqflite_common_ffi` : une seule `history.db` partagée par tous les tests d'un même fichier (`initFfiTestDb` isole les fichiers entre eux, pas les tests entre eux) — un test peut hériter d'un `checked_out` posé par le précédent. `clearFactsBetweenTests()` doit tourner en `setUp`, sans fermer la connexion (`openDatabase` renvoie l'instance en cache).
- **Notifications planifiées via `zonedSchedule` + fuseau réel de l'appareil (US-3 crit. 6, 2026-09-21)**, plus `periodicallyShow`. Bug corrigé au passage, présent depuis US-1 sprint B et invisible faute de test : `periodicallyShow` ignore purement `hour`/`minute`, les rappels se déclenchaient 24h après le dernier `enable()`/changement d'heure, jamais à l'heure configurée. Dépendances ajoutées : `timezone` (déjà transitive via `flutter_local_notifications`, rendue directe) + `flutter_timezone` (détection du fuseau IANA de l'appareil). `NotificationService._initializeTimeZone()` retombe explicitement sur `tz.UTC` si la détection échoue — `tz.local` est un champ `late` du package `timezone`, sans filet : le laisser non initialisé casserait silencieusement les 3 rappels pour toujours, pas seulement celui du jour.

---

## Backlog technique

Dette réelle et gaps prêts à l'implémentation — priorité qui reflète le risque/l'effort, pas l'enthousiasme produit. P1 = risque de correction (données/comportement), P2 = gap concret ou nettoyage rapide, P3 = différé délibérément (aucun bug connu) ou pure polish. Les idées produit non scopées vivent dans la section « Idées produit » plus bas, pas ici.

### [P3] Hook de reprise d'arrière-plan logé dans `ShellScreen`, pas `AppState`
Relevé en `/code-review high` du sprint US-3 (2026-09-21, altitude). Le `WidgetsBindingObserver`
qui rejoue `ensureDayPlan()` au retour d'arrière-plan (US-3 crit. 5) — et depuis US-10 Sprint B
`AudioDownloadService.resumePending()` — vit dans `ShellScreen`. Un
futur écran racine qui ne descendrait pas de `ShellScreen` devrait dupliquer ce hook. Différé :
un seul écran racine existe aujourd'hui, centraliser dans `AppState` maintenant serait de la
généralisation anticipée pour un cas qui n'existe pas encore.

### [P3] Deux accès aux sourates écrits plusieurs fois côté écrans
Relevé en `/simplify` du Sprint B d'US-20 (2026-10-13). Aucun bug : du code recopié. Différé
parce que le correctif touche le check-in, le check-out et `AppState`, hors du périmètre d'un
sprint d'écran.
- **Ouvrir la liste des sourates** : le même bloc `showModalBottomSheet<Sourate>(context,
  isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) =>
  SouratePickerSheet(…))` existe quatre fois (`check_in_screen.dart` deux fois,
  `check_out_sections.dart`, `reinforcement_tab.dart`). Ajouter à `SouratePickerSheet` une
  méthode `static Future<Sourate?> show(BuildContext context, {required List<Sourate> sourates,
  String? title})`, sur le modèle de `VerseBottomSheet.show`, et y faire passer les quatre
  appelants.
- **Retrouver une sourate par son id** : `AppState._sourateById` est privé, donc
  `series_screen.dart` (`_sourate`) et `return_proof_step.dart` refont chacun leur recherche.
  Le rendre public sous le nom `sourateById` (définition dans `app_state.dart`, trois appels dans
  `app_state_dayplan.dart` et `app_state_learning.dart`) et l'appeler depuis ces deux fichiers.
- **Tests** : `flutter test` avant et après, aucun comportement ne change. Sous Windows : ajouter
  une sourate au check-in, déclarer une sourate en plus au check-out, lancer une série sur une
  sourate.

### [P3] Test de l'ouverture du Récap puis des Réglages après la première clôture
Relevé au Sprint B d'US-20 (2026-10-13). `ShellScreen` ouvre le Récap puis les Réglages par
`_recapTab` et `_settingsTab` (2 et 3). Aucun test ne le verrouille : insérer ou déplacer un
onglet sans corriger ces deux constantes ouvrirait le mauvais onglet, en silence. Vérifié à la
main à ce sprint. Différé : aucun changement d'onglet n'est prévu (US-21 et US-22 n'en ajoutent
pas).
- **`test/screens/shell_screen_test.dart`** (nouveau, test widget, exception « piège d'état » de
  `test/CLAUDE.md`) : `ShellScreen` monté avec le vrai thème sous un `AppState` sans aucune étape
  guidée faite. Après `markGuideDone('checkout_done')`, `NavigationBar.selectedIndex` vaut 2.
  Après `markGuideDone('recap_seen')`, il vaut 3. Après un appui sur un autre onglet puis
  `markGuideDone('settings_seen')`, l'onglet choisi reste.
- **Risque** : `ShellScreen.initState` lance `ensureDayPlan()`, qui lit SQLite. Sous l'horloge
  simulée de `flutter test`, cette lecture ne se termine pas : le test ne doit pas en dépendre.

### [P3] Questions de mots : le signe « ۞ » suit le premier mot de 199 versets
Relevé au Sprint C d'US-22 (2026-10-13). En Hafs, « ۞ » est collé au mot suivant par une espace
insécable : quand ce mot est posé ou proposé, le signe vient avec lui. Il est alors doré dans le
passage, affiché dans le choix arabe et dans la ligne sous un mauvais choix. Aucune réponse n'est
faussée. Mesuré sur 5 200 questions : 0,2 % des questions sur le juz 30, 0,9 % sur 113 sourates.
Différé : rare, et sans effet sur la réponse.
- **`lib/core/reinforcement_words.dart`**, `_askableWords` : `WordChoice.arabic` reçoit le token
  sans ce qui précède l'espace insécable (`token.substring(token.lastIndexOf('\u00A0') + 1)`).
- **`lib/widgets/arabic_verse_text.dart`** : dans le mot mis en couleur, ce qui précède l'espace
  insécable, espace comprise, passe dans le premier `TextSpan`, non coloré.
- **Tests** : dans `test/core/reinforcement_words_test.dart`, l'invariant
  `passage.words[wordIndex] == answer.arabic` devient « se termine par `answer.arabic` », et un
  test sur la sourate 100 seule (20 graines) vérifie qu'aucun choix ne contient U+06DE. Sous
  Windows : une question sur le premier mot de 100:9, le signe reste de la couleur du texte.

## Idées produit (non scopées)

Vision/features pas encore prêtes à l'implémentation — pas de priorité technique tant qu'elles n'ont pas été cadrées (`quran-blueprint` → user story dans `docs/USER_STORIES.md`, puis `quran-scoping` → item ci-dessus). Ne pas lancer à la volée.

- **SRS réel par verset** (score de difficulté depuis l'historique `ayah_facts`, aujourd'hui écrasé par `lastRevisionDatesPerVerse` qui ne garde que `MAX(date)`) — dépendait de `needsWork`, **retiré du code au sprint US-3** (2026-09-21) ; à rescoper sur un autre signal (ex. fréquence des décochages verset par verset) avant toute implémentation.
- **Coran en SQLite** (texte + word-by-word + tajweed) — débloquerait "tajweed coloré" ci-dessous, JOIN naturel avec `ayah_facts`. Garde-fou : ne pas migrer parce que "c'est plus propre", seulement si cette feature est réellement engagée. Les questions de mots (US-22) s'en passent : leurs données sont un asset texte.
- **Affichage tajweed coloré** — bloqué faute de données tajwid (QUL), voir Coran SQLite. Passera par `AppPalette`/tokens sémantiques, jamais de couleur en dur.
- **Timeline d'activité (heatmap) dans Profil/Récap** — chaque fait `ayah_facts` est déjà daté, gratuit en donnée.
- **Mode "versets à retravailler" en jeu à part** — mécanique de jeu à définir avant tout code.
- **Gamification narrative [H]** — vision long terme, direction artistique déjà validée (Mus'haf/Tahajjud), mécanique narrative encore à définir.
- **Versets revenus en révision → section "à réviser en dehors des prières", pas verset de contexte** (reformulation 2026-09-26 des items P2 "verset de contexte") : pour la révision, le contexte n'aide pas autant qu'à l'apprentissage (où il a été livré le 2026-09-26, puis retiré par US-18 le 2026-10-13) — l'idée retenue est plutôt de faire atterrir les versets revenus dans le bloc hors-prières existant (`OutsidePrayersBlock`) plutôt que de les représenter avec leur contexte. À passer par `quran-blueprint` avant scoping : reste à définir comment ça s'articule avec `distributeToRakaas`/`RevisionUnit.==` (règle D) et si ça remplace ou complète le banner `return_proof_seen` actuel.
- **Vue Coran : la barre saute quand on resserre la portion après avoir défilé** (relevé au
  sprint US-18, 2026-10-13, mesuré sous Windows) : feuille défilée de 140 px, portion resserrée
  de 50 à 2 versets, le contenu devient plus court que la position de défilement, Flutter recale
  et la barre descend de 140 px sous le doigt. Le glissé d'une poignée n'est pas gêné, un ±1
  répété peut tomber à côté du bouton. Il reste à choisir le comportement voulu (défilement figé
  pendant le réglage, retour en haut, autre) avant tout correctif.
- **Vue Coran à 320×568 avec texte ×1,5 : deux débordements** (relevés au sprint US-19,
  2026-10-13, sous Windows, présents avec ou sans traduction) : la ligne « − v.282 + … − v.283 + »
  de `VerseRangeSlider` (`verse_range_slider.dart`, l. 71) déborde de 38 px à droite avec des
  numéros à trois chiffres (14 px avec deux), et `IndexBadge` coupe un numéro à trois chiffres
  (« 282 » affiché « 28 »). Il reste à choisir le correctif (réduire, passer à la ligne, plafonner
  l'agrandissement du texte) avant d'en faire un item de Backlog.
- **Renforcement : qualité des mauvais choix à régler sur usage** (relevé au Sprint A d'US-20,
  2026-10-13) : le mauvais choix « similaire » est tiré au hasard parmi les passages similaires,
  pas le plus proche, et les deux seuils (12 mots par passage, moitié des mots en commun) viennent
  des mesures du scoping, pas d'un usage. Il reste à jouer de vraies séries (après le Sprint B)
  pour choisir : garder le hasard, prendre toujours le plus proche (mais alors le même piège
  revient à chaque fois), ou déplacer un seuil. Déjà mesuré au Sprint B (5 900 questions) : le
  « … » final d'un choix ne désigne pas la bonne réponse (le choix « à part » est le bon dans 12
  à 20 % des cas, contre 25 % au hasard). Pour les questions de mots (Sprint C d'US-22, 5 200
  questions) : aucun mauvais choix ne se lit comme le bon sens, à la casse et à la ponctuation
  près. Mais 8 à 10 % des bons sens n'ont aucun mot de 4 lettres (« qui », « sur ») : la règle
  qui écarte un sens voisin ne les protège pas, et deux synonymes sans mot commun passent
  toujours. À juger aussi sur de vraies séries.
- **Sourate entièrement apprise alors qu'une plage en est déjà sélectionnée** (relevé en
  `/code-review` du Sprint A d'US-20, 2026-10-13) : `handOffLearnedSurahs` ne bascule pas une
  sourate qui a déjà une sélection, même partielle. Les versets appris hors de cette plage
  n'entrent donc ni dans le tour de révision ni dans les séries de Renforcement, alors que le
  Récap compte la sourate comme mémorisée. Il reste à choisir : élargir la sélection à la sourate
  entière au hand-off, ou la laisser telle que l'utilisateur l'a réglée.
- **Un seul style de titre en capitales (« eyebrow »)** (relevé au Sprint B d'US-15) : huit
  titres en capitales ont chacun leur taille et leur espacement (`check_in_screen.dart`,
  `check_out_sections.dart`, `day_closed_summary.dart`, `prayer_selector.dart`,
  `streak_card.dart`, `verse_chips_scaffold.dart`, `check_hero.dart`, `cycle_progress_card.dart`).
  `series_screen.dart` (Sprint B d'US-20) reprend tel quel celui de `cycle_progress_card.dart`.
  Il reste à choisir le style commun avant d'écrire un widget ou un style de thème partagé.
- **Barre à quatre onglets : « Renforcement » se coupe en deux lignes quand le texte est agrandi**
  (relevé au Sprint B d'US-20, 2026-10-13, mesuré sous Windows) : à la taille de texte par défaut,
  les quatre libellés tiennent sur une ligne à 390, 360 et 320 px (« Renforcement » occupe 79,4 px
  sur 80 à 320 px). Avec un texte système agrandi, le mot passe sur deux lignes (« Renforceme /
  nt ») : dès ×1,15 à 320 px, et à ×1,3 à 360 et 390 px (`NavigationBar` plafonne lui-même à
  ×1,3). « Plan du jour » fait de même à 320 px. Rien ne déborde. Avec trois onglets, aucun
  libellé ne se coupait. Il reste à choisir : plafonner l'agrandissement du texte dans la barre,
  resserrer l'espacement des lettres, raccourcir le libellé, ou l'accepter. Même question pour le
  sélecteur de mode de l'onglet (Sprint C d'US-22, mesuré sous Windows à 320 px) : à la taille
  par défaut, « Traduction » tient au plus juste (73,1 px sur 73,3). Avec un texte agrandi, chaque
  libellé rétrécit pour tenir sur une ligne, mais chacun pour soi : dès ×1,15, « Traduction »
  garde sa taille pendant que « Mélange » et « Versets » grandissent. Rien ne se coupe ni ne
  déborde.
- **Renforcement : le message « sélection trop petite » ne dit pas toujours vrai** (relevé au
  Sprint B d'US-20, 2026-10-13, déduit du code, non reproduit) : une sourate prise par « Choisir
  une sourate » peut n'offrir aucune question, quand un seul passage en est porté (premier verset
  appris d'une sourate en cours, plage d'un seul verset court). L'onglet affiche alors « Ta
  sélection est trop petite… Ajoute une sourate dans les Réglages », alors que la sélection
  entière suffirait. Le message reste aussi affiché après un ajout de sourates, jusqu'au
  lancement suivant. Il reste à choisir : ne lister que les sourates qui offrent une question,
  écrire un second message, ou les deux. Le mode « Traduction » (Sprint C d'US-22) a le même
  défaut : une sourate dont un seul mot est posable n'offre aucune question.
- **Renforcement : composer une série fige l'interface près d'une seconde sur une très grande
  sélection** (relevé au Sprint C d'US-22, 2026-10-13, mesuré dans l'app en debug sous Windows) :
  avec 113 sourates portées, 395 à 460 ms en mode « Versets » (inchangé), 365 à 420 ms en mode
  « Traduction », 710 à 810 ms en mode « Mélange », qui est le mode par défaut. La première série
  de mots lit en plus le fichier des sens, environ 100 ms. Sous `flutter test` : 120 ms en
  « Mélange » avec les cinq derniers juz, 22 ms avec le juz 30. Une série sur une seule sourate
  ne lit plus que ses mots (0 à 50 ms), mais ses passages lisent encore toute la sélection pour
  leurs mauvais choix : 310 à 400 ms en « Mélange ». Non mesuré sur téléphone. Il reste à mesurer
  sur un iPhone, puis à choisir : garder en mémoire les passages et les mots portés entre deux
  séries, retenir la forme normalisée de chaque mot distinct, normaliser le texte sans expression
  régulière, ou composer la série hors du fil de l'interface.
- **Questions de mots : trois points d'affichage** (relevés au Sprint C d'US-22, 2026-10-13) :
  dans le sens « sens vers arabe », la sourate et le verset ne sont affichés nulle part, même
  après la réponse (seul « Voir le texte » les donne). Le mot posé n'est signalé que par sa
  couleur or, ce qu'un lecteur d'écran ne dit pas. Sous un mauvais choix, le mot arabe de la
  ligne « mot : sens » est écrit dans la police du système et non en Amiri : lisible sous
  Windows, non vérifié sur iPhone. Il reste à choisir où afficher la référence et comment
  désigner le mot autrement que par la couleur, et à regarder cette ligne sur un iPhone.

---

## Convention de commit

```
feat(sprint-N): description
fix(sprint-N): corrections lié au commentaires utilisateurs
```
