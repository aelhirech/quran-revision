# User Stories — Quran_revision

Cadrage business : alimenté par le skill `quran-blueprint` (statement + critères d'acceptation),

Plafond indicatif : ~15 stories actives, au niveau **epic** (un pan entier de l'app, pas une tâche d'implémentation)

Les critères d'acceptation sont volontairement de haut niveau (le comportement observable qui définit "cet epic marche"), pas une liste exhaustive d'écrans/étapes — le détail logique à ajouter /mettre à jour se construit au scoping technique, pas au blueprint.

**Principe de regroupement** : on rassemble au maximum une fonctionnalité secondaire dans l'epic qu'elle sert (ex. les rappels matin/soir n'existent que pour soutenir le rituel Illuminer ma journée avec le Coran/Cloturer ma journée, donc ils vivent dans la même story plutôt que d'avoir la leur ; le choix de riwaya est un réglage parmi d'autres, donc il vit dans la story « Personnalisation »). 
On ne split une fonctionnalité en story séparée que si elle porte assez de valeur business à elle seule pour mériter son propre suivi — c'est le cas du rituel check-in/check-out par rapport au calcul du plan lui-même, qui aurait pu rester une seule story mais dont la mécanique de confirmation quotidienne est un pilier du produit à part entière.

**Fichier maintenu à la main** (comme `docs/DOCUMENTATION_TECHNIQUE.md` et `docs/CHANGELOG.md`) : chaque story porte un **état** — `à scoper` → `en sprint` → `terminée`. Une story terminée est **fondue dans `docs/SPEC_PRODUIT.md`** (ce que fait l'app aujourd'hui) puis supprimée d'ici : ce fichier ne contient que les changements à venir, `git log` garde les stories livrées. La liste active peut légitimement être vide juste après un blueprint entièrement livré : le prochain « Début de blueprint » la remplit.

## Résumé business de l'app

Quran Revision est une app mobile (iOS/Android, + web pour prévisualisation uniquement) à utilisateur unique : tout est local sur l'appareil, avec un data model pour préparer le backend. Elle s'adresse à quelqu'un qui a déjà mémorisé (ou est en train de mémoriser) des sourates du Coran et qui veut les garder fraîches dans sa mémoire sans effort d'organisation manuelle.

Le cœur du produit est une boucle quotidienne : après que l'utilisateur est configuré  les sourates déjà apprises et à quel rythme il veut les réviser (rythme exprimé en pages, qui sert à pré-remplir une proposition par défaut bornée aux limites de sourate ou de page — le calcul interne fonctionne en versets). Chaque jour, via le bouton Illuminer ma journée avec le Coran, l'utilisateur confirme le rythme ou l'ajuste et confirme le nombre de versets qu'il souhaite apprendre aujourd'hui ainsi que les prières qu'il compte prier en tant qu'imam puis l'app propose les versets à réviser et les versets à apprendre et répartit automatiquement ce contenu dans les rakaas de ses prières individuelles du jour — la révision occupant les premières rakaas, l'apprentissage la dernière — pour transformer un temps déjà consacré à la prière en temps de révision actif. L'utilisateur confirme ce qui a réellement été fait il peut en avoir fait plus, ou moins dans ce cas il flag les versets à retravailler ou à continuer d'apprendre — c'est cette confirmation qui fait progresser son cycle de révision et d'apprentissage.

Autour de cette boucle, l'app entretient la motivation (streak de régularité, vue d'ensemble de progression) et alerte discrètement sur ce qui commence à s'effriter dans la mémoire (fraîcheur par verset, pas juste par sourate). L'app fonctionne dans les deux riwayas les plus courantes (Hafs et Warsh) comme deux parcours de mémorisation totalement indépendants, permet à l'utilisateur de défini heure de rappel matin et heure de rappel soir et s'adapte à la langue de l'utilisateur. Il y a 4 pages : Plan du jour, Quiz, Récap, Réglages

---

## Stories actives

### Cadre commun du blueprint Zellige (2026-10-17) : toutes livrées (US-21, US-23, US-24, US-25, US-26)

Ces stories sortent d'une phase de design sans code (2026-10-13 et 14), partie d'un constat de
l'utilisateur : Renforcement et Récap n'avaient « ni DA, ni vraiment jeu, ni objectif, ni avancée
matérialisée ». Maquettes de référence : https://claude.ai/artifact/7vd5A955cuPtFYfNRfzT4H (page
privée ; les écrans « Zellige » et la planche « Mosaïque » en haut du canevas, le reste est
l'exploration). Les maquettes sont antérieures à ce blueprint : là où elles divergent des stories
(orange aux deux raisons, date d'apprentissage au Récap), ce sont les stories qui font foi.

- **Direction : Zellige** (choix utilisateur du 2026-10-13, contre l'enluminure et les
  constellations). Chaque sourate est un carreau d'une mosaïque. La forme et la couleur du carreau
  disent le niveau ; l'orange dit le risque d'oublier.
- **Le registre s'ouvre au jeu** (choix utilisateur du 2026-10-13, revient sur le registre sobre
  du blueprint Renforcement du 2026-10-13). Restent exclus : points d'expérience, niveau global, trophées et badges,
  classement, chrono, vies, monnaie, série de jours propre au jeu, son, partage.
- **Le test des 3 secondes** (critère de l'utilisateur, 2026-10-13) : en moins de 3 secondes,
  l'utilisateur sait où sont ses trous. Il prime sur le reste : un seul signal chaud, l'orange, et
  tout le reste au calme.
- **Couleurs** : l'habillage reste vert et or, les couleurs actuelles de l'app (choix utilisateur
  du 2026-10-14, contre le bleu de Fès, le turquoise et la terre cuite). Seuls les carreaux
  prennent plusieurs couleurs. **Police** : Outfit partout (choix utilisateur du 2026-10-17, contre
  Lora).
- **Public : 13 à 45 ans** (précision utilisateur du 2026-10-13). Un collégien comprend chaque mot,
  un adulte ne se sent pas infantilisé.
- **Ce qui ne change pas** : les questions ne valident jamais une révision (reconnaître n'est pas
  réciter, `docs/SPEC_PRODUIT.md` § Quiz). L'app décide à la place de l'utilisateur : ni niveau, ni seuil, ni
  pondération à régler.
- **Ordre conseillé** : US-25 d'abord (police, styles, couleurs ; livrée, voir
  `docs/SPEC_PRODUIT.md` § Registre visuel), puis US-21 (livrée, voir `docs/SPEC_PRODUIT.md` § Quiz), puis US-23 (livrée,
  voir `docs/SPEC_PRODUIT.md` § Récap), puis US-24 (livrée, voir `docs/SPEC_PRODUIT.md` § Les mots de
  l'app), et US-26 (livrée, voir `docs/SPEC_PRODUIT.md` § Règle du plan quotidien).

### US-32 — Une mosaïque qui donne envie : toutes mes sourates, nommées, celle que j'apprends comprise (extension d'US-21/US-23)

**État** : Sprint A livré (crit. 3 et 4, fondus dans `docs/SPEC_PRODUIT.md` § Quiz et § Registre
visuel) ; reste le Sprint B (crit. 1, 2 et 5) — blueprint et scoping du 2026-11-15. Rattachée à l'epic Zellige (mosaïque du Quiz et du
Récap).

**Statement** : En tant qu'utilisateur qui ouvre le Récap ou le Quiz, je veux voir dans une seule
mosaïque belle et nommée toutes les sourates qui m'occupent, y compris celle que j'apprends, afin
de reconnaître chaque carreau d'un coup d'œil et d'avoir envie de remplir ceux qui restent vides.

**Diagnostic (état actuel)** : la sourate en cours d'apprentissage vit au Récap dans une liste à
part, sous la grille, comme si elle n'appartenait pas au même ensemble. Les carreaux n'ont pas de
nom : il faut toucher un carreau pour savoir de quelle sourate il s'agit. La forme d'une sourate
« pas encore jouée » (petit losange gris) est terne et n'invite pas à jouer.

**Décisions de l'utilisateur (2026-11-15)** :
- Le nom et la nouvelle forme de base s'appliquent **aux deux onglets** (une seule mosaïque). La
  sourate en cours n'entre **qu'au Récap** : le Quiz montre ce que l'utilisateur connaît déjà.
- Le carreau d'une sourate en cours **se construit** : il se remplit à mesure des versets appris
  (contre une forme dédiée avec badge, ou la même forme avec une marque).
- Le nom est le **nom arabe calligraphié**, dans la police coranique (contre le nom français seul,
  ou les deux).
- La forme de base devient un **contour d'étoile à remplir**, une case qui attend (contre une
  rosace pâle ou un losange recoloré).

**Critères d'acceptation** :
1. Given une sourate en cours d'apprentissage, When j'ouvre le Récap, Then elle a son carreau dans
   la mosaïque, à sa place dans l'ordre du mushaf, et aucune liste « En cours d'apprentissage »
   n'apparaît plus à part. Son carreau est rempli à proportion des versets appris (rien appris =
   presque vide, presque tout appris = presque plein) et ne passe jamais en orange. Au Quiz, la
   mosaïque reste sans sourate en cours.
2. Given ce carreau, When je le touche, Then sa feuille montre le nom, les versets appris sur le
   total et un moyen d'abandonner l'apprentissage, après confirmation. C'est ce qui remplace le
   glissé de l'ancienne ligne. Rien d'autre ne permet plus d'abandonner depuis le Récap.
5. Given beaucoup de sourates, When j'ouvre le Récap, Then le nombre de sourates à risque
   d'oublier (ou la phrase calme) reste au-dessus de la grille. Le test des 3 secondes tient
   toujours : l'orange reste le seul signal chaud, et les noms et le carreau qui se construit
   restent au calme.

**Exclusions explicites** :
- Pas de nom français sous les carreaux. Il reste dans la feuille du carreau.
- Pas de carreau de sourate en cours au Quiz, et aucune question nouvelle sur une sourate en
  cours.
- Pas de « Voir le texte » ajouté pour une sourate en cours. Son texte s'ouvre toujours depuis la
  carte d'apprentissage du plan du jour (règle actuelle, non rediscutée ici).
- Les formes des niveaux 1 à 4 et du risque d'oublier ne changent pas. Seule la forme « pas encore
  jouée » est remplacée.
- La question ouverte au Backlog « Mosaïque d'une grande sélection sur un petit écran » (replier
  la grille au-delà d'un seuil ?) n'est pas tranchée ici, mais les noms l'aggravent. Le scoping
  doit mesurer la nouvelle hauteur de la grille avec 113 sourates et le dire.
- **À confirmer au scoping** : une sourate à la fois en révision (plage partielle) et en cours
  d'élargissement garde **un seul carreau**, montré en construction au Récap. Sa feuille montre
  alors le niveau et les versets appris.

**Scoping technique** (2026-11-15) :
- **Fichiers UI** : `lib/widgets/mosaic.dart` (124 lignes), `lib/widgets/mosaic_tile_shape.dart`
  (109), `lib/widgets/mosaic_tile_sheet.dart` (154), `lib/screens/recap_screen.dart` (215, perd la
  liste). `lib/screens/reinforcement/reinforcement_tab.dart` (324) n'est pas touché : l'API de
  `Mosaic` ne change pas. `lib/widgets/learning_progress_card.dart` est supprimé (Sprint B).
- **Variables / champs** : `MosaicTile` gagne `learnedCount`, `learnedTotal`, `learningFraction`,
  `isLearningOnly`. `AppState.mosaicTiles({bool withLearning = false})`. `S.enCoursDApprentissage`
  est supprimé. Aucune clé `SharedPreferences`.
- **`ayah_facts`** : aucune requête nouvelle. Réutilise `AppState.learningProgressList()`
  (`AyahFactsLearning.loadMainLearningProgress`, deux requêtes groupées, sourates démarrées à
  `reach=0` comprises) et `abandonLearning` (`deleteLearnFacts`).
- **Décision data model** : tout se calcule à partir d'`ayah_facts` par une requête qui existe
  déjà, sans nouvelle table ni nouvelle config.
- **Réutilisation** : `Sourate.nameAr` (`lib/core/quran_data.dart`), Amiri déjà embarquée, `_star`
  du painter, `AppPalette` sans nouveau champ (`primary` pour les noms, `goldDark` pour le
  contour, `gold` pour le remplissage). La feuille réutilise `MosaicTileSheet`. La confirmation
  réutilise `confirmDialog` et `S.supprimerApprentissage(De)`. Le décompte réutilise `S.versetsAppris`.
- **Risques / dépendances** : Quiz et Récap partagent le widget, donc une régression se voit dans
  les deux. Avec les noms, 113 sourates donnent une grille d'environ 1030 px à 375 px (×1), contre
  254 px aujourd'hui. À ×1,5, elle fait environ 2010 px. Ces hauteurs viennent d'une largeur
  d'Amiri estimée et sont à confirmer sous Windows. Choix de l'utilisateur du 2026-11-15 : on
  accepte, et l'idée « Mosaïque d'une grande sélection sur un petit écran » reste ouverte. Le
  Sprint B dépend du Sprint A, car il réutilise le contour d'étoile.
- **Tests** : Dart pur pour `Mosaic.build` avec la liste des sourates en cours, la fraction de
  remplissage et la largeur des cellules. Test de largeur sur les vraies polices pour les noms
  longs. Les formes, la feuille, le clair, le sombre et le ×1,5 se vérifient à l'œil sous Windows.
- **Item Backlog** : « US-32 Sprint A — Noms arabes sous les carreaux et contour d'étoile pour
  « pas encore jouée » » et « US-32 Sprint B — La sourate en cours dans la mosaïque du Récap ».

**Ajustement au scoping** (2026-11-15). Crit. 1 précisé, sens inchangé :
- Une sourate en cours hors de la sélection prend sa place dans l'ordre du mushaf.
- Une sourate à la fois révisée en partie et en cours garde un seul carreau, en construction. Ce
  carreau ne passe jamais en orange, même si sa partie révisée est à risque d'oublier. Ce risque
  reste visible au Quiz et revient au Récap une fois la sourate apprise en entier.
- Le remplissage est borné entre 12 % et 88 %. Une sourate démarrée sans verset appris se
  distingue ainsi d'une sourate « pas encore jouée ».

Validé par l'utilisateur : oui pour le risque caché, le 2026-11-15. Le plancher et le plafond
traduisent « presque vide » et « presque plein ».

**Ajustement au scoping** (2026-11-15). Crit. 2 précisé, sens inchangé :
- Sourate à la fois révisée et en cours : la feuille garde aussi le niveau, la dernière révision
  et « Voir le texte » de la plage révisée.
- Sourate seulement en cours : la feuille n'affiche aucun de ces trois éléments.
- Abandonner ne supprime que les lignes `learn`, jamais la sélection.

Validé par l'utilisateur : non, c'est une conséquence directe du crit. 1 et des exclusions.

## Écartées

- **Calendrier d'activité au Récap** (Idée produit « Calendrier d'activité (heatmap) », alias
  « Timeline d'activité ») — écarté le 2026-10-23 (choix utilisateur). Il contredit US-23 (le Récap
  ne garde que la mosaïque et les sourates à risque d'oublier) et le test des 3 secondes, et
  ajoute une statistique là où les jours de suite existent déjà (`docs/SPEC_PRODUIT.md` § Réglages,
  « Ne fait pas »). Que la donnée soit disponible ne dit rien de sa valeur pour l'utilisateur.
- **Case de hizb de l'onboarding dont toutes les sourates ont une plage partielle** — écarté le
  2026-10-23. Elle s'affiche cochée, et un appui retire ces sourates, plages comprises. C'est
  conforme à la règle (une plage partielle compte comme sélectionnée), et rien ne demande de la
  changer. À rouvrir seulement si un retour d'usage le signale.

