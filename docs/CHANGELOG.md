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

**Infra / divers**
- `sqflite_common_ffi` est en dépendance de **prod**, pas dev-only : `main.dart` bascule dessus derrière `if (Platform.isWindows)`, une condition runtime que Dart ne tree-shake pas — léger surcoût de taille binaire mobile assumé pour pouvoir tester sur cette machine sans device.
- Fraîcheur par verset (2026-09-04) : seuils changés délibérément (30j remplace l'ancien badge 7j ; paliers `neverRevised`/`sixMonths`/`oneYear` remplacent le seuil unique 180j). Pas tranché à l'identique partout — à ajuster sur retour utilisateur, pas à traiter comme un bug.
- Tests `sqflite_common_ffi` : une seule `history.db` partagée par tous les tests d'un même fichier (`initFfiTestDb` isole les fichiers entre eux, pas les tests entre eux) — un test peut hériter d'un `checked_out` posé par le précédent. `clearFactsBetweenTests()` doit tourner en `setUp`, sans fermer la connexion (`openDatabase` renvoie l'instance en cache).

---

## Backlog technique

Dette réelle et gaps prêts à l'implémentation — priorité qui reflète le risque/l'effort, pas l'enthousiasme produit. P1 = risque de correction (données/comportement), P2 = gap concret ou nettoyage rapide, P3 = différé délibérément (aucun bug connu) ou pure polish. Les idées produit non scopées vivent dans la section « Idées produit » plus bas, pas ici.

### [P1] US-3 — Rituel check-in/check-out avec rappels
Réf. `docs/USER_STORIES.md` US-3 (scopée 2026-09-20). **Débloque US-1 sprint C** (critère 7) —
livrer le critère 4 ci-dessous en dernier, avec son test, avant d'ouvrir ce sprint C.

**Périmètre exact** (6 critères d'acceptation, indépendants entre eux sauf le 4 qui doit être
livré en dernier) :

1. **Portion à l'ajout manuel d'une sourate au check-in** : `_CheckInScreenState` ouvre
   `VerseRangePicker` avant d'ajouter la sourate, même pattern que
   `CheckOutScreen._addRevisedSourate` — pas de sourate entière imposée. Réutilisation pure,
   aucune logique nouvelle.
2. **Progression visible en temps réel** : déjà couvert par `reach` + `PlanScreen` — vérifier
   seulement qu'aucune régression n'existe, rien à construire.
3. **Unification du geste « décocher »** : retirer `needs_work` de tout le code applicatif
   (`AyahFactsRitual.setNeedsWork`, toggle de `VerseBottomSheet`, écrans check-out) — un seul état
   par verset/jour, `reach`. Colonne `ayah_facts.needs_work` conservée en base (pas de migration
   sans utilisateurs réels) mais orpheline. Vérifier d'abord `AyahFactsRitual.lastRevisionFlags()`
   (consommée par le Récap) : la reporter sur `reach` si elle dépend encore de `needs_work`.
4. **Verset décoché + verset de contexte** (le plus risqué, à livrer en dernier) : règle ajoutée à
   `RevisionEngine.buildDayUnits()` (Dart pur, aucune nouvelle requête SQL) — un verset `reach=0`
   qui réapparaît est joint au verset `n-1` de la même sourate s'il appartient à la sélection,
   jamais seul, jamais hors plage (invariant E.3 de `CLAUDE.md`). Test de régression obligatoire
   dans `test/core/revision_engine_test.dart` (invariants A-F à préserver).
5. **Signal de jour non clôturé** : bannière d'accueil/`day_plan_tab.dart` appuyée sur
   `AyahFactsRitual.pendingDate()` (déjà utilisée par `ensureDayPlan`) — mécanique existante,
   ajout purement UI.
6. **Notification minuit** : troisième entrée dans `NotificationService` (matin/soir déjà livrés
   au sprint B d'US-1, heures configurables via `StorageService`), heure fixe non configurable,
   jamais de scellement automatique — simple rappel. Nouvelles clés `lib/core/strings.dart` FR/EN.

**Exclusions explicites** : pas de réglage d'heure pour la notification minuit ; pas de
scellement automatique à minuit ; pas d'extension du choix de portion aux unités déjà proposées
par le plan du jour (restent « tout ou rien ») ; le verset de contexte est un affichage d'aide,
jamais marqué fait du seul fait d'être montré.

**Ordre suggéré** : 6 (notifs, indépendant) → 1 (portion check-in) → 3 (retrait `needs_work`) →
5 (bannière) → 4 (contexte, dernier — condition de sprint C d'US-1).

`/code-review high` si la PR touche `RevisionEngine` (critère 4) — voir `CLAUDE.md` § Fin de
sprint.

### [P1] US-1 sprint C — La preuve du lendemain (crit. 7) — BLOQUÉ PAR US-3
Réf. `docs/USER_STORIES.md` US-1, critère 7. **Dépendance dure : US-3 critère 4** (« un verset
décoché réapparaît accompagné du verset qui le précède »), désormais scopée ci-dessus mais pas
encore implémentée.
Aujourd'hui, décocher une unité au check-out laisse `reach=0`, `AppState._completedPagesFor`
s'arrête sur ce groupe et le lendemain repropose **la page entière** — pas les versets seuls, et
sans verset de contexte. Le flag `needs_work` (colonne `ayah_facts.needs_work`,
`AyahFactsRitual.setNeedsWork`, toggle de `VerseBottomSheet`) est un marque-page d'affichage et ne
change rien à ce qui est proposé ; US-3 le supprime.
→ Livré avant US-3, le message affirmerait un comportement que le moteur n'a pas, **au moment
précis censé prouver la méthode**. Ne pas implémenter avant.

**Périmètre (après US-3)** : sur le plan du lendemain, signaler **une fois** que les versets
décochés sont revenus seuls avec celui qui les précède, et que le cycle a avancé sans rien noter.
Id `return_proof_seen`, armé par `guideDone('checkout_done')`, écrit au tap d'acquittement — jamais
à l'affichage. Réutilise intégralement le mécanisme du sprint B.

**Ordre global des sprints** : US-1 A → US-1 B → US-3 → US-1 C.

### [P2] Découper `lib/core/strings.dart`
**489 lignes aujourd'hui** (415 avant US-1 sprint A, ~450 après le sprint A, +39 au sprint B pour
les chaînes du guide et des heures de rappel) — au-delà du plafond de 300-350 de `CLAUDE.md`,
maintenant aussi au-delà des 400 lignes qui imposent une extraction dédiée. Une
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

- **SRS réel par verset** (score de difficulté depuis l'historique `ayah_facts`, aujourd'hui écrasé par `lastRevisionDatesPerVerse` qui ne garde que `MAX(date)`) — dépendrait de `needsWork`, pas des paliers de fraîcheur temporelle ; dépendance à reconfirmer avant de scoper.
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
