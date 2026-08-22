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
- **Fraîcheur** (SRS léger) : indépendant du cycle, `FreshnessEngine` calcule depuis quand chaque sourate n'a pas été révisée (hot/cold/frozen) à partir de l'historique réel (`HistoryService`), pour afficher un badge d'alerte — pas pour piloter la distribution du plan.
- **Riwaya** : Hafs (par défaut) ou Warsh — change uniquement le texte arabe affiché, jamais la numérotation des versets ni la logique de distribution.

---

## 2. Stack & environnement

- **Flutter** (SDK Dart `^3.12.2`), Material 3, **Provider** (`ChangeNotifier`) comme unique gestion d'état — voir `[[pas-de-sur-ingenierie]]` dans CLAUDE.md, ne pas introduire Riverpod/Bloc/GetX.
- Pas de backend : toute la persistance est locale (`shared_preferences` + `sqflite`).
- Dépendances clés (`pubspec.yaml`) : `provider`, `shared_preferences`, `sqflite`, `flutter_local_notifications`, `flutter_animate`, `quran` (texte Hafs + métadonnées via `package:quran`), `google_fonts` (Lora/Amiri), `path`.
- Build/CI : Codemagic (`codemagic.yaml`) — un seul workflow `ios-testflight` (build signé + upload TestFlight + email de notif). Pas de workflow Android configuré à ce jour.
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
| `UserConfig` | `user_config.dart` | Configuration persistée de l'utilisateur — la source de vérité pour tout calcul de plan | voir §5.3 |
| `LearningProgress` | `learning_progress.dart` | Progression de mémorisation d'une sourate, verset par verset | `sourate`, `learnedVerses: Set<int>`, `startDate` ; `progress`, `isComplete`, `nextVerse` |
| `SessionRecord` | `session_record.dart` | Une entrée d'historique de session (table SQLite `sessions`) | `date`, `unitsCompleted`, `totalUnits`, `prayers` |
| `StudentProfile` | `student_profile.dart` | Un profil élève (multi-élèves, ex. un parent qui suit plusieurs enfants) | `id`, `name` |
| `Riwaya` (enum) | `riwaya.dart` | `hafs` \| `warsh` — n'affecte que le texte arabe affiché, jamais la numérotation | — |

**Piège connu** : `Sourate.fromJson` a un fallback `j['words'] ?? j['verses'] * 12` (ligne 29) pour la rétro-compatibilité avec d'anciennes données persistées sans champ `words`. Si vous ajoutez un champ à `Sourate`, prévoyez le même genre de fallback pour ne pas planter au chargement d'une config existante sur l'appareil d'un utilisateur.

---

## 5. Moteurs métier (`lib/core/`)

C'est le cœur de l'application et la zone la plus sensible : `test/CLAUDE.md` le confirme, ces fichiers portent des règles métier accumulées sur plusieurs sprints **sans filet de sécurité réel** (une seule suite de tests existe, sur `RevisionEngine`, voir §9). Toute modification ici doit être accompagnée d'un test de régression.

### 5.1 `RevisionEngine` (`lib/core/revision_engine.dart`)

Responsable de construire le plan du jour (`DailySession`) à partir de la config utilisateur et des prières sélectionnées. Algorithme en 4 étapes, dans l'ordre d'appel de `buildDayPlan()` :

**Étape 1 — `buildUnits()`** : transforme `List<SourateSelection>` en `List<RevisionUnit>`. Une sélection dont l'estimation de mots (`estimatedWords`) dépasse `_wordLimit = 150` (≈1 page Mushaf Madinah) est découpée en plusieurs unités de taille égale (`chunks = ceil(rangeWords / 150)`). En dessous du seuil, la sélection reste une unité entière.

**Étape 2 — sélection des unités du jour** : deux modes exclusifs pilotés par `UserConfig.paceByLines` :
- *Par durée* (par défaut) : `dailyTarget()` calcule `ceil(unitsLeft / daysRemaining)` — combien d'unités il faut traiter aujourd'hui pour finir le cycle dans les temps.
- *Par lignes/jour* : `_unitsForLines()` accumule les `estimatedLines` des unités (à partir de `cyclePosition`, cycliquement) jusqu'à dépasser `config.targetLinesPerDay`, et retourne le nombre d'unités nécessaires.

Le nombre d'unités du jour est ensuite plafonné à `cycleTotal` (on ne peut pas assigner plus d'unités qu'il n'en existe dans le cycle).

**Étape 3 — `_expandToRakaas()`** : subdivise encore les unités du jour pour remplir exactement `totalSuratRakaas` (somme des `Prayer.suratRakaas` des prières sélectionnées). Règles :
1. Une unité n'est subdivisée que si `slots > 1 ET verseCount > 1 ET estimatedLines / slots >= _minLinesPerSlot (5.0)` — on ne fragmente jamais en dessous de 5 lignes Mushaf, pour éviter des micro-portions absurdes.
2. Si après expansion il reste **moins** d'unités que de rakaas à remplir (cas où même sans subdiviser il n'y a pas assez de matière), **répétition cyclique** des unités déjà produites — jamais de rakaa vide pour cette raison. C'est une règle actée au Sprint 5 (voir CHANGELOG.md) : « pas de rakaas vides ».

**Étape 4 — assignation par prière avec règle no-repeat (Sprint 6, `[S6-B]`)** : pour chaque prière, pour chaque rakaa à voix haute (`r <= prayer.suratRakaas`), l'algorithme :
1. Cherche la prochaine unité **non consommée aujourd'hui** et pas déjà utilisée dans **cette même prière exacte** (clé `_unitKey = sourateId_verseStart_verseEnd`, donc deux plages différentes de la même sourate sont considérées distinctes — la contrainte porte sur la plage exacte de versets, pas juste le numéro de sourate).
2. Si tout a déjà été consommé aujourd'hui, réutilise une unité assignée ailleurs mais pas encore dans cette prière (pas idéal, mais pas une répétition intra-prière).
3. En tout dernier recours (tout a déjà été récité dans cette prière), répète — c'est la seule situation admise pour ne pas laisser de rakaa vide.
4. Les rakaas au-delà de `suratRakaas` (rakaas silencieuses, ex. les rakaas 3-4 du Dhouhr) reçoivent `RakaaAssignment(rakaaNumber: r)` sans unité — Al-Fatiha seule. **C'est la seule situation où une rakaa reste volontairement vide** — toute autre rakaa vide dans le résultat serait un bug.

**`advanceCycle()`** : fonction pure `(currentPosition + unitsCompleted) % cycleTotal` — c'est la **source unique de vérité** pour faire progresser `AppState._cyclePosition` ; ne jamais recalculer cette arithmétique ailleurs (AppState délègue explicitement, voir `app_state.dart:101`).

**Ordre aléatoire** : si `config.shuffleEnabled`, les unités sont mélangées avec `Random(config.startDate.millisecondsSinceEpoch)` — le shuffle est **déterministe** par date de démarrage, pas vraiment aléatoire à chaque appel. Ça garantit que rebuilder le même jour donne le même plan.

### 5.2 `FreshnessEngine` (`lib/core/freshness_engine.dart`)

Module pur et minimal (35 lignes) — SRS léger indépendant de `RevisionEngine`. `compute(lastRevised, today)` :
- `null` → `frozen` (jamais révisé)
- `< 7 jours` → `hot`
- `7–13 jours` → `cold`
- `>= 14 jours` → `frozen`

`today` est toujours injecté (jamais `DateTime.now()` en interne) pour rester testable — respecter ce pattern si vous étendez ce module.

### 5.3 `UserConfig` en détail (`lib/models/user_config.dart`)

C'est l'objet de configuration central, il mérite d'être détaillé séparément des autres modèles car quasiment toute la logique de `RevisionEngine` en dépend :

| Champ | Rôle |
|---|---|
| `selections: List<SourateSelection>` | Ce que l'utilisateur a choisi de réviser |
| `revisionDays` | Durée cible du cycle (mode « par durée »), presets `durationPresets = [7,14,21,30,60,90,180,365]` + valeur libre |
| `startDate` | Date de démarrage du cycle actuel — sert aussi de graine au shuffle déterministe |
| `shuffleEnabled` | Ordre aléatoire (déterministe par date) des unités dans le cycle |
| `adaptiveCycle` | Si activé, `AppState.refreshAdaptiveCycle` recalcule une estimation de durée depuis `HistoryService.avgUnitsPerDay()` — **affichage informatif seulement**, ne modifie pas `revisionDays` ni le calcul réel du plan (voir `effectiveDays()` qui retourne toujours `revisionDays` telle quelle, commentaire explicite ligne 34 : *« Révision intelligente uniquement — le cycle est toujours basé sur revisionDays »*) |
| `paceByLines` / `targetLinesPerDay` | Mode alternatif au calcul par durée, presets `linesPerDayPresets = [5,10,15,20,30,40,60]` |

**Piège** : `adaptiveCycle` est un peu trompeur au premier abord — on pourrait croire qu'il change le comportement de `RevisionEngine`, mais il ne fait que calculer un `_adaptiveCycleDays` affiché dans l'UI (`AppState.adaptiveCycleDays` getter) pour informer l'utilisateur, sans jamais réinjecter cette valeur dans `buildDayPlan()`. Si un ticket demande de le rendre réellement adaptatif, c'est un changement de comportement, pas un bugfix.

---

## 6. Services (`lib/services/`)

Tous stateless, méthodes `static`, aucun `notifyListeners`. C'est la seule couche qui touche à l'I/O.

| Service | Support | Rôle |
|---|---|---|
| `StorageService` | SharedPreferences | Persiste `UserConfig`, `cyclePosition`, `locale`, `notifEnabled`, `previewSession`/`todaySession` (avec expiration au changement de jour, voir `_sessionOrNullIfStale`), `pauseDates`, `riwaya`. Clés préfixées `_key*`. |
| `HistoryService` | sqflite (`history.db`, v2) | Table `sessions` (une ligne par jour, upsert via delete+insert) et `sourate_sessions` (PK composite `date+sourate_id`, pour la fraîcheur par sourate). Calcule `currentStreak()` (jours consécutifs, pauses ignorées sans casser la série, cap 30 jours sautés d'affilée), `totalSessionDays()`, `avgUnitsPerDay()` (moyenne sur les 14 dernières sessions par défaut). |
| `LearningService` | SharedPreferences | Progression de mémorisation pour l'utilisateur principal (`learning_progress_v1`) — CRUD simple (`loadAll`/`saveAll`/`upsert`/`remove`). |
| `StudentService` | SharedPreferences | Idem mais multi-profils : `student_profiles_v1` + une clé `learning_progress_{profileId}_v1` par élève. Supprimer un profil nettoie aussi sa progression associée. |
| `NotificationService` | `flutter_local_notifications` | Deux notifs quotidiennes récurrentes (`RepeatInterval.daily`) : rappel matin (id 1) et bilan soir (id 2), heures configurables. Toutes les erreurs sont catch+debugPrint, jamais propagées — une notif qui échoue à se programmer ne doit pas crasher l'app. |
| `VerseService` | `package:quran` + `WarshService` | **Point d'entrée unique** pour le texte arabe affiché — arbitre Hafs/Warsh selon le `Riwaya` passé en paramètre. Ne jamais appeler `package:quran` directement depuis un écran. |
| `WarshService` | asset `assets/quran/warsh.json` | Charge une fois (`_data` en cache statique) le texte Warsh depuis l'asset bundlé. Source : dataset ouvert `fawazahmed0/quran-api`, édition `ara-quranwarsh`, licence Unlicense — **non un texte certifié**, à garder en tête si un utilisateur signale une variante (note déjà présente dans CHANGELOG.md, reprise ici car importante). |

### Base de données SQLite (`HistoryService`)

```sql
CREATE TABLE sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,             -- YYYY-MM-DD
  units_completed INTEGER NOT NULL,
  total_units INTEGER NOT NULL,
  prayers TEXT NOT NULL           -- noms de Prayer joints par virgule
);

CREATE TABLE sourate_sessions (   -- ajoutée en v2 (onUpgrade)
  date TEXT NOT NULL,
  sourate_id INTEGER NOT NULL,
  PRIMARY KEY (date, sourate_id)
);
```

Si vous ajoutez une table ou colonne, incrémentez `version` dans `_open()` et ajoutez la migration dans `onUpgrade` — ne modifiez jamais `onCreate` seul (les utilisateurs existants ne repasseront pas par `onCreate`).

---

## 7. `AppState` (`lib/state/app_state.dart`)

Unique `ChangeNotifier` de l'app, injecté à la racine via `ChangeNotifierProvider` (`main.dart`). Tient l'état runtime et délègue tout calcul/persistance aux engines/services — **ne contient pas de logique métier elle-même**, seulement de l'orchestration.

État tenu : `_config` (UserConfig?), `_cyclePosition`, `_previewSession`/`_todaySession` (DailySession?), `_pauseDates`, `_locale`, `_riwaya`, `_adaptiveCycleDays`, `_freshness` (Map sourateId→FreshnessLevel).

Méthodes notables :
- `saveConfig()` — remplace toute la config **et réinitialise le cycle à zéro** (`_cyclePosition = 0`, sessions effacées). C'est intentionnel (nouvelle sélection = nouveau cycle) mais destructif — les écrans qui appellent ça (édition des sourates, réinitialisation) doivent avertir l'utilisateur avant (voir `modifierPlanConfirm` / `reinitConfirm` dans `strings.dart`).
- `advanceCycle(unitsCompleted, cycleTotal)` — délègue à `RevisionEngine.advanceCycle`, ne recalcule jamais l'arithmétique ici.
- `setPreviewSession()` — après avoir sauvegardé la preview, lance `refreshFreshness().catchError((_) {})` en arrière-plan (fire-and-forget volontaire : si la DB échoue, les badges de fraîcheur sont simplement absents, pas de crash).
- `engager()` — transforme la `previewSession` en `todaySession` (c'est l'action du bouton « S'engager »).
- `refreshAdaptiveCycle()` — no-op silencieux si `adaptiveCycle` est désactivé ou `totalUnits <= 0` ; ne fait qu'informer l'affichage (voir piège §5.3).
- `clearConfig()` — reset complet, y compris `StorageService.clear()` (efface **tout** SharedPreferences, pas seulement la config).

**Piège** : `saveConfig`, `clearConfig` et le flux d'édition des sourates dans `profile_screen.dart` réinitialisent `_cyclePosition` à 0 — sauf le fix Sprint 6 `[S6-A]` qui a spécifiquement préservé `startDate` lors de l'édition des sourates pour éviter de reset silencieusement toute la progression. Si vous touchez à ce flux, vérifiez que ce fix n'est pas régressé.

---

## 8. Écrans et navigation (`lib/screens/`, `lib/widgets/`)

> Cette section est complétée en §8.1–8.4 ci-dessous par une analyse fichier par fichier (générée à partir d'une lecture complète du code, y compris pour les composants dont le rôle n'est pas évident au premier coup d'œil).

### Structure générale

`main.dart` choisit entre `OnboardingScreen` (si `AppState.config == null`) et `ShellScreen` (sinon), sous un `MaterialApp` avec `ThemeMode.system` (suit le thème clair/sombre de l'OS — direction artistique Mus'haf/Tahajjud, voir §10).

`ShellScreen` est un `IndexedStack` à 4 onglets, tous montés en permanence (l'état de chaque onglet survit à la navigation) : `0 = DayPlanTab` (« Réviser »), `1 = RecapScreen`, `2 = LearnScreen` (« Apprendre »), `3 = ProfileScreen`.

### 8.1 Flux « Réviser » — Home / Shell / Plan

**`DayPlanTab` (`widgets/day_plan_tab.dart`) est un routeur, pas un écran.** Stateless, il inspecte `AppState.todaySession`/`previewSession` et choisit :
1. Ni l'un ni l'autre → `HomeScreen` (sélection des prières).
2. `previewSession` défini → `PlanScreen(isPreview: true)`.
3. `todaySession` défini → `PlanScreen(isPreview: false)` (checklist active).

Flux complet : `HomeScreen` (« Voir le plan du jour ») → `AppState.setPreviewSession()` → `PlanScreen` preview (« S'engager ») → `AppState.engager()` (promeut preview → todaySession) → `PlanScreen` actif (checklist) → complétion → `DayPlanTab._onComplete()` → `AppState.clearTodaySession()` → retour à `HomeScreen`.

**`HomeScreen`** — sélection des prières récitées seul (`_prayersAlone: Set<Prayer>`) + compteur d'entrées à la mosquée (`_tahiyyatCount`, chaque entrée = une occurrence dupliquée de `Prayer.tahiyyatMasjid` dans `_effectivePrayers`). Bouton « Voir le plan du jour » appelle `RevisionEngine.buildDayPlan()` puis `onVoirPlan`. **Attention** : `build()` recalcule indépendamment `units`, `cycleTotal`, `pos`, `daysRemaining` à partir de `RevisionEngine.buildUnits()` — cette arithmétique de cycle est dupliquée à plusieurs endroits de l'UI (voir §8.5), pas seulement centralisée dans l'engine/AppState.

**`PlanScreen`** — écran unique réutilisé pour la preview (lecture seule) et la session active (checklist), distingués par le flag `isPreview`. Points métier intégrés à l'UI (donc absents de `RevisionEngine`, à connaître avant de les modifier) :
- **Modal d'engagement** (`_CommitmentSheet`, non-dismissible) : force l'utilisateur à déclarer « Tout fait / Une part / Rien fait » avant d'abandonner un plan actif. Le nombre de rakaas par défaut en mode « Une part » est `(totalRakaas / 2).round().clamp(1, totalRakaas)` — règle ad-hoc locale à ce widget.
- **`_StreakBadge`** : paliers de streak codés en dur — `1` (« premier jour »), `7`/`30`/`100` (« nouveau palier ») — n'existent nulle part ailleurs, à dupliquer manuellement si un autre écran doit les afficher.
- **Streak anticipé** : `HistoryService.currentStreak() + 1` à l'écran de complétion, pour anticiper la session du jour pas encore enregistrée en DB au moment de l'affichage.
- `_FocusMosqueeScreen` (mode focus plein écran) utilise des couleurs codées en dur (`Color(0xFF0E1410)` etc.) au lieu de `AppPalette` — **déroge à la règle CLAUDE.md « couleurs toujours via AppPalette »**, à corriger si cet écran est retouché.

**`DayPlanTab._onComplete()`** est le pipeline de complétion de session (le point le plus sensible de ce groupe de fichiers) :
1. Calcule `cycleWraps` (le cycle boucle-t-il avec cette session ?) — **logique dupliquée localement**, pas exposée par `AppState`/`RevisionEngine`.
2. Capture `now` une seule fois (évite un décalage si minuit survient pendant le flux).
3. Extrait les `sourateId` de la session pour alimenter l'historique de fraîcheur.
4. Enchaîne séquentiellement : `AppState.advanceCycle()` → `refreshAdaptiveCycle(notify: false)` → `HistoryService.recordSession()` + `recordSourateHistory()` → `refreshFreshness(notify: false)`.
5. Si le cycle boucle, affiche `_CycleMilestoneDialog` (non-dismissible).
6. `AppState.clearTodaySession()`.

La saisie manuelle (`ManualSessionSheet`, stepper 1..maxUnits) suit le même pipeline `advanceCycle → refreshAdaptiveCycle → refreshFreshness`, mais avec `prayers: const []` (aucune prière associée).

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

**Connexion révision ↔ apprentissage** (le point le plus important pour la maintenance) : quand `LearningProgress.isComplete` (tous les versets appris), `LearnSurahScreen` propose « Ajouter à la révision ». Ce n'est **pas automatique côté engine** — c'est un hand-off piloté par l'UI : `LearnScreen._addToRevision()` ajoute `SourateSelection.whole(s)` à `UserConfig.selections` via `AppState.saveConfig()`, **puis** supprime l'entrée de `LearningService`. Une sourate passe donc du domaine « apprentissage » au domaine « révision » comme une opération UI atomique, jamais déclenchée depuis `core/`. Cette action n'est proposée que pour le profil principal (`_activeStudentId == null`) — un profil élève ne peut pas alimenter la config de révision du parent.

**Sélecteur de bloc (`[B] Apprentissage multi-versets`)** : `SegmentedButton<int>` à 3 valeurs fixes `{1, 3, 5}`. `_currentBlock` calcule les N prochains versets *non appris* en ordre croissant (pas nécessairement `nextVerse` si des versets ont été désappris hors séquence).

**Duplication identifiée** : `learn_surah_screen.dart` construit son propre bloc de hadith de clôture (`_closingHadith`, appelle `hadithDuJour()` directement) et son propre badge de streak inline (`_streakBadge`), plutôt que de réutiliser les widgets `HadithCard`/`StreakCard` qui existent déjà et font la même chose ailleurs dans l'app. Si le format d'affichage du hadith ou du streak doit changer, il faut le faire aux deux endroits.

**Petits écarts aux conventions repérés** : `learning_progress_card.dart` affiche `'✓ Complet'` en chaîne française codée en dur (pas via `S.`), et utilise `Colors.red.shade100`/`Colors.red` directement au lieu de `AppPalette` pour la couleur de suppression.

### 8.4 Profil, Récap, Réglages

**`ProfileScreen`** est la **seule surface d'édition** de `UserConfig` : sélection des sourates (mode édition plein écran), rythme (dialog dédié avec `PresetDropdown`), cycle adaptatif, pause du jour, et réinitialisation complète (irréversible, `AppState.clearConfig()`). En sauvegardant une nouvelle sélection de sourates, les sourates déjà cochées **conservent leur plage de versets existante** (`existingSelections[s.id] ?? SourateSelection.whole(s)`) — seules les sourates nouvellement cochées deviennent des sélections « entières ».

**`SettingsCard`** (imbriqué dans `ProfileScreen`) : langue, riwaya, shuffle (tous via `AppState`), et notifications — dont l'état (`notif_enabled`) est stocké **directement dans `StorageService`**, hors de `UserConfig`, donc **il survit à `AppState.clearConfig()`** (réinitialisation du profil). À savoir avant de supposer qu'un « reset complet » efface vraiment tout.

**`RecapScreen`** est en lecture seule (streak, position de cycle, répartition sourates, historique 7 jours). Piège à connaître : la carte de répartition (`enRevision`/`memorisees`/`enCours`) combine deux sources de données indépendantes (`UserConfig.selections` vs `LearningProgress`) qui **ne sont pas mutuellement exclusives** — une sourate peut compter à la fois « en révision » et « mémorisée », la carte ne réconcilie pas les deux. `HistoryCard` reçoit 14 sessions mais n'en affiche que les 7 premières (`sessions.take(7)`) — écart entre ce que demande l'appelant et ce que le widget restitue, à clarifier si quelqu'un y touche.

**`StudentProfileBar`** (onglet Apprendre, pas Profil) : la suppression d'un profil élève se fait par **un simple appui long, sans aucune confirmation** dans toute la chaîne d'appel (`student_profile_bar.dart` → `learn_screen.dart:_deleteStudent`). C'est l'action la plus dangereuse identifiée dans toute la couche UI — à corriger en priorité si le sujet de la robustesse UX revient.

**Écart de convention** : `sourates_recap_card.dart` utilise `Colors.white` en dur pour le fond de carte au lieu de `context.palette.surfaceCard` — casse probablement l'apparence en thème sombre (Tahajjud).

### 8.5 Dette technique UI identifiée (à garder à l'esprit, pas à corriger d'office)

Cette liste consolide ce que l'analyse fichier-par-fichier a fait remonter — utile pour prioriser un futur nettoyage, mais **ne pas corriger silencieusement en marge d'une autre tâche** (règle CLAUDE.md « changements chirurgicaux »).

1. **Arithmétique de cycle dupliquée** dans `home_screen.dart`, `plan_screen.dart` (`_summaryBar`), `recap_screen.dart` et `day_plan_tab.dart` (`cycleWraps`) — chacun recalcule `pos`/`cycleTotal`/`daysRemaining` ou la détection de bouclage indépendamment plutôt que de consommer une valeur unique exposée par `AppState`/`RevisionEngine`.
2. **Magic numbers métier hors de `core/`** : seuil 80% « bonne journée » répété 5 fois dans `history_card.dart` ; paliers de streak 1/7/30/100 dans `plan_screen.dart` ; plafond de 5 entrées Tahiyyat dans `prayer_selector.dart` ; règle « moitié des rakaas par défaut » dans `_CommitmentSheet`.
3. **Couleurs codées en dur** (déroge à la règle `AppPalette`) : `_FocusMosqueeScreen` (plan_screen.dart), `sourates_recap_card.dart`, `learning_progress_card.dart`.
4. **Chaîne hors `S.`** : `'✓ Complet'` dans `learning_progress_card.dart`.
5. **Composants dupliqués plutôt que réutilisés** : hadith de clôture et badge de streak réimplémentés dans `learn_surah_screen.dart` au lieu de `HadithCard`/`StreakCard` ; filtre de recherche sourate dupliqué entre `OnboardingScreen` et `SouratePickerSheet`.
6. **Confirmation manquante** : suppression d'un profil élève (`StudentProfileBar` → appui long direct, aucun dialog).
7. **Mismatch appelant/widget** : `HistoryCard` reçoit 14 sessions, n'en affiche que 7.
8. **Libellé ambigu** : « Sourates mémorisées » dans `ProfileInfoCard` compte en réalité `config.selections.length` (sourates en révision), pas les sourates réellement mémorisées via `LearningProgress.isComplete` — à ne pas confondre avec le calcul distinct de `RecapScreen`.

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
- **Texte arabe du Coran** : jamais d'appel direct à `package:quran` depuis un écran/widget — toujours via `VerseService` (`lib/services/verse_service.dart`), qui arbitre Hafs (`package:quran`, par défaut) vs Warsh (`WarshService`, asset local `assets/quran/warsh.json`). La numérotation des versets est identique entre les deux éditions ; seul le texte diffère.
- **Source Warsh** : dataset ouvert `fawazahmed0/quran-api`, édition `ara-quranwarsh`, licence Unlicense — **non un texte certifié**. À garder en tête si un utilisateur signale une variante inhabituelle.
- **Données statiques** : `lib/core/quran_data.dart` contient les 113 sourates (hors Al-Fatiha, récitée automatiquement à chaque rakaa) avec compte de mots, plus `sourateHizbMap` (calculé une fois au chargement depuis la position cumulative des versets). `lib/core/hadith_data.dart` contient les hadiths motivants (rotation quotidienne déterministe via `hadithDuJour(date)`) et le hadith d'intention affiché sur la preview.
- **Prières** : les noms affichés passent par l'extension `PrayerL10n.displayName` (`lib/core/prayer_l10n.dart`), séparée du modèle `Prayer` pour ne pas polluer `models/` d'une dépendance à `S`.

---

## 11. Tests (`test/`)

**État réel au moment de la rédaction** (voir aussi `test/CLAUDE.md`, à lire avant tout travail dans ce dossier) : **couverture quasi nulle**.
- `test/widget_test.dart` — placeholder (`expect(true, isTrue)`), ne teste rien.
- `test/core/revision_engine_test.dart` — seule suite réelle (100 lignes, 3 tests) : vérifie qu'un seul cycle de 3 unités sur 30 jours ne planifie qu'une unité/jour (mode « par durée »), et deux cas du mode « par lignes/jour » (accumulation d'unités jusqu'au seuil, avancée cyclique depuis un `cyclePosition` non nul). **Ne couvre pas** : la règle no-repeat sourate par prière (`[S6-B]`), la répétition cyclique de `_expandToRakaas`, le shuffle déterministe, ni `FreshnessEngine`.

**Priorités si vous ajoutez des tests** (reprises de `test/CLAUDE.md`) :
1. `RevisionEngine` — pur Dart, zéro I/O, le plus critique et le moins couvert vu sa complexity réelle.
2. `FreshnessEngine` — pur Dart également, trivial à tester.
3. Services (`SharedPreferences.setMockInitialValues({})` pour le storage ; `sqflite` n'a **pas** de lib de mock installée — ajouter `sqflite_common_ffi` en dev_dependency serait un prérequis avant de tester `HistoryService`).

Aucune lib de mock (mockito/mocktail) n'est dans `pubspec.yaml` — ne pas en ajouter tant qu'un test de service/`AppState` n'en a pas réellement besoin (règle anti-sur-ingénierie du projet).

**Avant de refactorer `RevisionEngine` ou `FreshnessEngine`** : ces fichiers portent des règles métier actées sur plusieurs sprints sans filet de sécurité. Écrire un test de régression sur le comportement actuel avant tout changement plutôt que de se fier à une relecture manuelle — et le signaler explicitement si ce n'est pas fait (règle CLAUDE.md du projet).

Lancer les tests : `flutter test`.

---

## 12. CI/CD

`codemagic.yaml` — un seul workflow, `ios-testflight` :
- `flutter pub get` → `flutter build ipa --release` (signature App Store via `ios_signing.distribution_type: app_store`) → publication automatique sur TestFlight (groupe bêta « External Testers ») → email de notification (succès/échec) à l'adresse du mainteneur.
- **Aucun workflow Android** n'est configuré à ce jour — un build/déploiement Android nécessiterait d'ajouter un workflow dédié.
- `max_build_duration: 60` (minutes).

---

## 13. Règles d'architecture — résumé actionnable

Ces règles viennent de `CLAUDE.md` (racine et projet) ; ce document les documente avec leur *pourquoi* concret observé dans le code, pas seulement leur énoncé.

| Règle | Pourquoi ça compte ici |
|---|---|
| `lib/core/` : zéro import Flutter (sauf `app_colors.dart`/`app_theme.dart`), zéro I/O | `RevisionEngine`/`FreshnessEngine` doivent rester testables en pur Dart sans `WidgetTester` — c'est déjà le cas, ne pas régresser. |
| `lib/services/` : stateless, jamais de `notifyListeners` | Seule `AppState` doit notifier l'UI ; un service qui notifie casserait l'hypothèse « un seul `notifyListeners()` par opération logique ». |
| `AppState` : un seul `notifyListeners()` par opération logique | Déjà respecté dans le code actuel (`app_state.dart`) — vérifier en review qu'un nouveau setter ne notifie pas deux fois. |
| Modèles : mise à jour uniquement via `copyWith()` | `UserConfig.copyWith()` est le point d'entrée utilisé partout (onboarding excepté, qui construit un `UserConfig` neuf faute de config existante) — préserver ce pattern. |
| `if (!mounted) return;` après chaque `await` dans un `State` | Respecté quasi partout dans le code actuel (voir notes par écran en §8) — un des rares écarts trouvés est `learn_screen.dart`/`_loadStreak` qui utilise `if (mounted) setState(...)` (équivalent, style différent). |
| Texte utilisateur → `lib/core/strings.dart` ; texte arabe → `VerseService` | Deux écarts connus à ce jour : `'✓ Complet'` en dur dans `learning_progress_card.dart` (texte), et aucun appel direct à `package:quran` détecté hors `VerseService`/`WarshService` (texte arabe respecté). |
| Couleurs → toujours `AppPalette` | Écarts connus listés en §8.5 point 3 — à ne pas reproduire. |

---

## 14. Index des fichiers (où trouver quoi)

| Je veux… | Fichier |
|---|---|
| Comprendre/modifier l'algorithme de distribution du plan du jour | `lib/core/revision_engine.dart` |
| Comprendre le calcul de fraîcheur (SRS léger) | `lib/core/freshness_engine.dart` |
| Ajouter/modifier une chaîne affichée à l'utilisateur | `lib/core/strings.dart` |
| Modifier les couleurs/thème (Mus'haf/Tahajjud) | `lib/core/app_colors.dart`, `lib/core/app_theme.dart` |
| Changer les métadonnées d'une sourate (nb de mots, etc.) | `lib/core/quran_data.dart` |
| Comprendre l'état global et son cycle de vie | `lib/state/app_state.dart` |
| Modifier la persistance SharedPreferences | `lib/services/storage_service.dart` |
| Modifier le schéma/les requêtes SQLite (historique, streak) | `lib/services/history_service.dart` |
| Changer le texte Hafs/Warsh affiché | `lib/services/verse_service.dart`, `lib/services/warsh_service.dart` |
| Modifier le wizard d'onboarding | `lib/screens/onboarding_screen.dart` |
| Modifier la sélection des prières / l'écran d'accueil de révision | `lib/screens/home_screen.dart` |
| Modifier l'affichage/la checklist du plan du jour | `lib/screens/plan_screen.dart` |
| Modifier le routage entre Home/Preview/Actif de l'onglet Réviser | `lib/widgets/day_plan_tab.dart` |
| Modifier la pratique de mémorisation verset par verset | `lib/screens/learn_surah_screen.dart` |
| Modifier l'édition de la configuration (sourates, rythme, reset) | `lib/screens/profile_screen.dart` |
| Modifier le dashboard de statistiques | `lib/screens/recap_screen.dart` |
| Modifier la navigation globale (4 onglets) | `lib/screens/shell_screen.dart` |
| Modifier les tests de régression du moteur de révision | `test/core/revision_engine_test.dart` |
| Modifier le pipeline de build/déploiement iOS | `codemagic.yaml` |

---

## 15. Maintenir ce document

Ce document a été généré par une lecture complète du code source (tous les fichiers de `lib/`, `test/`, `codemagic.yaml`, `pubspec.yaml`) à la date indiquée en fin de fichier — il n'est **pas** auto-généré à chaque build et **va driver avec le temps**, exactement comme `CHANGELOG.md` (voir la note d'expérience du 2026-08-20 dans `CLAUDE.md` du projet : une doc maintenue à la main a déjà divergé du dépôt réel par le passé).

- Après un sprint qui touche `RevisionEngine`, `FreshnessEngine`, `AppState`, ou qui ajoute/supprime un écran/service : mettre à jour la section correspondante ici, en plus de `CHANGELOG.md`.
- Si vous (humain ou Claude) trouvez une divergence entre ce document et le code réel, corrigez ce document plutôt que de le laisser mentir — le code fait toujours foi.
- Les points de §8.5 (« dette technique identifiée ») doivent être retirés de la liste au fur et à mesure qu'ils sont corrigés, pas laissés indéfiniment.

*Dernière rédaction complète : 2026-08-22, à partir d'une lecture intégrale de `lib/` (8093 lignes) et de `test/`.*

