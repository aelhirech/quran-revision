# Documentation technique — Quran Revision App

> Référence de maintenance pour l'équipe de développement. Ce document explique **comment le code est construit et pourquoi**, pas seulement ce qu'il fait. Il complète `CHANGELOG.md` (historique des sprints, backlog) sans le remplacer : CHANGELOG.md dit *quoi a été livré et quand*, ce document dit *comment ça marche et comment y toucher sans casser les règles métier*.
>
> **Pour Claude Code** : lire ce document en entier avant de modifier `lib/core/revision_engine.dart`, `lib/core/freshness_engine.dart`, `lib/state/app_state.dart`, ou tout écran — il évite de devoir relire tout le code source à chaque session. S'il y a divergence entre ce document et le code réel, faire confiance au code et corriger ce document (voir §12 "Maintenir ce document").

---

## 1. Vue d'ensemble

Quran Revision est une application mobile (iOS/Android, + web pour prévisualisation) qui aide un utilisateur à réviser des sourates du Coran déjà mémorisées, en les répartissant automatiquement dans les rakaas de ses prières quotidiennes (celles qu'il effectue seul, hors mosquée en congrégation). Elle propose aussi un mode « Apprendre » pour mémoriser de nouvelles sourates verset par verset.

Concepts métier centraux (à comprendre avant de lire le code) :

- **Unité de révision** (`RevisionUnit`) : une sourate entière ou une portion de sourate, assignée à une rakaa. C'est le grain atomique que `RevisionEngine` distribue.
- **Cycle** : l'ensemble des unités issues de la sélection de l'utilisateur (`UserConfig.selections`) forme un cycle. `cyclePosition` avance à chaque session ; quand il boucle, l'utilisateur a tout révisé une fois.
- **Rythme** : deux modes exclusifs pour décider combien d'unités réviser aujourd'hui — *par durée* (`revisionDays` restants) ou *par lignes/jour* (`targetLinesPerDay`, mode `paceByLines`).
- **Fraîcheur** (SRS léger) : indépendant du cycle, `FreshnessEngine` calcule depuis quand chaque sourate n'a pas été révisée (hot/cold/frozen) à partir de l'historique réel (`AyahFactsService`, table `ayah_facts` — remplace l'ancien `HistoryService` depuis la Phase 6), pour afficher un badge d'alerte — pas pour piloter la distribution du plan.
- **Riwaya** : Hafs (par défaut) ou Warsh — change uniquement le texte arabe affiché, jamais la numérotation des versets ni la logique de distribution.

---

## 2. Stack & environnement

- **Flutter** (SDK Dart `^3.12.2`), Material 3, **Provider** (`ChangeNotifier`) comme unique gestion d'état — voir `[[pas-de-sur-ingenierie]]` dans CLAUDE.md, ne pas introduire Riverpod/Bloc/GetX.
- Pas de backend : toute la persistance est locale (`shared_preferences` + `sqflite`).
- Dépendances clés (`pubspec.yaml`) : `provider`, `shared_preferences`, `sqflite`, `flutter_local_notifications`, `flutter_animate`, `google_fonts` (Lora/Amiri), `path`. Le texte coranique (Hafs + Warsh) n'est plus un package pub.dev depuis le Sprint 8 (retrait de `quran: ^1.4.1`) — assets bundlés `assets/quran/hafs.json`/`warsh.json`, voir §6.
- Build/déploiement : CI/CD Codemagic connectée au dépôt (`codemagic.yaml`, workflow `ios-testflight`) — un `git push` sur `main` déclenche automatiquement build + signing + publication TestFlight. Pas de pipeline Android à ce jour.
- Dépôt GitHub : `aelhirech/quran-revision`.

---

## 3. Architecture des couches

```
lib/
├── core/      — logique pure : moteurs métier, données statiques, thème, strings. Zéro import Flutter (sauf app_colors.dart/app_theme.dart qui sont le thème visuel), zéro I/O.
├── models/    — data classes immuables, toJson/fromJson, copyWith.
├── services/  — I/O stateless (SharedPreferences, SQLite, notifications, assets). Jamais de notifyListeners.
├── state/     — AppState : seul ChangeNotifier de l'app, orchestrateur entre UI et services/engines.
├── screens/   — pages pleine page (routées depuis ShellScreen ou en modal).
└── widgets/   — composants réutilisables, essentiellement présentation.
```

### Règle de dépendance (sens unique, ne jamais inverser)

```
screens/widgets → state/AppState → services/ → (SharedPreferences, sqflite, plugins)
screens/widgets → core/ (engines, strings, thème, quran_data)          — lecture directe OK, ce sont des fonctions pures
core/ ─────────────────────────────────────────────────────────────── → ne dépend de rien d'autre dans lib/
```

- `core/` ne doit **jamais** importer `package:flutter/material.dart` pour sa logique (exception assumée : `app_colors.dart`/`app_theme.dart` sont explicitement le thème visuel, pas de la logique métier).
- Les écrans ne doivent **jamais** appeler `package:quran` directement — toujours passer par `VerseService` (`lib/services/verse_service.dart`), qui arbitre Hafs/Warsh. C'est une règle qui a été explicitement corrigée dans le sprint « Riwaya Warsh/Hafs » (voir CHANGELOG.md) : avant, certains écrans appelaient `package:quran` en dur.
- Un seul `notifyListeners()` par opération logique dans `AppState` (règle CLAUDE.md).

---

## 4. Modèles (`lib/models/`)

Tous les modèles sont immuables, avec `toJson()`/`fromJson()` pour la persistance JSON (SharedPreferences) et mise à jour uniquement via `copyWith()` (sauf modèles très simples sans besoin de copie partielle).

| Modèle | Fichier | Rôle | Champs clés |
|---|---|---|---|
| `Sourate` | `sourate.dart` | Métadonnées statiques d'une sourate | `id`, `nameAr`, `nameFr`, `verses`, `words` |
| `SourateSelection` | `sourate_selection.dart` | Portion d'une sourate choisie par l'utilisateur pour la révision (source de `UserConfig.selections`) | `sourate`, `verseStart`, `verseEnd` ; `isWhole`, `estimatedWords` |
| `RevisionUnit` | `revision_unit.dart` | Grain atomique distribué dans les rakaas — dérivé des `SourateSelection` par `RevisionEngine.buildUnits` | `sourate`, `verseStart`, `verseEnd`, `isWhole` ; `verseCount`, `estimatedLines` (mots/8.5), `label` |
| `Prayer` (enum) | `prayer.dart` | Les 12 prières/sunnas sélectionnables (5 fard + 6 sunna/witr + tahiyyat al-masjid) | `rakaas` (total), `suratRakaas` (combien récitent une sourate après Al-Fatiha), `isFard`, `isTahiyyat` |
| `DailySession` | `daily_session.dart` | Le plan du jour calculé par `RevisionEngine.buildDayPlan` — utilisé à la fois pour la preview et pour la session engagée | `plan: List<PrayerPlan>`, `totalUnits`, `cyclePosition`, `cycleTotal`, `daysRemaining` ; `totalRakaas`, `cycleProgress`, `isOnTrack` |
| `PrayerPlan` | `daily_session.dart` | Une prière du plan avec ses rakaas assignées | `prayer`, `rakaas: List<RakaaAssignment>` |
| `RakaaAssignment` | `daily_session.dart` | Une rakaa avec son unité (ou `null` = Al-Fatiha seule, rakaa silencieuse) | `rakaaNumber`, `unit` |
| `UserConfig` | `user_config.dart` | Configuration persistée de l'utilisateur — la source de vérité pour tout calcul de plan | voir §5.4 |
| `LearningProgress` | `learning_progress.dart` | Progression de mémorisation d'une sourate, verset par verset | `sourate`, `learnedVerses: Set<int>`, `startDate` ; `progress`, `isComplete`, `nextVerse` |
| `SessionRecord` | `session_record.dart` | Une entrée d'historique de session (table SQLite `sessions`) | `date`, `unitsCompleted`, `totalUnits`, `prayers` |
| `StudentProfile` | `student_profile.dart` | Un profil élève (multi-élèves, ex. un parent qui suit plusieurs enfants) | `id`, `name` |
| `Riwaya` (enum) | `riwaya.dart` | `hafs` \| `warsh` — n'affecte que le texte arabe affiché, jamais la numérotation | — |

**Piège connu** : `Sourate.fromJson` a un fallback `j['words'] ?? j['verses'] * 12` (ligne 29) pour la rétro-compatibilité avec d'anciennes données persistées sans champ `words`. Si vous ajoutez un champ à `Sourate`, prévoyez le même genre de fallback pour ne pas planter au chargement d'une config existante sur l'appareil d'un utilisateur.

---

## 5. Moteurs métier (`lib/core/`)

C'est le cœur de l'application et la zone la plus sensible : `test/CLAUDE.md` le confirme, ces fichiers portent des règles métier accumulées sur plusieurs sprints **sans filet de sécurité réel** (une seule suite de tests existe, sur `RevisionEngine`, voir §9). Toute modification ici doit être accompagnée d'un test de régression.

### 5.1 `RevisionEngine` (`lib/core/revision_engine.dart`)

Depuis Phase 6 Sprint 2, éclaté en deux fonctions pures indépendantes plutôt qu'un seul `buildDayPlan()` monolithique — nécessaire pour que le moteur quotidien (§7) puisse choisir les unités du jour sans les répartir en rakaas (ça n'a lieu que côté PlanScreen, une fois les prières choisies), et pour que PlanScreen puisse répartir des unités **déjà validées au check-in** plutôt que d'en calculer de nouvelles.

**`selectDayUnits()`** (étapes 1-2 de l'ancien algorithme) — quelles unités composent le plan du jour :
1. **`buildUnits()`** : transforme `List<SourateSelection>` en `List<RevisionUnit>`. Une sélection dont l'estimation de mots (`estimatedWords`) dépasse `_wordLimit = 150` (≈1 page Mushaf Madinah) est découpée en plusieurs unités de taille égale (`chunks = ceil(rangeWords / 150)`). En dessous du seuil, la sélection reste une unité entière.
2. **Sélection des unités du jour** : deux modes exclusifs pilotés par `UserConfig.paceByLines` — *par durée* (`dailyTarget()`, `ceil(unitsLeft / daysRemaining)`) ou *par lignes/jour* (`_unitsForLines()`, accumule `estimatedLines` depuis `cyclePosition` jusqu'à dépasser `config.targetLinesPerDay`). Plafonné à `cycleTotal`.

Retourne un `DaySelection` (`{units, cyclePosition, cycleTotal, daysRemaining}`) — `cyclePosition`/`cycleTotal`/`daysRemaining` y voyagent ensemble avec `units` pour que les appelants n'aient jamais à les recalculer séparément.

**`distributeToRakaas()`** (étapes 3-4 de l'ancien algorithme) — répartit des unités déjà choisies (par `selectDayUnits()`, ou lues depuis `ayah_facts` après édition au check-in) dans les rakaas des prières données :
3. **`_expandToRakaas()`** : subdivise pour remplir exactement `totalSuratRakaas`. Une unité n'est subdivisée que si `slots > 1 ET verseCount > 1 ET estimatedLines / slots >= _minLinesPerSlot (5.0)` — jamais en dessous de 5 lignes Mushaf. Si après expansion il reste moins d'unités que de rakaas à remplir, **répétition cyclique** — jamais de rakaa vide pour cette raison (règle actée Sprint 5).
4. **Assignation par prière avec règle no-repeat** (Sprint 6, `[S6-B]`) : pour chaque prière, pour chaque rakaa à voix haute, cherche la prochaine unité non consommée aujourd'hui et pas déjà utilisée dans **cette même prière exacte** (clé `_unitKey = sourateId_verseStart_verseEnd`) ; à défaut, réutilise une unité assignée ailleurs ; en dernier recours, répète — c'est la seule situation admise pour ne pas laisser de rakaa vide. Les rakaas silencieuses (au-delà de `suratRakaas`) reçoivent `RakaaAssignment(rakaaNumber: r)` sans unité.

**`buildDayPlan()`** : composition pure de `selectDayUnits()` + `distributeToRakaas()`, conservée pour sa couverture de test (`test/core/revision_engine_test.dart`) mais **plus appelée par aucun appelant applicatif** depuis Sprint 2 — `AppState` appelle les deux étapes séparément (`ensureDayPlan`/`buildTodaySession`, voir §7).

**`advanceCycle()`** : fonction pure `(currentPosition + unitsCompleted) % cycleTotal` — source unique de vérité pour faire progresser `AppState._cyclePosition`. Depuis Sprint 2, n'est appelée que par `AppState.checkOut()` (une fois par journée scellée), plus à chaque manche PlanScreen complétée.

**Ordre aléatoire** : si `config.shuffleEnabled` (activé par défaut), les unités sont mélangées avec `Random(config.startDate.millisecondsSinceEpoch)` — déterministe par date de démarrage. **Piège Sprint 2** : ce shuffle peut séparer deux morceaux non-adjacents d'une même sourate découpée (>150 mots) sur deux jours différents ; `AyahFactsService.dayFacts` reconstruit la plage d'une sourate par `MIN`/`MAX(ayah_id)` en base, donc un jour peut alors afficher une plage plus large que ce qui a réellement été proposé ce jour-là (cas rare, backlog CHANGELOG).

### 5.2 `FreshnessEngine` (`lib/core/freshness_engine.dart`)

Module pur et minimal — SRS léger indépendant de `RevisionEngine`. `compute(lastRevised, today)` :
- `null` → `frozen` (jamais révisé)
- `< 7 jours` → `hot`
- `7–13 jours` → `cold`
- `>= 14 jours` → `frozen`

`today` est toujours injecté (jamais `DateTime.now()` en interne) pour rester testable — respecter ce pattern si vous étendez ce module.

**`computeAll<K>`** (Phase 6, généralisé) : générique sur le type de clé du `Map` passé en entrée — `K=int` pour une fraîcheur par sourate (tous les appelants actuels), n'importe quel autre type de clé (ex. un identifiant composite par verset) fonctionnerait à l'identique sans dupliquer la logique de seuils. Anticipe un besoin Sprint 2 (fraîcheur par verset dans la vue journée) ; aucun appelant n'exploite encore `K != int`. Couvert par `test/core/freshness_engine_test.dart` (zéro couverture avant Phase 6).

### 5.3 `StreakEngine` (`lib/core/streak_engine.dart`, Phase 6)

Module pur extrait de l'ancien `HistoryService.currentStreak` — calcule un streak (jours consécutifs d'activité) en remontant jour par jour depuis `today`, jours de pause sautés sans casser la série (cap 30 jours consécutifs sautés). `compute({activeDates, pauseDates, today})` : `activeDates`/`pauseDates` sont des `Set<String>` au format `YYYY-MM-DD`, fournis par l'appelant (`AyahFactsService.currentStreak` construit `activeDates` depuis `ayah_facts`).

**Comportement à connaître (préexistant, verrouillé par le test de régression, pas introduit en Phase 6)** : une activité hier sans rien aujourd'hui et sans pause déclarée aujourd'hui donne un streak à **0**, pas 1 — la boucle démarre à `today` et s'arrête immédiatement si ce jour précis n'est ni actif ni en pause, même si `canStart` (le garde d'entrée) a validé qu'une activité existait hier. Si ce comportement doit un jour être corrigé, ce sera un changement de comportement métier à traiter comme tel, pas un bugfix silencieux.

### 5.4 `UserConfig` en détail (`lib/models/user_config.dart`)

C'est l'objet de configuration central, il mérite d'être détaillé séparément des autres modèles car quasiment toute la logique de `RevisionEngine` en dépend :

| Champ | Rôle |
|---|---|
| `selections: List<SourateSelection>` | Ce que l'utilisateur a choisi de réviser |
| `revisionDays` | Durée cible du cycle (mode « par durée »), presets `durationPresets = [7,14,21,30,60,90,180,365]` + valeur libre |
| `startDate` | Date de démarrage du cycle actuel — sert aussi de graine au shuffle déterministe |
| `shuffleEnabled` | Ordre aléatoire (déterministe par date) des unités dans le cycle |
| `adaptiveCycle` | Si activé, `AppState.refreshAdaptiveCycle` recalcule une estimation de durée depuis `AyahFactsService.avgVersesPerDay()` (Phase 6 ; anciennement `HistoryService.avgUnitsPerDay()`), stockée dans `AppState._adaptiveCycleDays` |
| `paceByLines` / `targetLinesPerDay` | Mode alternatif au calcul par durée, presets `linesPerDayPresets = [5,10,15,20,30,40,60]` |
| `riwaya` (Sprint 8) | Auto-descriptif — le parcours (`StorageService`) sous lequel ce `UserConfig` est déjà stocké détermine en pratique la riwaya ; ce champ sert surtout de défaut `Riwaya.hafs` pour les anciens `UserConfig` persistés sans ce champ (installations pré-Sprint 8) |

`effectiveDays()` retourne toujours `revisionDays` telle quelle (commentaire explicite ligne 34 : *« Révision intelligente uniquement — le cycle est toujours basé sur revisionDays »*) — `adaptiveCycle` ne modifie jamais ce champ directement. **Piège corrigé au Sprint 2** : avant, `AppState.adaptiveCycleDays` n'était réinjecté dans le calcul du plan que par `HomeScreen._buildPlan` (`effectiveDaysOverride: state.adaptiveCycleDays`), un seul appelant parmi plusieurs — un bug de code-review Sprint 2 avait fait disparaître cette réinjection lors du passage à `AppState._selectionFor` (§7), qui centralise désormais tous les appels à `RevisionEngine.selectDayUnits` avec `effectiveDaysOverride: adaptiveCycleDays` systématiquement. Si vous ajoutez un nouvel appelant de `selectDayUnits`/`buildDayPlan`, passer par `AppState._selectionFor` plutôt que d'appeler `RevisionEngine` directement, pour ne pas réintroduire cet oubli.

---

## 6. Services (`lib/services/`)

Tous stateless, méthodes `static`, aucun `notifyListeners`. C'est la seule couche qui touche à l'I/O.

**Depuis le Sprint 8, Hafs et Warsh sont deux parcours indépendants** (profil principal uniquement — les profils élèves restent à parcours unique, voir §7) : `StorageService` et `AyahFactsService` prennent tous deux un paramètre `Riwaya` explicite et scopent leurs clés/lignes en conséquence. Rien n'est jamais traduit d'un parcours vers l'autre — voir le piège en fin de section.

| Service | Support | Rôle |
|---|---|---|
| `StorageService` | SharedPreferences | Persiste `UserConfig`, `cyclePosition`, `pauseDates`, `checkedRakaas`, `lastSessionPrayers`, `activePrayers` (Phase 6 Sprint 2, voir §7/§8.1) — ces 6 clés sont préfixées par riwaya (`_track(base, riwaya)`, factorisé dans `riwaya_key.dart`). `locale`, `notifEnabled`, `riwaya` (la riwaya *active*, pas les données d'un parcours), `tourSeen` restent des préférences globales non préfixées. **`previewSession`/`todaySession` supprimés au Sprint 2** — le plan du jour n'est plus un objet `DailySession` persisté en JSON, voir §7. `migrateLegacyTrackData()` — migration one-shot des installations pré-Sprint 8 : renomme les anciennes clés non préfixées vers le parcours Hafs (elles étaient déjà implicitement numérotées en Hafs). |
| `AyahFactsService` (Phase 6) | sqflite (`history.db`, v4) | **Remplace entièrement `HistoryService` et le rôle "profil principal" de `LearningService`** (tous deux supprimés Sprint 1 de la Phase 6). Une seule table `ayah_facts`, granularité verset — voir "Base de données SQLite" ci-dessous pour le schéma complet et les requêtes. Toutes les méthodes prennent `riwaya` en paramètre requis et filtrent dessus. Les élèves (`StudentService`) ne passent pas par ce service. **Sprint 2** ajoute le rituel check-in/check-out : `pendingDate` (jour non scellé le plus ancien, `date < aujourd'hui`), `proposeUnits` (écrit `reach=0, checked_out=0`), `setReach`/`setReachForUnits`/`setCold`, `isRangeReached`/`rangeExists`, `sealDay`, `dayFacts` (reconstruit le plan groupé par sourate). |
| `StudentService` | SharedPreferences | Progression de mémorisation multi-profils élèves : `student_profiles_v1` + une clé `learning_progress_{profileId}_v1` par élève — **volontairement non séparé par riwaya** (choix Sprint 8 : les profils élèves restent un seul parcours, quelle que soit la riwaya active ; limitation acceptée, pas un oubli) et **non migré vers `ayah_facts`** (choix Phase 6 : hors scope, voir CHANGELOG). Persiste des `LearningProgress` complets (le modèle garde son `toJson`/`fromJson` pour cet usage, même si le profil principal ne persiste plus l'objet directement). Supprimer un profil nettoie aussi sa progression associée. |
| `NotificationService` | `flutter_local_notifications` | Deux notifs quotidiennes récurrentes (`RepeatInterval.daily`) : rappel matin (id 1) et bilan soir (id 2), heures configurables. Toutes les erreurs sont catch+debugPrint, jamais propagées — une notif qui échoue à se programmer ne doit pas crasher l'app. |
| `VerseService` | `HafsService` + `WarshService` | **Point d'entrée unique** pour le texte arabe affiché, `verseCount`/`wordCount` riwaya-aware — arbitre Hafs/Warsh selon le `Riwaya` passé en paramètre. Ne jamais appeler `HafsService`/`WarshService` directement depuis un écran. Formate elle-même le chiffre arabe-indien de fin de verset (`verseEndSymbol`, défaut `true`) — plus de dépendance à `package:quran` (retiré Sprint 8). |
| `HafsService` / `WarshService` | assets `assets/quran/hafs.json` / `warsh.json` | Chargent le texte + calculent `verseCounts`/`wordCounts` par sourate (une fois, en cache statique). Implémentation partagée dans `QuranTextAsset` (`quran_text_asset.dart`) — les deux classes ne sont que de fines façades statiques paramétrées par le chemin d'asset. Source Sprint 8 : QUL (Tarteel AI) — Hafs explicitement crédité King Fahd Complex sur la page de la ressource ; Warsh moins explicitement sourcé (piste ouverte au backlog) mais plateforme bien mieux maintenue que l'ancien dataset communautaire. **Hafs et Warsh ont chacun leur propre numérotation native** (6236 vs 6214 versets au total, frontières de versets différentes sur ~50 sourates) — ce n'est pas juste un texte différent sur la même grille. |
| `HizbMetadataService` | asset `assets/quran/metadata/quran-metadata-hizb.json` | `surahStartHizb` : numéro de Hizb où commence chaque sourate, donnée QUL officielle (remplace l'ancienne estimation par position cumulative de `quran_data.dart`). Retombe sur `{}` si jamais initialisé/échec de chargement — purement cosmétique (groupement dans l'onboarding), ne doit jamais bloquer le boot. |

### Base de données SQLite (`AyahFactsService`, Phase 6 — remplace `HistoryService`)

```sql
CREATE TABLE ayah_facts (
  user_id     TEXT NOT NULL,   -- constante 'local' pour l'instant, réservé pour un futur compte/sync
  date        TEXT NOT NULL,   -- YYYY-MM-DD
  riwaya      TEXT NOT NULL,
  surah_id    INTEGER NOT NULL,
  ayah_id     INTEGER NOT NULL,
  type        TEXT NOT NULL,   -- 'learn' | 'revise'
  reach       INTEGER NOT NULL DEFAULT 0,  -- proposé (0) puis coché "fait" au check-in/PlanScreen/check-out (1)
  cold        INTEGER NOT NULL DEFAULT 0,  -- "à retravailler", déclaré au check-out par verset précis
  checked_out INTEGER NOT NULL DEFAULT 0   -- jour scellé (1) au check-out — AppState.checkOut, voir §7
);
CREATE INDEX idx_ayah_facts_date ON ayah_facts(date);
CREATE INDEX idx_ayah_facts_verse ON ayah_facts(riwaya, surah_id, ayah_id);
CREATE UNIQUE INDEX idx_ayah_facts_unique ON ayah_facts(date, riwaya, surah_id, ayah_id, type);
CREATE INDEX idx_ayah_facts_active ON ayah_facts(riwaya, type, reach, date);
```

L'index unique est nécessaire pour la correction, pas seulement la performance : une même plage de versets peut apparaître plusieurs fois dans le plan du jour (répétition cyclique de `RevisionEngine`, §5.1) — sans lui, une sourate répétée dans 2 rakaas insérerait 2 lignes dupliquées pour le même verset/jour et fausserait les comptages. `idx_ayah_facts_active` couvre le filtre `WHERE riwaya = ? AND type = ? AND reach = 1` commun à `currentStreak`/`totalActiveDays`/`recentDayVerseCounts`/`avgVersesPerDay` (`date` en dernière colonne pour satisfaire aussi le `ORDER BY date` sans scan supplémentaire).

**Migration v3→v4 (Sprint 1, Phase 6)** : `sessions`/`sourate_sessions` sont **droppées** (`DROP TABLE IF EXISTS`), pas migrées ligne-par-ligne — décision explicite prise en cours de route car il n'existe pas d'utilisateur réel en production à ce jour (voir CHANGELOG, "Décisions actées" du cadrage Phase 6). **Si un utilisateur réel existe au moment d'un futur changement de schéma, ne pas reconduire ce pattern sans redemander confirmation** — la règle générale du projet reste : si vous ajoutez une table ou colonne, incrémentez `version` dans `_open()` et ajoutez la migration dans `onUpgrade`, ne modifiez jamais `onCreate` seul (les utilisateurs existants ne repasseront pas par `onCreate`).

**Requêtes clés** (toutes filtrent `riwaya` + `type`, la plupart aussi `reach = 1`) : `lastRevisionDatesPerSourate` (`MAX(date) GROUP BY surah_id`, alimente `FreshnessEngine` via `AppState.refreshFreshness`, et `S.lastRevisionLabel`/`needsAttention` via `AppState.lastRevisionFor`, Sprint 2) ; `currentStreak` (`SELECT DISTINCT date` → délègue à `StreakEngine.compute`, §5.3) ; `avgVersesPerDay`/`recentDayVerseCounts` (`COUNT(*) GROUP BY date`) ; `learnedVersesBySourate`/`learnStartDatesBySourate`/`loadMainLearningProgress` (reconstruction de `LearningProgress` pour le profil principal, une seule requête groupée par sourate — pas un aller-retour SQL par sourate en boucle, voir §8.3/§8.4).

**Rituel check-in/check-out (Sprint 2)** : `pendingDate({riwaya})` — `SELECT MIN(date) WHERE checked_out=0 AND date < aujourd'hui` ; le filtre `date < aujourd'hui` est nécessaire, pas juste `checked_out=0` seul, sinon le plan du jour tout juste proposé (non scellé) se compterait lui-même comme "en attente" (bug trouvé en revue de code Sprint 2, testé dans `ayah_facts_service_test.dart`). `proposeUnits(date, riwaya, units)` — insert batché un verset par ligne, `ConflictAlgorithm.ignore` (pas `replace` : ne doit jamais écraser un `reach`/`cold` déjà posé sur un verset qui y figurait déjà). `dayFacts(date, riwaya)` groupe les lignes par sourate via `MIN`/`MAX(ayah_id)` en Dart (`DayFactGroup{surahId, verseStart, verseEnd, reach, coldVerses}`) — suppose les versets d'une sourate contigus pour le jour, piège si le shuffle sépare une sourate découpée sur 2 jours (voir §5.1). `isRangeReached`/`rangeExists` distinguent "pas encore fait" (`total>0, reach<total`) de "retiré au check-in" (`total=0`) — nécessaire pour que `AppState.checkOut` ignore une unité retirée plutôt que de la traiter comme bloquante (bug trouvé en revue de code Sprint 2).

**Piège (Sprint 8)** : un verset "appris" ou "sélectionné" en Hafs n'est pas le même contenu mémorisé qu'en Warsh (texte différent, numérotation différente) — traduire un index ou une plage de versets d'un parcours vers l'autre n'a pas de sens, même approximativement. C'est pourquoi Hafs/Warsh sont deux parcours **complètement indépendants** plutôt qu'un mapping de numérotation (une piste explorée puis abandonnée — voir CHANGELOG Sprint 8). Ne jamais réintroduire de logique qui suppose qu'un `verseStart`/`verseEnd` garde son sens en changeant de riwaya.

---

## 7. `AppState` (`lib/state/app_state.dart`)

Unique `ChangeNotifier` de l'app, injecté à la racine via `ChangeNotifierProvider` (`main.dart`). Tient l'état runtime et délègue tout calcul/persistance aux engines/services — **ne contient pas de logique métier elle-même**, seulement de l'orchestration.

État tenu : `_config` (UserConfig?), `_cyclePosition`, `_todaySession` (DailySession?, dérivé — voir plus bas), `_pendingDate` (String? YYYY-MM-DD, Sprint 2), `_justCheckedIn` (bool transitoire, Sprint 2), `_pauseDates`, `_locale`, `_riwaya`, `warshAvailable` (bool, immuable pour la durée du process — Warsh a-t-il pu charger au boot), `_hasSeenTour` (Sprint 8, voir plus bas), `_sourates` (Sprint 8, `List<Sourate>` riwaya-aware — remplace l'usage direct de `quran_data.allSourates`, désormais dépourvue de comptes verses/words), `_adaptiveCycleDays`, `_freshness` (Map sourateId→FreshnessLevel), `_lastRevisionDates` (Map sourateId→DateTime, Sprint 2 — même source que `_freshness`, conservée pour l'affichage texte discret du check-in/check-out), `_checkedRakaas` (Map prayerIndex→Set\<rakaaNumber\>, Sprint 7).

### Rituel check-in/check-out (Phase 6 Sprint 2) — méthodes notables

**`previewSession`/`todaySession` (objets `DailySession` persistés en JSON) ont disparu.** `_todaySession` est désormais calculé à la demande, jamais chargé depuis `StorageService` — la seule source du plan du jour est `ayah_facts` (voir cadrage CHANGELOG « Moteur quotidien — source unique de vérité »).

- **`_selectionFor(date)`** (privée) — encapsule l'appel à `RevisionEngine.selectDayUnits(config, cyclePosition, today: DateTime.parse(date), effectiveDaysOverride: adaptiveCycleDays)`. **Tous** les appels à `selectDayUnits` dans `AppState` passent par cette méthode plutôt que d'appeler `RevisionEngine` directement — deux raisons : (1) `today` est **toujours** ancré à minuit (`DateTime.parse` d'une date `YYYY-MM-DD`), jamais `DateTime.now()`, pour que la même date produise la même sélection qu'elle soit calculée à la génération du plan ou plus tard au check-out (bug trouvé en revue de code Sprint 2 : un décalage d'heure entre les deux appels pouvait faire dériver `daysElapsed`/`dailyTarget` en mode « par durée ») ; (2) `effectiveDaysOverride` est systématiquement transmis, sans quoi le cycle adaptatif reste affiché mais cesse d'influencer réellement le plan généré (même classe de bug, voir piège §5.4).
- **`ensureDayPlan({notify})`** — point d'entrée du moteur quotidien, appelé une fois au montage de `ShellScreen` (`initState`, fire-and-forget). Calcule `_pendingDate` via `AyahFactsService.pendingDate`. Si `null` (aucun jour antérieur en attente) **et** qu'`ayah_facts` n'a encore aucune ligne pour aujourd'hui, écrit le plan proposé (`AyahFactsService.proposeUnits`, `reach=0, checked_out=0`) et passe `_justCheckedIn = true`. Tente ensuite de reprendre une manche en cours (`StorageService.loadActivePrayers` → `buildTodaySession`) si l'app a redémarré après un début de check-in/PlanScreen le même jour.
- **`dayUnits({date})`** / **`dayUnitsWithStatus({date})`** — reconstruisent `List<RevisionUnit>` (resp. avec `reach`/`coldVerses`) depuis `AyahFactsService.dayFacts`, en résolvant chaque `surah_id` vers un `Sourate` de `_sourates` (`_sourateById`, scan linéaire — 113 sourates au maximum, jugé insignifiant). `dayUnits()` alimente `PlanScreen`/`CheckInScreen` ; `dayUnitsWithStatus()` alimente `CheckOutScreen` (a besoin de savoir ce qui est déjà coché/flagué).
- **`addToDayPlan`/`removeFromDayPlan`/`extendDayPlanVerse`** — édition du plan du jour depuis `CheckInScreen` : INSERT (`AyahFactsService.proposeUnits`) ou DELETE (`removeFromDayPlan`) direct sur `ayah_facts`, pas d'objet intermédiaire à reconstruire.
- **`buildTodaySession(prayersAlone, {notify})`** — construit `_todaySession` (un `DailySession`, pour que `PlanScreen` garde exactement son rendu existant) en répartissant les unités déjà validées au check-in (`dayUnits()`) dans les rakaas des prières choisies (`RevisionEngine.distributeToRakaas`) — **ne génère jamais de nouvelles unités**, contrairement à l'ancien `HomeScreen._buildPlan`. Persiste la sélection de prières (`StorageService.saveActivePrayers`) pour survivre à un redémarrage avant la fin de la manche.
- **`markUnitsReached(units)`** — appelé à la fin d'une manche PlanScreen (`reach=1` en batch, `AyahFactsService.setReachForUnits`). **N'avance plus `cyclePosition`** — voir `checkOut` ci-dessous.
- **`setUnitReach(date, unit, reach)`** / **`setVerseCold(date, surahId, ayahId, cold)`** — bascules du check-out (case à cocher par sourate/portion, flag « à retravailler » par verset précis).
- **`checkOut(date)`** — scelle la journée (`AyahFactsService.sealDay`) et avance `cyclePosition` **une seule fois pour toute la journée**, à partir des unités que `_selectionFor(date)` avait proposées et qui ont effectivement `reach=1`, dans l'ordre, en s'arrêtant à la première non faite (même logique que l'ancienne déclaration partielle de PlanScreen). Une unité **retirée** au check-in (`AyahFactsService.rangeExists` → `false`) est **ignorée** (`continue`), pas traitée comme bloquante — bug trouvé en revue de code Sprint 2 : avant, une unité retirée cassait le comptage des unités suivantes réellement complétées. Les ajouts hors-sélection au check-in ne font pas avancer le cycle au-delà de ce que le moteur avait proposé (alimentent l'historique/la fraîcheur quand même) — décision documentée faute d'une règle plus précise actée au cadrage. Écritures indépendantes (`sealDay`, `refreshAdaptiveCycle`, `refreshFreshness`, `clearActivePrayers`, reset des rakaas cochées, `advanceCycle`) lancées via `Future.wait`, un seul `notifyListeners()` pour toute l'opération. Retourne `true` si le cycle vient de boucler (`CheckOutScreen` affiche alors `CycleMilestoneDialog`).
- **`previewTodayUnits()`** — aperçu pur (aucune écriture) de ce que le moteur proposerait maintenant, utilisé par `CheckOutScreen` (Partie 2, « ajouter aussi aujourd'hui ») pour que l'écran n'ait jamais besoin d'importer `RevisionEngine` directement.

### Autres méthodes notables

- `saveConfig()` — remplace la config du parcours actif. Depuis le Sprint 7, ne réinitialise le cycle (`_cyclePosition = 0`, plan/rakaas cochées effacés) **que si la sélection de sourates a réellement changé** (`_sameSelections`, comparaison par id+plage de versets) — un simple changement de rythme (durée, lignes/jour) préserve la progression en cours. **Piège (Sprint 2, non résolu)** : rien n'empêche d'appeler `saveConfig()` pendant qu'un jour est en attente de check-out (`pendingDate != null`) — `checkOut` recalculerait alors sur une config différente de celle utilisée à la génération du plan en attente. Le gate check-out bloque l'onglet Réviser, pas Profil. Backlog CHANGELOG.
- `advanceCycle(unitsCompleted, cycleTotal, {notify})` — délègue à `RevisionEngine.advanceCycle`, ne recalcule jamais l'arithmétique ici. Depuis Sprint 2, n'est appelée que par `checkOut()`.
- `refreshAdaptiveCycle(totalVerses)` — no-op silencieux si `adaptiveCycle` est désactivé ou `totalVerses <= 0`. **Paramètre en échelle "versets" depuis la Phase 6** (`config.totalSelectedVerses`, avant : nombre d'unités `RevisionEngine`) — doit rester cohérent avec `AyahFactsService.avgVersesPerDay` (même échelle), bug trouvé en code-review Sprint 1 (mélange unités/versets faussait fortement l'estimation).
- `toggleChecked(prayerIndex, rakaaNumber)` (Sprint 7) — coche/décoche une rakaa de la manche en cours, persistée via `StorageService.saveCheckedRakaas` à chaque appel (survit à un redémarrage de l'app avant validation). `notifyListeners()` est appelé **avant** l'écriture disque pour que l'UI réagisse sans attendre le round-trip SharedPreferences.
- `clearConfig()` — reset complet du parcours actif uniquement, via `StorageService.clearConfigOnly(_riwaya)` — l'autre riwaya (si configurée) n'est pas touchée. Ne touche pas non plus langue/riwaya-active/notifications/tour-vu.
- **`setRiwaya(riwaya)`** (Sprint 8, réécrit) — bascule le parcours actif. No-op (retourne `true`) si déjà sur cette riwaya. Retourne **`false` sans rien changer** si `riwaya == Riwaya.warsh && !warshAvailable`. Sinon : persiste la nouvelle riwaya active, appelle `_loadTrackState()`, notifie une fois.
- **`_loadTrackState()`** (privée) — recharge tout l'état scopé par riwaya (config, cycle, pauses, cases cochées — lectures `StorageService` démarrées en parallèle) pour `_riwaya`, reconstruit `_sourates`, rafraîchit fraîcheur/cycle adaptatif, **puis appelle `ensureDayPlan(notify: false)`** (Sprint 2) — changer de riwaya équivaut à « ouvrir » ce parcours, le moteur quotidien doit s'y appliquer aussi. Si la config du parcours cible est `null` (jamais configuré), `_config` redevient `null` et l'app retombe naturellement sur l'onboarding.
- `hasSeenTour` / `markTourSeen()` (Sprint 8) — réactifs via `AppState` plutôt qu'un booléen figé au boot.

**Piège (Sprint 8)** : `HomeScreen`, `RecapScreen` et `LearnScreen` restent montés en permanence dans l'`IndexedStack` de `ShellScreen` — un changement de riwaya via `setRiwaya()` ne les recrée pas. Chacun compare la riwaya actuelle à la dernière connue dans `didChangeDependencies()` et relance son chargement si elle a changé. Si vous ajoutez un nouvel écran qui charge des données riwaya-scopées dans `initState()`, il a besoin du même pattern.

---

## 8. Écrans et navigation (`lib/screens/`, `lib/widgets/`)

> Cette section est complétée en §8.1–8.4 ci-dessous par une analyse fichier par fichier (générée à partir d'une lecture complète du code, y compris pour les composants dont le rôle n'est pas évident au premier coup d'œil).

### Structure générale

`main.dart` choisit entre `OnboardingScreen` (si `AppState.config == null`) et `ShellScreen` (sinon), sous un `MaterialApp` avec `ThemeMode.system` (suit le thème clair/sombre de l'OS — direction artistique Mus'haf/Tahajjud, voir §10).

`ShellScreen` est un `IndexedStack` à 4 onglets, tous montés en permanence (l'état de chaque onglet survit à la navigation) : `0 = DayPlanTab` (« Réviser »), `1 = RecapScreen`, `2 = LearnScreen` (« Apprendre »), `3 = ProfileScreen`.

### 8.1 Flux « Réviser » — Home / Shell / Plan / Check-in / Check-out

**`DayPlanTab` (`widgets/day_plan_tab.dart`) est un routeur, pas un écran** (Sprint 2 : `StatefulWidget`, pas `Stateless` — doit garder `_checkInShown`/`_checkOutShown`, deux gardes anti-double-push). Inspecte `AppState.pendingDate`/`justCheckedIn`/`todaySession` et choisit :
1. `pendingDate` non-null → pousse `CheckOutScreen` en plein écran (`Navigator.push`, `fullscreenDialog: true`), affiche un simple indicateur de chargement en dessous le temps que le popup apparaisse.
2. `justCheckedIn` → pousse `CheckInScreen` de la même façon, puis `AppState.acknowledgeCheckIn()` une fois le popup fermé (peu importe comment : bouton « Valider » ou retour arrière).
3. `todaySession` défini → `PlanScreen` (checklist active).
4. Sinon → `HomeScreen` (sélection des prières).

**Important** : check-in et check-out sont des popups **poussés** (`Navigator.push`), jamais rendus comme corps d'onglet directement — `CheckOutScreen` appelle `Navigator.of(context).pop()` en se fermant, qui ne fonctionnerait pas s'il était retourné en place par `build()` (bug trouvé en revue de code Sprint 2, corrigé).

Flux complet : `ShellScreen.initState()` → `AppState.ensureDayPlan()` (moteur quotidien, §7) → si jour en attente, `CheckOutScreen` (scelle, avance le cycle) → sinon si plan fraîchement généré, `CheckInScreen` (édite les unités du jour) → `HomeScreen` (« Voir le plan du jour ») → `AppState.buildTodaySession(prayersAlone)` (répartit en rakaas les unités déjà validées, ne les régénère pas) → `PlanScreen` (checklist) → complétion → `DayPlanTab._onComplete()` → `AppState.clearTodaySession()` → retour à `HomeScreen`. Plusieurs manches par jour restent possibles (une manche complétée revient à `HomeScreen`, une nouvelle sélection de prières peut répartir les mêmes unités `ayah_facts` du jour différemment).

**`HomeScreen`** — sélection des prières récitées seul (`_prayersAlone: Set<Prayer>`) + compteur d'entrées à la mosquée (`_tahiyyatCount`). Bouton « Voir le plan du jour » appelle directement `widget.onVoirPlan(_effectivePrayers)` (Sprint 2 : ne construit plus de `DailySession` lui-même, `AppState.buildTodaySession` s'en charge — voir §7). `daysRemaining` utilise `state.adaptiveCycleDays ?? config.effectiveDays(...)`. **Attention** : `build()` recalcule quand même indépendamment `units`/`cycleTotal`/`pos` à partir de `RevisionEngine.buildUnits()` pour l'affichage de la barre de cycle — cette arithmétique reste dupliquée à plusieurs endroits de l'UI (voir §8.5). Tour guidé (`SpotlightOverlay`) via des `KeyedSubtree` posées sur le sélecteur de prières et le bouton « Voir le plan ». **« Reprendre les prières d'hier »** (`_lastPrayers`/`_isYesterday`) lit `StorageService.loadLastSessionPrayers`, écrite par `DayPlanTab._onComplete` à chaque manche normale complétée (pas la saisie manuelle) — bug trouvé en revue de code Sprint 2 : cet appel avait disparu lors du remplacement de `_onComplete`, cassant silencieusement cette fonctionnalité ; restauré.

**`PlanScreen`** — depuis Sprint 2, checklist active uniquement (le mode `isPreview`/bouton « S'engager »/carte de résumé check-in ont disparu, rendus redondants par `CheckInScreen`). Ne calcule plus son propre plan : reçoit un `DailySession` déjà construit par `AppState.buildTodaySession()` à partir des unités validées au check-in. Points métier intégrés à l'UI (donc absents de `RevisionEngine`, à connaître avant de les modifier) :
- **Cases cochées persistées (Sprint 7)** : `checkedByPrayer` vient de `AppState.checkedRakaas`, persisté à chaque coche (survit à un redémarrage avant validation).
- **Modal d'engagement** (`_CommitmentSheet`, non-dismissible) : force l'utilisateur à déclarer « Tout fait / Une part / Rien fait » avant d'abandonner une manche active. `PlanScreen._coverageForFirstRakaas(n)` traduit un nombre de rakaas (naturel pour l'utilisateur) en unités de cycle réelles + sourates réellement couvertes (les N premières rakaas du plan, dans l'ordre) avant d'appeler `onComplete`.
- `onComplete` a la signature `Function(int unitsCompleted, List<RevisionUnit> coveredUnits)`. Depuis Sprint 2, `DayPlanTab._onComplete` **ne fait plus avancer `cyclePosition`** avec ces unités — elle les marque seulement `reach=1` (`AppState.markUnitsReached`) ; `cyclePosition` n'avance qu'au check-out (§7).
- **`_StreakBadge`** : paliers de streak codés en dur — `1` (« premier jour »), `7`/`30`/`100` (« nouveau palier »).
- **Streak anticipé** : `AyahFactsService.currentStreak() + 1` à l'écran de complétion, pour anticiper la manche pas encore enregistrée en DB au moment de l'affichage.
- `_FocusMosqueeScreen` (mode focus plein écran) utilise des couleurs codées en dur au lieu de `AppPalette` — déroge à la règle CLAUDE.md, non traité, priorité basse.
- **`_CycleMilestoneDialog` déplacée** vers `widgets/cycle_milestone_dialog.dart` (public, `CycleMilestoneDialog`) au Sprint 2 — affichée par `CheckOutScreen` maintenant que c'est le check-out qui fait boucler le cycle, plus par `PlanScreen`.

**`DayPlanTab._onComplete()`** (manche PlanScreen complétée) — Sprint 2, pipeline simplifié par rapport à avant : `AppState.markUnitsReached(coveredUnits)` puis, en parallèle (`Future.wait`), `refreshAdaptiveCycle`, `refreshFreshness` et `StorageService.saveLastSessionPrayers` ; enfin `AppState.clearTodaySession()`. **Ne calcule plus `cycleWraps` ni n'appelle `advanceCycle`** — déplacé dans `AppState.checkOut`/`CheckOutScreen` (§7).

`_onManualSession` (`ManualSessionSheet`, stepper 1..maxUnits) — depuis Sprint 2, les unités couvertes sont les N premières de `AppState.dayUnits()` (le plan du jour déjà validé au check-in), pas dérivées indépendamment de `cyclePosition` comme au Sprint 1. Marque `reach=1` via `markUnitsReached`, n'avance pas non plus le cycle.

### 8.1bis Check-in / Check-out (`screens/check_in_screen.dart`, `check_out_screen.dart`, Phase 6 Sprint 2)

Popups plein écran poussés par `DayPlanTab` (voir ci-dessus), pas des onglets. Tous deux suivent le même patron : liste "chapelet" en tête + écran détail poussé (`Navigator.push`, route privée dans le même fichier) par sourate, pas d'accordéon en place.

**`CheckInScreen`** — affiche/édite les lignes `ayah_facts` du jour (déjà écrites par le moteur quotidien, `reach=0, checked_out=0`) :
- Liste chapelet (`_UnitRow`) : nom + plage de versets + `S.lastRevisionLabel` (texte discret, pas de badge chaud/froid — décision actée à la maquette Sprint 1). Tap → écran détail (`_CheckInDetailScreen`, versets en `VerseChip`, chip "+" pointillé pour étendre la portée d'un verset via `AppState.extendDayPlanVerse`, garde anti-double-tap `_extending`). "×" sur la ligne retire directement la sourate (`AppState.removeFromDayPlan`).
- Section "À prioriser" (`_watchSection`) : sourates dont `S.needsAttention(lastRevisionFor(...), now)` est vrai (même seuil — 180 jours — que `lastRevisionLabel`, une seule constante `_staleSinceDays` dans `strings.dart`, pas deux seuils indépendants).
- Bouton "Ajouter une sourate" → bottom sheet (`_AddSourateSheet`) listant les sourates hors sélection courante du jour ; tap ajoute la sourate entière (`AppState.addToDayPlan`).
- "Valider le check-in" ferme juste le popup (`Navigator.pop`) — les éditions sont déjà écrites en direct dans `ayah_facts`, rien à "promouvoir".

**`CheckOutScreen(date)`** — scelle le jour `date` (le plus ancien non scellé, fourni par `DayPlanTab`) :
- Écart d'1 jour (`gapDays == 1`) : liste + checkbox "fait"/"pas fait" par sourate (`AppState.setUnitReach`), lien "Voir les N versets" → écran détail (`_CheckOutDetailScreen`) où toucher un verset le flague "à retravailler" (`AppState.setVerseCold`, granularité verset précis, pas la sourate). CTA "Clôturer hier" → `_close()`.
- Écart multi-jours (`gapDays > 1`) : même Partie 1, puis CTA "Clôturer ce jour" révèle la Partie 2 (`_step = 2`, même écran, pas de nouvelle route) — toggle "Ajouter aussi aujourd'hui" (aperçu via `AppState.previewTodayUnits()`, aucune écriture), CTA final "Valider aussi aujourd'hui" (rempli) ou "Terminer sans aujourd'hui" (contour) selon le toggle.
- `_close()` : `AppState.checkOut(date)` (scelle + avance le cycle) puis, **seulement si écart d'1 jour ou toggle "ajouter aujourd'hui" actif**, `AppState.ensureDayPlan()` pour proposer immédiatement le plan du jour — bug trouvé en revue de code Sprint 2 : les deux boutons de la Partie 2 appelaient initialement le même code sans respecter le toggle, "Terminer sans aujourd'hui" générait quand même le plan du jour. Si le cycle vient de boucler (retour de `checkOut`), affiche `CycleMilestoneDialog` avant de fermer. `try/finally` autour de `_sealing` pour ne jamais rester bloqué (bouton désactivé indéfiniment) si `checkOut`/`ensureDayPlan` lève une exception.
- `VerseChip` (`widgets/verse_chip.dart`, Sprint 2) : petit badge carré partagé entre les deux écrans détail (numéro de verset / chip "+" / bookmark "à retravailler") — remplace 3 occurrences dupliquées inline (`/simplify`).

**Tour guidé (Sprint 7, `widgets/spotlight_tour.dart`)** : `SpotlightOverlay` — overlay maison (`CustomPainter`, pas de dépendance externe) affiché une seule fois par `ShellScreen` juste après l'onboarding, tant qu'aucune session n'est encore engagée (`StorageService.hasSeenTour()`/`setTourSeen()`). Cible 3 `GlobalKey` statiques (`TourKeys` — nav bar, sélecteur de prières, bouton « Voir le plan ») posées via `KeyedSubtree` dans `ShellScreen`/`HomeScreen`. Pas de bouton « revoir le tutoriel » (voir Backlog dans CHANGELOG.md).

**`prayer_selector.dart`** : le nombre maximum d'entrées « Tahiyyat al-Masjid » est plafonné en dur à `5` (`tahiyyatCount < 5`) — encore une règle métier sans source de vérité centrale.

**`prayer_plan_card.dart`** : décide localement quels niveaux de fraîcheur affichent un badge (`cold`/`frozen` seulement, pas `hot`) — mapping dupliqué de l'énumération `FreshnessLevel`, à resynchroniser manuellement si un niveau est ajouté à `FreshnessEngine`.

### 8.2 Onboarding (`screens/onboarding_screen.dart` + widgets associés)

Wizard 3 pages (`PageView` + `NeverScrollableScrollPhysics`, navigation par boutons uniquement) — rien n'est persisté avant la confirmation finale.

- **Page 0 (Intro)** : écran statique, bouton `PrimaryCtaButton` fait juste avancer le `PageController`.
- **Page 1 (Sélection)** : pills de sélection rapide (Tout / 3/4 / 1/2 / 1/4), recherche, groupement par Hizb, liste des 113 sourates. Tap = sélection sourate entière ; appui long ouvre `VerseRangePicker` (bottom sheet) pour sélectionner une plage partielle.
  - **`_quickSelect(fraction)`** : calcule `target = (totalVerses * fraction).round()`, puis parcourt `allSourates.reversed` (donc **depuis la fin du Coran**, sourate 114 vers 1) en accumulant des sourates entières jusqu'à atteindre `target` — c'est une approximation par nombre de versets, pas une correspondance exacte de fraction (peut légèrement dépasser).
  - Piège : les pills 3/4, 1/2, 1/4 ont un état « sélectionné » codé en dur à `false` (ne reflètent jamais si la sélection courante correspond réellement au preset).
  - `VerseRangePicker` propose des raccourcis par blocs de 50 versets (sourates ≤100 versets) ou 100 versets (sourates >100 versets), plus un `RangeSlider` verset par verset.
- **Page 2 (Récap)** : carte résumé + carte rythme (`SegmentedButton` durée/lignes-par-jour piloté par `PresetDropdown`, presets `durationPresets`/`linesPerDayPresets`) + bouton « Commencer » qui construit le `UserConfig` (`startDate: DateTime.now()`) et appelle `AppState.saveConfig()`. **`shuffleEnabled` et `adaptiveCycle` ne sont pas exposés à l'onboarding** — ils gardent leurs valeurs par défaut (`true`/`false`).

Widgets réutilisables transverses : `PillChip` (chip sélectionnable, `dashed: true` change seulement la couleur de bordure — ne dessine pas de pointillés malgré son nom), `IndexBadge` (badge numéro sourate), `OrnamentalDivider` (motif ligne-losange-ligne décoratif), `PrimaryCtaButton` (ombre dorée dure en clair / lueur menthe douce en sombre), `PresetDropdown` (partagé avec `profile_screen.dart` — toute modification impacte les deux écrans), `SouratePickerSheet` (picker mono-sélection indépendant, dont le filtre de recherche duplique celui de `OnboardingScreen._listItems` plutôt que de le partager).

### 8.3 Apprentissage (`screens/learn_screen.dart`, `screens/learn_surah_screen.dart`)

`LearnScreen` est la liste/vue d'ensemble : profils élèves (`StudentProfile`/`StudentService`) + liste des sourates en cours de mémorisation (`LearningProgress`). `LearnSurahScreen` est le détail/pratique d'une sourate, poussé via `Navigator.push`, qui notifie le parent via `onChanged` après chaque changement.

**`LearningProgress` du profil principal n'est plus persisté comme blob depuis Phase 6 Sprint 1** : `LearnScreen._loadProgress()` appelle `AyahFactsService.loadMainLearningProgress(riwaya, sourates)`, qui reconstruit un `LearningProgress` par sourate en cours à partir de deux requêtes groupées (`learnedVersesBySourate` + `learnStartDatesBySourate`, pas un aller-retour SQL par sourate en boucle). Les profils élèves, eux, continuent de persister `LearningProgress` complet via `StudentService` (le modèle garde donc `toJson`/`fromJson` pour cet usage, même si le profil principal ne les utilise plus). **Piège** : `LearnScreen._startNewSourate()` construit un `LearningProgress.start(picked)` en mémoire pour ouvrir immédiatement `LearnSurahScreen`, mais **n'écrit rien** côté profil principal tant qu'aucun verset n'est marqué appris (`ayah_facts` n'a pas de notion de "sourate démarrée à 0 verset") — si l'utilisateur quitte l'écran avant de marquer un premier bloc, la sourate disparaît silencieusement de "en cours d'apprentissage" au rechargement suivant. Non destructif (rien n'était réellement appris), accepté consciemment, voir backlog dans CHANGELOG.md.

**Connexion révision ↔ apprentissage** (le point le plus important pour la maintenance) : quand `LearningProgress.isComplete` (tous les versets appris), `LearnSurahScreen` propose « Ajouter à la révision ». Ce n'est **pas automatique côté engine** — c'est un hand-off piloté par l'UI : `LearnScreen._addToRevision()` ajoute `SourateSelection.whole(s)` à `UserConfig.selections` via `AppState.saveConfig()`, **puis** appelle `AyahFactsService.deleteLearnFacts(s.id, riwaya)` (Phase 6 ; avant, `LearningService.remove`). Une sourate passe donc du domaine « apprentissage » au domaine « révision » comme une opération UI atomique, jamais déclenchée depuis `core/`. Cette action n'est proposée que pour le profil principal (`_activeStudentId == null`) — un profil élève ne peut pas alimenter la config de révision du parent.

**Sélecteur de bloc (`[B] Apprentissage multi-versets`)** : `SegmentedButton<int>` à 3 valeurs fixes `{1, 3, 5}`. `_currentBlock` calcule les N prochains versets *non appris* en ordre croissant (pas nécessairement `nextVerse` si des versets ont été désappris hors séquence). **Depuis Phase 6**, `_markBlockLearned` écrit tout le bloc en un seul batch côté profil principal (`AyahFactsService.learnVerses`, une transaction/un aller-retour) plutôt qu'un `learnVerse` par verset — évite un bloc à moitié persisté si l'app est interrompue en cours de marquage. Les élèves continuent de sauvegarder le blob complet via `StudentService.upsertProgress`.

**Duplication identifiée** : `learn_surah_screen.dart` construit son propre bloc de hadith de clôture (`_closingHadith`, appelle `hadithDuJour()` directement) et son propre badge de streak inline (`_streakBadge`), plutôt que de réutiliser les widgets `HadithCard`/`StreakCard` qui existent déjà et font la même chose ailleurs dans l'app. Si le format d'affichage du hadith ou du streak doit changer, il faut le faire aux deux endroits.

**Petits écarts aux conventions repérés** : `learning_progress_card.dart` affiche `'✓ Complet'` en chaîne française codée en dur (pas via `S.`), et utilise `Colors.red.shade100`/`Colors.red` directement au lieu de `AppPalette` pour la couleur de suppression.

### 8.4 Profil, Récap, Réglages

**`ProfileScreen`** est la **seule surface d'édition** de `UserConfig` : sélection des sourates (mode édition plein écran), rythme (dialog dédié avec `PresetDropdown`), cycle adaptatif, pause du jour, et réinitialisation complète (irréversible, `AppState.clearConfig()`). En sauvegardant une nouvelle sélection de sourates, les sourates déjà cochées **conservent leur plage de versets existante** (`existingSelections[s.id] ?? SourateSelection.whole(s)`) — seules les sourates nouvellement cochées deviennent des sélections « entières ».

**`SettingsCard`** (imbriqué dans `ProfileScreen`) : langue, riwaya, shuffle (tous via `AppState`), et notifications — dont l'état (`notif_enabled`) est stocké **directement dans `StorageService`**, hors de `UserConfig`, donc **il survit à `AppState.clearConfig()`** (réinitialisation du profil). À savoir avant de supposer qu'un « reset complet » efface vraiment tout.

**`RecapScreen`** est en lecture seule (streak, position de cycle, répartition sourates, historique 7 jours). Piège à connaître : la carte de répartition (`enRevision`/`memorisees`/`enCours`) combine deux sources de données indépendantes (`UserConfig.selections` vs `LearningProgress`, cette dernière via `AyahFactsService.loadMainLearningProgress` depuis Phase 6) qui **ne sont pas mutuellement exclusives** — une sourate peut compter à la fois « en révision » et « mémorisée », la carte ne réconcilie pas les deux. `HistoryCard` reçoit 14 sessions mais n'en affiche que les 7 premières (`sessions.take(7)`) — écart entre ce que demande l'appelant et ce que le widget restitue, à clarifier si quelqu'un y touche. `_load()` démarre `AppState.refreshFreshness(notify: false)` en parallèle des autres lectures (Sprint 7, avant : appelé après coup, en série). **Depuis Phase 6 Sprint 1**, `_sessions` (`List<SessionRecord>`) est reconstruit depuis `AyahFactsService.recentDayVerseCounts` (compte de versets révisés par jour) — `unitsCompleted`/`totalUnits` sont désormais en échelle "versets" (`totalUnits = config.totalSelectedVerses`, une constante par config, pas un total par jour), pas en échelle "unités RevisionEngine" comme avant. `HistoryCard` a été mis à jour pour afficher `S.versetsLabel` au lieu de `S.unitesLabel` en conséquence.

**`SouratesRecapCard` (Sprint 7)** : affiche désormais un badge de fraîcheur (`FreshnessBadge`, `widgets/freshness_badge.dart` — Récente/Froide/Très froide) par sourate, et chaque ligne est cliquable (`onTap`) vers le nouvel écran **`SurahReaderScreen`** (`screens/surah_reader_screen.dart`) — lecture plein texte d'une sourate/plage, sans mode caché/révélé. Avant Sprint 7, aucune navigation de lecture n'existait depuis le Récap. Le fond de carte utilise maintenant `context.palette.surfaceCard` + `cardBorder` (avant : `Colors.white` en dur, cassait l'apparence en thème sombre — corrigé).

**`StudentProfileBar`** (onglet Apprendre, pas Profil) : la suppression d'un profil élève se fait par **un simple appui long, sans aucune confirmation** dans toute la chaîne d'appel (`student_profile_bar.dart` → `learn_screen.dart:_deleteStudent`). C'est l'action la plus dangereuse identifiée dans toute la couche UI — à corriger en priorité si le sujet de la robustesse UX revient (non traité au Sprint 7).

### 8.5 Dette technique UI identifiée (à garder à l'esprit, pas à corriger d'office)

Cette liste consolide ce que l'analyse fichier-par-fichier a fait remonter — utile pour prioriser un futur nettoyage, mais **ne pas corriger silencieusement en marge d'une autre tâche** (règle CLAUDE.md « changements chirurgicaux »).

1. **Arithmétique de cycle dupliquée** dans `home_screen.dart` et `plan_screen.dart` (`_summaryBar`) — recalculent `pos`/`cycleTotal`/`daysRemaining` indépendamment pour l'affichage plutôt que de consommer une valeur unique exposée par `AppState`. **Partiellement résolu au Sprint 2** : `day_plan_tab.dart` ne calcule plus `cycleWraps` localement (déplacé dans `AppState.checkOut`, seule source qui fait réellement avancer le cycle désormais) ; `recap_screen.dart` lit déjà `AppState.cyclePosition` sans recalcul. `home_screen.dart`/`plan_screen.dart` restent à corriger si retouchés.
2. **Magic numbers métier hors de `core/`** : seuil 80% « bonne journée » répété 5 fois dans `history_card.dart` ; paliers de streak 1/7/30/100 dans `plan_screen.dart` ; plafond de 5 entrées Tahiyyat dans `prayer_selector.dart` ; règle « moitié des rakaas par défaut » dans `_CommitmentSheet`.
3. **Couleurs codées en dur** (déroge à la règle `AppPalette`) : `_FocusMosqueeScreen` (plan_screen.dart), `learning_progress_card.dart`. `sourates_recap_card.dart` corrigé au Sprint 7 (utilise `palette.surfaceCard`). Le voile (scrim) de `SpotlightOverlay` (Sprint 7) reste en `Colors.black` en dur, mais **volontairement** — un voile de modale est conventionnellement invariant au thème (comme `ModalBarrier` de Flutter), le passer par `AppPalette` l'inverserait en thème sombre.
4. **Chaîne hors `S.`** : `'✓ Complet'` dans `learning_progress_card.dart`.
5. **Composants dupliqués plutôt que réutilisés** : hadith de clôture et badge de streak réimplémentés dans `learn_surah_screen.dart` au lieu de `HadithCard`/`StreakCard` ; filtre de recherche sourate dupliqué entre `OnboardingScreen` et `SouratePickerSheet`. Non traité au Sprint 7 (revue de code identifiée, priorité basse).
6. **Confirmation manquante** : suppression d'un profil élève (`StudentProfileBar` → appui long direct, aucun dialog).
7. **Mismatch appelant/widget** : `HistoryCard` reçoit 14 sessions, n'en affiche que 7.
8. **Libellé ambigu** : « Sourates mémorisées » dans `ProfileInfoCard` compte en réalité `config.selections.length` (sourates en révision), pas les sourates réellement mémorisées via `LearningProgress.isComplete` — à ne pas confondre avec le calcul distinct de `RecapScreen`.
9. **Race lire-modifier-écrire** (Sprint 7, revue de code) : `StudentService` (`upsert`/`remove`) suit un schéma lire-tout/modifier/réécrire-tout sans synchronisation — deux appels rapprochés peuvent se piétiner. **Corrigé pour le profil principal en Phase 6 Sprint 1** (`AyahFactsService` écrit/supprime des lignes individuelles, plus de blob à réécrire en entier) ; toujours présent pour `StudentService` (profils élèves) — non traité, une vraie synchronisation serait disproportionnée pour une app locale mono-utilisateur (risque réel faible).
10. **Race check-then-await sur `AyahFactsService._open()`** (Phase 6 Sprint 1, revue de code) : le singleton lazy (`_db ??= await openDatabase(...)`) peut ouvrir la DB deux fois si deux appelants arrivent avant la résolution de la première promesse (ex. `AppState._loadTrackState()` et l'`initState` d'un écran au boot) — pattern hérité tel quel de l'ancien `HistoryService._open()`, pas introduit par ce sprint, mais qui sert désormais un volume d'écriture par verset bien plus important. Non traité : même risque réel faible qu'avant (app locale mono-utilisateur), mais à garder à l'esprit si des symptômes d'ouverture DB concurrente apparaissent.
11. **Sourate démarrée à 0 verset non persistée** (Phase 6 Sprint 1, revue de code) : voir §8.3 — `LearnScreen._startNewSourate()` ne persiste rien tant qu'aucun verset n'est marqué appris côté profil principal. Non traité, accepté consciemment (non destructif, cas rare).
10. **Plage de versets trompeuse** (Sprint 7, revue de code) : `learn_surah_screen.dart` affiche `v.X–Y` pour le bloc courant, ce qui laisse croire à une plage contiguë alors que `_currentBlock` peut retourner des versets non contigus si l'utilisateur a désappris des versets précis entre-temps. Non traité (cas rare, priorité basse).
12. **`AyahFactsService.dayFacts` suppose les versets d'une sourate contigus pour le jour** (Phase 6 Sprint 2) : groupe par `MIN`/`MAX(ayah_id)` — si le shuffle du cycle (activé par défaut) sépare deux morceaux non-adjacents d'une même sourate découpée (>150 mots) sur deux jours différents, un jour peut afficher une plage plus large que ce qui a réellement été proposé ce jour-là. Non traité, cas rare (backlog CHANGELOG).
13. **Config éditable pendant un jour en attente de check-out** (Phase 6 Sprint 2) : `AppState.saveConfig()` ne vérifie pas `pendingDate` — éditer sourates/rythme (Profil) pendant qu'un jour reste non scellé fait recalculer `AppState.checkOut` sur une config différente de celle utilisée à la génération du plan en attente. Le gate check-out ne bloque que l'onglet Réviser. Non traité, cas rare (backlog CHANGELOG).
14. **Duplication visuelle `CheckInScreen`/`CheckOutScreen`** (Phase 6 Sprint 2, `/simplify` + revue de code) : en-tête "hero" (eyebrow/titre/badge), ligne de sourate (avatar+nom+plage), formatage "Sourate · v.X–Y" de l'AppBar détail — dupliqués entre les deux écrans plutôt qu'un composant partagé. `VerseChip` a bien été extrait (3 chips dupliqués → 1 widget), mais l'unification plus large des deux écrans n'a pas été faite faute de pouvoir vérifier visuellement le résultat sur cette machine (§12 build bloqué). Non traité, à reprendre si un des deux écrans est retouché (backlog CHANGELOG).

---

## 9. Direction artistique & theming

Deux thèmes : **Mus'haf** (clair — papier crème, vert profond, or) et **Tahajjud** (sombre), suivis automatiquement via `ThemeMode.system` (`main.dart`) — pas de sélecteur manuel dans l'app.

- `AppPalette` (`lib/core/app_colors.dart`) : `ThemeExtension` définissant les tokens sémantiques (`cream`, `primary`, `gold`, `textPrimary`, `textMuted`, `danger`, `ctaShadow`, `isDark`, etc.), avec deux instances constantes `AppPalette.light`/`AppPalette.dark`. Accès via l'extension `context.palette`.
- `buildAppTheme(Brightness)` (`lib/core/app_theme.dart`) construit le `ThemeData` complet (police Lora via `google_fonts`, `CardTheme`, `NavigationBarTheme`, `FilledButtonTheme`, `SwitchTheme`, `ChipTheme`) à partir de la palette choisie.
- **Règle absolue (CLAUDE.md)** : toute couleur dans un widget doit passer par `context.palette.*`, jamais de `Color(0x...)` en dur. Des dérogations existent déjà dans le code (voir §8.5 point 3) — ne pas en ajouter de nouvelles, et corriger celles rencontrées si l'écran concerné est de toute façon retouché.
- Police arabe des versets : `GoogleFonts.scheherazadeNew` (utilisée dans `verse_display_card.dart` notamment), distincte de la police latine Lora utilisée pour le reste de l'UI.

---

## 10. Localisation & contenu

- **Toutes les chaînes UI** passent par la classe statique `S` (`lib/core/strings.dart`, ~290 lignes) — getters `S.xxx` retournant FR ou EN selon `S.locale` (`'fr'` par défaut), plus quelques fonctions paramétrées (`S.streakJours(n)`, `S.versetN(n, total)`, etc.). `S.locale` est synchronisé avec `AppState.locale` à l'initialisation (`main.dart`) et à chaque `AppState.setLocale()`.
- **Texte arabe du Coran** : jamais d'appel direct à `HafsService`/`WarshService` depuis un écran/widget — toujours via `VerseService` (`lib/services/verse_service.dart`), qui arbitre Hafs vs Warsh selon la `Riwaya` passée en paramètre. **Depuis le Sprint 8, Hafs (6236 versets) et Warsh (6214 versets) ont chacun leur propre numérotation native — ce n'est plus une hypothèse "texte différent, numérotation identique"** (fausse, voir §6). Source : QUL (Tarteel AI), Hafs explicitement crédité King Fahd Complex, Warsh moins explicitement sourcé (voir Backlog).
- **Données statiques** : `lib/core/quran_data.dart` contient id/noms (FR/AR) des 113 sourates (hors Al-Fatiha) — les comptes de versets/mots ne sont plus stockés ici depuis le Sprint 8 (riwaya-dépendants, injectés via `buildSourates()` depuis `HafsService`/`WarshService`, voir §6). Le regroupement par Hizb vient de `HizbMetadataService` (donnée QUL officielle), plus de l'ancienne estimation locale. `lib/core/hadith_data.dart` contient les hadiths motivants (rotation quotidienne déterministe via `hadithDuJour(date)`) et le hadith d'intention affiché sur la preview.
- **Prières** : les noms affichés passent par l'extension `PrayerL10n.displayName` (`lib/core/prayer_l10n.dart`), séparée du modèle `Prayer` pour ne pas polluer `models/` d'une dépendance à `S`.

---

## 11. Tests (`test/`)

**État réel au moment de la rédaction** : couverture encore partielle mais en nette amélioration depuis Phase 6 — 31 tests au total (contre 18 après Sprint 1).
- `test/widget_test.dart` — placeholder (`expect(true, isTrue)`), ne teste rien.
- `test/core/revision_engine_test.dart` — suite historique (100 lignes, 4 tests, testant `buildDayPlan` — inchangée par le découpage Sprint 2 en `selectDayUnits`/`distributeToRakaas`, voir §5.1, comportement identique confirmé par ces mêmes tests). **Ne couvre pas** : la règle no-repeat sourate par prière (`[S6-B]`), la répétition cyclique de `_expandToRakaas`, ni le shuffle déterministe.
- `test/core/freshness_engine_test.dart` (Phase 6 Sprint 1) : seuils 7/14 jours, plus un cas de clé générique non-`int` pour `computeAll<K>`.
- `test/core/streak_engine_test.dart` (Phase 6 Sprint 1) : verrouille l'algorithme extrait de l'ancien `HistoryService.currentStreak`, y compris le comportement contre-intuitif documenté en §5.3 (activité hier seule sans rien aujourd'hui → streak 0).
- **`test/services/ayah_facts_service_test.dart`** (Phase 6 Sprint 2, 11 tests) — première suite sur `AyahFactsService`, avec `sqflite_common_ffi` (voir prérequis ci-dessous, comblé ce sprint). Couvre le rituel check-in/check-out : `pendingDate` (gating, y compris l'exclusion du jour même — bug trouvé en revue de code), idempotence de `proposeUnits`, `setReach`/`isRangeReached`, `setCold`, `removeFromDayPlan`, `sealDay`, groupement de `dayFacts`.
- **`test/state/app_state_checkin_test.dart`** (Phase 6 Sprint 2, 3 tests) — première suite sur `AppState` (nécessite `TestWidgetsFlutterBinding.ensureInitialized()` + `HafsService.initialize()` réel via `rootBundle`, `AppState` construit `_sourates` dès son constructeur). Couvre le gating du moteur quotidien de bout en bout et `checkOut` (avancée du cycle, unité retirée au check-in ignorée plutôt que bloquante).
- **Piège de test découvert au Sprint 2** : `databaseFactoryFfi.getDatabasesPath()` résout un chemin par défaut **partagé** entre fichiers de test — `flutter test` lance les fichiers dans des process séparés mais qui peuvent écrire dans le même `history.db` s'ils tournent en parallèle. Les deux suites SQLite pointent chacune vers un répertoire temporaire dédié (`databaseFactory.setDatabasesPath(...)` dans `setUpAll`) plutôt que de compter sur des dates de test disjointes pour s'isoler — à reproduire pour toute nouvelle suite touchant `AyahFactsService`/`AppState`.

**Priorités si vous ajoutez des tests** (reprises de `test/CLAUDE.md`) :
1. `RevisionEngine` — pur Dart, zéro I/O, le plus critique et le moins couvert vu sa complexity réelle (voir "ne couvre pas" ci-dessus).
2. `sqflite_common_ffi` ajouté en dev_dependency au Sprint 2 (`AyahFactsService`/`AppState` désormais testables) — reste à couvrir : `StorageService` (`SharedPreferences.setMockInitialValues({})`).
3. **Sprint 8/Phase 6 (toujours non fait, signalé explicitement)** : la logique par-riwaya (`StorageService` clés préfixées + `migrateLegacyTrackData()`, `AyahFactsService` schéma v4, `AppState.setRiwaya`/`_loadTrackState`) n'a **aucun test de régression** malgré `sqflite_common_ffi` désormais disponible — zone non triviale (migration de schéma, guard `warshAvailable`) qui mériterait d'être en tête de liste de la prochaine session de tests.

Aucune lib de mock (mockito/mocktail) n'est dans `pubspec.yaml` — ne pas en ajouter tant qu'un test de service/`AppState` n'en a pas réellement besoin (règle anti-sur-ingénierie du projet).

**Avant de refactorer `RevisionEngine`, `FreshnessEngine` ou `StreakEngine`** : ces fichiers portent des règles métier actées sur plusieurs sprints sans filet de sécurité. Écrire un test de régression sur le comportement actuel avant tout changement plutôt que de se fier à une relecture manuelle — et le signaler explicitement si ce n'est pas fait (règle CLAUDE.md du projet).

Lancer les tests : `flutter test`.

---

## 12. Build & déploiement

CI/CD Codemagic connectée au dépôt via `codemagic.yaml` (workflow `ios-testflight`, `aelhirech/quran-revision`). **Un `git push` sur `main` déclenche automatiquement** : `flutter pub get` → signing (voir ci-dessous) → détermination du build number → `flutter build ipa --release` → publication TestFlight via l'API App Store Connect. C'est pourquoi la confirmation explicite avant push vers `main` (voir `CLAUDE.md`, section « Fin de sprint ») est désormais requise pour une vraie raison opérationnelle, pas seulement par prudence générale.

**Signing iOS** : mécanisme natif Codemagic (`environment.ios_signing`, `distribution_type: app_store`), pas de script manuel `fetch-signing-files` (abandonné — échouait de façon persistante avec « Cannot save Signing Certificates without certificate private key » même avec un compte Apple propre). Certificat de distribution et profil de provisioning générés manuellement (OpenSSL + upload CSR sur Apple Developer, profil App Store créé et téléchargé) puis uploadés dans Codemagic (Team settings → Code signing identities), référencés par `codemagic_certificate`.

**Build number automatique** : script `Determine next build number` résout l'Apple ID numérique de l'app via `app-store-connect apps list --bundle-id-identifier ... --json` (les commandes `get-latest-app-store-build-number`/`get-latest-testflight-build-number` exigent cet ID numérique, pas le bundle identifier) — échoue explicitement (`exit 1`) si cette résolution ne renvoie rien, plutôt que de continuer avec un ID invalide (bug vécu le 2026-08-29 : résolution ratée → les deux appels `get-latest-*` échouaient silencieusement → build number retombé à 1 alors que TestFlight avait déjà le build 3 → rejet App Store Connect). Prend le max entre App Store, TestFlight, **et le `+N` de `pubspec.yaml`** (plancher de sécurité), l'incrémente, et l'injecte via `--build-number` à `flutter build ipa`. Le `+N` dans `pubspec.yaml` (`version:`) reste par ailleurs le fallback pour les builds manuels via Xcode — la CI ne le modifie jamais.

Pas de pipeline Android à ce jour.

---

## 13. Règles d'architecture — résumé actionnable

Ces règles viennent de `CLAUDE.md` (racine et projet) ; ce document les documente avec leur *pourquoi* concret observé dans le code, pas seulement leur énoncé.

| Règle | Pourquoi ça compte ici |
|---|---|
| `lib/core/` : zéro import Flutter (sauf `app_colors.dart`/`app_theme.dart`), zéro I/O | `RevisionEngine`/`FreshnessEngine` doivent rester testables en pur Dart sans `WidgetTester` — c'est déjà le cas, ne pas régresser. |
| `lib/services/` : stateless, jamais de `notifyListeners` | Seule `AppState` doit notifier l'UI ; un service qui notifie casserait l'hypothèse « un seul `notifyListeners()` par opération logique ». |
| `AppState` : un seul `notifyListeners()` par opération logique | Déjà respecté dans le code actuel (`app_state.dart`) — vérifier en review qu'un nouveau setter ne notifie pas deux fois. |
| Modèles : mise à jour uniquement via `copyWith()` | `UserConfig.copyWith()` est le point d'entrée utilisé partout (onboarding excepté, qui construit un `UserConfig` neuf faute de config existante) — préserver ce pattern. |
| `if (!mounted) return;` après chaque `await` dans un `State` | Respecté quasi partout dans le code actuel (voir notes par écran en §8) — un des rares écarts trouvés est `learn_screen.dart`/`_loadStreak` qui utilise `if (mounted) setState(...)` (équivalent, style différent). `profile_screen.dart._showDurationDialog` avait un `setState` sans re-check `mounted` après un `await state.saveConfig(...)` — corrigé au Sprint 7. |
| Texte utilisateur → `lib/core/strings.dart` ; texte arabe → `VerseService` | `'✓ Complet'` en dur dans `learning_progress_card.dart` (texte, non traité). `verse_bottom_sheet.dart` appelait `package:quran` directement (`getSurahNameArabic`) au lieu de passer par `VerseService` — corrigé au Sprint 7 (`VerseService.surahNameArabic()` ajouté) ; plus aucun appel direct à `package:quran` hors `VerseService`/`WarshService`. |
| Couleurs → toujours `AppPalette` | Écarts connus listés en §8.5 point 3 — à ne pas reproduire. |

---

## 14. Index des fichiers (où trouver quoi)

| Je veux… | Fichier |
|---|---|
| Comprendre/modifier l'algorithme de distribution du plan du jour | `lib/core/revision_engine.dart` |
| Comprendre le calcul de fraîcheur (SRS léger) | `lib/core/freshness_engine.dart` |
| Comprendre le calcul de streak | `lib/core/streak_engine.dart` |
| Ajouter/modifier une chaîne affichée à l'utilisateur | `lib/core/strings.dart` |
| Modifier les couleurs/thème (Mus'haf/Tahajjud) | `lib/core/app_colors.dart`, `lib/core/app_theme.dart` |
| Changer les métadonnées d'une sourate (nb de mots, etc.) | `lib/core/quran_data.dart` |
| Comprendre l'état global et son cycle de vie | `lib/state/app_state.dart` |
| Modifier la persistance SharedPreferences | `lib/services/storage_service.dart` |
| Modifier le schéma/les requêtes SQLite (faits par verset, historique, streak, apprentissage profil principal) | `lib/services/ayah_facts_service.dart` |
| Changer le texte Hafs/Warsh affiché | `lib/services/verse_service.dart`, `lib/services/warsh_service.dart` |
| Modifier le wizard d'onboarding | `lib/screens/onboarding_screen.dart` |
| Modifier la sélection des prières / l'écran d'accueil de révision | `lib/screens/home_screen.dart` |
| Modifier l'affichage/la checklist du plan du jour | `lib/screens/plan_screen.dart` |
| Modifier le routage entre Home/Check-in/Check-out/Actif de l'onglet Réviser | `lib/widgets/day_plan_tab.dart` |
| Modifier le popup de check-in (édition du plan du jour) | `lib/screens/check_in_screen.dart` |
| Modifier le popup de check-out (scellement, rattrapage multi-jours) | `lib/screens/check_out_screen.dart` |
| Modifier le moteur quotidien / l'orchestration check-in/check-out | `lib/state/app_state.dart` (§7, section "Rituel check-in/check-out") |
| Modifier la pratique de mémorisation verset par verset | `lib/screens/learn_surah_screen.dart` |
| Modifier la liste d'apprentissage / le hand-off vers la révision | `lib/screens/learn_screen.dart` |
| Modifier l'édition de la configuration (sourates, rythme, reset) | `lib/screens/profile_screen.dart` |
| Modifier le dashboard de statistiques | `lib/screens/recap_screen.dart` |
| Modifier la navigation globale (4 onglets) | `lib/screens/shell_screen.dart` |
| Modifier les tests de régression du moteur de révision | `test/core/revision_engine_test.dart` |
| Modifier les tests de fraîcheur / streak | `test/core/freshness_engine_test.dart`, `test/core/streak_engine_test.dart` |
| Modifier les tests du rituel check-in/check-out | `test/services/ayah_facts_service_test.dart`, `test/state/app_state_checkin_test.dart` |
| Builder/distribuer l'app iOS | Xcode (`ios/Runner.xcworkspace`) — Archive → Distribute App, manuel |

---

## 15. Maintenir ce document

Ce document a été généré par une lecture complète du code source (tous les fichiers de `lib/`, `test/`, `pubspec.yaml`) à la date indiquée en fin de fichier — il n'est **pas** auto-généré à chaque build et **va driver avec le temps**, exactement comme `CHANGELOG.md` (voir la note d'expérience du 2026-08-20 dans `CLAUDE.md` du projet : une doc maintenue à la main a déjà divergé du dépôt réel par le passé).

- Après un sprint qui touche `RevisionEngine`, `FreshnessEngine`, `StreakEngine`, `AppState`, ou qui ajoute/supprime un écran/service : mettre à jour la section correspondante ici, en plus de `CHANGELOG.md`.
- Si vous (humain ou Claude) trouvez une divergence entre ce document et le code réel, corrigez ce document plutôt que de le laisser mentir — le code fait toujours foi.
- Les points de §8.5 (« dette technique identifiée ») doivent être retirés de la liste au fur et à mesure qu'ils sont corrigés, pas laissés indéfiniment.

*Dernière rédaction complète : 2026-08-22, à partir d'une lecture intégrale de `lib/` (8093 lignes) et de `test/`. Mise à jour le 2026-08-22 (même jour) pour refléter le Sprint 7 (`lib/` : 8860 lignes) et le retrait de `codemagic.yaml` (déploiement manuel via Xcode). Mise à jour le 2026-08-29 : `codemagic.yaml` réintroduit et rendu fonctionnel (signing + build number auto + publication TestFlight sur push `main`) — voir §12. Mise à jour le 2026-08-29 (Sprint 8) : source du texte coranique remplacée (QUL/Tarteel), Hafs/Warsh transformés en parcours de révision/mémorisation/historique indépendants (numérotation de versets réellement différente entre les deux riwayat) — §2, §6, §7, §10, §11 revus en conséquence. Mise à jour le 2026-08-30 (Phase 6 Sprint 1) : `HistoryService`/`LearningService` (profil principal) remplacés par `AyahFactsService`/table `ayah_facts` (granularité verset), `StreakEngine` extrait en pur Dart, `FreshnessEngine.computeAll` généralisé — §1, §5, §6, §7, §8.1, §8.3, §8.4, §8.5, §11, §14 revus en conséquence. Mise à jour le 2026-08-30 (Phase 6 Sprint 2) : rituel check-in/check-out — `RevisionEngine` éclaté en `selectDayUnits`/`distributeToRakaas`, `AppState` devient la seule source du plan du jour (`previewSession`/`todaySession` supprimés), `cyclePosition` n'avance plus qu'au check-out, nouveaux écrans `CheckInScreen`/`CheckOutScreen` — §5.1, §5.4, §6, §7, §8.1, §8.5, §11, §14 revus en conséquence.*

