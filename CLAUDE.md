# CLAUDE.md — quran-revision

Instructions de travail pour ce dépôt. Complète `context/CONTEXT.md` (contexte fonctionnel, historique de sprints, backlog) — ne le remplace pas.

## Au début de chaque session
1. Lire `context/CONTEXT.md` en entier.
2. Si le travail touche `test/`, lire aussi `test/CLAUDE.md`.
3. Ne pas prendre `context/CONTEXT.md` pour argent comptant : c'est un fichier maintenu à la main, il dérive du code réel avec le temps (voir "Vérifier l'harmonie" ci-dessous).

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
- Le code correspond-il à ce que `context/CONTEXT.md` prétend ? Ce fichier est maintenu à la main et peut dériver du dépôt réel (exemple vécu le 2026-08-20 : une section documentait des fonctionnalités et un test de régression qui n'étaient pas encore commités). Corriger l'un ou l'autre plutôt que de laisser la doc mentir.
- Un changement dans `revision_engine.dart` ou `freshness_engine.dart` respecte-t-il les règles métier déjà actées (répétition cyclique sans rakaa vide, no-repeat sourate par prière, cycle adaptatif, mode lignes/jour vs durée) ?
- Un changement visuel respecte-t-il la direction artistique Mus'haf/Tahajjud (clair papier crème/vert/or, sombre Tahajjud, suivi via `ThemeMode.system`) plutôt que d'introduire un style isolé ?

## Ne jamais oublier
- Mettre à jour `context/CONTEXT.md` (« Fonctionnalités livrées » + « Backlog ») à la fin de chaque sprint/tâche notable — c'est le seul historique persistant du projet, pas de ticket externe.
- Si une règle métier change dans `RevisionEngine`/`FreshnessEngine` sans test de régression associé, le signaler explicitement à l'utilisateur plutôt que de laisser passer silencieusement (voir `test/CLAUDE.md`, couverture quasi nulle aujourd'hui).
- Convention de commit : `feat(sprint-N): description` / `fix(sprint-N): description`.
