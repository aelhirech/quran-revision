# Quran Revision App — Contexte projet

> Fichier de continuité : à lire au début de chaque nouveau chat.
> Un chat = un sprint. Ce fichier remplace le résumé de contexte.

---

## Stack & environnement

- **Flutter** 3.44.2, Material 3, Provider (ChangeNotifier)
- **Dart**, pas de TypeScript ni backend
- `PUB_CACHE = D:\pub-cache\Cache`
- Flutter : `D:\develop\flutter\bin\flutter.bat`
- Commande flutter : `$env:PUB_CACHE = "D:\pub-cache\Cache"; D:\develop\flutter\bin\flutter.bat <cmd>`
- Working dir : `D:\Prog\Quran_revision`
- **C: est plein** — tout va sur D: (SDK, dossiers, fichiers volumineux)
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

---

## Backlog

| Priorité | Feature | Notes |
|----------|---------|-------|
| P2 | **Fix edit Surah** | bug signalé, à reproduire |
| P3 | **Gamification narrative [H]** | vision long terme, direction artistique à valider |

---

## Fichiers clés à lire en priorité

| Fichier | Rôle |
|---------|------|
| `lib/core/revision_engine.dart` | Algorithme de distribution des versets dans les rakaas |
| `lib/state/app_state.dart` | Orchestrateur état global |
| `lib/screens/onboarding_screen.dart` | Onboarding à refaire |
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

- `app-developer` (local) — implémentation Flutter UI + logique
- `flutter-logic` (local) — logique métier, services, state
- `code-review` — revue post-implémentation, sévérité CRITICAL→SUGGESTION
- `product-strategist` — specs fonctionnelles depuis backlog

## Démarrer un nouveau sprint

1. Lire ce fichier
2. Lire les fichiers clés listés ci-dessus (surtout `revision_engine.dart` + `app_state.dart`)
3. Créer une branch `feature/phase-4-sprint6` (ou phase suivante)
4. Implémenter avec le skill `app-developer`
5. Code review avec le skill `code-review`
6. Appliquer les corrections
7. Mettre à jour ce fichier (section "Fonctionnalités livrées" + backlog)
8. Commit + PR vers `main`
