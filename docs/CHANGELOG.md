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

**Infra / divers**
- `sqflite_common_ffi` est en dépendance de **prod**, pas dev-only : `main.dart` bascule dessus derrière `if (Platform.isWindows)`, une condition runtime que Dart ne tree-shake pas — léger surcoût de taille binaire mobile assumé pour pouvoir tester sur cette machine sans device.
- Fraîcheur par verset (2026-09-04) : seuils changés délibérément (30j remplace l'ancien badge 7j ; paliers `neverRevised`/`sixMonths`/`oneYear` remplacent le seuil unique 180j). Pas tranché à l'identique partout — à ajuster sur retour utilisateur, pas à traiter comme un bug.
- Tests `sqflite_common_ffi` : une seule `history.db` partagée par tous les tests d'un même fichier (`initFfiTestDb` isole les fichiers entre eux, pas les tests entre eux) — un test peut hériter d'un `checked_out` posé par le précédent. `clearFactsBetweenTests()` doit tourner en `setUp`, sans fermer la connexion (`openDatabase` renvoie l'instance en cache).

---

## Backlog technique

Dette réelle et gaps prêts à l'implémentation — priorité qui reflète le risque/l'effort, pas l'enthousiasme produit. P1 = risque de correction (données/comportement), P2 = gap concret ou nettoyage rapide, P3 = différé délibérément (aucun bug connu) ou pure polish. Les idées produit non scopées vivent dans la section « Idées produit » plus bas, pas ici.

| Priorité | Feature | Notes |
|----------|---------|-------|
| P1 | **Config modifiable pendant un jour en attente de check-out** | Vérifié dans le code 2026-09-13 : `AppState.saveConfig` ne consulte `pendingDate` nulle part — rien n'empêche d'éditer la **sélection** de sourates tant qu'un jour antérieur reste non scellé, alors que `checkOut` recalculerait sur une config différente de celle qui a généré le plan en attente. **Partiellement traité** : `setPagesPerDay` ne régénère plus la proposition d'une journée déjà clôturée (ça, c'est réglé). Le cas général (sélection) reste ouvert. Seul item du backlog qui est un vrai risque de correction, pas un choix de design. |
| P2 | **`lib/core/revision_engine.dart` dépasse 400 lignes (428)** | Touché par le sprint du 2026-09-13 (traduction FR→EN) sans être inclus dans l'audit "fichiers > 400 lignes" de ce même sprint — oubli de périmètre, pas un désaccord sur la règle. Fichier le plus dense en règles métier de l'app (`test/CLAUDE.md` : quasi aucun filet de test) — tout découpage doit être accompagné de tests de régression écrits AVANT, pas seulement d'un déplacement de code. Monté en P2 (pas P3) parce que c'est le fichier où une régression silencieuse coûterait le plus cher. |
| P2 | **Reste de la dette technique §8.5 de `docs/DOCUMENTATION_TECHNIQUE.md`** | Composants dupliqués (hadith/streak réimplémentés dans `learn_surah_screen.dart` au lieu de `HadithCard`/`StreakCard`, filtre de recherche sourate dupliqué entre `OnboardingScreen` et `SouratePickerSheet`), `'✓ Complet'` hors `S.` et couleurs en dur dans `learning_progress_card.dart`, `HistoryCard` qui reçoit 14 sessions et n'en affiche que 7. Mécanique et à faible risque — bon candidat de sprint rapide. |
| P2 | **Récap : permettre de flaguer un verset "à retravailler" directement depuis le Récap** | `AppState.setVerseNeedsWork` n'est appelable que depuis `CheckOutDetailScreen` — pas de main sur ce flag depuis `RecapScreen`/`VerseBottomSheet`, l'endroit naturel où l'utilisateur relit une sourate hors rituel quotidien. |
| P3 | **Sections de `check_in_screen.dart`/`check_out_screen.dart` : `extension`+`part of` plutôt que de vrais widgets** | Relevé en `/code-review high` du 2026-09-13 (angle "altitude") : les sections lisent/écrivent directement les champs privés du `State` via une `extension`, plutôt que d'être de vrais widgets avec constructeur `(value, onChanged)` comme `CheckInDetailScreen`/`CheckOutDetailScreen`/`CheckOutRow` extraits dans le même sprint — l'`extension` ne compile qu'au prix du forwarder `_setState`. **Délibérément pas corrigé** : transformer chaque section en vrai widget demanderait de faire descendre ~5-10 callbacks/valeurs par section — un vrai changement de frontière d'état, pas une décomposition de fichier. À rouvrir si ces écrans grossissent encore ou si une section doit devenir testable indépendamment. |
| P3 | **`RevisionUnit`/`SourateSelection` : deux notions d'identité distinctes** | `RevisionUnit.==` (égalité de valeur `sourate.id`+`verseStart`+`verseEnd`) coexiste avec un dédoublonnage par `label` dans `plan_screen.dart`, et une clé composite `String` manuelle dans `AppState._sameSelections`. Aucune divergence de comportement connue à ce jour ; à réconcilier (probablement vers `==`/`hashCode` sur les deux modèles) si l'un de ces fichiers est retouché. |
| P3 | **`RakaaAssignment.isLearning` : booléen propagé sur 4 couches là où le concept est `AyahFactType`** | Se retraduit en `learning:`/`type:` sur plusieurs méthodes, oblige `PlanScreen` à tenir `_learningReached` à part de `_reached`. Porter `AyahFactType type` sur `RakaaAssignment` supprimerait les deux couches — mais fusionner les Maps sans ce changement créerait un aliasing silencieux (`RevisionUnit.==` ignore le type). **Délibérément pas corrigé** : à trancher si une 3ᵉ nature de rakaa apparaît, pas avant — le faire maintenant serait une abstraction sans cas d'usage réel. |
| P3 | **`learnPlanFor` et `dayFacts` reconstruisent chacun « le plan du jour »** | `dayFacts` (figé `type='revise'`) rend des plages contiguës (`MIN`/`MAX(ayah_id)`) ; `learnPlanFor` rend la liste exacte des versets. **Délibérément pas fusionné** : le grain diffère réellement (la portion à apprendre peut avoir des trous) — ne pas fusionner sans porter la liste exacte sur `DayFactGroup`. |
| P3 | **Cycle wrap affiché** | Afficher « (cycle bouclé) » quand le cycle vient de reboucler. Formule d'origine obsolète depuis la suppression de `DailySession.totalUnits` (Phase 9 Sprint 2) — à redéfinir avec l'unité actuelle de `cyclePosition`. |
| P3 | **Animation badge de fraîcheur à la validation** | `FreshnessBadge` ne s'anime pas (scale/color) quand la sourate vient d'être validée dans `PlanScreen`. |
| P3 | **Rail de navigation alphabétique sur la liste des sourates (onboarding)** | En complément des en-têtes Hizb épinglés déjà en place, un rail type Contacts iOS pour sauter directement à une section. |
| P3 | **Support `sqflite` sur Flutter Web** | `AyahFactsService` plante sur web faute de `sqflite_common_ffi_web`. Délibérément déprioritisé : le web n'est qu'une cible de prévisualisation, pas une cible livrée. |
| P3 | **Unifier la vue "sourates" entre check-in et récap** | `CheckInScreen` (liste éditable du jour) et `SouratesRecapCard` (toute la sélection, lecture seule) montrent chacun une liste de sourates avec données/permissions différentes — **décision produit requise** (laquelle des deux fonctions doit dominer) avant de pouvoir scoper un fix. |
| P3 | **Retour "Récap incomplet" (vague)** | Retour TestFlight non actionnable tel quel — recoupe probablement l'item ci-dessus ; à réévaluer une fois celui-ci tranché. |
| P3 | **« Fait en plus » : pas de sourate d'apprentissage hors plan du jour** | Le geste "fait plus" couvre une sourate/portion de révision et un verset de plus sur la sourate déjà en apprentissage. Déclarer des versets appris sur une **autre** sourate que celle du jour reste possible via Récap → écran de pratique, mais non rattaché au check-out. À ouvrir seulement si l'usage réel le réclame. |
| P3 | ~~**Deux bottom sheets de choix de sourate dans le même check-in**~~ | **Écarté le 2026-09-08** — le widget décrit (`_AddSourateSheet`) n'existe plus sur le code actuel. Conservé avec sa raison plutôt que supprimé (règle : un besoin écarté reste dans le Backlog, contrairement à un besoin traité). À rouvrir seulement si deux styles de sélecteur réapparaissent. |

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
