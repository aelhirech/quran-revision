# CLAUDE.md — quran-revision

Instructions de travail pour ce dépôt. Complète `docs/DOCUMENTATION_TECHNIQUE.md` (architecture, moteurs métier, écrans — comment le code fonctionne) et `CHANGELOG.md` (historique des sprints, backlog — quoi a été livré et quand) — ne les remplace pas.

> Ce projet utilisait un fichier `context/CONTEXT.md` comme fichier de continuité unique. Il a été scindé le 2026-08-22 en `docs/DOCUMENTATION_TECHNIQUE.md` + `CHANGELOG.md` (voir entrée « Documentation technique » dans `CHANGELOG.md`). Le « Sprint Workflow » défini dans le `CLAUDE.md` parent (`d:\Prog\CLAUDE.md`, partagé entre projets) se déclenche sur la présence d'un fichier `context/CONTEXT.md` — pour ce projet, considérer que `CHANGELOG.md` en tient lieu (section « Fonctionnalités livrées » = sprint section, section « Backlog » = backlog) pour les étapes de ce workflow.

## Déclencheurs de sprint

Deux phrases suffisent pour piloter tout le cycle défini dans le Sprint Workflow du `CLAUDE.md` parent (`d:\Prog\CLAUDE.md`) — pas besoin de redétailler les étapes à chaque fois.

### « Début de sprint » (+ description de ce qu'on fait)
1. Lire `docs/DOCUMENTATION_TECHNIQUE.md` + `CHANGELOG.md` (+ `test/CLAUDE.md` si le travail touche `test/`).
2. Créer la branche `feature/phase-X-sprintN`.
3. Implémenter.

### « Fin de sprint »
Exécuter dans l'ordre, sans redemander de confirmation entre chaque étape **sauf pour le push final** :
1. `/simplify` — sur-ingénierie, réutilisation, cleanups.
2. `/code-review` — bugs de correction.
3. Appliquer les fixes remontés par les deux passes.
4. Mettre à jour `CHANGELOG.md` (Fonctionnalités livrées + Backlog), et `docs/DOCUMENTATION_TECHNIQUE.md` si le sprint a touché `RevisionEngine`, `FreshnessEngine`, `AppState`, ou ajouté/supprimé un écran/service.
5. Commit sur la feature branch (`feat(sprint-N): ...` / `fix(sprint-N): ...`).
6. Merge la feature branch dans `main`.
7. **Avant de pusher `main` : demander confirmation explicite.** `codemagic.yaml` soumet automatiquement un build à TestFlight (groupe "External Testers") — si le déclenchement Codemagic est configuré sur push vers `main`, un push automatique enverrait potentiellement un build à de vrais testeurs externes sans avertissement. Toutes les autres étapes ci-dessus peuvent s'enchaîner sans interruption ; celle-ci non.

## Au début de chaque session
1. Lire `docs/DOCUMENTATION_TECHNIQUE.md` et `CHANGELOG.md` en entier.
2. Si le travail touche `test/`, lire aussi `test/CLAUDE.md`.
3. Ne pas prendre `docs/DOCUMENTATION_TECHNIQUE.md`/`CHANGELOG.md` pour argent comptant : ce sont des fichiers maintenus à la main, ils dérivent du code réel avec le temps (voir "Vérifier l'harmonie" ci-dessous).

## Ne jamais sur-ingénierer
Projet solo, un seul développeur, Provider comme unique gestion d'état.
- Pas de nouvelle lib de state management, DI ou couche d'architecture supplémentaire tant que la taille du projet ne le justifie pas.
- Pas d'abstraction ajoutée « au cas où » (interface pour un seul service concret, factory pour un seul type, config générique pour un seul cas d'usage).
- Le code minimal qui fait marcher la fonctionnalité proprement, pas plus. Une règle métier utilisée une seule fois ne se généralise pas.
- Avant d'ajouter une dépendance dans `pubspec.yaml`, vérifier qu'elle n'est pas déjà couverte par l'existant.

## Règles d'architecture à ne jamais casser
- `lib/core/` : zéro import Flutter, zéro I/O, Dart pur.
- `lib/services/` : stateless, jamais de `notifyListeners`.
- `lib/state/app_state.dart` : un seul `notifyListeners()` par opération logique.
- Modèles (`lib/models/`) : mise à jour uniquement via `copyWith()`.
- Dans un `State` : `if (!mounted) return;` après chaque `await`.
- Texte affiché à l'utilisateur → `lib/core/strings.dart` (FR/EN) ; texte arabe → `lib/services/verse_service.dart`. Jamais d'appel direct à `package:quran` dans un écran/widget.
- Couleurs/typo → toujours via `AppPalette` (`lib/core/app_colors.dart`), jamais de couleur en dur dans un widget.

## Vérifier l'harmonie avant de clore une tâche
- Le code correspond-il à ce que `docs/DOCUMENTATION_TECHNIQUE.md`/`CHANGELOG.md` prétendent ? Ces fichiers sont maintenus à la main et peuvent dériver du dépôt réel (exemple vécu le 2026-08-20 : une section documentait des fonctionnalités et un test de régression qui n'étaient pas encore commités). Corriger l'un ou l'autre plutôt que de laisser la doc mentir.
- Un changement dans `revision_engine.dart` ou `freshness_engine.dart` respecte-t-il les règles métier déjà actées (répétition cyclique sans rakaa vide, no-repeat sourate par prière, cycle adaptatif, mode lignes/jour vs durée) ?
- Un changement visuel respecte-t-il la direction artistique Mus'haf/Tahajjud (clair papier crème/vert/or, sombre Tahajjud, suivi via `ThemeMode.system`) plutôt que d'introduire un style isolé ?

## Ne jamais oublier
- Mettre à jour `CHANGELOG.md` (« Fonctionnalités livrées » + « Backlog ») à la fin de chaque sprint/tâche notable — c'est le seul historique persistant du projet, pas de ticket externe. Mettre à jour `docs/DOCUMENTATION_TECHNIQUE.md` en plus si le sprint touche `RevisionEngine`, `FreshnessEngine`, `AppState`, ou ajoute/supprime un écran/service.
- Si une règle métier change dans `RevisionEngine`/`FreshnessEngine` sans test de régression associé, le signaler explicitement à l'utilisateur plutôt que de laisser passer silencieusement (voir `test/CLAUDE.md`, couverture quasi nulle aujourd'hui).
- Convention de commit : `feat(sprint-N): description` / `fix(sprint-N): description`.
