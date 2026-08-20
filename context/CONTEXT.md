# Quran Revision App — Contexte projet

> Fichier de continuité : à lire au début de chaque nouveau chat.
> Un chat = un sprint. Ce fichier remplace le résumé de contexte.

---

## Stack & environnement

- **Flutter** 3.47.0 (stable), Material 3, Provider (ChangeNotifier)
- **Dart**, pas de TypeScript ni backend
- macOS — SDK installé localement : `~/Documents/Prog/Applications/flutter/bin` (ajouté au PATH via `~/.zshrc`)
- Working dir : `~/Documents/Prog/quran-revision`
- Branch principale : `main` / feature branches : `feature/phase-X`

---

## Architecture

```
lib/
├── core/           — logique pure (RevisionEngine, AppColors, Strings)
├── models/         — data classes immuables avec copyWith + toJson/fromJson
├── services/       — I/O stateless (SharedPrefs, SQLite, notifications)
├── state/          — AppState extends ChangeNotifier (orchestrateur)
├── screens/        — UI pages
└── widgets/        — composants réutilisables
```

### Règles architecture (ne pas briser)
- `core/` : zéro import Flutter, zéro I/O, pur Dart
- Services : stateless, `static` ou injection constructeur, jamais de `notifyListeners`
- AppState : un seul `notifyListeners()` par opération logique
- Modèles : toujours `copyWith()` pour mises à jour partielles
- `if (!mounted) return;` après chaque `await` dans un `State`

---

## Fonctionnalités livrées

### Phase 4 — Sprint 1 (commit `ef4fbfd`, fix `37b2494`)
- **[C] Navigation rename** : "Plan du jour" → "Réviser", "Apprendre" ajouté dans nav
- **[F] Groupement Hizb** : boutons rapides (tout, 1/4, 1/2, 3/4 du Coran) dans setup/onboarding

### Phase 4 — Sprint 2 (commit `2172c78`, fix `b858942`)
- **[G] Cycle adaptatif** : durée du cycle calculée depuis les prières sélectionnées (RevisionEngine)
- **[D] Récap différencié** : stats séparées révision / apprentissage / mémorisées (RecapScreen)

### Phase 4 — Sprint 3 (commit `e437e12`, fix `febaa89`)
- **SRS léger** : fraîcheur par sourate (HistoryService.lastRevisionDate)
- **Indicateur "sourate froide"** : badge chaud/froid dans PlanScreen

### Phase 4 — Sprint 4 (commit `8d00651`, fix `3452820`)
- **[B] Apprentissage multi-versets** : sélecteur bloc 1/3/5 dans LearnSurahScreen (UI state pur)
- **[E] Saisie manuelle** : bottom sheet stepper dans DayPlanTab → ManualSessionSheet

### Phase 4 — Sprint 5 (commit `5661555`)
- **Onboarding wizard** : refacto en 3-pages (PageView + NeverScrollableScrollPhysics) avec sélection rapide (Tout, 1/4, 1/2, 3/4 depuis la fin du Coran)
- **Moteur lignes** : distribution par lignes Mushaf (~8,5 mots/ligne, min 3 lignes/rakaa) au lieu de mots fixes
- **Répétition cyclique** : si rakaas > unités disponibles, répétition cyclique (pas de rakaas vides)
- **Suppression "by duration"** : versesPerDay supprimé de UserConfig, révision intelligente par défaut
- **Gamification** : écran waouh (ما شاء الله) avec streak anticipé (+1 avant enregistrement) à la complétion
- **Commitment modal** : non-dismissable (isDismissible: false, enableDrag: false), 3 options (tout/partie/rien)
- **Mode focus mosquée** : plein écran texte arabe RTL via rootNavigator (masque la NavigationBar)

### Phase 4 — Sprint 6 (commit `528bc23`)
- **[S6-A] Fix edit surah** : `startDate` préservé lors de l'édition des sourates — évitait de réinitialiser silencieusement toute la progression du cycle
- **[S6-B] No-repeat sourate par prière** : `RevisionEngine.buildDayPlan` interdit maintenant qu'une sourate apparaisse deux fois dans la même prière (swap + `usedInPrayer` set) — règle liturgique
- **[S6-C] Cycle progress bar** : `_summaryBar` du `PlanScreen` affiche `Cycle en cours : X / Y` avec une mini barre de progression linéaire

### Direction artistique — Mus'haf / Tahajjud (commit `bf47184`)
- Refonte visuelle complète sur tous les écrans : thème clair « Mus'haf » (papier crème, vert profond, or, serif Lora/Amiri) + thème sombre « Tahajjud » suivi automatiquement via `ThemeMode.system`
- Nouveaux tokens de design : `AppPalette` (`core/app_colors.dart`), composants partagés (`DomeProgressCard`, `OrnamentalDivider`, `PrimaryCtaButton`, `IndexBadge`, `PillChip`)
- Support web ajouté pour prévisualisation locale (`flutter run -d chrome`)
- Ajout ultérieur : badge de série + hadith de clôture dans `LearnSurahScreen`, pour coller au mockup « Verset du soir » du design doc

### Rythme personnalisable + riwaya Warsh/Hafs
- **Durée d'objectif étendue** : presets 7→365 jours + « Personnalisé… » (`PresetDropdown`, `lib/widgets/preset_dropdown.dart`), utilisé dans profil et onboarding
- **[Rythme par lignes/jour]** : mode alternatif à la durée — `UserConfig.paceByLines`/`targetLinesPerDay`, `RevisionEngine._unitsForLines` sélectionne les unités du jour par seuil de lignes Mushaf plutôt que par jours restants (toggle "Par durée"/"Par lignes/jour")
- **[Riwaya Warsh/Hafs]** : toggle dans `SettingsCard` (`AppState.riwaya`, persistée via `StorageService`). Texte Warsh bundlé en asset local `assets/quran/warsh.json` (6236 versets, numérotation identique au Hafs — source : dataset ouvert `fawazahmed0/quran-api`, édition `ara-quranwarsh`, licence Unlicense — **non un texte certifié**, à garder en tête si un utilisateur signale une variante). Tous les call sites de texte arabe passent maintenant par `VerseService` (plus d'appel direct à `package:quran` dans les écrans)
- Tests de régression ajoutés : `test/core/revision_engine_test.dart` (mode lignes/jour vs durée)

---

## Backlog

| Priorité | Feature | Notes |
|----------|---------|-------|
| P3 | **Gamification narrative [H]** | vision long terme — direction artistique déjà validée (Mus'haf/Tahajjud), reste à définir la mécanique narrative |
| P3 | **Cycle wrap affiché** | si cyclePosition + totalUnits > cycleTotal, afficher "(cycle bouclé)" dans le summary bar |

---

## Fichiers clés à lire en priorité

| Fichier | Rôle |
|---------|------|
| `lib/core/revision_engine.dart` | Algorithme de distribution des versets dans les rakaas |
| `lib/state/app_state.dart` | Orchestrateur état global |
| `lib/screens/onboarding_screen.dart` | Onboarding 3 pages (intro/sélection/récap) |
| `lib/screens/plan_screen.dart` | Affichage plan du jour + indicateur fraîcheur |
| `lib/screens/learn_surah_screen.dart` | Apprentissage verset par verset (bloc) |
| `lib/widgets/day_plan_tab.dart` | Routing Plan/Preview/Home + saisie manuelle |
| `lib/services/history_service.dart` | Historique sessions + fraîcheur sourates |
| `lib/core/strings.dart` | Toutes les chaînes FR/EN |

---

## Conventions commits

```
feat(sprint-N): description
fix(sprint-N): corrections code review
```

## Skills disponibles (Claude Code)

- `code-review` — revue post-implémentation, sévérité CRITICAL→SUGGESTION

> Les skills locaux `app-developer` / `flutter-logic` / `product-strategist` mentionnés dans une version antérieure de ce fichier ne sont pas présents dans ce dépôt (pas de `.claude/skills/`) — à reconfigurer si besoin, sinon travailler directement avec les agents généraux.

## Démarrer un nouveau sprint

1. Lire ce fichier
2. Lire les fichiers clés listés ci-dessus (surtout `revision_engine.dart` + `app_state.dart`)
3. Créer une branch `feature/phase-N-sprintM`
4. Implémenter
5. Code review avec le skill `code-review`
6. Appliquer les corrections
7. Mettre à jour ce fichier (section "Fonctionnalités livrées" + backlog)
8. Commit + PR vers `main`
