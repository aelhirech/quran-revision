# Changelog — Quran Revision App

> Backlog technique en attente + idées produit non scopées. L'historique des sprints livrés vit dans `git log`, pas ici. Ce que fait l'app aujourd'hui (règles produit, plan quotidien, invariants, cas limites) : `docs/SPEC_PRODUIT.md`. Comment c'est codé, et les décisions techniques actives à respecter : `docs/DOCUMENTATION_TECHNIQUE.md` (§13bis). Modèle de données `ayah_facts` : `CLAUDE.md`.

---

## Backlog technique

Dette réelle et gaps prêts à l'implémentation — priorité qui reflète le risque/l'effort, pas l'enthousiasme produit. P1 = risque de correction (données/comportement), P2 = gap concret ou nettoyage rapide, P3 = différé délibérément (aucun bug connu) ou pure polish. Les idées produit non scopées vivent dans la section « Idées produit » plus bas, pas ici.

### [P2] US-25 Sprint B1 — Les six styles sur le plan du jour, le check-in et le check-out
Le Sprint A est livré : `AppText` (`lib/core/app_theme.dart`) porte les six styles.
- **Périmètre** : accueil et plan du jour (`plan_screen.dart`, `home_screen.dart`, cartes
  `cycle_progress_card`, `streak_card`, `learning_progress_card`, `prayer_plan_card`,
  `hadith_card`, `pill_chip`), check-in (`check_in_screen.dart`, `prayer_selector.dart`,
  `check_hero.dart`), check-out (`check_out_screen.dart`, `check_out_sections.dart`,
  `day_closed_summary.dart`, `verse_chips_scaffold.dart`), et les widgets qu'ils incluent.
- **Règle** : chaque `TextStyle` à `fontSize:` littéral devient `AppText.<style>.copyWith(...)`, en
  prenant le style de son rôle (pas celui de sa taille actuelle). Les graisses 500 et 800 passent à
  600 et 700. Le texte arabe (Amiri, Scheherazade) n'est pas touché.
- **Titres de section en capitales** : `check_in_screen.dart:276`, `check_out_sections.dart:98`,
  `cycle_progress_card.dart:73`, `day_closed_summary.dart:107`, `prayer_selector.dart:48` et `:80`,
  `streak_card.dart:48`, `verse_chips_scaffold.dart:37`, `check_hero.dart:38` passent tous au style
  titre de section d'`AppText` (le `.toUpperCase()` reste à l'appel). « Hadith du jour » reste en
  casse normale.
- **Fichiers proches du plafond** (`check_out_screen.dart` 356, `plan_screen.dart` 353,
  `check_in_screen.dart` 305) : le remplacement ne doit pas ajouter de lignes ; s'il en ajoute,
  extraire d'abord.
- **Vérification à l'œil sous Windows** : clair et sombre, 390 et 320 px, texte ×1,5, chaque écran
  touché.
- **Exclus** : mise en page, couleurs de niveau, le reflet `Colors.white` de `plan_screen.dart:346`.

### [P2] US-25 Sprint B2 — Les six styles sur les réglages, l'onboarding et la vue Coran
Le Sprint A est livré. Indépendant de B1.
- **Périmètre** : réglages (`profile_screen.dart`, 361 lignes : extraire avant si le remplacement
  ajoute des lignes), onboarding (`lib/screens/onboarding/`), vue Coran et feuille de versets (texte
  latin seulement : titres, traductions, boutons), séries (`series_screen.dart`, dont le titre en
  capitales l. 54 passe au style titre de section), et les widgets restants qui portent un
  `fontSize:` littéral, hors Récap et onglet Quiz.
- **Règle** : celle du Sprint B1.
- **Récap et onglet Quiz exclus** : US-23 et US-21 les reconstruisent avec les six styles. Seul
  `recap_screen.dart:226` change ici : `cs.tertiary`, hors palette, devient `palette.primary`.
- **Vérification à l'œil sous Windows** : clair et sombre, 390 et 320 px, texte ×1,5.
- **Doc** : `docs/DOCUMENTATION_TECHNIQUE.md` §8.5 point 3 (retirer les dérogations corrigées ; la
  mention du `Colors.black` de `SpotlightOverlay` ne correspond plus au code, à corriger).

### [P2] Embarquer Amiri et Scheherazade dans l'app
Relevé au scoping d'US-25 (2026-10-22). Les polices du texte coranique sont téléchargées par
`google_fonts` au premier affichage : hors connexion au premier lancement, le Coran s'affiche dans la
police du système. Tâche technique, hors blueprint. US-25 Sprint A a créé `assets/fonts/` (Outfit,
déclaré dans `pubspec.yaml`).
- **Fontes** : les fichiers Amiri et Scheherazade New utilisés par l'app (graisses à relever sur les
  12 appels existants) vont dans `assets/fonts/` avec leurs licences OFL. `google_fonts` les trouve
  dans les assets par leur nom de fichier : garder le nom exact attendu par le package
  (`Amiri-Regular.ttf`, ...) et ne pas changer les 12 appels.
- **`lib/main.dart`** : `GoogleFonts.config.allowRuntimeFetching = false`, pour qu'aucune police ne
  soit plus téléchargée.
- **Tests** : les tests qui mettent déjà `allowRuntimeFetching = false` passent toujours ; à l'œil
  sous Windows, réseau coupé, le texte coranique s'affiche en Amiri.

### [P3] Hook de reprise d'arrière-plan logé dans `ShellScreen`, pas `AppState`
Relevé en `/code-review high` du sprint US-3 (2026-09-21, altitude). Le `WidgetsBindingObserver`
qui rejoue `ensureDayPlan()` au retour d'arrière-plan (US-3 crit. 5) — et depuis US-10 Sprint B
`AudioDownloadService.resumePending()` — vit dans `ShellScreen`. Un
futur écran racine qui ne descendrait pas de `ShellScreen` devrait dupliquer ce hook. Différé :
un seul écran racine existe aujourd'hui, centraliser dans `AppState` maintenant serait de la
généralisation anticipée pour un cas qui n'existe pas encore.

### [P3] Retirer les `await` sur `DaySelection` dans deux fichiers de test
Relevé à la clôture du sprint 23 (2026-10-22) : `flutter analyze lib test` remonte 26 infos
`await_only_futures` — 21 dans `test/core/revision_engine_test.dart`, 5 dans
`test/state/app_state_checkin_test.dart` — sur des `await` devant une expression `DaySelection`
synchrone. Retirer ces `await`, sans autre changement ; `flutter analyze lib test` doit revenir à
zéro. Pur bruit d'analyse, aucun comportement touché.

## Idées produit (non scopées)

Vision/features pas encore prêtes à l'implémentation — pas de priorité technique tant qu'elles n'ont pas été cadrées (`quran-blueprint` → user story dans `docs/USER_STORIES.md`, puis `quran-scoping` → item ci-dessus). Ne pas lancer à la volée.

- **Verset de contexte des versets revenus : calculé, jamais affiché** (relevé à la consolidation
  de `docs/SPEC_PRODUIT.md`, 2026-10-22). US-3 crit. 4 et US-1 crit. 7 promettaient d'afficher le
  verset qui précède un verset revenu. `AppState.returningVersesContext` le calcule
  (`RevisionEngine.contextVerseFor`), mais `ReturnProofStep` n'utilise que les clés de la map :
  la valeur est un calcul mort. La spec décrit l'état actuel (non affiché). À trancher : l'afficher
  (story, recoupe l'idée « Versets revenus en révision » ci-dessous) ou retirer le calcul (item de
  Backlog trivial).
- **Section « À prioriser » du check-in (US-5) : absente du code** (relevé à la même
  consolidation). US-5 la décrivait livrée ; seul subsiste un libellé discret de fraîcheur par
  ligne du check-in. À vérifier : retrait volontaire (alors rien à faire, la spec est juste) ou
  perte accidentelle (alors une story, à articuler avec US-26 qui fait déjà passer plus tôt ce qui
  n'a pas été revu depuis longtemps).

- **Check-in : trois comportements aux bords, relevés au Sprint A d'US-27 (2026-10-21)**, à trancher
  avant d'en faire un item :
  - *Jour validé sans aucune ligne* (tout retiré, rien à apprendre) : indiscernable d'un jour jamais
    commencé, donc un check-in rouvert après « Refaire le plan » repropose les valeurs par défaut du
    moteur. Avant US-27 le cas existait aussi, à chaque ouverture de l'app. Un marqueur « commencé »
    (comme `last_sealed_date`) le réglerait, au prix d'une seconde source de vérité.
  - *Retirer une unité déjà atteinte* (`reach=1`) dans un check-in rouvert : l'unité disparaît de
    l'écran, mais `commitCheckIn` ne supprime jamais une ligne `reach=1`, donc elle revient au plan
    sans message. Il reste à choisir : bloquer le « × » sur une unité atteinte, ou autoriser la
    suppression.
  - *Étendre une unité jusqu'à toucher la suivante* (deux unités adjacentes d'une même sourate le
    même jour, `+` du détail) : le brouillon montre le même verset dans les deux, alors que la base
    n'en écrit qu'un. Il reste à choisir : cacher le « + » à la frontière, ou fusionner les deux
    unités.

- **Plan du jour sans prière : trois textes parlent encore de prières** (relevé au Sprint B
  d'US-27, 2026-10-22, vu sous Windows) : la description du bloc hors prières dit « il ne rentrait
  pas dans les prières que tu as choisies » alors qu'aucune n'est choisie ; le résumé affiche
  « 0 rakaas » et le compteur du bas « 0 / 0 rakaas », avec une barre de progression pleine dès
  l'ouverture. Rien n'est faux dans les données. Il reste à choisir : une seconde description pour
  le cas sans prière, cacher le compteur de rakaas, ou les deux.
- **Rattrapage d'un jour passé : le curseur lit celui d'aujourd'hui** (relevé en `/code-review`
  du sprint 21, déduit du code, non reproduit) : `_completedPagesFor` parcourt le cycle depuis
  `cyclePosition` d'aujourd'hui même pour un check-out passé ; une sourate de la sélection déclarée
  « en plus » un jour passé pourrait faire sauter des groupes jamais révisés si ce jour est scellé
  après que le curseur a bougé. `ensureDayPlan` gèle le plan tant qu'un jour est en attente, ce
  qui rend le cas rare. À reproduire par un test avant de décider d'un correctif.
- **Onboarding : case de hizb dont toutes les sourates ont une plage partielle** (sprint 21) : elle
  s'affiche cochée, et un appui retire alors ces sourates, plages comprises. Conforme à l'item
  (une plage partielle « compte comme sélectionnée »), à revoir sur usage.
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
- **Barre à quatre onglets : « Renforcement » se coupe en deux lignes quand le texte est agrandi**
  (remesuré en Outfit au sprint 24, US-25 Sprint A, 2026-10-22 : « Renforcement » occupe 76,5 px au
  lieu de 79,4 à la taille par défaut, et passe toujours sur deux lignes à 320 px ×1,5, comme avant ;
  à remesurer quand US-24 renommera l'onglet « Quiz »)
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
- **320×568 avec texte ×1,5 : débordements et mots coupés hors vue Coran** (relevés au sprint 24,
  US-25 Sprint A, 2026-10-22, sous Windows ; tous présents avant le passage à Outfit, qui les
  réduit) : au check-in, le bouton « Choisir une sourate à apprendre » déborde de 23 px (39 en
  Lora) et la ligne « Mes prières du jour » + « Dernières prières » de 88 px (101 en Lora) ; la
  carte de série du Récap coupe « Aucune session enregistrée » au milieu des mots ; aux Réglages,
  le libellé « Rythme » s'écrit une lettre par ligne ; le titre « Révision en cours » est tronqué.
  Seul changement dû à Outfit : la plage « (v.1–10) » d'une rakaa se coupe désormais après le
  tiret. Il reste à choisir le correctif (plafonner l'agrandissement du texte, passer à la ligne,
  raccourcir), comme pour les deux débordements de la vue Coran ci-dessus. Le Récap est reconstruit
  par US-23 : à revérifier après.
- **Italique synthétique en Outfit** (relevé au sprint 24, US-25 Sprint A, 2026-10-22) : Outfit
  n'a pas de fichier italique, Flutter penche donc les lettres (hadith du jour, « 10 versets »,
  plage « v.1–40 » du check-out, « jours de révision »). Lisible sous Windows, non vérifié sur
  iPhone. Les six styles d'US-25 n'ont pas d'italique. Il reste à choisir aux Sprints B1/B2 :
  retirer l'italique (le style de légende suffit) ou le garder penché.
- **Sélecteur de plage : « Tout sélectionner » passe sur deux lignes** (relevé au sprint 20,
  2026-10-13, vu sous Windows à 390 px, taille de texte par défaut, en clair et en sombre) : dans
  `VerseRangePicker`, le bouton de gauche écrit « Tout / sélectionner » sur deux lignes, calé à
  gauche, à côté d'un « Confirmer » sur une ligne. Rien ne déborde. Il reste à choisir :
  raccourcir le libellé, réduire le texte comme `PrimaryCtaButton`, ou empiler les deux boutons.

---

## Convention de commit

```
feat(sprint-N): description
fix(sprint-N): corrections lié au commentaires utilisateurs
```
