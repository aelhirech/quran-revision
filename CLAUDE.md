# CLAUDE.md — quran-revision

Instructions de travail pour ce dépôt. Complète `docs/DOCUMENTATION_TECHNIQUE.md` (architecture, moteurs métier, écrans — comment le code fonctionne), `docs/USER_STORIES.md` (cadrage business : user stories actives + leurs critères d'acceptation, alimenté par le skill `quran-blueprint` puis complété par `quran-scoping`) et `docs/CHANGELOG.md` (backlog technique prêt-à-implémenter + décisions transversales utiles aux futurs sprints — plus un historique de livraison, voir `git log` pour ça) — ne les remplace pas.

> Ce projet utilisait un fichier `context/CONTEXT.md` comme fichier de continuité unique, scindé le 2026-08-22 en `docs/DOCUMENTATION_TECHNIQUE.md` + `docs/CHANGELOG.md`. Le « Sprint Workflow » défini dans le `CLAUDE.md` parent (`d:\Prog\CLAUDE.md`, partagé entre projets) se déclenche sur la présence d'un fichier `context/CONTEXT.md` — pour ce projet, considérer que `docs/CHANGELOG.md` en tient lieu, mais uniquement pour l'étape « Backlog » (retirer les items traités, ajouter les nouvelles idées) : depuis le 2026-09-01, ce fichier ne journalise plus les livraisons sprint par sprint (rôle repris par `git log`/les messages de commit) et ne garde que le Backlog + quelques décisions transversales utiles à qui reprend un item.

## Déclencheurs de sprint

Quatre phrases suffisent pour piloter tout le cycle défini dans le Sprint Workflow du `CLAUDE.md` parent (`d:\Prog\CLAUDE.md`) — pas besoin de redétailler les étapes à chaque fois. Le Sprint Workflow parent se déclenche historiquement sur « Début de scoping » ; ici ce trigger est scindé en deux (« Début de blueprint » puis « Début de scoping », voir ci-dessous) avant d'enchaîner sur « Début de sprint ».

### « Début de blueprint » (+ description du besoin) — skill `quran-blueprint`
Phase de cadrage business — **zéro code, zéro branche, zéro écriture dans le Backlog technique**.
Transforme le besoin décrit dans le prompt (+ ce qui traîne déjà dans `docs/USER_STORIES.md`) en
user stories testables (statement + critères d'acceptation), plafonnées à ~10 stories actives,
ajustées plutôt qu'empilées. S'arrête sur `docs/USER_STORIES.md` mis à jour et validé par
l'utilisateur — n'enchaîne jamais sur le scoping technique ni sur l'implémentation dans la même
phase. Détail complet des étapes : `SKILL.md` du plugin `quran-blueprint`.

### « Début de scoping » (+ ID de story ou "backlog") — skill `quran-scoping`
Phase d'analyse technique — **zéro code, zéro branche**. Prend une ou plusieurs user stories de
`docs/USER_STORIES.md` (état "à scoper"), deep-dive dans le code pour identifier fichiers UI/
variables/tables concernés, tranche "variable ou nouvelle table" selon le modèle `ayah_facts` et
les règles d'architecture du projet (sur-ingénierie, duplication — voir sections dédiées
ci-dessous), ajuste les critères d'acceptation si le code révèle un cas non prévu, puis écrit
l'item prêt-à-implémenter dans le Backlog de `docs/CHANGELOG.md` (remplace une entrée vague
existante plutôt que de s'ajouter à côté ; un besoin écarté reste dans le Backlog avec sa raison,
jamais retiré silencieusement). Ne remet jamais en cause le besoin business déjà tranché par le
blueprint. **Ne dispense pas des étapes `/simplify`/`/code-review` de fin de sprint** — le scoping
réduit ce qu'elles remontent, il ne les remplace pas (une analyse avant écriture du code ne peut
pas attraper les erreurs qui n'apparaissent qu'à l'implémentation). S'arrête sur le Backlog mis à
jour et attend le déclencheur « Début de sprint ». Détail complet : `SKILL.md` du plugin
`quran-scoping`.

### « Début de sprint » (+ description de ce qu'on fait)
1. Lire `docs/DOCUMENTATION_TECHNIQUE.md` + `docs/CHANGELOG.md` 
2. Créer la branche `feature/phase-X-sprintN`.
3. Implémenter.

### « Fin de sprint »
Exécuter dans l'ordre, sans redemander de confirmation entre chaque étape **sauf pour le push final** :
1. `/simplify` — sur-ingénierie, réutilisation, cleanups. **Sauter cette étape si le sprint est structurellement trivial** (bump de version, renommage de string, changement de config sans logique) : rien à simplifier dans ce genre de diff, la passe ne consomme des tokens que pour un résultat vide.
2. `/code-review medium` — bugs de correction. **Toujours préciser le niveau explicitement** : sans niveau, la commande réutilise silencieusement le dernier niveau tapé dans la session, qui peut dériver vers `high`/`max` sans qu'on s'en aperçoive. Monter à `/code-review high` si le sprint touche `RevisionEngine`, `FreshnessEngine`, ou `AppState`.
3. Appliquer les fixes remontés par les deux passes.
4. Mettre à jour `docs/CHANGELOG.md` (retirer du Backlog les items traités par ce sprint, ajouter les nouvelles idées identifiées, noter une décision transversale seulement si elle sera utile à un futur sprint — pas un résumé de ce qui a été livré, le commit s'en charge), et `docs/DOCUMENTATION_TECHNIQUE.md` si le sprint a touché `RevisionEngine`, `FreshnessEngine`, `AppState`, ou ajouté/supprimé un écran/service.
5. Commit sur la feature branch (feature(sprint-N):)
6. Vérifier que la demande utilisateur a bien été traitée dans son intégralité avec soit une modification de code soit un enregistrement dans docs/CHANGELOG.md après discussion avec l'utilisateur : (Pourquoi on la pas traité, décision manquantes, trop flou pour être implémenter etc)
7. **Avant de merger et pusher `main`, si le sprint touche du code iOS : bumper le build number dans `pubspec.yaml`.** Depuis le 2026-08-31, `codemagic.yaml` ne calcule plus automatiquement le build number (le lookup App Store Connect/TestFlight s'est montré peu fiable — voir incident du même jour : collision `ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE` car le build 5 avait déjà été publié et rien ne répercutait le nombre utilisé dans `pubspec.yaml`). `pubspec.yaml` (`version: X.Y.Z+N`) est donc la **seule source de vérité** du build number iOS : `flutter build ipa` lit `+N` directement, sans override. Avant de pusher `main`, vérifier le dernier build number publié sur TestFlight/App Store Connect et bumper `+N` strictement au-dessus dans `pubspec.yaml`.
8. **Avant de merger et pusher `main` : demander confirmation explicite.** Depuis le 2026-08-29, CI/CD Codemagic connectée à ce dépôt (`codemagic.yaml`, workflow `ios-testflight`) : un `git push` sur `main` déclenche automatiquement build + signing + **publication TestFlight**. La confirmation est donc requise pour une vraie raison opérationnelle (déclenchement automatique d'une distribution externe), pas seulement par prudence générale. Toutes les autres étapes ci-dessus peuvent s'enchaîner sans interruption ; celle-ci non.

## Au début de chaque session
1. Lire `docs/DOCUMENTATION_TECHNIQUE.md` et `docs/CHANGELOG.md` en entier ; lire aussi `docs/USER_STORIES.md` s'il existe et que le travail touche un blueprint/scoping en cours.
2. Si le travail touche `test/`, lire aussi `test/CLAUDE.md`.
3. Ne pas prendre `docs/DOCUMENTATION_TECHNIQUE.md`/`docs/USER_STORIES.md`/`docs/CHANGELOG.md` pour argent comptant : ce sont des fichiers maintenus à la main, ils dérivent du code réel avec le temps (voir "Vérifier l'harmonie" ci-dessous).

## Ne jamais sur-ingénierer
Projet solo, un seul développeur, Provider comme unique gestion d'état.
- Pas de nouvelle lib de state management, DI ou couche d'architecture supplémentaire tant que la taille du projet ne le justifie pas.
- Pas d'abstraction ajoutée « au cas où » (interface pour un seul service concret, factory pour un seul type, config générique pour un seul cas d'usage).
- Le code minimal qui fait marcher la fonctionnalité proprement, pas plus. Une règle métier utilisée une seule fois ne se généralise pas.
- Avant d'ajouter une dépendance dans `pubspec.yaml`, vérifier qu'elle n'est pas déjà couverte par l'existant.

## Ne jamais dupliquer une logique quasi identique

Avant d'écrire un nouveau mécanisme (widget, service, requête, calcul) pour un besoin, chercher
(grep/lecture du code existant, ou agent `Explore`) si un mécanisme quasi identique répond déjà à
un besoin quasi identique ailleurs dans le code — réutiliser ou étendre plutôt que réimplémenter
en parallèle. S'applique à tout agent qui explore ou modifie ce dépôt (recherche de code avant
d'implémenter une feature, audit, revue avant de clore une tâche), pas seulement à un domaine
précis — deux précédents réels l'ont révélée dans des domaines différents :
- `AppState._checkedRakaas` dupliquait ce qu'`ayah_facts.reach` savait déjà faire (sprint
  "simplify-ayah-facts", 2026-09-02 — voir § « Modèle de données central » ci-dessous).
- Trois écrans (Plan du jour, Récap, Apprendre) réimplémentaient chacun une boucle d'affichage
  d'une plage de versets coraniques, avant unification derrière `VerseBottomSheet`/`VerseRow`
  (sprint 2026-09-02 — voir `docs/DOCUMENTATION_TECHNIQUE.md` §8.6).

## Règles d'architecture à ne jamais casser
- `lib/core/` : zéro import Flutter, zéro I/O, Dart pur.
- `lib/services/` : stateless, jamais de `notifyListeners`.
- `lib/state/app_state.dart` : un seul `notifyListeners()` par opération logique.
- Modèles (`lib/models/`) : mise à jour uniquement via `copyWith()`.
- Dans un `State` : `if (!mounted) return;` après chaque `await`.
- Texte affiché à l'utilisateur → `lib/core/strings.dart` (FR/EN) ; texte arabe → `lib/services/verse_service.dart`. Jamais d'appel direct à `package:quran` dans un écran/widget.
- Couleurs/typo → toujours via `AppPalette` (`lib/core/app_colors.dart`), jamais de couleur en dur dans un widget.

## Commentaires : priment sur "match existing style"
Le code existant contient beaucoup de commentaires en français — ne pas reproduire ce style dans le nouveau code, ni l'imiter par mimétisme malgré la règle générale "colle au style existant" (`d:\Prog\CLAUDE.md` §3, qui ne s'applique pas ici).
- Anglais, pas français.
- Uniquement pour le WHY non-évident (contrainte cachée, invariant, contournement d'un bug précis) — jamais pour décrire le WHAT (le nom des variables/fonctions doit suffire).
- Pas de docstring multi-lignes sauf API publique exposée (service/package partagé).
- Ne pas nettoyer rétroactivement les commentaires français existants sans qu'on le demande — cette règle vise uniquement la propagation dans le nouveau code.

## Modèle de données central : `ayah_facts`

`ayah_facts` (`lib/services/ayah_facts_service.dart`) n'est pas une table parmi d'autres : c'est le **journal de la relation entre l'utilisateur et le Coran** — l'unique source de vérité dont tout le reste (fraîcheur, streak, plan du jour, apprentissage, récap) est *reconstruit* par requête, jamais recalculé/stocké en parallèle. Avant d'ajouter un flag, un compteur ou une table séparée pour une nouvelle fonctionnalité, se demander d'abord si elle peut se dériver d'`ayah_facts`.

**Grain et sémantique** — une ligne = un événement daté, un verset **réel** (`ayah_id` toujours dans la plage 1..N de la sourate, jamais un id hors-plage/sentinelle), un type (`learn`|`revise`) :
- `reach=0` = verset **visé/proposé** (elle cherche à l'apprendre / il est proposé au plan du jour), pas encore acquis.
- `reach=1` = verset **atteint** (appris, ou fait/révisé).
- Passer de 0 à 1 se fait par **mise à jour** de la ligne existante (`setReach`, `learnVerses`) ou par une **nouvelle ligne datée** si l'action a lieu un autre jour (l'unicité est `date+riwaya+surah_id+ayah_id+type` — deux dates distinctes coexistent, ce qui préserve l'historique : "visé le J1, atteint le J5").
- **Annuler une progression repasse `reach` à 0, ne supprime jamais la ligne** (`unlearnVerse`) — sinon la seule ligne qui rattachait un verset/une sourate à "en cours" disparaît et on retombe dans la même classe de bug que celui corrigé au sprint "fix" du 2026-09-01 (sourate qui disparaît de "en cours d'apprentissage"). Un vrai `DELETE` (`deleteLearnFacts`, `removeFromDayPlan`) reste réservé aux hand-off/abandons explicites (ex. sourate qui bascule d'apprentissage vers révision), pas à un simple "retour en arrière" d'un pas.
- **Ne jamais introduire de ligne sentinelle hors-plage** (ex. `ayah_id=0`) pour représenter un état ("démarré", "en attente"...) — modéliser l'état comme un fait sur un **vrai** verset (typiquement `reach=0` sur le verset 1) au lieu d'un id inventé. Précédent corrigé : `startLearning()` écrit `ayah_id=1, reach=0` au démarrage d'une sourate, pas un id 0 fictif.
- Toute reconstruction d'état "en cours"/"actif" doit s'appuyer sur **l'existence d'une ligne** (n'importe quel `reach`), pas seulement sur les lignes `reach=1` — sinon un état "visé mais pas encore atteint" redevient invisible (piège identique à celui du sprint "fix").

## Règle du plan quotidien : quelles pages, et comment elles arrivent dans les rakaas

> **RÈGLE CIBLE — le code n'y est PAS encore conforme** (voir Backlog P1 de `docs/CHANGELOG.md`,
> « Refonte du curseur de cycle »). En cas d'écart entre ce bloc et le code, **c'est le code qui est
> faux**, pas ce bloc. Cette règle est écrite ici parce que son absence a laissé passer trois bugs
> majeurs pendant plusieurs sprints : personne ne pouvait constater que le code ne la respectait pas.

### Vocabulaire

| Terme | Définition |
|---|---|
| **Sélection** | Ce que l'utilisateur a choisi de réviser : une liste de portions (sourate + plage `verseStart..verseEnd`, souvent la sourate entière) — `UserConfig.selections`. |
| **Page** | Une page **réelle** du mushaf, pour la riwaya active (`PageMetadataService`). |
| **Fragment** | L'intersection d'une portion de la sélection et d'une page. |
| **Entrée de cycle** | Une page, avec tous les fragments de la sélection qui s'y trouvent. |
| **Curseur** (`cyclePosition`) | L'index de la **prochaine entrée** à réviser. **En pages, jamais en sourates.** |

### A. Construire le cycle — fonction pure et déterministe

```text
CONSTRUIRE_LE_CYCLE(sélection, pagination, mélange, graine) -> [entrées]

1. ordre := sélection
   si mélange : ordre := mélanger(ordre, graine)
   # Le mélange s'applique au niveau SOURATE uniquement.
   # Une sourate n'est jamais éclatée ni réordonnée par le mélange.

2. fragments := []
   pour chaque portion de `ordre`, dans l'ordre :
       pour chaque page p couverte par [portion.début .. portion.fin], n° croissant :
           fragments += { page:     p,
                          sourate:  portion.sourate,
                          début:    max(portion.début, premier verset de p),
                          fin:      min(portion.fin,   dernier verset de p),
                          rang:     index de la portion dans `ordre` }

3. entrées := regrouper les fragments par numéro de page
   # Plusieurs courtes sourates sur une même page physique = UNE entrée,
   # donc UNE journée. Le regroupement tombe du modèle, ce n'est pas un cas particulier.

4. trier les entrées par (plus petit `rang` de leurs fragments, puis n° de page croissant)
   # Le mélange ordonne les sourates ; à l'intérieur d'une sourate,
   # les pages restent toujours dans l'ordre du mushaf.

5. cycleTotal := nombre d'entrées   # = nombre de pages réelles à réviser
```

### B. Le plan du jour

```text
PLAN_DU_JOUR(cycle, curseur, pagesParJour) -> [entrées du jour]

si cycle est vide : ne rien proposer, et le SIGNALER (ne jamais boucler à vide en silence)

n := min(pagesParJour, cycleTotal)
retourner [ cycle[(curseur + i) mod cycleTotal] pour i de 0 à n-1 ]
```

### C. La clôture — ce qui fait avancer le curseur

```text
CLÔTURE(jour) -> de combien avancer le curseur

faites := 0
pour i de 0 en avant :
    e := cycle[(curseur + i) mod cycleTotal]
    selon l'état des fragments de `e` pour ce jour dans ayah_facts :
      aucune ligne, et `e` était dans la proposition du jour
          -> retirée au check-in : ni comptée ni bloquante, on continue
      aucune ligne, et `e` est AU-DELÀ de la proposition du jour
          -> contenu simplement pas fait : on s'arrête
      au moins une ligne, toutes à reach=1
          -> faites += 1, on continue      # « faire plus » fait avancer le cycle
      au moins une ligne, au moins une à reach=0
          -> on s'arrête

curseur := (curseur + faites) mod cycleTotal
# Une même journée ne fait avancer le curseur qu'UNE fois (garde `isDaySealed`).
```

### D. La répartition en rakaas

```text
RÉPARTIR_EN_RAKAAS(entrées du jour, prières choisies, portion à apprendre)

# LE PLAN PAR RAKAA EST UN AFFICHAGE, PAS UNE SOURCE DE VÉRITÉ (cadrage 2026-09-08).
# Il ne décide jamais NI de ce qui est proposé (c'est PLAN_DU_JOUR),
# NI de ce qui est crédité (c'est CLÔTURE).
# Seuls le check-in et le check-out écrivent dans `ayah_facts`.

rakaasRécitées := somme des rakaas récitées des prières choisies
si une portion à apprendre existe :
    réserver la TOUTE DERNIÈRE rakaa récitée du jour
    budget := rakaasRécitées - 1
sinon :
    budget := rakaasRécitées

fragments := tous les fragments des entrées du jour, dans l'ordre

si nombre de fragments <= budget :
    subdiviser les fragments pour remplir exactement `budget`,
    sans jamais descendre sous `_minLinesPerSlot` lignes par rakaa ;
    s'il reste des rakaas à remplir, répéter cycliquement (jamais de rakaa vide)
sinon :
    les `budget` premiers fragments vont dans les rakaas, dans l'ordre ;
    LE RESTE est affiché à part, dans un bloc « à réviser en dehors des prières ».
    # Rien n'est perdu ni caché : tout le contenu du jour reste visible et créditable.

dans une même prière : ne jamais assigner deux fois le même fragment
tant qu'une alternative non encore utilisée dans cette prière existe.
les rakaas au-delà de `suratRakaas` restent « Al-Fatiha seule » — seul cas de rakaa vide légitime.
```

### E. Invariants — à vérifier par test, pas par relecture

1. **Aucune page sautée.** Une sourate de N pages est couverte en N entrées consécutives : page 1
   aujourd'hui, page 2 demain, jusqu'à la fin. C'était le bug principal du 2026-09-08.
2. **Aucune répétition avant bouclage.** Tant que `cycleTotal` entrées n'ont pas été parcourues,
   aucune page n'est reproposée.
3. **Jamais hors de la plage choisie.** Si l'utilisateur ne sélectionne que les versets 255–260
   d'Al-Baqara, aucun autre verset n'est jamais proposé. C'était le second bug du 2026-09-08.
4. **Le curseur progresse à l'intérieur d'une sourate**, y compris quand elle est seule sélectionnée.
5. **Aucun contenu crédité sans avoir été proposé** au check-in ou déclaré au check-out.
6. **Aucune rakaa récitée vide** tant qu'il reste de la matière.

### F. Cas limites — la réponse est ici, pas dans le code

| Cas | Comportement attendu |
|---|---|
| Portion sans métadonnée de page | Ignorée du cycle **et signalée**, jamais un plan vide silencieux. |
| `pagesParJour` > `cycleTotal` | Le jour propose tout le cycle, une seule fois (pas de répétition). |
| Page partagée par 2 sourates sélectionnées | Une seule entrée, donc une seule journée, et **une seule page** dans les compteurs. |
| Page partagée dont une seule sourate est sélectionnée | Entrée normale ; la sourate non sélectionnée n'y entre jamais. |
| Portion retirée au check-in | Ni comptée ni bloquante à la clôture. |
| Changement de rythme en cours de sourate | Le curseur ne bouge pas : seul le nombre d'entrées prises par jour change. |
| Changement de sélection | Le cycle est reconstruit ; la progression repart de 0 (`saveConfig` le fait déjà). |
| Changement de riwaya | Cycle et curseur sont scopés par riwaya, indépendants. |
| Journée sautée | Le curseur n'avance pas ; rien n'est perdu, le contenu revient le lendemain. |

## Vérifier l'harmonie avant de clore une tâche
- Le code correspond-il à ce que `docs/DOCUMENTATION_TECHNIQUE.md`/`docs/CHANGELOG.md` prétendent ? Ces fichiers sont maintenus à la main et peuvent dériver du dépôt réel (exemple vécu le 2026-08-20 : une section documentait des fonctionnalités et un test de régression qui n'étaient pas encore commités). Corriger l'un ou l'autre plutôt que de laisser la doc mentir.
- Un changement dans `revision_engine.dart` ou `freshness_engine.dart` respecte-t-il les règles métier déjà actées (répétition cyclique sans rakaa vide, no-repeat sourate par prière, cycle adaptatif, mode lignes/jour vs durée) ?
- Un changement visuel respecte-t-il la direction artistique Mus'haf/Tahajjud (clair papier crème/vert/or, sombre Tahajjud, suivi via `ThemeMode.system`) plutôt que d'introduire un style isolé ?
- Le mécanisme que je viens d'écrire fait-il double emploi avec un mécanisme quasi identique déjà présent ailleurs (même requête, même boucle d'affichage, même calcul) ? Voir § « Ne jamais dupliquer une logique quasi identique » — factoriser avant de clore plutôt que laisser deux implémentations diverger silencieusement.

## Ne jamais oublier
- Mettre à jour le Backlog de `docs/CHANGELOG.md` (retirer les items traités, ajouter les nouvelles idées) à la fin de chaque sprint/tâche notable — c'est le seul backlog technique persistant du projet, pas de ticket externe. L'historique de ce qui a été livré vit dans `git log`, pas dans ce fichier (nettoyé en ce sens le 2026-09-01, ne garde plus que Backlog + décisions transversales). Mettre à jour `docs/DOCUMENTATION_TECHNIQUE.md` en plus si le sprint touche `RevisionEngine`, `FreshnessEngine`, `AppState`, ou ajoute/supprime un écran/service.
- Quand un sprint clôt une story issue de `docs/USER_STORIES.md`, passer son état à "terminée" puis l'archiver (section "Archivées" du fichier) — ne pas la laisser traîner à l'état "en sprint".
- `docs/CHANGELOG.md` est le **seul** fichier de backlog du projet — pas de fichier séparé (`README.md` racine et `bakclog-developper.txt` supprimés le 2026-08-29, fusionnés dans ce fichier). Toujours utiliser le chemin complet `docs/CHANGELOG.md` (pas `CHANGELOG.md` seul) pour éviter de recréer un fichier fantôme à la racine.
- Si une règle métier change dans `RevisionEngine`/`FreshnessEngine` sans test de régression associé, le signaler explicitement à l'utilisateur plutôt que de laisser passer silencieusement (voir `test/CLAUDE.md`, couverture quasi nulle aujourd'hui).
- Convention de commit : `feature/sprint-N: description` / `fix/sprint-N: description`.
