# Changelog — Quran Revision App

> Backlog technique en attente + idées produit non scopées. L'historique des sprints livrés vit dans `git log`, pas ici. Ce que fait l'app aujourd'hui (règles produit, plan quotidien, invariants, cas limites) : `docs/SPEC_PRODUIT.md`. Comment c'est codé, et les décisions techniques actives à respecter : `docs/DOCUMENTATION_TECHNIQUE.md` (§13bis). Modèle de données `ayah_facts` : `CLAUDE.md`.

---

## Backlog technique

Dette réelle et gaps prêts à l'implémentation — priorité qui reflète le risque/l'effort, pas l'enthousiasme produit. P1 = risque de correction (données/comportement), P2 = gap concret ou nettoyage rapide, P3 = différé délibérément (aucun bug connu) ou pure polish. Les idées produit non scopées vivent dans la section « Idées produit » plus bas, pas ici.

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
- **Pied du check-in et du check-out : les deux boutons ne rétrécissent pas ensemble** (vérification
  Windows d'US-31 Sprint B, 2026-11-07) : `StepFooter` partage la largeur 1/3 – 2/3. À 320 px avec
  texte ×1,5, « Retour » garde presque sa taille, et « Voir mon plan du jour » descend à environ
  deux tiers de la sienne. Rien ne déborde. Reste à choisir : accepter, faire rétrécir les deux à la
  même échelle, ou changer le partage.
- **Noms de sourate coupés au trait d'union** (même vérification) : à 320 px avec texte ×1,5,
  « Al-Kawthar », « Al-Kafirun » et « Al-Ikhlas » (sélection de l'onboarding), ou « Al-Imran » (carte
  de rakaa), passent à la ligne après « Al- ». Rien ne déborde. Reste à choisir : accepter (le trait
  d'union est un point de coupure normal), ou interdire la coupure (trait d'union insécable U+2011,
  à vérifier dans Outfit), au risque de rétrécir ou de pousser la ligne.
- **Plage d'un seul verset écrite « 5–5 (1 verset) »** (sprint 37, 2026-11-08, carte des sourates
  du Récap) : le pluriel est corrigé, mais la plage répète le même numéro. Reste à choisir :
  « verset 5 », « 5 (1 verset) », ou garder tel quel (même format que les autres plages).

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
- **Quiz « sans attente » : quelle mesure fait foi** (sprint 36, 2026-11-08) : en profile sous Windows,
  113 sourates, l'écran ne gèle jamais plus de 83 ms. Mais de l'appui à la première image de la
  série (la mesure du Sprint A), la première série « Mélange » prend 126 à 152 ms, et les
  suivantes 98 à 107 ms : le reste est le temps de construire l'écran de série, pendant lequel
  l'interface répond. À choisir : le gel (critère atteint), ou l'appui-à-l'image (alors chercher
  du côté de la construction de l'écran de série, pas du moteur).
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
