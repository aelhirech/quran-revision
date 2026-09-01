# CLAUDE.md — quran-revision

Instructions de travail pour ce dépôt. Complète `docs/DOCUMENTATION_TECHNIQUE.md` (architecture, moteurs métier, écrans — comment le code fonctionne) et `docs/CHANGELOG.md` (backlog + décisions transversales utiles aux futurs sprints — plus un historique de livraison, voir `git log` pour ça) — ne les remplace pas.

> Ce projet utilisait un fichier `context/CONTEXT.md` comme fichier de continuité unique, scindé le 2026-08-22 en `docs/DOCUMENTATION_TECHNIQUE.md` + `docs/CHANGELOG.md`. Le « Sprint Workflow » défini dans le `CLAUDE.md` parent (`d:\Prog\CLAUDE.md`, partagé entre projets) se déclenche sur la présence d'un fichier `context/CONTEXT.md` — pour ce projet, considérer que `docs/CHANGELOG.md` en tient lieu, mais uniquement pour l'étape « Backlog » (retirer les items traités, ajouter les nouvelles idées) : depuis le 2026-09-01, ce fichier ne journalise plus les livraisons sprint par sprint (rôle repris par `git log`/les messages de commit) et ne garde que le Backlog + quelques décisions transversales utiles à qui reprend un item.

## Déclencheurs de sprint

Deux phrases suffisent pour piloter tout le cycle défini dans le Sprint Workflow du `CLAUDE.md` parent (`d:\Prog\CLAUDE.md`) — pas besoin de redétailler les étapes à chaque fois.

### « Début de sprint » (+ description de ce qu'on fait)
1. Lire `docs/DOCUMENTATION_TECHNIQUE.md` + `docs/CHANGELOG.md` 
2. Créer la branche `feature/phase-X-sprintN`.
3. Implémenter.

### « Fin de sprint »
Exécuter dans l'ordre, sans redemander de confirmation entre chaque étape **sauf pour le push final** :
1. `/simplify` — sur-ingénierie, réutilisation, cleanups.
2. `/code-review` — bugs de correction.
3. Appliquer les fixes remontés par les deux passes.
4. Mettre à jour `docs/CHANGELOG.md` (retirer du Backlog les items traités par ce sprint, ajouter les nouvelles idées identifiées, noter une décision transversale seulement si elle sera utile à un futur sprint — pas un résumé de ce qui a été livré, le commit s'en charge), et `docs/DOCUMENTATION_TECHNIQUE.md` si le sprint a touché `RevisionEngine`, `FreshnessEngine`, `AppState`, ou ajouté/supprimé un écran/service.
5. Commit sur la feature branch (feature(sprint-N):)
6. Vérifier que la demande utilisateur a bien été traitée dans son intégralité avec soit une modification de code soit un enregistrement dans docs/CHANGELOG.md après discussion avec l'utilisateur : (Pourquoi on la pas traité, décision manquantes, trop flou pour être implémenter etc)
7. **Avant de merger et pusher `main`, si le sprint touche du code iOS : bumper le build number dans `pubspec.yaml`.** Depuis le 2026-08-31, `codemagic.yaml` ne calcule plus automatiquement le build number (le lookup App Store Connect/TestFlight s'est montré peu fiable — voir incident du même jour : collision `ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE` car le build 5 avait déjà été publié et rien ne répercutait le nombre utilisé dans `pubspec.yaml`). `pubspec.yaml` (`version: X.Y.Z+N`) est donc la **seule source de vérité** du build number iOS : `flutter build ipa` lit `+N` directement, sans override. Avant de pusher `main`, vérifier le dernier build number publié sur TestFlight/App Store Connect et bumper `+N` strictement au-dessus dans `pubspec.yaml`.
8. **Avant de merger et pusher `main` : demander confirmation explicite.** Depuis le 2026-08-29, CI/CD Codemagic connectée à ce dépôt (`codemagic.yaml`, workflow `ios-testflight`) : un `git push` sur `main` déclenche automatiquement build + signing + **publication TestFlight**. La confirmation est donc requise pour une vraie raison opérationnelle (déclenchement automatique d'une distribution externe), pas seulement par prudence générale. Toutes les autres étapes ci-dessus peuvent s'enchaîner sans interruption ; celle-ci non.

## Au début de chaque session
1. Lire `docs/DOCUMENTATION_TECHNIQUE.md` et `docs/CHANGELOG.md` en entier.
2. Si le travail touche `test/`, lire aussi `test/CLAUDE.md`.
3. Ne pas prendre `docs/DOCUMENTATION_TECHNIQUE.md`/`docs/CHANGELOG.md` pour argent comptant : ce sont des fichiers maintenus à la main, ils dérivent du code réel avec le temps (voir "Vérifier l'harmonie" ci-dessous).

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

## Modèle de données central : `ayah_facts`

`ayah_facts` (`lib/services/ayah_facts_service.dart`) n'est pas une table parmi d'autres : c'est le **journal de la relation entre l'utilisateur et le Coran** — l'unique source de vérité dont tout le reste (fraîcheur, streak, plan du jour, apprentissage, récap) est *reconstruit* par requête, jamais recalculé/stocké en parallèle. Avant d'ajouter un flag, un compteur ou une table séparée pour une nouvelle fonctionnalité, se demander d'abord si elle peut se dériver d'`ayah_facts`.

**Grain et sémantique** — une ligne = un événement daté, un verset **réel** (`ayah_id` toujours dans la plage 1..N de la sourate, jamais un id hors-plage/sentinelle), un type (`learn`|`revise`) :
- `reach=0` = verset **visé/proposé** (elle cherche à l'apprendre / il est proposé au plan du jour), pas encore acquis.
- `reach=1` = verset **atteint** (appris, ou fait/révisé).
- Passer de 0 à 1 se fait par **mise à jour** de la ligne existante (`setReach`, `learnVerses`) ou par une **nouvelle ligne datée** si l'action a lieu un autre jour (l'unicité est `date+riwaya+surah_id+ayah_id+type` — deux dates distinctes coexistent, ce qui préserve l'historique : "visé le J1, atteint le J5").
- **Annuler une progression repasse `reach` à 0, ne supprime jamais la ligne** (`unlearnVerse`) — sinon la seule ligne qui rattachait un verset/une sourate à "en cours" disparaît et on retombe dans la même classe de bug que celui corrigé au sprint "fix" du 2026-09-01 (sourate qui disparaît de "en cours d'apprentissage"). Un vrai `DELETE` (`deleteLearnFacts`, `removeFromDayPlan`) reste réservé aux hand-off/abandons explicites (ex. sourate qui bascule d'apprentissage vers révision), pas à un simple "retour en arrière" d'un pas.
- **Ne jamais introduire de ligne sentinelle hors-plage** (ex. `ayah_id=0`) pour représenter un état ("démarré", "en attente"...) — modéliser l'état comme un fait sur un **vrai** verset (typiquement `reach=0` sur le verset 1) au lieu d'un id inventé. Précédent corrigé : `startLearning()` écrit `ayah_id=1, reach=0` au démarrage d'une sourate, pas un id 0 fictif.
- Toute reconstruction d'état "en cours"/"actif" doit s'appuyer sur **l'existence d'une ligne** (n'importe quel `reach`), pas seulement sur les lignes `reach=1` — sinon un état "visé mais pas encore atteint" redevient invisible (piège identique à celui du sprint "fix").

## Vérifier l'harmonie avant de clore une tâche
- Le code correspond-il à ce que `docs/DOCUMENTATION_TECHNIQUE.md`/`docs/CHANGELOG.md` prétendent ? Ces fichiers sont maintenus à la main et peuvent dériver du dépôt réel (exemple vécu le 2026-08-20 : une section documentait des fonctionnalités et un test de régression qui n'étaient pas encore commités). Corriger l'un ou l'autre plutôt que de laisser la doc mentir.
- Un changement dans `revision_engine.dart` ou `freshness_engine.dart` respecte-t-il les règles métier déjà actées (répétition cyclique sans rakaa vide, no-repeat sourate par prière, cycle adaptatif, mode lignes/jour vs durée) ?
- Un changement visuel respecte-t-il la direction artistique Mus'haf/Tahajjud (clair papier crème/vert/or, sombre Tahajjud, suivi via `ThemeMode.system`) plutôt que d'introduire un style isolé ?

## Ne jamais oublier
- Mettre à jour le Backlog de `docs/CHANGELOG.md` (retirer les items traités, ajouter les nouvelles idées) à la fin de chaque sprint/tâche notable — c'est le seul backlog persistant du projet, pas de ticket externe. L'historique de ce qui a été livré vit dans `git log`, pas dans ce fichier (nettoyé en ce sens le 2026-09-01, ne garde plus que Backlog + décisions transversales). Mettre à jour `docs/DOCUMENTATION_TECHNIQUE.md` en plus si le sprint touche `RevisionEngine`, `FreshnessEngine`, `AppState`, ou ajoute/supprime un écran/service.
- `docs/CHANGELOG.md` est le **seul** fichier de backlog du projet — pas de fichier séparé (`README.md` racine et `bakclog-developper.txt` supprimés le 2026-08-29, fusionnés dans ce fichier). Toujours utiliser le chemin complet `docs/CHANGELOG.md` (pas `CHANGELOG.md` seul) pour éviter de recréer un fichier fantôme à la racine.
- Si une règle métier change dans `RevisionEngine`/`FreshnessEngine` sans test de régression associé, le signaler explicitement à l'utilisateur plutôt que de laisser passer silencieusement (voir `test/CLAUDE.md`, couverture quasi nulle aujourd'hui).
- Convention de commit : `feature/sprint-N: description` / `fix/sprint-N: description`.
