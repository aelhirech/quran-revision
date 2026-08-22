# Changelog — Quran Revision App

> Historique des sprints livrés + backlog en attente. C'est le seul historique persistant du projet (pas de ticket externe) — à mettre à jour à la fin de chaque sprint/tâche notable (voir `CLAUDE.md`, section « Ne jamais oublier »).
>
> Pour *comment* le code fonctionne aujourd'hui (architecture, moteurs métier, écrans), voir `docs/DOCUMENTATION_TECHNIQUE.md`. Ce fichier documente *quoi a été livré et quand*.

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

### Phase 5 — Sprint 7 : retours utilisateur (commits `191c570`, `a25da4a`)
- **Fix perte de progression** : les rakaas cochées dans la session du jour sont maintenant persistées (`AppState.checkedRakaas` + `StorageService`) — un redémarrage de l'app avant validation ne fait plus tout perdre. Le vrai passage de minuit régénère toujours un nouveau plan (comportement voulu), mais un simple redémarrage dans la même journée ne réinitialise plus les cases cochées.
- **Ordre des prières + Salat ad-Duha** : l'enum `Prayer` est réordonné par ordre chronologique réel de la journée (sunna avant/après le fard concerné, ex. Sunna Fajr → Fajr → Doha → Sunna Dhouhr (avant) → Dhouhr…) au lieu de "tous les fards puis toutes les sunnas". Ajout de `Prayer.duha` (absente jusqu'ici). Sérialisation par `.name` (pas d'index) — réordonner l'enum ne casse pas les configs déjà sauvegardées.
- **Nav réordonnée** : Réviser, Apprendre, Récap, Profil (au lieu de Réviser, Récap, Apprendre, Profil).
- **Profil — boutons rythme/sourates** : libellé texte visible ajouté à côté de l'icône (avant : icône seule + tooltip, peu clair au tactile).
- **Rendu des numéros de verset arabes** : police `Amiri` au lieu de `Scheherazade New` pour le texte arabe avec glyphe de fin de verset (`verse_display_card.dart`, `verse_bottom_sheet.dart`, mode Focus Mosquée) — le glyphe ornemental + chiffres arabes-indiens débordait de son cadre avec Scheherazade New.
- **Récap consultable** : `SouratesRecapCard` affiche désormais un badge de fraîcheur (Récente/Froide/Très froide) par sourate, réutilisant `FreshnessEngine`. Nouvel écran `SurahReaderScreen` (lecture plein texte, pas de mode caché/révélé) accessible en tapant une sourate depuis le Récap — jusqu'ici aucune navigation de lecture n'existait depuis cet écran.
- **Check-in "plan du jour"** : nouvelle carte en tête de l'aperçu du plan (avant engagement) avec salutation selon l'heure + liste des sourates froides/gelées du plan du jour, pour savoir en un coup d'œil quoi surveiller. Scope volontairement réduit par rapport à la demande initiale (pas de rituel matin/soir séparé, pas de mode jeu "versets froids" à part) — voir Backlog.
- **Onboarding avec surbrillance** : tour guidé (`SpotlightOverlay`, `lib/widgets/spotlight_tour.dart`) affiché une seule fois après l'onboarding, tant qu'aucune session n'est encore engagée. 6 étapes : présentation des 4 onglets, sélection des prières, bouton "Voir le plan du jour". Pas de dépendance externe ajoutée (overlay + `CustomPainter` maison). Pas de bouton "revoir le tutoriel" pour l'instant (aurait nécessité de faire communiquer ProfileScreen ↔ ShellScreen ↔ état HomeScreen — mis au backlog si le besoin se confirme).
- **Fix robustesse démarrage** : `WarshService.initialize()` entouré d'un `try/catch` dans `main.dart` — un échec de chargement de l'asset Warsh ne bloque plus le démarrage de l'app (fallback silencieux sur Hafs).
- **`/simplify` (commit `98b8e05`)** : badge de fraîcheur et rendu du texte arabe des versets factorisés (`widgets/freshness_badge.dart`, `widgets/arabic_verse_text.dart`, plus 2 duplications) ; état mort supprimé (`_justCompleted`) ; `AppState.toggleChecked` notifie avant l'écriture disque au lieu d'après (case cochée affichée sans attendre le round-trip SharedPreferences) ; `StorageService.loadCheckedRakaas` gère elle-même la péremption au lieu d'un check ad hoc dans `main.dart`.
- **`/code-review` complet du projet + fixes (commit `02acd78`)** : revue à 8 agents sur tout `lib/`, 25 findings consolidés. Corrigés notamment : la déclaration manuelle "une part fait" avançait le cycle en comptant des **rakaas** comme si c'étaient des **unités de cycle** (`PlanScreen._coverageForFirstRakaas` calcule maintenant la vraie couverture) ; la complétion partielle marquait *toutes* les sourates du plan comme "revues" même sans rien coché (fraîcheur faussée) ; `AppState.saveConfig` remettait le cycle à zéro pour tout changement de config, même un simple ajustement de rythme (compare maintenant l'ancienne et la nouvelle sélection) ; `clearConfig` vidait toutes les SharedPreferences (langue, riwaya, notifications) au lieu de la seule config (`StorageService.clearConfigOnly`) ; divergence "jours restants" Home vs Récap en cycle adaptatif ; division par zéro dans `RevisionEngine.buildDayPlan` si aucune sourate sélectionnée (+ test de régression) ; `loadConfig()` ne plante plus sur une config corrompue. Détail complet dans l'historique de conversation — 6 findings mineurs sciemment non traités (over-engineering vs risque réel pour une app locale mono-utilisateur), listés avec leur raison dans le rapport de revue.

### Documentation technique (2026-08-22)
- Création de `docs/DOCUMENTATION_TECHNIQUE.md` — référence de maintenance complète (architecture, moteurs métier détaillés, services, écrans, dette technique UI identifiée), générée à partir d'une lecture intégrale du code source.
- Suppression de `context/CONTEXT.md` — remplacé par `docs/DOCUMENTATION_TECHNIQUE.md` (comment ça marche) + ce fichier `CHANGELOG.md` (quoi a été livré, backlog).
- **Correction déploiement** : `codemagic.yaml` supprimé (n'était pas réellement utilisé — le déploiement se fait manuellement via Xcode, pas Codemagic). `CLAUDE.md`/`docs/DOCUMENTATION_TECHNIQUE.md` corrigés en conséquence ; la confirmation explicite avant push vers `main` reste requise (prudence générale), mais n'est plus justifiée par un risque de déclenchement TestFlight automatique.
- Mise à jour de `docs/DOCUMENTATION_TECHNIQUE.md` pour refléter les changements Sprint 7 (`checkedRakaas`/`_sameSelections`/`clearConfigOnly` dans `AppState`, `SurahReaderScreen`, `SpotlightOverlay`, fix unités/rakaas de `_CommitmentSheet`, pipeline `_onComplete` réordonné+parallélisé) — dette technique §8.5 mise à jour (items corrigés retirés, nouveaux items non traités ajoutés avec raison).

---

## Backlog

| Priorité | Feature | Notes |
|----------|---------|-------|
| P3 | **Gamification narrative [H]** | vision long terme — direction artistique déjà validée (Mus'haf/Tahajjud), reste à définir la mécanique narrative |
| P3 | **Cycle wrap affiché** | si cyclePosition + totalUnits > cycleTotal, afficher "(cycle bouclé)" dans le summary bar |
| P2 | **Rituel matin/soir "check-in/check-out"** | Sprint 7 a livré un check-in simple (salutation + sourates froides) mais pas de distinction matin (check-in) / soir (check-out) ni de mécanique dédiée — à définir : qu'est-ce qui différencie concrètement les deux moments dans ce contexte de révision (pas un usage compulsif à limiter comme les apps anti-addiction) |
| P2 | **Mode "versets froids" en jeu à part** | écran dédié en dehors du plan du jour classique pour retravailler spécifiquement les versets/sourates froids ou gelés, en mode ludique — nécessite de définir la mécanique de jeu avant d'implémenter (valeur vs complexité à évaluer) |
| P3 | **Historique par verset** | aujourd'hui la fraîcheur (Sprint 3, étendue Sprint 7) est au niveau sourate ; un suivi verset par verset demanderait un nouveau modèle de données (`sourate_sessions` ne descend pas à ce niveau) |
| P3 | **Revoir le tutoriel depuis Profil** | le tour (Sprint 7) ne s'affiche qu'une fois après l'onboarding ; un bouton de replay demanderait de faire communiquer ProfileScreen → ShellScreen (changer d'onglet + relancer le tour), pas fait faute de demande explicite |
| P3 | **Source vérifié du coran** | vérifier le coran warsh et hafs |

---

## Convention de commit

```
feat(sprint-N): description
fix(sprint-N): corrections code review
```
