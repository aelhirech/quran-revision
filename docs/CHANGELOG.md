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

**Cadrage produit encore valide**
- « Prières où il est imam » = prières où c'est lui qui récite (seul ou en dirigeant) — un simple élargissement de libellé, pas un filtre d'exclusion ni une pondération de répartition.
- L'apprentissage n'a plus d'onglet dédié : la sourate à apprendre est choisie au check-in, récitée dans la **dernière rakaa** du plan, confirmée au check-out.
- Le hand-off "sourate mémorisée → révision" est automatique et passe par `AppState.addSelectionKeepingCycle`, **jamais** `saveConfig` (qui remettrait `cyclePosition` à 0).
- « Faire plus » (sourate en plus, verset en plus) fait avancer le cycle au-delà de la proposition du jour — mais seulement si l'utilisateur l'a explicitement déclaré ce jour-là ; le curseur reste ordonné, déclarer un groupe plus loin dans la rotation ne crédite pas ceux qui le précèdent.
- **Accompagnement guidé (`AppState.guideDone`/`markGuideDone`, US-1 sprint B, remplace l'ancien `hasSeenHook`/`HookBanner`)** : un id n'est marqué que par le callback du GESTE RÉEL qu'il accompagne (check-in validé, verset ouvert, check-out scellé, action du `GuideStep`) — jamais par le simple affichage d'une carte ni par une croix de fermeture. Toute nouvelle étape guidée doit suivre cette règle, pas réintroduire un dismiss passif.
- Heures de rappel matin/soir (`StorageService.loadMorningTime`/`loadEveningTime`) sont des préférences **globales**, jamais préfixées par riwaya et jamais rechargées dans `_loadTrackState` — un réglage de notification n'a rien à voir avec le parcours de révision actif.
- **`needs_work` retiré de tout le code applicatif (US-3, 2026-09-21)** : la colonne `ayah_facts.needs_work` reste dans le schéma SQLite (DEFAULT 0, jamais migrée/droppée sans utilisateurs réels) mais plus aucun code Dart ne l'écrit ni ne la lit — `AyahFactsRitual.setNeedsWork`/`lastRevisionFlags`, `AppState.setVerseNeedsWork`/`lastRevisionFlagsFor` et le toggle bookmark de `VerseBottomSheet` ont disparu. Le check-out est désormais **verset par verset** (`CheckOutRow`/`VerseToggleChips`, `Set<(int surahId, int ayahId)>`), plus par sourate/portion entière — un seul geste (décocher un verset précis) couvre révision et apprentissage. Ne jamais réintroduire de colonne/flag parallèle pour un besoin de correction fine : `reach` par verset suffit.

**Cycle / `RevisionEngine`**
- **Verset revenu + contexte (US-3 crit. 4, 2026-09-21)** : `RevisionEngine.contextVerseFor(surahId, ayahId, selections)` — pure, Dart — renvoie le verset `n-1` d'un verset donné **s'il reste dans la plage sélectionnée par l'utilisateur** (jamais hors plage, invariant E.3), `null` sinon. `AyahFactsRitual.returningVerses`/`AppState.returningVersesContext` identifient les versets laissés `reach=0` à un check-out **scellé** (`checked_out=1`) et redevenus candidats du plan du jour. Infrastructure prête, **pas encore consommée par un écran** — c'est US-1 sprint C (bloqué jusqu'ici) qui affichera le message « ce verset est revenu seul ».

**Infra / divers**
- `sqflite_common_ffi` est en dépendance de **prod**, pas dev-only : `main.dart` bascule dessus derrière `if (Platform.isWindows)`, une condition runtime que Dart ne tree-shake pas — léger surcoût de taille binaire mobile assumé pour pouvoir tester sur cette machine sans device.
- Fraîcheur par verset (2026-09-04) : seuils changés délibérément (30j remplace l'ancien badge 7j ; paliers `neverRevised`/`sixMonths`/`oneYear` remplacent le seuil unique 180j). Pas tranché à l'identique partout — à ajuster sur retour utilisateur, pas à traiter comme un bug.
- Tests `sqflite_common_ffi` : une seule `history.db` partagée par tous les tests d'un même fichier (`initFfiTestDb` isole les fichiers entre eux, pas les tests entre eux) — un test peut hériter d'un `checked_out` posé par le précédent. `clearFactsBetweenTests()` doit tourner en `setUp`, sans fermer la connexion (`openDatabase` renvoie l'instance en cache).
- **Notifications planifiées via `zonedSchedule` + fuseau réel de l'appareil (US-3 crit. 6, 2026-09-21)**, plus `periodicallyShow`. Bug corrigé au passage, présent depuis US-1 sprint B et invisible faute de test : `periodicallyShow` ignore purement `hour`/`minute`, les rappels se déclenchaient 24h après le dernier `enable()`/changement d'heure, jamais à l'heure configurée. Dépendances ajoutées : `timezone` (déjà transitive via `flutter_local_notifications`, rendue directe) + `flutter_timezone` (détection du fuseau IANA de l'appareil). `NotificationService._initializeTimeZone()` retombe explicitement sur `tz.UTC` si la détection échoue — `tz.local` est un champ `late` du package `timezone`, sans filet : le laisser non initialisé casserait silencieusement les 3 rappels pour toujours, pas seulement celui du jour.

---

## Backlog technique

Dette réelle et gaps prêts à l'implémentation — priorité qui reflète le risque/l'effort, pas l'enthousiasme produit. P1 = risque de correction (données/comportement), P2 = gap concret ou nettoyage rapide, P3 = différé délibérément (aucun bug connu) ou pure polish. Les idées produit non scopées vivent dans la section « Idées produit » plus bas, pas ici.

### [P2] Afficher le verset de contexte d'un verset revenu (reste de US-1 crit. 7 / US-3 crit. 4)
Le banner `return_proof_seen` (US-1 sprint C, `PlanScreen`) signale qu'un verset décoché est revenu,
mais **ne promet volontairement plus** « avec le verset qui le précède » : aucun écran du plan
n'affiche ce verset de contexte. `RevisionEngine.contextVerseFor` est calculé par
`AppState.returningVersesContext()` mais seul le premier verset revenu est nommé dans le texte
(sans son contexte). À faire : montrer le verset `n-1` dans la rakaa/`VerseBottomSheet` du verset
revenu, puis réintroduire la mention dans le banner. Décision produit/UI requise (où le montrer).

### [P2] `returningVerses` compte d'anciennes lignes `reach=0` déjà rattrapées
Relevé en `/code-review medium` du sprint US-1 C (2026-09-21). `AyahFactsRitual.returningVerses`
(`reach = 0 AND checked_out = 1 AND date < today`) matche n'importe quelle ancienne ligne non
atteinte, même si le verset a été atteint un jour ultérieur (autre ligne `reach=1`). Le banner étant
à usage unique, l'impact est faible, mais « revenu » peut désigner une simple récurrence du cycle.
Correctif : exclure les versets ayant une ligne `reach=1` postérieure à la dernière ligne `reach=0`.

### [P3] Extraire `plan_screen.dart` (418 lignes)
Dépasse le seuil de 400 lignes après US-1 sprint C (357 avant). Extraire les blocs `GuideStep`
conditionnels (verses_reachable / non-terminé / return_proof) et `_summaryBar` dans des widgets
dédiés, en sprint séparé.

### [P2] `returningVersesContext` recalcule ses candidats plutôt que de dériver de `dayFacts()`
Relevé en `/code-review high` du sprint US-3 (2026-09-21, altitude). `AppState.
returningVersesContext()` reconstruit l'ensemble des versets du jour depuis `dayUnits()` puis
interroge `AyahFactsRitual.returningVerses` séparément, au lieu que ce statut « revenu » soit porté
nativement par `DayFactGroup`/`dayFacts()`. Différé : aucun consommateur avant US-1 sprint C — a
attendre que cet écran précise le besoin réel avant de refaçonner la requête.

### [P3] `returningVerses` scanne tout l'historique scellé avant de filtrer en Dart
Relevé en `/code-review high` du sprint US-3 (2026-09-21, efficiency). `AyahFactsRitual.
returningVerses` récupère toutes les lignes `reach=0, checked_out=1` de la riwaya avant
d'intersecter avec les candidats du jour côté Dart, plutôt qu'un filtre SQL sur les candidats.
Négligeable à l'échelle réelle de l'app (un seul utilisateur, base locale, quelques centaines de
lignes même après plusieurs mois) — ne traiter que si un profilage montre un coût réel.

### [P3] Hook de reprise d'arrière-plan logé dans `ShellScreen`, pas `AppState`
Relevé en `/code-review high` du sprint US-3 (2026-09-21, altitude). Le `WidgetsBindingObserver`
qui rejoue `ensureDayPlan()` au retour d'arrière-plan (US-3 crit. 5) vit dans `ShellScreen`. Un
futur écran racine qui ne descendrait pas de `ShellScreen` devrait dupliquer ce hook. Différé :
un seul écran racine existe aujourd'hui, centraliser dans `AppState` maintenant serait de la
généralisation anticipée pour un cas qui n'existe pas encore.

### [P2] Découper `lib/core/strings.dart`
**484 lignes aujourd'hui** (415 avant US-1 sprint A, ~450 après le sprint A, +39 au sprint B pour
les chaînes du guide et des heures de rappel, quasi stable au sprint US-3 : +2 minuit / -4 needs
work) — au-delà du plafond de 300-350 de `CLAUDE.md`, toujours au-delà des 400 lignes qui imposent
une extraction dédiée. Une
classe Dart ne peut pas être répartie sur des `part` : le découpage impose plusieurs classes par
domaine (`S`, `SOnboarding`, `SCheckIn`, …) et un renommage sur l'ensemble des sites d'appel.
**Sprint dédié, pas un à-côté de sprint fonctionnel.**


### [P2] « 121 jours » (entrées de cycle) contre « 85 pages » (pages réelles) — deux chiffres vrais qui se contredisent à l'écran
Constaté au sprint US-1 A (2026-09-20) sur une sélection du dernier quart du Coran : l'onboarding
annonce « un tour complet : 121 jours » à 1 page/jour, tandis que l'accueil affiche « 0 / 85 pages ».
Les deux sont corrects — 121 **entrées de cycle** pour 85 **pages physiques**, l'écart venant des
sourates à cheval sur une page frontière, qui coûtent chacune une entrée propre (`CLAUDE.md`
§ Règle du plan quotidien, A.3). Mais côte à côte ils se contredisent : « 1 page / jour » + « 85 pages »
suggère 85 jours. En pratique l'app sert ~0,7 page réelle par jour, et c'est le libellé
« N page(s) / jour » qui est le plus trompeur des trois.
**Décision produit requise avant tout code** — trois sorties possibles, non tranchées :
(a) renommer le rythme en « unités/jour » ou équivalent ; (b) afficher la progression de l'accueil
en entrées plutôt qu'en pages réelles (contredirait la règle « un écran qui promet des pages doit
utiliser `realPages` ») ; (c) assumer l'écart et l'expliquer d'une phrase. **Ne pas « corriger »
`cycleDays` vers `realPages`** : le scoping a tranché pour les entrées parce que compter en pages
réelles promettrait un tour plus court que celui réellement parcouru, pour un chiffre présenté
comme une garantie (verrouillé par `test/core/revision_engine_test.dart`).

### [P3] Pluralisation « 1 versets » / « 1 verses »
`'${unit.verseCount} ${S.versets}'` est écrit à trois endroits (`lib/screens/check_in_sections.dart`,
`lib/widgets/prayer_plan_card.dart`, `lib/screens/onboarding/steps/preview_page.dart`) avec un
`S.versets` toujours au pluriel — une portion d'un seul verset affiche « 1 versets ». Visible sur
l'écran Jour 1 de l'onboarding. À traiter en **une seule passe sur les trois sites** (en corriger un
seul rendrait l'app incohérente) ; `S.streakJours` montre déjà le patron singulier/pluriel à suivre.

### [P3] Le wizard d'onboarding reconstruit le cycle à chaque frappe clavier
`_OnboardingScreenState.build()` appelle `_daySelection` (donc `RevisionEngine.buildDayUnits`) sans
garde, et le `PageView(children:)` construit toutes ses pages à chaque build — donc chaque tap de
sourate et chaque frappe dans la recherche de la page Sélection reconstruit le cycle entier, alors
que seules les pages Rythme et Jour 1 en consomment le résultat et qu'aucune des deux n'est visible
à ce moment. Coût mesuré à l'analyse : ~15-20k opérations + ~1500 constructions de `Random` +
~700-800 allocations par frappe sur une sélection « tout le Coran » (`pageMetadataFor` est un lookup
en cache, il n'est pas en cause).
**Différé délibérément** : aucun profilage n'a montré de saccade, et le correctif naturel (passer en
`PageView.builder` pour n'évaluer `_daySelection` que dans les `itemBuilder` des pages concernées)
**change la liveness des pages** — `PageView(children:)` garde toutes les pages vivantes, `.builder`
peut disposer les pages hors écran, ce qui mettrait en jeu l'état du champ de recherche et la
position de scroll de la liste des 114 sourates. Ne traiter que si un profilage sur appareil réel
montre une saccade, et vérifier ces deux états après coup. **Ne pas mémoïser `_daySelection` dans un
champ** : un flag à invalider est exactement ce que le projet refuse (voir `_lastQuickFraction`).
## Idées produit (non scopées)

Vision/features pas encore prêtes à l'implémentation — pas de priorité technique tant qu'elles n'ont pas été cadrées (`quran-blueprint` → user story dans `docs/USER_STORIES.md`, puis `quran-scoping` → item ci-dessus). Ne pas lancer à la volée.

- **SRS réel par verset** (score de difficulté depuis l'historique `ayah_facts`, aujourd'hui écrasé par `lastRevisionDatesPerVerse` qui ne garde que `MAX(date)`) — dépendait de `needsWork`, **retiré du code au sprint US-3** (2026-09-21) ; à rescoper sur un autre signal (ex. fréquence des décochages verset par verset) avant toute implémentation.
- **Coran en SQLite** (texte + word-by-word + tajweed) — débloquerait "jeu mot arabe → traduction" et "tajweed coloré" ci-dessous, JOIN naturel avec `ayah_facts`. Garde-fou : ne pas migrer parce que "c'est plus propre", seulement si une des deux features dépendantes est réellement engagée.
- **Jeu mot arabe → traduction** (Apprendre) — bloqué faute de données word-by-word (QUL), voir Coran SQLite.
- **Affichage tajweed coloré** — bloqué faute de données tajwid (QUL), voir Coran SQLite. Passera par `AppPalette`/tokens sémantiques, jamais de couleur en dur.
- **Timeline d'activité (heatmap) dans Profil/Récap** — chaque fait `ayah_facts` est déjà daté, gratuit en donnée.
- **Mode "versets à retravailler" en jeu à part** — mécanique de jeu à définir avant tout code.
- **Gamification narrative [H]** — vision long terme, direction artistique déjà validée (Mus'haf/Tahajjud), mécanique narrative encore à définir.

---

## Convention de commit

```
feat(sprint-N): description
fix(sprint-N): corrections lié au commentaires utilisateurs
```
