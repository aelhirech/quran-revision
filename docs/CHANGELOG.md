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
- Cycle adaptatif, compteurs de cycle en "unités" (remplacés par des pages réelles), déclaration "Tout fait/Une part/Rien fait" + écran de fin de manche + saisie manuelle libre : **retirés délibérément** (Phase 9 Sprint 2, 2026-09-08) sur décision utilisateur. Ne pas réintroduire sans besoin confirmé.

**Infra / divers**
- `sqflite_common_ffi` est en dépendance de **prod**, pas dev-only : `main.dart` bascule dessus derrière `if (Platform.isWindows)`, une condition runtime que Dart ne tree-shake pas — léger surcoût de taille binaire mobile assumé pour pouvoir tester sur cette machine sans device.
- Fraîcheur par verset (2026-09-04) : seuils changés délibérément (30j remplace l'ancien badge 7j ; paliers `neverRevised`/`sixMonths`/`oneYear` remplacent le seuil unique 180j). Pas tranché à l'identique partout — à ajuster sur retour utilisateur, pas à traiter comme un bug.
- Tests `sqflite_common_ffi` : une seule `history.db` partagée par tous les tests d'un même fichier (`initFfiTestDb` isole les fichiers entre eux, pas les tests entre eux) — un test peut hériter d'un `checked_out` posé par le précédent. `clearFactsBetweenTests()` doit tourner en `setUp`, sans fermer la connexion (`openDatabase` renvoie l'instance en cache).

---

## Backlog

**Axe "data model"** — les items P1/P2 en tête de table découlent de la correction du bug "sourate qui disparaît" (2026-09-01) : `ayah_facts` (journal daté, granularité verset) peut alimenter bien plus qu'aujourd'hui — voir `CLAUDE.md` § « Modèle de données central ». Trancher lesquels entrent dans le prochain sprint avant de les lancer à la volée.

| Priorité | Feature | Notes |
|----------|---------|-------|
| P3 | **`RevisionUnit`/`SourateSelection` : deux notions d'identité distinctes** | `RevisionUnit.==` (égalité de valeur `sourate.id`+`verseStart`+`verseEnd`) coexiste avec un dédoublonnage par `label` dans `plan_screen.dart`, et une clé composite `String` manuelle dans `AppState._sameSelections`. Aucune divergence de comportement connue à ce jour ; à réconcilier (probablement vers `==`/`hashCode` sur les deux modèles) si l'un de ces fichiers est retouché. |
| P2 | **Commentaires du sprint Phase 9 Sprint 2 non conformes à la règle `CLAUDE.md`** | La règle « commentaires en anglais, uniquement pour le WHY, pas de docstring multi-lignes hors API publique » a été ajoutée en cours d'écriture de ce sprint (2026-09-07) — non appliquée sur son diff. ~286 lignes de commentaires FR ajoutées, concentrées dans `app_state*.dart` (découpé depuis en extensions), `revision_engine.dart`, `plan_screen.dart`, `spotlight_tour.dart`. Beaucoup portent de vraies décisions de cadrage à garder — mais à traduire et resserrer sur le WHY. |
| P3 | **Quatre fichiers de `lib/` dépassent le plafond de 400 lignes** | Reconfirmé le 2026-09-13 : `services/ayah_facts_service.dart` (691, priorité — seul des quatre grossi par la Phase 9, porte le modèle de données central, ses commentaires de section donnent déjà la coupure en `part`/`part of`), `screens/check_out_screen.dart` (672-696 selon relevé), `screens/check_in_screen.dart` (495-576, devenu un wizard à 3 étapes en Phase 11 Sprint 3 sans réduire sa taille), `core/strings.dart` (401). Check-in/check-out sont des écrans à sections simultanées (pas un wizard séquentiel comme l'onboarding) — les splitter par section, sans chercher à calquer le pattern "étapes onboarding". |
| P2 | **SRS réel par verset (score de difficulté depuis l'historique `ayah_facts`)** | `ayah_facts` garde plusieurs lignes datées par verset, aujourd'hui écrasées par `lastRevisionDatesPerVerse` qui ne garde que `MAX(date)`. Un score simple (proportion de fois où `needsWork` a été posé / nombre de révisions) prioriserait le plan du jour vers les versets fragiles, sans nouvelle table. **Dépendance à reconfirmer** avant de lancer : ce score se base sur `needsWork`, pas directement sur les paliers de fraîcheur temporelle — les deux partagent le même grain verset mais la dépendance n'est peut-être pas stricte. |
| P2 | **Coran en SQLite (texte + word-by-word + tajweed)** | Débloquerait d'un coup "Jeu mot arabe → traduction" et "Affichage tajweed coloré" (tous deux bloqués faute de données QUL word-by-word/tajwid), et permettrait un JOIN naturel `ayah_facts` ↔ texte du verset. **Garde-fou** : ne pas migrer "parce que c'est plus propre" — ne se justifie que si une des deux features est réellement engagée. |
| P3 | **Timeline d'activité (heatmap) dans Profil/Récap** | chaque fait `ayah_facts` est déjà daté — calendrier d'activité type GitHub, gratuit en donnée, juste une requête + un widget. Complète le streak actuel par une vue de régularité. |
| P3 | **Gamification narrative [H]** | vision long terme — direction artistique déjà validée (Mus'haf/Tahajjud), reste à définir la mécanique narrative. |
| P3 | **Cycle wrap affiché** | afficher « (cycle bouclé) » quand le cycle vient de reboucler. Formule d'origine obsolète depuis la suppression de `DailySession.totalUnits` (Phase 9 Sprint 2) — à redéfinir avec l'unité actuelle de `cyclePosition`. |
| P2 | **Mode "versets à retravailler" en jeu à part** | écran dédié pour retravailler les versets `needsWork` et/ou peu récents, en mode ludique — définir la mécanique de jeu avant d'implémenter. |
| P3 | **Jeu mot arabe → traduction (Apprendre)** | mini-jeu de traduction mot par mot — nécessite les données word-by-word (QUL), voir "Coran en SQLite" ci-dessus. |
| P3 | **Affichage tajweed coloré** | coloration par règle de tajwid (QUL) — passer par `AppPalette`/tokens sémantiques, pas de couleurs en dur. Voir "Coran en SQLite" ci-dessus. |
| P3 | **Animation badge de fraîcheur à la validation** | `FreshnessBadge` ne s'anime pas (scale/color) quand la sourate vient d'être validée dans `PlanScreen`. |
| P3 | **Support `sqflite` sur Flutter Web** | `AyahFactsService` plante sur web faute de `sqflite_common_ffi_web`. Le web n'est qu'une cible de prévisualisation, pas une cible livrée. |
| P3 | **Config modifiable pendant un jour en attente de check-out** | rien n'empêche d'éditer sourates/rythme tant qu'un jour reste non scellé — `AppState.checkOut` recalculerait alors sur une config différente de celle utilisée à la génération du plan en attente. **Partiellement traité** : `setPagesPerDay` ne régénère plus la proposition d'une journée déjà clôturée. Le cas général (éditer la **sélection** pendant qu'un jour antérieur est en attente) reste ouvert — `saveConfig` ne consulte toujours pas `pendingDate`. |
| P3 | **Rail de navigation alphabétique sur la liste des sourates (onboarding)** | en complément des en-têtes Hizb épinglés déjà en place, un rail type Contacts iOS pour sauter directement à une section. |
| P3 | **Reste de la dette technique §8.5 de `docs/DOCUMENTATION_TECHNIQUE.md`** | composants dupliqués (hadith/streak réimplémentés dans `learn_surah_screen.dart` au lieu de `HadithCard`/`StreakCard`, filtre de recherche sourate dupliqué entre `OnboardingScreen` et `SouratePickerSheet`), `'✓ Complet'` hors `S.` et couleurs en dur dans `learning_progress_card.dart`, `HistoryCard` qui reçoit 14 sessions et n'en affiche que 7. |
| P2 | **Récap : permettre de flaguer un verset "à retravailler" directement depuis le Récap** | `AppState.setVerseNeedsWork` n'est appelable que depuis `_CheckOutDetailScreen` — pas de main sur ce flag depuis `RecapScreen`/`VerseBottomSheet`, l'endroit naturel où l'utilisateur relit une sourate hors rituel quotidien. |
| P3 | **Unifier la vue "sourates" entre check-in et récap** | `CheckInScreen` (liste éditable du jour) et `SouratesRecapCard` (toute la sélection, lecture seule) montrent chacun une liste de sourates avec données/permissions différentes — trancher laquelle des deux fonctions doit dominer avant de fusionner l'affichage. |
| P3 | **Retour "Récap incomplet" (vague)** | retour TestFlight non actionnable tel quel — recoupe probablement les deux items ci-dessus ; à réévaluer une fois faits. |
| P3 | **« Fait en plus » : pas de sourate d'apprentissage hors plan du jour** | le geste "fait plus" couvre une sourate/portion de révision et un verset de plus sur la sourate déjà en apprentissage. Déclarer des versets appris sur une **autre** sourate que celle du jour reste possible via Récap → écran de pratique, mais non rattaché au check-out. À ouvrir seulement si l'usage réel le réclame. |
| P3 | ~~**Deux bottom sheets de choix de sourate dans le même check-in**~~ | **Écarté le 2026-09-08** — le widget décrit (`_AddSourateSheet`) n'existe plus sur le code actuel. Conservé avec sa raison plutôt que supprimé (règle : un besoin écarté reste dans le Backlog). À rouvrir seulement si deux styles de sélecteur réapparaissent. |
| P3 | **`RakaaAssignment.isLearning` : booléen propagé sur 4 couches là où le concept est `AyahFactType`** | se retraduit en `learning:`/`type:` sur plusieurs méthodes, oblige `PlanScreen` à tenir `_learningReached` à part de `_reached`. Porter `AyahFactType type` sur `RakaaAssignment` et clé `_reached` par `(type, unit)` supprimerait les deux couches — mais fusionner les Maps sans ce changement créerait un aliasing silencieux (`RevisionUnit.==` ignore le type). À trancher si une 3ᵉ nature de rakaa apparaît, pas avant. |
| P3 | **`learnPlanFor` et `dayFacts` reconstruisent chacun « le plan du jour »** | `dayFacts` (figé `type='revise'`) rend des plages contiguës (`MIN`/`MAX(ayah_id)`) ; `learnPlanFor` rend la liste exacte des versets. Les paramétrer par `type` en une seule requête serait plus propre, **mais le grain diffère réellement** (la portion à apprendre peut avoir des trous) — ne pas fusionner sans porter la liste exacte sur `DayFactGroup`. |

---

## Convention de commit

```
feat(sprint-N): description
fix(sprint-N): corrections lié au commentaires utilisateurs
```
