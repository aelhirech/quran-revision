# Changelog — Quran Revision App

> Backlog technique en attente + idées produit non scopées. L'historique des sprints livrés vit dans `git log`, pas ici. Ce que fait l'app aujourd'hui (règles produit, plan quotidien, invariants, cas limites) : `docs/SPEC_PRODUIT.md`. Comment c'est codé, et les décisions techniques actives à respecter : `docs/DOCUMENTATION_TECHNIQUE.md` (§13bis). Modèle de données `ayah_facts` : `CLAUDE.md`.

---

## Backlog technique

Dette réelle et gaps prêts à l'implémentation — priorité qui reflète le risque/l'effort, pas l'enthousiasme produit. P1 = risque de correction (données/comportement), P2 = gap concret ou nettoyage rapide, P3 = différé délibérément (aucun bug connu) ou pure polish. Les idées produit non scopées vivent dans la section « Idées produit » plus bas, pas ici.

### [P3] Test qui interdit un `fontSize:` littéral hors `app_theme.dart`
Relevé au Sprint B1 d'US-25 (2026-10-22) : rien n'empêche un futur écran de réécrire un
`TextStyle(fontSize: …)` à côté des six styles d'`AppText`. Un test (`test/core/
app_text_usage_test.dart`) lit chaque fichier `.dart` de `lib/` et échoue sur toute ligne où
`fontSize:` est suivi d'un nombre (`fontSize:\s*\d`), sauf dans `lib/core/app_theme.dart` et sauf
les lignes `GoogleFonts.` (texte arabe). Le nombre et pas le simple `fontSize:` (relevé au Sprint
B2) : deux lignes légitimes restent, `IndexBadge` (`fontSize: size * 0.37`, chiffre proportionnel
à la pastille) et `VerseRow` (`ArabicVerseText(fontSize: fontSize)`, paramètre de la police
arabe). Exclus tant qu'US-23 et US-21 n'ont pas reconstruit le Récap et l'onglet Quiz :
`recap_screen.dart`, les trois widgets qu'il est seul à afficher (`history_card.dart`,
`sourates_recap_card.dart`, `learning_progress_card.dart`) et `lib/screens/reinforcement/`, listés
en dur dans le test et retirés au fil des livraisons.

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

Besoins réels mais pas encore cadrés : chacun contient une décision ouverte. Ils passent par `quran-blueprint` (user story dans `docs/USER_STORIES.md`) puis `quran-scoping` (item au Backlog ci-dessus) avant tout code. Ne pas lancer à la volée.

### Plan du jour et check-in

- **Versets revenus : contexte calculé, jamais affiché.** `AppState.returningVersesContext` calcule
  le verset qui précède chaque verset revenu (`RevisionEngine.contextVerseFor`), mais
  `ReturnProofStep` n'en lit que les clés : la valeur est un calcul mort. Piste retenue le
  2026-09-26 : faire atterrir les versets revenus dans le bloc hors prières
  (`OutsidePrayersBlock`) plutôt que de les montrer avec leur contexte. Reste à choisir : cette
  piste (story, à articuler avec `distributeToRakaas`/`RevisionUnit.==` et le message
  `return_proof_seen`), ou retirer le calcul (alors item de Backlog trivial).
- **Check-in : trois comportements aux bords** (Sprint A d'US-27, 2026-10-21) :
  - *Jour validé sans aucune ligne* (tout retiré, rien à apprendre) : indiscernable d'un jour jamais
    commencé, donc un check-in rouvert après « Refaire le plan » repropose les valeurs par défaut.
    Un marqueur « commencé » (comme `last_sealed_date`) le réglerait, au prix d'une seconde source
    de vérité.
  - *Retirer une unité déjà atteinte* (`reach=1`) dans un check-in rouvert : elle disparaît de
    l'écran, mais `commitCheckIn` ne supprime jamais une ligne `reach=1`, donc elle revient au plan
    sans message. À choisir : bloquer le « × » sur une unité atteinte, ou autoriser la suppression.
  - *Étendre une unité jusqu'à toucher la suivante* (même sourate, même jour, `+` du détail) : le
    brouillon montre le même verset dans les deux unités, la base n'en écrit qu'un. À choisir :
    cacher le « + » à la frontière, ou fusionner les deux unités.
- **Plan du jour sans prière : trois textes parlent encore de prières** (Sprint B d'US-27) : le
  bloc hors prières dit « il ne rentrait pas dans les prières que tu as choisies » alors
  qu'aucune n'est choisie ; le résumé affiche « 0 rakaas », le compteur du bas « 0 / 0 rakaas »
  avec une barre pleine dès l'ouverture. Les données sont justes. À choisir : une seconde
  description pour ce cas, cacher le compteur de rakaas, ou les deux.
- **Rattrapage d'un jour passé : le curseur lit celui d'aujourd'hui** (déduit du code au sprint
  21, non reproduit) : `_completedPagesFor` parcourt le cycle depuis la `cyclePosition` du jour
  même pour un check-out passé. Une sourate déclarée « en plus » un jour passé pourrait faire
  sauter des groupes jamais révisés si ce jour est scellé après que le curseur a bougé.
  `ensureDayPlan` gèle le plan tant qu'un jour est en attente, ce qui rend le cas rare. À
  reproduire par un test avant de choisir un correctif.
- **Sourate entièrement apprise alors qu'une plage en est déjà sélectionnée** (Sprint A d'US-20) :
  `handOffLearnedSurahs` ne bascule pas une sourate qui a déjà une sélection, même partielle. Les
  versets appris hors de la plage n'entrent ni dans le tour ni dans les séries, alors que le Récap
  compte la sourate comme mémorisée. À choisir : élargir la sélection à la sourate entière au
  passage en révision, ou la laisser telle que l'utilisateur l'a réglée.
- **Onboarding : case de hizb dont toutes les sourates ont une plage partielle** (sprint 21) :
  elle s'affiche cochée, et un appui retire ces sourates, plages comprises. Conforme à l'item (une
  plage partielle compte comme sélectionnée), à revoir sur usage.

### Renforcement (onglet « Quiz » après US-24)

- **Qualité des mauvais choix, à régler sur de vraies séries** (US-20, US-22) : le mauvais choix
  « similaire » est tiré au hasard parmi les passages similaires, pas le plus proche ; les seuils
  (12 mots par passage, moitié des mots en commun) viennent des mesures du scoping. Mesuré : le
  « … » final d'un choix ne trahit pas la bonne réponse (le choix « à part » est le bon dans 12 à
  20 % des cas, contre 25 % au hasard) ; aucun mauvais sens de mot ne se lit comme le bon. Mais 8 à
  10 % des bons sens n'ont aucun mot de 4 lettres (« qui », « sur ») et échappent à la règle qui
  écarte un sens voisin ; deux synonymes sans mot commun passent toujours. À choisir après usage :
  garder le hasard, prendre toujours le plus proche (le même piège reviendrait), ou déplacer un
  seuil.
- **Message « sélection trop petite » parfois faux** (déduit du code, non reproduit) : une sourate
  prise par « Choisir une sourate » peut n'offrir aucune question (un seul passage porté, un seul
  mot posable en mode « Traduction ») ; l'onglet dit alors « Ta sélection est trop petite… »
  alors que la sélection entière suffirait. Le message reste aussi affiché après un ajout de
  sourates, jusqu'au lancement suivant. À choisir : ne lister que les sourates qui offrent une
  question, écrire un second message, ou les deux.
- **Composer une série fige l'interface sur une très grande sélection** (mesuré en debug sous
  Windows, 113 sourates portées) : 395 à 460 ms en « Versets », 365 à 420 ms en « Traduction »,
  710 à 810 ms en « Mélange » (mode par défaut), plus environ 100 ms pour lire les sens à la
  première série de mots. Une série sur une seule sourate prend encore 310 à 400 ms en
  « Mélange » (ses mauvais choix lisent toute la sélection). À mesurer sur iPhone, puis choisir :
  garder les passages et les mots en mémoire entre deux séries, retenir la forme normalisée de
  chaque mot, normaliser sans expression régulière, ou composer hors du fil de l'interface.
- **Questions de mots : trois points d'affichage** (US-22) : en « sens vers arabe », la sourate et
  le verset ne sont affichés nulle part, même après la réponse (seul « Voir le texte » les
  donne) ; le mot posé n'est signalé que par sa couleur or, ce qu'un lecteur d'écran ne dit pas ;
  sous un mauvais choix, le mot arabe de la ligne « mot : sens » est dans la police du système, pas
  en Amiri (non vérifié sur iPhone). À choisir : où afficher la référence, comment désigner le mot
  sans la couleur.
- **Mode « versets à retravailler » en jeu à part** : mécanique de jeu à définir avant tout code.

### Affichage et texte agrandi

Une seule question derrière les cinq premiers points : que faire quand le texte système est
agrandi (plafonner l'agrandissement, passer à la ligne, faire rétrécir le libellé comme
`PrimaryCtaButton`, raccourcir, ou accepter). La trancher une fois, puis l'appliquer partout.
375×667 avec texte ×1,5 correspond au plus petit iPhone pris en charge ; 320×568 sert de marge.
Mesures sous Windows, à jour au 2026-10-23.

- **À 375 px ×1,5** : la rangée « Sélection rapide » de l'onboarding déborde de 12 px à droite ;
  l'en-tête du mode édition des Réglages (« Réviser en 2 pages / jour » + « Tout sélectionner »)
  déborde de 110 px ; l'en-tête des étapes d'onboarding (titre d'écran, 28 px) ne laisse que deux
  sourates visibles dans la liste de sélection. Accueil, check-in, plan du jour, check-out et
  Récap : aucun débordement.
- **À 320 px ×1,5, hors vue Coran** : rangée « Sélection rapide » (67 px) ; au plan du jour, la
  ligne d'une rakaa d'apprentissage (« Apprentissage » + « 3 versets ») déborde de 54 px, le badge
  « Jamais » est coupé d'un demi-pixel, la plage « (v.1–10) » se coupe après le tiret ; au
  check-in, la ligne « Mes prières du jour » + « Dernières prières » débordait de 88 px (pas
  remesurée depuis le 2026-10-22) ; aux Réglages, « Rythme » s'écrit une lettre par ligne ; le
  titre « Révision en cours » est tronqué. Au Récap (reconstruit par US-23, à revérifier après) :
  « Aucune session enregistrée » se coupe au milieu des mots, et la zone de fin d'une ligne de
  sourate peut prendre toute la largeur (assertion Flutter en debug).
- **Vue Coran à 320 px ×1,5** : la ligne « − v.282 + … − v.283 + » de `VerseRangeSlider` déborde de
  38 px avec des numéros à trois chiffres (18 px avec deux), et `IndexBadge` coupe un numéro à
  trois chiffres (« 282 » affiché « 28 »).
- **Barre d'onglets** : avec un texte agrandi, « Renforcement » passe sur deux lignes (dès ×1,15 à
  320 px, à ×1,3 à 360 et 390 px ; `NavigationBar` plafonne lui-même à ×1,3), « Plan du jour »
  aussi à 320 px. Rien ne déborde. À remesurer quand US-24 renommera l'onglet « Quiz ». Dans le
  sélecteur de mode de l'onglet, chaque libellé rétrécit pour tenir, mais chacun pour soi
  (« Traduction » garde sa taille quand « Mélange » et « Versets » grandissent).
- **Sélecteur de plage** (`VerseRangePicker`, dès 390 px, taille par défaut) : « Tout /
  sélectionner » passe sur deux lignes à côté d'un « Confirmer » sur une ligne. Rien ne déborde.
- **Vue Coran : la barre saute quand on resserre la portion après avoir défilé** : feuille défilée
  de 140 px, portion resserrée de 50 à 2 versets, le contenu devient plus court que la position
  de défilement et la barre descend de 140 px sous le doigt ; un ±1 répété peut tomber à côté du
  bouton. À choisir : défilement figé pendant le réglage, retour en haut, ou autre.
- **Italique synthétique en Outfit** : Outfit n'a pas de fichier italique, Flutter penche les
  lettres (hadith du jour, « 10 versets », plage « v.1–40 » du check-out, « jours de révision »,
  textes de l'intro, de la méthode et de la célébration de l'onboarding). Lisible sous Windows,
  non vérifié sur iPhone. À choisir : retirer l'italique (les six styles n'en ont pas) ou le
  garder penché.

### Long terme

- **Révision espacée par verset** : un score de difficulté tiré de l'historique `ayah_facts`
  (aujourd'hui `lastRevisionDatesPerVerse` ne garde que la dernière date). L'ancien signal
  `needsWork` a été retiré au sprint US-3 : à rescoper sur un autre signal (par exemple la
  fréquence des versets décochés) avant tout code.
- **Coran en SQLite et tajwid coloré** : texte, mot à mot et tajwid dans une base, jointe
  naturellement à `ayah_facts`. Le tajwid coloré en dépend (données QUL) et passera par
  `AppPalette`. Ne migrer que si cette fonctionnalité est réellement engagée, pas parce que
  « c'est plus propre ». Les questions de mots s'en passent (asset texte).
- **Calendrier d'activité (heatmap) au Récap** : chaque fait `ayah_facts` est déjà daté, la donnée
  est gratuite.

---

## Convention de commit

```
feat(sprint-N): description
fix(sprint-N): corrections lié au commentaires utilisateurs
```
