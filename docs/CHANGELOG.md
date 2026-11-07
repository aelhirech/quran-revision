# Changelog — Quran Revision App

> Backlog technique en attente + idées produit non scopées. L'historique des sprints livrés vit dans `git log`, pas ici. Ce que fait l'app aujourd'hui (règles produit, plan quotidien, invariants, cas limites) : `docs/SPEC_PRODUIT.md`. Comment c'est codé, et les décisions techniques actives à respecter : `docs/DOCUMENTATION_TECHNIQUE.md` (§13bis). Modèle de données `ayah_facts` : `CLAUDE.md`.

---

## Backlog technique

Dette réelle et gaps prêts à l'implémentation — priorité qui reflète le risque/l'effort, pas l'enthousiasme produit. P1 = risque de correction (données/comportement), P2 = gap concret ou nettoyage rapide, P3 = différé délibérément (aucun bug connu) ou pure polish. Les idées produit non scopées vivent dans la section « Idées produit » plus bas, pas ici.

### [P2] US-30 Sprint B — Composer les questions hors du fil de l'interface
Déclencheur atteint à la clôture du Sprint A (2026-11-07, profile sous Windows, 113 sourates, pire
de trois essais, `docs/DOCUMENTATION_TECHNIQUE.md` §5.6) :
- à froid, 439 ms à la première ouverture de l'onglet (calcul de l'offre :
  `surahsOfferingPassages` analyse toute la sélection) et 575 ms à la première série « Mélange »
  (mots de toute la sélection) ;
- à chaud, 104 à 129 ms pour une série « Mélange » sur toute la sélection et 85 à 106 ms en
  « Versets ». « Traduction » (73 à 93 ms), une seule sourate (45 à 79 ms) et « Choisir une
  sourate » (environ 27 ms) tiennent déjà.
Les deux étapes sont donc à faire, dans l'ordre, avec la mesure après chacune.
- **Étape 1, froid** : `ReinforcementCorpus.warm(carried, textOf, glosses)` remplit le mémo par
  tranches de 10 sourates (passages, puis mots si `WordGlossService.availableFor`), avec `await
  Future<void>.delayed(Duration.zero)` entre deux tranches. Lancé par l'onglet quand il devient
  affiché (`shown`, `didUpdateWidget`), **avant** `_computeOffer`, qui attend sa fin. Aucun isolate.
- **Étape 2, chaud** (si un cas dépasse encore 100 ms après l'étape 1) : composer dans un isolate avec `Isolate.run` (`dart:isolate`), appelé
  depuis `reinforcement_tab.dart`. En entrée : textes et sens des versets connus, graine, mode,
  `surahId`. En sortie : la liste de questions. `lib/core/` reste sans import Flutter. Les objets
  renvoyés sont des copies : les écrans comparent déjà par `id`, jamais par `identical`.
- **Tests** : parité, même graine avec et sans isolate, mêmes `id`. Même protocole de mesure que le
  Sprint A, après chaque étape.
- **Exclus** : normalisation sans expression régulière (à reconsidérer seulement si l'étape 1 ne
  suffit pas à froid) ; aucun changement d'affichage.
- **Doc** : `docs/DOCUMENTATION_TECHNIQUE.md` §5.6 (mesures avant et après), §13bis (préchauffage,
  isolate). Fondre US-30 dans `docs/SPEC_PRODUIT.md` § Renforcement, puis la retirer de
  `docs/USER_STORIES.md`.

### [P2] US-31 Sprint B — vérification sous Windows (onboarding, Réglages, check-in, plan)
Le Sprint B est livré sans les captures Windows prévues (choix utilisateur, 2026-11-07). Seuls les
widgets recopiés dans `test/widgets/text_scale_fit_test.dart` sont verrouillés ; les écrans qui
chargent `AppState` ne l'ont jamais été vus avec un texte ×1,5.
- **À faire** : `flutter run -d windows`, 320×568 et 375×667, texte ×1,5, en clair et en sombre.
  - Onboarding, sélection : l'en-tête défile, plus de deux sourates visibles, les en-têtes de hizb
    restent collés, « Al-Baqara » suivi de sa plage ne déborde pas.
  - Réglages : ligne « Rythme » entière ; mode édition, « Tout sélectionner » sur une ligne.
  - Check-in : section prières, libellé et « Dernières prières » côte à côte.
  - Plan du jour : titre « Révision en cours », ligne d'une rakaa d'apprentissage avec badge.
- **Corriger** ce qui déborde, avec le même motif (`Flexible` autour du `FittedBox` dans une `Row`).
- **Doc** : rien. Supprimer cet item une fois la vérification faite.

### [P3] « 1 versets » dans la carte des sourates du Récap
Vu au Sprint C d'US-31 (2026-11-07), qui l'a corrigé dans le curseur de plage : une plage d'un
seul verset affiche « (1 versets) ». `S.versetsCount(n)` accorde déjà le pluriel.
- **`lib/widgets/sourates_recap_card.dart`** (plage partielle) : `(${sel.verseCount}
  ${S.versetsLabel})` devient `(${S.versetsCount(sel.verseCount)})`.
- Les libellés « x/y versets » et « x / y versets » (`sourate_list.dart`, `history_card.dart`)
  restent : le pluriel s'y accorde à y.
- **Tests** : aucun nouveau ; `flutter test` vert.

### [P3] Test qui interdit un `fontSize:` littéral hors `app_theme.dart`
Relevé au Sprint B1 d'US-25 (2026-10-22) : rien n'empêche un futur écran de réécrire un
`TextStyle(fontSize: …)` à côté des six styles d'`AppText`. Un test (`test/core/
app_text_usage_test.dart`) lit chaque fichier `.dart` de `lib/` et échoue sur toute ligne où
`fontSize:` est suivi d'un nombre (`fontSize:\s*\d`), sauf dans `lib/core/app_theme.dart` et sauf
les lignes `GoogleFonts.` (texte arabe). Le nombre et pas le simple `fontSize:` (relevé au Sprint
B2) : deux lignes légitimes restent, `IndexBadge` (`fontSize: size * 0.37`, chiffre proportionnel
à la pastille) et `VerseRow` (`ArabicVerseText(fontSize: fontSize)`, paramètre de la police
arabe). Exclus tant qu'US-23 et US-21 n'ont pas reconstruit le Récap et l'onglet Quiz :
`recap_screen.dart`, les trois widgets qu'il est seul à afficher (`history_card.dart`,
`sourates_recap_card.dart`, `learning_progress_card.dart`) et `lib/screens/reinforcement/`, listés
en dur dans le test et retirés au fil des livraisons.

### [P2] Embarquer Amiri et Scheherazade dans l'app
Relevé au scoping d'US-25 (2026-10-22). Les polices du texte coranique sont téléchargées par
`google_fonts` au premier affichage : hors connexion au premier lancement, le Coran s'affiche dans la
police du système. Tâche technique, hors blueprint. US-25 Sprint A a créé `assets/fonts/` (Outfit,
déclaré dans `pubspec.yaml`).
- **Fontes** : les fichiers Amiri et Scheherazade New utilisés par l'app (graisses à relever sur les
  12 appels existants) vont dans `assets/fonts/` avec leurs licences OFL. `google_fonts` les trouve
  dans les assets par leur nom de fichier : garder le nom exact attendu par le package
  (`Amiri-Regular.ttf`, ...) et ne pas changer les 12 appels.
- **`lib/main.dart`** : `GoogleFonts.config.allowRuntimeFetching = false`, pour qu'aucune police ne
  soit plus téléchargée.
- **Tests** : les tests qui mettent déjà `allowRuntimeFetching = false` passent toujours ; à l'œil
  sous Windows, réseau coupé, le texte coranique s'affiche en Amiri.

### [P3] Hook de reprise d'arrière-plan logé dans `ShellScreen`, pas `AppState`
Relevé en `/code-review high` du sprint US-3 (2026-09-21, altitude). Le `WidgetsBindingObserver`
qui rejoue `ensureDayPlan()` au retour d'arrière-plan (US-3 crit. 5) — et depuis US-10 Sprint B
`AudioDownloadService.resumePending()` — vit dans `ShellScreen`. Un
futur écran racine qui ne descendrait pas de `ShellScreen` devrait dupliquer ce hook. Différé :
un seul écran racine existe aujourd'hui, centraliser dans `AppState` maintenant serait de la
généralisation anticipée pour un cas qui n'existe pas encore.

### [P3] Retirer les `await` sur `DaySelection` dans deux fichiers de test
Relevé à la clôture du sprint 23 (2026-10-22) : `flutter analyze lib test` remonte 26 infos
`await_only_futures` — 21 dans `test/core/revision_engine_test.dart`, 5 dans
`test/state/app_state_checkin_test.dart` — sur des `await` devant une expression `DaySelection`
synchrone. Retirer ces `await`, sans autre changement ; `flutter analyze lib test` doit revenir à
zéro. Pur bruit d'analyse, aucun comportement touché.

## Idées produit (non scopées)

Besoins réels mais pas encore cadrés : chacun contient une décision ouverte. Ils passent par `quran-blueprint` (user story dans `docs/USER_STORIES.md`) puis `quran-scoping` (item au Backlog ci-dessus) avant tout code. Ne pas lancer à la volée.

### Plan du jour et check-in

- **Versets revenus : contexte calculé, jamais affiché.** `AppState.returningVersesContext` calcule
  le verset qui précède chaque verset revenu (`RevisionEngine.contextVerseFor`), mais
  `ReturnProofStep` n'en lit que les clés : la valeur est un calcul mort. Piste retenue le
  2026-09-26 : faire atterrir les versets revenus dans le bloc hors prières
  (`OutsidePrayersBlock`) plutôt que de les montrer avec leur contexte. Reste à choisir : cette
  piste (story, à articuler avec `distributeToRakaas`/`RevisionUnit.==` et le message
  `return_proof_seen`), ou retirer le calcul (alors item de Backlog trivial).
- **Check-in : trois comportements aux bords** (Sprint A d'US-27, 2026-10-21) :
  - *Jour validé sans aucune ligne* (tout retiré, rien à apprendre) : indiscernable d'un jour jamais
    commencé, donc un check-in rouvert après « Refaire le plan » repropose les valeurs par défaut.
    Un marqueur « commencé » (comme `last_sealed_date`) le réglerait, au prix d'une seconde source
    de vérité.
  - *Retirer une unité déjà atteinte* (`reach=1`) dans un check-in rouvert : elle disparaît de
    l'écran, mais `commitCheckIn` ne supprime jamais une ligne `reach=1`, donc elle revient au plan
    sans message. À choisir : bloquer le « × » sur une unité atteinte, ou autoriser la suppression.
  - *Étendre une unité jusqu'à toucher la suivante* (même sourate, même jour, `+` du détail) : le
    brouillon montre le même verset dans les deux unités, la base n'en écrit qu'un. À choisir :
    cacher le « + » à la frontière, ou fusionner les deux unités.
- **Rattrapage d'un jour passé : le curseur lit celui d'aujourd'hui** (déduit du code au sprint
  21, non reproduit) : `_completedPagesFor` parcourt le cycle depuis la `cyclePosition` du jour
  même pour un check-out passé. Une sourate déclarée « en plus » un jour passé pourrait faire
  sauter des groupes jamais révisés si ce jour est scellé après que le curseur a bougé.
  `ensureDayPlan` gèle le plan tant qu'un jour est en attente, ce qui rend le cas rare. À
  reproduire par un test avant de choisir un correctif.
- **Verset retiré après l'élargissement d'une sourate** (US-29, 2026-10-28) : retirer au check-out
  le dernier bloc appris d'une sourate déjà élargie la remet en apprentissage, mais sa sélection
  reste entière. Quand elle est finie à nouveau, la fin de journée ne l'annonce plus, car elle est
  déjà entière. À choisir : revenir à la plage d'avant, ou garder la sélection et refaire l'annonce.
- **Check-in sans prière : la phrase annonce encore « en dehors des prières »** (US-28, 2026-11-07) :
  `SCheckIn.checkInSansPriere` dit « tout ton plan sera en dehors des prières », alors que le plan
  sans prière affiche désormais « À réviser aujourd'hui ». À choisir : la nouvelle phrase, ou la
  garder (elle décrit le choix au moment où on le fait).

### Affichage et texte agrandi

- **Zones tactiles des contrôles qui rétrécissent** (relevé à la revue d'US-31 Sprint A,
  2026-11-07) : le sélecteur de mode du Quiz et la rangée « Tout sélectionner » / « Confirmer »
  rétrécissent en bloc avec un texte agrandi, zone tactile comprise. À 320 px et ×1,5, les boutons
  descendent sous 48 px de haut. Reste à choisir : accepter, ou empiler les boutons sur deux
  lignes au-delà d'un seuil (lequel ?).

### Renforcement (onglet « Quiz » après US-24)

- **Qualité des mauvais choix, à régler sur de vraies séries** (US-20, US-22) : le mauvais choix
  « similaire » est tiré au hasard parmi les passages similaires, pas le plus proche ; les seuils
  (12 mots par passage, moitié des mots en commun) viennent des mesures du scoping. Mesuré : le
  « … » final d'un choix ne trahit pas la bonne réponse (le choix « à part » est le bon dans 12 à
  20 % des cas, contre 25 % au hasard) ; aucun mauvais sens de mot ne se lit comme le bon. Mais 8 à
  10 % des bons sens n'ont aucun mot de 4 lettres (« qui », « sur ») et échappent à la règle qui
  écarte un sens voisin ; deux synonymes sans mot commun passent toujours. À choisir après usage :
  garder le hasard, prendre toujours le plus proche (le même piège reviendrait), ou déplacer un
  seuil.
- **Mode « versets à retravailler » en jeu à part** : mécanique de jeu à définir avant tout code.
- **« Choisir une sourate » quand aucune sourate n'offre de question** (US-30 Sprint A,
  2026-11-07) : le bouton reste affiché sous le message « sélection trop petite » et ouvre une
  feuille vide. À choisir : masquer le bouton, le désactiver, ou garder la feuille vide.

### Long terme

- **Révision espacée par verset** : un score de difficulté tiré de l'historique `ayah_facts`
  (aujourd'hui `lastRevisionDatesPerVerse` ne garde que la dernière date). L'ancien signal
  `needsWork` a été retiré au sprint US-3 : à rescoper sur un autre signal (par exemple la
  fréquence des versets décochés) avant tout code.
- **Coran en SQLite et tajwid coloré** : texte, mot à mot et tajwid dans une base, jointe
  naturellement à `ayah_facts`. Le tajwid coloré en dépend (données QUL) et passera par
  `AppPalette`. Ne migrer que si cette fonctionnalité est réellement engagée, pas parce que
  « c'est plus propre ». Les questions de mots s'en passent (asset texte).

---

## Convention de commit

```
feat(sprint-N): description
fix(sprint-N): corrections lié au commentaires utilisateurs
```
