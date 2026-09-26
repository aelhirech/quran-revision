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
- **Verset de contexte à l'apprentissage (2026-09-26)** : `VerseBottomSheet` accepte un `contextAyah` optionnel — le verset `verseStart - 1`, affiché en tête de liste et atténué (`VerseRow.isContext`), jamais coché/compté/inclus dans la plage audio. `PrayerPlanCard` ne le passe que pour la rakaa d'apprentissage (`r.isLearning`) quand `verseStart > 1` — décision produit : apprendre un verset avec celui qui le précède aide la mémorisation, la révision n'en a pas besoin au même degré. Ne pas étendre à la révision sans repasser par blueprint (voir idée produit ci-dessous).

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

### [P3] Récitateurs KSU : catalogue figé en dur, pas de vérification de disponibilité par verset
`lib/core/reciters.dart` (`kReciters`) recopie le mapping `quraa_map` lu dans `js/engine.js` de
`quran.ksu.edu.sa` au 2026-09-26 — aucune garantie que chaque récitateur couvre bien les 6236
(Hafs)/6214 (Warsh) versets sans trou, ni que le site ne change pas cette liste sans préavis
(aucune API documentée, voir §8.6bis). `VerseBottomSheet` affiche un message d'erreur générique
si la lecture échoue (`S.audioErreurLecture`), donc un trou de couverture dégrade proprement au
lieu de planter — mais sans distinguer "récitateur incomplet" de "pas de réseau". Différé :
aucun signalement utilisateur réel à ce jour, revoir si un trou de couverture est rapporté.

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
- **Versets revenus en révision → section "à réviser en dehors des prières", pas verset de contexte** (reformulation 2026-09-26 des items P2 "verset de contexte") : pour la révision, le contexte n'aide pas autant qu'à l'apprentissage (déjà traité, voir décision UI/lecture ci-dessus) — l'idée retenue est plutôt de faire atterrir les versets revenus dans le bloc hors-prières existant (`OutsidePrayersBlock`) plutôt que de les représenter avec leur contexte. À passer par `quran-blueprint` avant scoping : reste à définir comment ça s'articule avec `distributeToRakaas`/`RevisionUnit.==` (règle D) et si ça remplace ou complète le banner `return_proof_seen` actuel.

---

## Convention de commit

```
feat(sprint-N): description
fix(sprint-N): corrections lié au commentaires utilisateurs
```
