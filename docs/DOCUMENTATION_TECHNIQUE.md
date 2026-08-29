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
| `riwaya` (Sprint 8) | Auto-descriptif — le parcours (`StorageService`) sous lequel ce `UserConfig` est déjà stocké détermine en pratique la riwaya ; ce champ sert surtout de défaut `Riwaya.hafs` pour les anciens `UserConfig` persistés sans ce champ (installations pré-Sprint 8) |

**Piège** : `adaptiveCycle` est un peu trompeur au premier abord — on pourrait croire qu'il change le comportement de `RevisionEngine`, mais il ne fait que calculer un `_adaptiveCycleDays` affiché dans l'UI (`AppState.adaptiveCycleDays` getter) pour informer l'utilisateur, sans jamais réinjecter cette valeur dans `buildDayPlan()`. Si un ticket demande de le rendre réellement adaptatif, c'est un changement de comportement, pas un bugfix.

---

## 6. Services (`lib/services/`)

Tous stateless, méthodes `static`, aucun `notifyListeners`. C'est la seule couche qui touche à l'I/O.

**Depuis le Sprint 8, Hafs et Warsh sont deux parcours indépendants** (profil principal uniquement — les profils élèves restent à parcours unique, voir §7) : `StorageService`, `LearningService` et `HistoryService` prennent tous un paramètre `Riwaya` explicite et scopent leurs clés/lignes en conséquence. Rien n'est jamais traduit d'un parcours vers l'autre — voir le piège en fin de section.

| Service | Support | Rôle |
|---|---|---|
| `StorageService` | SharedPreferences | Persiste `UserConfig`, `cyclePosition`, `previewSession`/`todaySession` (expiration au changement de jour, `_sessionOrNullIfStale`), `pauseDates`, `checkedRakaas` — ces 6 clés sont préfixées par riwaya (`_track(base, riwaya)`, factorisé dans `riwaya_key.dart`, partagé avec `LearningService`). `locale`, `notifEnabled`, `riwaya` (la riwaya *active*, pas les données d'un parcours), `tourSeen` restent des préférences globales non préfixées. `migrateLegacyTrackData()` — migration one-shot des installations pré-Sprint 8 : renomme les 6 anciennes clés non préfixées vers le parcours Hafs (elles étaient déjà implicitement numérotées en Hafs). |
| `HistoryService` | sqflite (`history.db`, v3 depuis Sprint 8) | Table `sessions` (une ligne par jour+riwaya, upsert via delete+insert) et `sourate_sessions` (PK composite `date+sourate_id+riwaya`, pour la fraîcheur par sourate). Toutes les méthodes (`recordSession`, `recordSourateHistory`, `currentStreak`, `totalSessionDays`, `lastRevisionDates`, `avgUnitsPerDay`) prennent `riwaya` en paramètre requis et filtrent dessus. |
| `LearningService` | SharedPreferences | Progression de mémorisation du profil principal — une clé par riwaya (`learning_progress_v1_hafs`/`_warsh`) depuis Sprint 8. CRUD simple (`loadAll`/`saveAll`/`upsert`/`remove`), toutes prennent `riwaya`. |
| `StudentService` | SharedPreferences | Idem mais multi-profils : `student_profiles_v1` + une clé `learning_progress_{profileId}_v1` par élève — **volontairement non séparé par riwaya** (choix Sprint 8 : les profils élèves restent un seul parcours, quelle que soit la riwaya active ; limitation acceptée, pas un oubli). Supprimer un profil nettoie aussi sa progression associée. |
| `NotificationService` | `flutter_local_notifications` | Deux notifs quotidiennes récurrentes (`RepeatInterval.daily`) : rappel matin (id 1) et bilan soir (id 2), heures configurables. Toutes les erreurs sont catch+debugPrint, jamais propagées — une notif qui échoue à se programmer ne doit pas crasher l'app. |
| `VerseService` | `HafsService` + `WarshService` | **Point d'entrée unique** pour le texte arabe affiché, `verseCount`/`wordCount` riwaya-aware — arbitre Hafs/Warsh selon le `Riwaya` passé en paramètre. Ne jamais appeler `HafsService`/`WarshService` directement depuis un écran. Formate elle-même le chiffre arabe-indien de fin de verset (`verseEndSymbol`, défaut `true`) — plus de dépendance à `package:quran` (retiré Sprint 8). |
| `HafsService` / `WarshService` | assets `assets/quran/hafs.json` / `warsh.json` | Chargent le texte + calculent `verseCounts`/`wordCounts` par sourate (une fois, en cache statique). Implémentation partagée dans `QuranTextAsset` (`quran_text_asset.dart`) — les deux classes ne sont que de fines façades statiques paramétrées par le chemin d'asset. Source Sprint 8 : QUL (Tarteel AI) — Hafs explicitement crédité King Fahd Complex sur la page de la ressource ; Warsh moins explicitement sourcé (piste ouverte au backlog) mais plateforme bien mieux maintenue que l'ancien dataset communautaire. **Hafs et Warsh ont chacun leur propre numérotation native** (6236 vs 6214 versets au total, frontières de versets différentes sur ~50 sourates) — ce n'est pas juste un texte différent sur la même grille. |
| `HizbMetadataService` | asset `assets/quran/metadata/quran-metadata-hizb.json` | `surahStartHizb` : numéro de Hizb où commence chaque sourate, donnée QUL officielle (remplace l'ancienne estimation par position cumulative de `quran_data.dart`). Retombe sur `{}` si jamais initialisé/échec de chargement — purement cosmétique (groupement dans l'onboarding), ne doit jamais bloquer le boot. |

### Base de données SQLite (`HistoryService`)

```sql
CREATE TABLE sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,             -- YYYY-MM-DD
  units_completed INTEGER NOT NULL,
  total_units INTEGER NOT NULL,
  prayers TEXT NOT NULL,          -- noms de Prayer joints par virgule
  riwaya TEXT NOT NULL            -- ajouté en v3
);

CREATE TABLE sourate_sessions (   -- ajoutée en v2, PK élargie en v3 (rebuild table)
  date TEXT NOT NULL,
  sourate_id INTEGER NOT NULL,
  riwaya TEXT NOT NULL,
  PRIMARY KEY (date, sourate_id, riwaya)
);
```

Si vous ajoutez une table ou colonne, incrémentez `version` dans `_open()` et ajoutez la migration dans `onUpgrade` — ne modifiez jamais `onCreate` seul (les utilisateurs existants ne repasseront pas par `onCreate`). Élargir une PRIMARY KEY n'est pas exprimable via `ALTER TABLE` en SQLite : suivre le pattern v2→v3 (créer la table `_new` avec la bonne PK, `INSERT ... SELECT`, `DROP`, `RENAME`).

**Piège (Sprint 8)** : un verset "appris" ou "sélectionné" en Hafs n'est pas le même contenu mémorisé qu'en Warsh (texte différent, numérotation différente) — traduire un index ou une plage de versets d'un parcours vers l'autre n'a pas de sens, même approximativement. C'est pourquoi Hafs/Warsh sont deux parcours **complètement indépendants** plutôt qu'un mapping de numérotation (une piste explorée puis abandonnée — voir CHANGELOG Sprint 8). Ne jamais réintroduire de logique qui suppose qu'un `verseStart`/`verseEnd` garde son sens en changeant de riwaya.

---

## 7. `AppState` (`lib/state/app_state.dart`)

Unique `ChangeNotifier` de l'app, injecté à la racine via `ChangeNotifierProvider` (`main.dart`). Tient l'état runtime et délègue tout calcul/persistance aux engines/services — **ne contient pas de logique métier elle-même**, seulement de l'orchestration.

État tenu : `_config` (UserConfig?), `_cyclePosition`, `_previewSession`/`_todaySession` (DailySession?), `_pauseDates`, `_locale`, `_riwaya`, `warshAvailable` (bool, immuable pour la durée du process — Warsh a-t-il pu charger au boot), `_hasSeenTour` (Sprint 8, voir plus bas), `_sourates` (Sprint 8, `List<Sourate>` riwaya-aware — remplace l'usage direct de `quran_data.allSourates`, désormais dépourvue de comptes verses/words), `_adaptiveCycleDays`, `_freshness` (Map sourateId→FreshnessLevel), `_checkedRakaas` (Map prayerIndex→Set\<rakaaNumber\>, Sprint 7).

Méthodes notables :
- `saveConfig()` — remplace la config du parcours actif. Depuis le Sprint 7, ne réinitialise le cycle (`_cyclePosition = 0`, sessions/checked rakaas effacés) **que si la sélection de sourates a réellement changé** (`_sameSelections`, comparaison par id+plage de versets) — un simple changement de rythme (durée, lignes/jour) préserve la progression en cours.
- `advanceCycle(unitsCompleted, cycleTotal)` — délègue à `RevisionEngine.advanceCycle`, ne recalcule jamais l'arithmétique ici.
- `setPreviewSession()` — après avoir sauvegardé la preview, lance `refreshFreshness().catchError((_) {})` en arrière-plan (fire-and-forget volontaire : si la DB échoue, les badges de fraîcheur sont simplement absents, pas de crash).
- `engager()` — transforme la `previewSession` en `todaySession` (c'est l'action du bouton « S'engager »).
- `refreshAdaptiveCycle()` — no-op silencieux si `adaptiveCycle` est désactivé ou `totalUnits <= 0` ; ne fait qu'informer l'affichage (voir piège §5.3).
- `toggleChecked(prayerIndex, rakaaNumber)` (Sprint 7) — coche/décoche une rakaa de la session en cours, persistée via `StorageService.saveCheckedRakaas` à chaque appel (survit à un redémarrage de l'app avant validation). `notifyListeners()` est appelé **avant** l'écriture disque pour que l'UI réagisse sans attendre le round-trip SharedPreferences.
- `clearConfig()` — reset complet du parcours actif uniquement, via `StorageService.clearConfigOnly(_riwaya)` — l'autre riwaya (si configurée) n'est pas touchée. Ne touche pas non plus langue/riwaya-active/notifications/tour-vu.
- **`setRiwaya(riwaya)`** (Sprint 8, réécrit — avant Sprint 8 c'était un simple setter de champ qui ne changeait que le texte affiché) — bascule le parcours actif. No-op (retourne `true`) si déjà sur cette riwaya. Retourne **`false` sans rien changer** si `riwaya == Riwaya.warsh && !warshAvailable` (évite de planter sur `WarshService.verseCounts` qui n'a jamais chargé — bug trouvé en code-review Sprint 8). Sinon : persiste la nouvelle riwaya active, appelle `_loadTrackState()`, notifie une fois. Les appelants (`settings_card.dart`, `onboarding_screen.dart`) doivent vérifier le retour et informer l'utilisateur si `false`.
- **`_loadTrackState()`** (privée, Sprint 8) — recharge tout l'état scopé par riwaya (config, cycle, sessions, pauses, cases cochées — 6 lectures `StorageService` démarrées en parallèle) pour `_riwaya`, reconstruit `_sourates`, rafraîchit fraîcheur/cycle adaptatif. Si la config du parcours cible est `null` (jamais configuré), `_config` redevient `null` et l'app retombe naturellement sur l'onboarding (`main.dart`, routage sur `config == null`) — pas de mécanisme séparé de "mini-onboarding".
- `hasSeenTour` / `markTourSeen()` (Sprint 8, déplacés depuis `StorageService` direct) — réactifs via `AppState` plutôt qu'un booléen figé au boot, pour rester corrects si l'utilisateur termine le tour puis change de riwaya dans la même session (bug trouvé en code-review Sprint 8 : `_AppRoot.hasSeenTour` était capturé une fois au démarrage du process et ne se mettait jamais à jour).

**Piège (partiellement résolu au Sprint 7)** : le flux d'édition des sourates dans `profile_screen.dart` et `learn_screen.dart._addToRevision` passent tous les deux par `saveConfig()`, qui ne reset plus le cycle si la sélection n'a pas changé (fix Sprint 7). Le fix Sprint 6 `[S6-A]` (préserver `startDate`) reste par ailleurs en place. Si vous touchez à ce flux, vérifiez que ces deux fixes ne régressent pas.

**Piège (Sprint 8)** : `HomeScreen`, `RecapScreen` et `LearnScreen` restent montés en permanence dans l'`IndexedStack` de `ShellScreen` — un changement de riwaya via `setRiwaya()` ne les recrée pas. Chacun compare la riwaya actuelle à la dernière connue dans `didChangeDependencies()` (qui se déclenche car leur `build()` fait `context.watch<AppState>()`) et relance son chargement si elle a changé. Si vous ajoutez un nouvel écran qui charge des données riwaya-scopées (`HistoryService`/`LearningService`) dans `initState()`, il a besoin du même pattern, sinon il affichera les données de l'ancien parcours après un changement de riwaya en cours de session.

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

**`HomeScreen`** — sélection des prières récitées seul (`_prayersAlone: Set<Prayer>`) + compteur d'entrées à la mosquée (`_tahiyyatCount`, chaque entrée = une occurrence dupliquée de `Prayer.tahiyyatMasjid` dans `_effectivePrayers`). Bouton « Voir le plan du jour » appelle `RevisionEngine.buildDayPlan()` puis `onVoirPlan`. `daysRemaining` utilise `state.adaptiveCycleDays ?? config.effectiveDays(...)` (fix Sprint 7 — avant, Home ignorait le cycle adaptatif et affichait un nombre différent de `RecapScreen` pour le même état). **Attention** : `build()` recalcule quand même indépendamment `units`/`cycleTotal`/`pos` à partir de `RevisionEngine.buildUnits()` — cette arithmétique reste dupliquée à plusieurs endroits de l'UI (voir §8.5). Sprint 7 y a aussi ajouté le tour guidé (`SpotlightOverlay`, voir plus bas) via des `KeyedSubtree` posées sur le sélecteur de prières et le bouton « Voir le plan ».

**`PlanScreen`** — écran unique réutilisé pour la preview (lecture seule) et la session active (checklist), distingués par le flag `isPreview`. Points métier intégrés à l'UI (donc absents de `RevisionEngine`, à connaître avant de les modifier) :
- **Cases cochées persistées (Sprint 7)** : `checkedByPrayer` vient de `AppState.checkedRakaas` (persisté) en mode actif, d'un `Map` local jetable (`_previewChecked`) en mode preview (cases non interactives). Avant Sprint 7, l'état coché n'était qu'un `State` local jamais persisté — un redémarrage de l'app avant validation faisait tout perdre.
- **Carte de check-in (Sprint 7)** : `_checkInSummary`, affichée en tête de l'aperçu avant engagement — salutation selon l'heure + chips des sourates froides/gelées du plan du jour (via `freshnessOf`, couleur par `freshnessColor()` de `widgets/freshness_badge.dart`).
- **Modal d'engagement** (`_CommitmentSheet`, non-dismissible) : force l'utilisateur à déclarer « Tout fait / Une part / Rien fait » avant d'abandonner un plan actif. Le nombre de rakaas par défaut en mode « Une part » est `(totalRakaas / 2).round().clamp(1, totalRakaas)` — règle ad-hoc locale à ce widget. **Fix Sprint 7** : la déclaration « une part fait » se fait toujours en nombre de **rakaas** (naturel pour l'utilisateur), mais `PlanScreen._coverageForFirstRakaas(n)` traduit maintenant ce nombre en unités de cycle réelles + sourates réellement couvertes (les N premières rakaas du plan, dans l'ordre) avant d'appeler `onComplete`. Avant ce fix, le nombre de rakaas était transmis tel quel comme si c'était des unités de cycle (échelles différentes), et l'historique de fraîcheur marquait *tout* le plan du jour comme revu même si rien n'était réellement coché.
- `onComplete` a désormais la signature `Function(int unitsCompleted, Set<int> sourateIds)` (avant Sprint 7 : juste `unitsCompleted`) — précisément pour porter la couverture réelle décrite ci-dessus jusqu'à `DayPlanTab`.
- **`_StreakBadge`** : paliers de streak codés en dur — `1` (« premier jour »), `7`/`30`/`100` (« nouveau palier ») — n'existent nulle part ailleurs, à dupliquer manuellement si un autre écran doit les afficher.
- **Streak anticipé** : `HistoryService.currentStreak() + 1` à l'écran de complétion, pour anticiper la session du jour pas encore enregistrée en DB au moment de l'affichage.
- `_FocusMosqueeScreen` (mode focus plein écran) utilise des couleurs codées en dur (`Color(0xFF0E1410)` etc.) au lieu de `AppPalette` — **déroge à la règle CLAUDE.md « couleurs toujours via AppPalette »**, à corriger si cet écran est retouché. Toujours présent après Sprint 7 (non traité, priorité basse).

**`DayPlanTab._onComplete()`** est le pipeline de complétion de session (le point le plus sensible de ce groupe de fichiers) :
1. Calcule `cycleWraps` (le cycle boucle-t-il avec cette session ?) — **logique dupliquée localement**, pas exposée par `AppState`/`RevisionEngine`.
2. Capture `now` une seule fois (évite un décalage si minuit survient pendant le flux).
3. Reçoit `sourateIds` directement de `PlanScreen` (Sprint 7, voir plus haut) au lieu de les re-dériver de tout `session.plan`.
4. Lance en parallèle (`Future.wait`, Sprint 7) `AppState.advanceCycle()`, `HistoryService.recordSession()` et `recordSourateHistory()` — les 3 écritures sont indépendantes (prefs `cyclePosition`, table `sessions`, table `sourate_sessions`). Puis, dans un second `Future.wait`, `refreshAdaptiveCycle(notify: false)` et `refreshFreshness(notify: false)` — chacun dépend d'une des 3 écritures précédentes (respectivement `recordSession`/`recordSourateHistory`), donc attend la fin du premier groupe. **Avant Sprint 7** ces 5 appels étaient tous séquentiels, et `refreshAdaptiveCycle` était appelé *avant* `recordSession` (la moyenne adaptative restait alors en retard d'une session par rapport à la saisie manuelle, qui faisait déjà les choses dans le bon ordre).
5. Si le cycle boucle, affiche `_CycleMilestoneDialog` (non-dismissible).
6. `AppState.clearTodaySession()`.

La saisie manuelle (`ManualSessionSheet`, stepper 1..maxUnits) suit un pipeline similaire (`recordSession → advanceCycle → refreshAdaptiveCycle → refreshFreshness`), mais avec `prayers: const []` (aucune prière associée) — resté séquentiel, non touché par la parallélisation du Sprint 7.

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

**Connexion révision ↔ apprentissage** (le point le plus important pour la maintenance) : quand `LearningProgress.isComplete` (tous les versets appris), `LearnSurahScreen` propose « Ajouter à la révision ». Ce n'est **pas automatique côté engine** — c'est un hand-off piloté par l'UI : `LearnScreen._addToRevision()` ajoute `SourateSelection.whole(s)` à `UserConfig.selections` via `AppState.saveConfig()`, **puis** supprime l'entrée de `LearningService`. Une sourate passe donc du domaine « apprentissage » au domaine « révision » comme une opération UI atomique, jamais déclenchée depuis `core/`. Cette action n'est proposée que pour le profil principal (`_activeStudentId == null`) — un profil élève ne peut pas alimenter la config de révision du parent.

**Sélecteur de bloc (`[B] Apprentissage multi-versets`)** : `SegmentedButton<int>` à 3 valeurs fixes `{1, 3, 5}`. `_currentBlock` calcule les N prochains versets *non appris* en ordre croissant (pas nécessairement `nextVerse` si des versets ont été désappris hors séquence).

**Duplication identifiée** : `learn_surah_screen.dart` construit son propre bloc de hadith de clôture (`_closingHadith`, appelle `hadithDuJour()` directement) et son propre badge de streak inline (`_streakBadge`), plutôt que de réutiliser les widgets `HadithCard`/`StreakCard` qui existent déjà et font la même chose ailleurs dans l'app. Si le format d'affichage du hadith ou du streak doit changer, il faut le faire aux deux endroits.

**Petits écarts aux conventions repérés** : `learning_progress_card.dart` affiche `'✓ Complet'` en chaîne française codée en dur (pas via `S.`), et utilise `Colors.red.shade100`/`Colors.red` directement au lieu de `AppPalette` pour la couleur de suppression.

### 8.4 Profil, Récap, Réglages

**`ProfileScreen`** est la **seule surface d'édition** de `UserConfig` : sélection des sourates (mode édition plein écran), rythme (dialog dédié avec `PresetDropdown`), cycle adaptatif, pause du jour, et réinitialisation complète (irréversible, `AppState.clearConfig()`). En sauvegardant une nouvelle sélection de sourates, les sourates déjà cochées **conservent leur plage de versets existante** (`existingSelections[s.id] ?? SourateSelection.whole(s)`) — seules les sourates nouvellement cochées deviennent des sélections « entières ».

**`SettingsCard`** (imbriqué dans `ProfileScreen`) : langue, riwaya, shuffle (tous via `AppState`), et notifications — dont l'état (`notif_enabled`) est stocké **directement dans `StorageService`**, hors de `UserConfig`, donc **il survit à `AppState.clearConfig()`** (réinitialisation du profil). À savoir avant de supposer qu'un « reset complet » efface vraiment tout.

**`RecapScreen`** est en lecture seule (streak, position de cycle, répartition sourates, historique 7 jours). Piège à connaître : la carte de répartition (`enRevision`/`memorisees`/`enCours`) combine deux sources de données indépendantes (`UserConfig.selections` vs `LearningProgress`) qui **ne sont pas mutuellement exclusives** — une sourate peut compter à la fois « en révision » et « mémorisée », la carte ne réconcilie pas les deux. `HistoryCard` reçoit 14 sessions mais n'en affiche que les 7 premières (`sessions.take(7)`) — écart entre ce que demande l'appelant et ce que le widget restitue, à clarifier si quelqu'un y touche. `_load()` démarre `AppState.refreshFreshness(notify: false)` en parallèle des autres lectures (Sprint 7, avant : appelé après coup, en série).

**`SouratesRecapCard` (Sprint 7)** : affiche désormais un badge de fraîcheur (`FreshnessBadge`, `widgets/freshness_badge.dart` — Récente/Froide/Très froide) par sourate, et chaque ligne est cliquable (`onTap`) vers le nouvel écran **`SurahReaderScreen`** (`screens/surah_reader_screen.dart`) — lecture plein texte d'une sourate/plage, sans mode caché/révélé. Avant Sprint 7, aucune navigation de lecture n'existait depuis le Récap. Le fond de carte utilise maintenant `context.palette.surfaceCard` + `cardBorder` (avant : `Colors.white` en dur, cassait l'apparence en thème sombre — corrigé).

**`StudentProfileBar`** (onglet Apprendre, pas Profil) : la suppression d'un profil élève se fait par **un simple appui long, sans aucune confirmation** dans toute la chaîne d'appel (`student_profile_bar.dart` → `learn_screen.dart:_deleteStudent`). C'est l'action la plus dangereuse identifiée dans toute la couche UI — à corriger en priorité si le sujet de la robustesse UX revient (non traité au Sprint 7).

### 8.5 Dette technique UI identifiée (à garder à l'esprit, pas à corriger d'office)

Cette liste consolide ce que l'analyse fichier-par-fichier a fait remonter — utile pour prioriser un futur nettoyage, mais **ne pas corriger silencieusement en marge d'une autre tâche** (règle CLAUDE.md « changements chirurgicaux »).

1. **Arithmétique de cycle dupliquée** dans `home_screen.dart`, `plan_screen.dart` (`_summaryBar`), `recap_screen.dart` et `day_plan_tab.dart` (`cycleWraps`) — chacun recalcule `pos`/`cycleTotal`/`daysRemaining` ou la détection de bouclage indépendamment plutôt que de consommer une valeur unique exposée par `AppState`/`RevisionEngine`.
2. **Magic numbers métier hors de `core/`** : seuil 80% « bonne journée » répété 5 fois dans `history_card.dart` ; paliers de streak 1/7/30/100 dans `plan_screen.dart` ; plafond de 5 entrées Tahiyyat dans `prayer_selector.dart` ; règle « moitié des rakaas par défaut » dans `_CommitmentSheet`.
3. **Couleurs codées en dur** (déroge à la règle `AppPalette`) : `_FocusMosqueeScreen` (plan_screen.dart), `learning_progress_card.dart`. `sourates_recap_card.dart` corrigé au Sprint 7 (utilise `palette.surfaceCard`). Le voile (scrim) de `SpotlightOverlay` (Sprint 7) reste en `Colors.black` en dur, mais **volontairement** — un voile de modale est conventionnellement invariant au thème (comme `ModalBarrier` de Flutter), le passer par `AppPalette` l'inverserait en thème sombre.
4. **Chaîne hors `S.`** : `'✓ Complet'` dans `learning_progress_card.dart`.
5. **Composants dupliqués plutôt que réutilisés** : hadith de clôture et badge de streak réimplémentés dans `learn_surah_screen.dart` au lieu de `HadithCard`/`StreakCard` ; filtre de recherche sourate dupliqué entre `OnboardingScreen` et `SouratePickerSheet`. Non traité au Sprint 7 (revue de code identifiée, priorité basse).
6. **Confirmation manquante** : suppression d'un profil élève (`StudentProfileBar` → appui long direct, aucun dialog).
7. **Mismatch appelant/widget** : `HistoryCard` reçoit 14 sessions, n'en affiche que 7.
8. **Libellé ambigu** : « Sourates mémorisées » dans `ProfileInfoCard` compte en réalité `config.selections.length` (sourates en révision), pas les sourates réellement mémorisées via `LearningProgress.isComplete` — à ne pas confondre avec le calcul distinct de `RecapScreen`.
9. **Race lire-modifier-écrire** (Sprint 7, revue de code) : `LearningService`/`StudentService` (`upsert`/`remove`) suivent un schéma lire-tout/modifier/réécrire-tout sans synchronisation — deux appels rapprochés peuvent se piétiner. Non traité : ajouter une vraie synchronisation serait disproportionné pour une app locale mono-utilisateur (risque réel faible).
10. **Plage de versets trompeuse** (Sprint 7, revue de code) : `learn_surah_screen.dart` affiche `v.X–Y` pour le bloc courant, ce qui laisse croire à une plage contiguë alors que `_currentBlock` peut retourner des versets non contigus si l'utilisateur a désappris des versets précis entre-temps. Non traité (cas rare, priorité basse).

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

**État réel au moment de la rédaction** (voir aussi `test/CLAUDE.md`, à lire avant tout travail dans ce dossier) : **couverture quasi nulle**.
- `test/widget_test.dart` — placeholder (`expect(true, isTrue)`), ne teste rien.
- `test/core/revision_engine_test.dart` — seule suite réelle (100 lignes, 3 tests) : vérifie qu'un seul cycle de 3 unités sur 30 jours ne planifie qu'une unité/jour (mode « par durée »), et deux cas du mode « par lignes/jour » (accumulation d'unités jusqu'au seuil, avancée cyclique depuis un `cyclePosition` non nul). **Ne couvre pas** : la règle no-repeat sourate par prière (`[S6-B]`), la répétition cyclique de `_expandToRakaas`, le shuffle déterministe, ni `FreshnessEngine`.

**Priorités si vous ajoutez des tests** (reprises de `test/CLAUDE.md`) :
1. `RevisionEngine` — pur Dart, zéro I/O, le plus critique et le moins couvert vu sa complexity réelle.
2. `FreshnessEngine` — pur Dart également, trivial à tester.
3. Services (`SharedPreferences.setMockInitialValues({})` pour le storage ; `sqflite` n'a **pas** de lib de mock installée — ajouter `sqflite_common_ffi` en dev_dependency serait un prérequis avant de tester `HistoryService`).
4. **Sprint 8 (non fait, signalé explicitement)** : la logique par-riwaya ajoutée (`StorageService`/`LearningService` clés préfixées + `migrateLegacyTrackData()`, `HistoryService` schéma v3, `AppState.setRiwaya`/`_loadTrackState`) n'a **aucun test de régression** — même limitation que le reste des services (pas de `sqflite_common_ffi`), mais c'est une zone neuve et non triviale (migration one-shot, guard `warshAvailable`) qui mériterait d'être en tête de liste si une session de tests est ouverte.

Aucune lib de mock (mockito/mocktail) n'est dans `pubspec.yaml` — ne pas en ajouter tant qu'un test de service/`AppState` n'en a pas réellement besoin (règle anti-sur-ingénierie du projet).

**Avant de refactorer `RevisionEngine` ou `FreshnessEngine`** : ces fichiers portent des règles métier actées sur plusieurs sprints sans filet de sécurité. Écrire un test de régression sur le comportement actuel avant tout changement plutôt que de se fier à une relecture manuelle — et le signaler explicitement si ce n'est pas fait (règle CLAUDE.md du projet).

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
| Builder/distribuer l'app iOS | Xcode (`ios/Runner.xcworkspace`) — Archive → Distribute App, manuel |

---

## 15. Maintenir ce document

Ce document a été généré par une lecture complète du code source (tous les fichiers de `lib/`, `test/`, `pubspec.yaml`) à la date indiquée en fin de fichier — il n'est **pas** auto-généré à chaque build et **va driver avec le temps**, exactement comme `CHANGELOG.md` (voir la note d'expérience du 2026-08-20 dans `CLAUDE.md` du projet : une doc maintenue à la main a déjà divergé du dépôt réel par le passé).

- Après un sprint qui touche `RevisionEngine`, `FreshnessEngine`, `AppState`, ou qui ajoute/supprime un écran/service : mettre à jour la section correspondante ici, en plus de `CHANGELOG.md`.
- Si vous (humain ou Claude) trouvez une divergence entre ce document et le code réel, corrigez ce document plutôt que de le laisser mentir — le code fait toujours foi.
- Les points de §8.5 (« dette technique identifiée ») doivent être retirés de la liste au fur et à mesure qu'ils sont corrigés, pas laissés indéfiniment.

*Dernière rédaction complète : 2026-08-22, à partir d'une lecture intégrale de `lib/` (8093 lignes) et de `test/`. Mise à jour le 2026-08-22 (même jour) pour refléter le Sprint 7 (`lib/` : 8860 lignes) et le retrait de `codemagic.yaml` (déploiement manuel via Xcode). Mise à jour le 2026-08-29 : `codemagic.yaml` réintroduit et rendu fonctionnel (signing + build number auto + publication TestFlight sur push `main`) — voir §12. Mise à jour le 2026-08-29 (Sprint 8) : source du texte coranique remplacée (QUL/Tarteel), Hafs/Warsh transformés en parcours de révision/mémorisation/historique indépendants (numérotation de versets réellement différente entre les deux riwayat) — §2, §6, §7, §10, §11 revus en conséquence.*

