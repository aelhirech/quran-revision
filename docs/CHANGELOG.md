# Changelog — Quran Revision App

> Backlog technique en attente + idées produit non scopées. L'historique des sprints livrés vit dans `git log`, pas ici. Ce que fait l'app aujourd'hui (règles produit, plan quotidien, invariants, cas limites) : `docs/SPEC_PRODUIT.md`. Comment c'est codé, et les décisions techniques actives à respecter : `docs/DOCUMENTATION_TECHNIQUE.md` (§13bis). Modèle de données `ayah_facts` : `CLAUDE.md`.

---

## Backlog technique

Dette réelle et gaps prêts à l'implémentation — priorité qui reflète le risque/l'effort, pas l'enthousiasme produit. P1 = risque de correction (données/comportement), P2 = gap concret ou nettoyage rapide, P3 = différé délibérément (aucun bug connu) ou pure polish. Les idées produit non scopées vivent dans la section « Idées produit » plus bas, pas ici.

### [P2] US-30 Sprint A — Quiz : sourates proposées exactes, message à jour, composition sans calcul répété, mots lisibles
US-20 et US-22 sont livrées (`docs/DOCUMENTATION_TECHNIQUE.md` §5.6, §5.7, §8.7). Trois causes lues
dans le code :
- **Liste « Choisir une sourate »** : `reinforcement_tab.dart` l.124-126 la filtre sur
  `inputs.carried`, donc toute sourate connue, même sans question.
- **Message « trop petite »** : `_tooSmall` est posé une fois dans `_start` (l.89-91) et jamais
  recalculé.
- **Temps de composition** : `ReinforcementEngine.buildSeries` (l.149-156) analyse toute la sélection
  (passages et mots, regex par jeton) à chaque série, même pour une seule sourate, et chaque mauvais
  choix matérialise le pool entier (`pick`).
Aucune écriture, aucune persistance.
- **`lib/core/reinforcement_corpus.dart`** (nouveau, `part of 'reinforcement_engine.dart'` ;
  `reinforcement_engine.dart` est à 281 lignes) : classe `ReinforcementCorpus`, mémo de session tenu
  par l'onglet.
  - `passagesOf(surahId, ayahId, text)` et `wordsOf(surahId, ayahId, text, glosses)` renvoient le
    résultat de `ReinforcementEngine.passagesOf` et de `_askableWords`, mémorisé par
    `(surahId, ayahId)`.
  - Les listes plates `all` (passages, mots) sont aussi mémorisées, et recalculées seulement quand
    `carried` change (comparaison de valeur).
  - `clear()` est appelé quand la riwaya change. Sinon, un verset Hafs serait servi en Warsh.
- **`lib/core/reinforcement_engine.dart`** et **`lib/core/reinforcement_words.dart`** :
  - `buildSeries`, `buildMixedSeries` et `buildWordQuestions` acceptent un paramètre optionnel
    `ReinforcementCorpus? corpus` ; sans lui, comportement actuel. Avec lui, `chains` et `all` passent
    par le mémo.
  - Nouvelle fonction `surahsOfferingPassages({carried, textOf, corpus})` : les `surahId` qui ont au
    moins un lien posable (`_askableLinks`), dont le couple (passage montré, bonne suite) laisse au
    moins une clé de passage connue hors de {clé du passage montré, clé de la suite}. C'est
    exactement la condition qu'applique `_question`, car tous ses pools sont des sous-ensembles de
    `all`. Les clés distinctes de `all` sont calculées une fois.
  - `pick` (dans les deux fichiers) : tirer d'abord jusqu'à 20 candidats au hasard
    (`pool[random.nextInt(pool.length)]`). Le filtre ne parcourt le pool entier que si aucun
    candidat ne convient. Distribution inchangée.
- **`lib/screens/reinforcement/reinforcement_tab.dart`** :
  - État `Set<int> _offered` : les sourates qui offrent une question dans `_mode`.
    - Passages : `surahsOfferingPassages`.
    - Mots : `await WordGlossService.load()`, puis une sourate S est offerte si
      `buildWordQuestions(…, surahId: S, count: 1, corpus: _corpus)` est non vide.
    - Mélange : union des deux.
  - Quand recalculer : au changement de mode (`onSelectionChanged`, l.156-159) et à chaque
    notification d'`AppState` dont `carried` a changé. Un compteur de génération écarte un résultat
    périmé ; vérifier `if (!mounted) return;` après chaque `await`.
  - `_pickSourate` : `state.sourates.where((s) => _offered.contains(s.id))`.
  - `_tooSmall` n'est plus un état posé : il vaut `_offered.isEmpty`. Le garde `questions.isEmpty`
    de `_start` reste en repli.
  - `_start` passe `_corpus` aux trois composeurs. `_corpus.clear()` au changement de riwaya.
- **`lib/screens/reinforcement/series_word_question.dart`** :
  - `_wordFollowUp` : si `!question.arabicToMeaning`, afficher
    `SReinforcement.sourateVerset(surah.nameFr, answer.ayahId)` au-dessus du passage (même style que
    l'en-tête de question). En « arabe vers sens », la ligne est déjà affichée avant la réponse : ne
    pas la répéter.
  - `_passageWithWord` : envelopper dans `Semantics(container: true, label: '<texte affiché>,
    ${SReinforcement.motDemande(answer.arabic)}', child: ExcludeSemantics(child: …))`.
  - Sous un mauvais choix : `Text.rich` avec le mot arabe en `GoogleFonts.amiri(fontSize: 15, color:
    palette.textMuted)`, puis `SReinforcement.motSensSep` et le sens.
- **`lib/screens/reinforcement/widgets/passage_choice.dart`** : `note` passe de `String?` à `Widget?`.
  L'appel des passages enveloppe `SReinforcement.passageDans(…)` dans un `Text` au style actuel
  (12, `palette.textMuted`).
- **`lib/widgets/arabic_verse_text.dart`** l.55 : le `TextSpan` du mot en or reçoit
  `decoration: TextDecoration.underline, decorationColor: highlightColor`. Rien ne change sans
  `highlightWord` (seul appelant : la question de mots).
- **`lib/core/strings_reinforcement.dart`** :
  - `motDemande(String mot)` : FR « mot demandé : $mot » / EN « asked word: $mot ».
  - `motSensSep` : FR ' : ' / EN ': '.
  - `motSens` est retiré (son seul usage disparaît).
- **Réutilisé tel quel** : `_draw`, `_question`, `passagesOf`, `SeriesScreen`, `SouratePickerSheet`,
  `WordGlossService`, `VerseBottomSheet`, `AppPalette.gold`.
- **Tests** :
  - Parité de l'offre, `test/core/reinforcement_engine_test.dart` : sur la sélection réelle (Hafs et
    Warsh, toutes sourates connues), pour chaque sourate S, S ∈ `surahsOfferingPassages` ⇔
    `buildSeries(…, surahId: S, count: 1)` non vide. Une sourate à un seul passage n'est pas offerte.
  - Parité des mots, `test/core/reinforcement_words_test.dart` : même équivalence en mode mots (Hafs).
  - Même graine, série avec et sans `corpus` : mêmes `Passage.id` et `WordChoice.id`.
  - `clear()` : après `clear()`, un verset Warsh n'est pas servi par le mémo Hafs.
  - `flutter test` vert. L'échantillonnage change la suite aléatoire : ne corriger une assertion que
    si elle porte sur une valeur de tirage précise, jamais sur une règle.
  - **Mesure (crit. 3)** : `flutter run -d windows --profile`, sélection de 113 sourates, trois modes
    × {sélection entière, une sourate}, à froid (première série) et à chaud (série suivante),
    ouverture de « Choisir une sourate » comprise. `Stopwatch` temporaire du tap jusqu'à l'affichage
    de la série, retiré avant le commit. Pire de trois essais, seuil 100 ms par cas. Consigner les
    chiffres dans §5.6.
  - Vérification sous Windows :
    - crit. 2 : le message disparaît à l'ajout d'une sourate et revient au retrait ;
    - crit. 4 : sourate et verset affichés après la réponse en « sens vers arabe » ;
    - crit. 5 : mot en or et souligné ;
    - crit. 6 : mot arabe de la note en Amiri.
    Le lecteur d'écran (VoiceOver) ne se vérifie que sur iPhone.
- **Exclus** : pas de second message ; la qualité des mauvais choix (Idée produit) ; rien n'est crédité
  ni écrit ; composition hors du fil de l'interface (Sprint B).
- **Doc** :
  - `docs/DOCUMENTATION_TECHNIQUE.md` :
    - §5.6 : mémo, échantillonnage, fonction d'offre et mesures en profile. Remplacer « Coût » et
      « Si ce temps dépasse 500 ms ».
    - §8.7 : sélecteur filtré, `_tooSmall` dérivé, référence en sens vers arabe, soulignement et
      sémantique, note en Amiri. Retirer les points correspondants des « Limites connues ».
    - §11 : les nouveaux tests.
    - §13bis : le mémo est lié à la riwaya ; l'offre et `_question` partagent leur condition,
      verrouillée par test.
  - `docs/SPEC_PRODUIT.md` § Renforcement : « Choisir une sourate » ne liste que les sourates qui
    offrent une question, et le message suit la sélection et le mode. Fondre US-30 dans ce
    paragraphe à la clôture du Sprint A si le Sprint B n'est pas déclenché, sinon à celle du
    Sprint B.

### [P3] US-30 Sprint B — Composer les questions hors du fil de l'interface (seulement si déclenché par le Sprint A)
Déclencheur, consigné à la clôture du Sprint A : un cas de la mesure en profile sous Windows
dépasse 100 ms, ou l'utilisateur sent l'écran se figer sur iPhone (TestFlight). Sans déclencheur,
supprimer cet item en notant la mesure dans §5.6. Le Sprint A doit être livré.
- **Étape 1, si le dépassement n'a lieu qu'à froid (première série)** : `ReinforcementCorpus.warm(
  carried, textOf, glosses)` remplit le mémo par tranches de 10 sourates, avec `await
  Future<void>.delayed(Duration.zero)` entre deux tranches. Il est lancé à la première image de
  l'onglet. Aucun isolate.
- **Étape 2, si un cas à chaud dépasse encore 100 ms après l'étape 1** (ou d'emblée, si le
  dépassement est à chaud) : composer dans un isolate avec `Isolate.run` (`dart:isolate`), appelé
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

### [P3] Livrer les licences OFL des polices dans l'app
Relevé au sprint 34 (2026-11-07, polices embarquées). La licence OFL demande que chaque copie d'une
police l'accompagne. `assets/fonts/OFL.txt` (Outfit), `Amiri-OFL.txt` et `ScheherazadeNew-OFL.txt`
sont dans le dépôt mais pas dans l'app installée : aucun n'est déclaré dans `pubspec.yaml`.
- **`pubspec.yaml`** : ajouter les trois fichiers sous `assets:`, sans renommer `OFL.txt`.
- **Tests** : `flutter test` vert ; `flutter build windows` puis vérifier que les trois fichiers
  sont présents dans `build/windows/x64/runner/Release/data/flutter_assets/assets/fonts/`.
- **Exclus** : pas d'écran de licences dans l'app.

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
