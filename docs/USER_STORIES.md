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

Autour de cette boucle, l'app entretient la motivation (streak de régularité, vue d'ensemble de progression) et alerte discrètement sur ce qui commence à s'effriter dans la mémoire (fraîcheur par verset, pas juste par sourate). L'app fonctionne dans les deux riwayas les plus courantes (Hafs et Warsh) comme deux parcours de mémorisation totalement indépendants, permet à l'utilisateur de défini heure de rappel matin et heure de rappel soir et s'adapte à la langue de l'utilisateur. Il y a 4 pages : Plan du jour, Renforcement, Récap, Réglages

---

## Stories actives

### Cadre commun à US-20, US-21 et US-22 (blueprint Renforcement du 2026-10-13)

Ces trois stories sortent d'un même besoin : « une page de jeux avec deux QCM (le sens d'un mot, la
suite d'un verset), pour la révision et le renforcement ». Elles sont découpées **par valeur**, pas
par jeu : s'éprouver (US-20), voir ce qui tient (US-21), comprendre ce qu'on récite (US-22). US-20
est livrée (2026-10-13, voir `docs/SPEC_PRODUIT.md` § Renforcement), US-22 la suit (droits de la source vérifiés le
2026-10-13), US-21 vient ensuite et apporte la mémoire des réponses.

- **Moment de l'histoire** : le milieu de journée, à un moment choisi, comme l'écoute (US-9) :
  avant de réciter, ou dans un temps mort. Ce que la section y prouve : ce que je porte tient
  quand on me le demande **dans le désordre**, hors du fil de la récitation. La question « quel
  verset vient ensuite » reprend la forme habituelle d'un contrôle de mémorisation (on donne un
  verset, l'élève poursuit).
- **Registre : sobre** (choix utilisateur du 2026-10-13, contre un parcours à points et contre un
  simple tableau d'états). Le cadre du 2026-09-30 tient ici aussi. Sont exclus des trois stories :
  points d'expérience, niveau global, trophées et badges, classement, chrono, vies, monnaie, série
  de jours propre au jeu, son, partage.
  _Remplacé le 2026-10-17 par le cadre commun du blueprint Zellige (plus bas) : le registre
  s'ouvre au jeu, avec la mosaïque et les niveaux par sourate. Les exclusions ci-dessus restent
  valables._
- **Le score est un fait** : les questions qui ont tenu, sur le total de la série. Il s'affiche
  avec le losange doré de l'ornement déjà présent sous les titres (plein si la question a tenu,
  vide sinon) et ne s'additionne pas d'un jour à l'autre.
- **Quatrième onglet, nommé « Renforcement »** (choix utilisateur du 2026-10-13, contre une carte
  dans le Plan du jour). Le mot « jeu » n'apparaît pas dans l'app. Pour tenir la thèse, l'onglet
  s'ouvre toujours sur une série déjà composée, jamais sur un menu.
- **L'app propose, l'utilisateur peut choisir** (choix utilisateur du 2026-10-13) : la série du
  jour d'abord ; un second geste permet de jouer sur une sourate précise de sa sélection. Le
  niveau ne se choisit pas. _Modifié le 2026-10-13 (demande de l'utilisateur, après le scoping
  d'US-20)_ : le type de question se choisit par **trois modes**, « Mélange », « Versets » et
  « Traduction ». « Mélange » est présélectionné, donc lancer une série ne demande toujours
  qu'un geste. Les modes n'apparaissent que là où les questions de mots existent (français,
  Hafs).
- **Rien ne change dans la progression** (choix utilisateur du 2026-10-13) : ni tour de révision,
  ni série de jours, ni fraîcheur, ni ce que le check-out crédite. Reconnaître un verset n'est pas
  le réciter. Même règle que l'écoute (US-9 crit. 4).
- **Le texte coranique n'est jamais modifié** : tout choix affiché est un vrai verset ou un vrai
  mot, tel qu'il figure dans la riwaya active. Aucun piège fabriqué, recomposé ou altéré.
  _Ajusté au scoping d'US-20 (2026-10-13, sur proposition de l'utilisateur)_ : un verset long
  peut être montré par **passages** qui se suivent, coupés seulement aux signes de pause du
  mushaf. Un passage est toujours une suite de mots du verset, dans l'ordre.
- **Chaque question se termine sur la bonne réponse affichée.** Un QCM sans retour peut installer
  la confusion qu'il veut soigner : lire une mauvaise suite juste après un verset laisse une trace
  (Roediger et Marsh, 2005), que le retour immédiat répare (Butler et Roediger, 2008).
- **L'app n'est pas un enseignant** : elle ne corrige pas la récitation. Pour les mots, elle cite
  une source, elle n'explique pas.
- **Conséquence traitée au Sprint B d'US-20** (2026-10-13) : la ligne « Milieu » de la direction
  narrative de `docs/SPEC_PRODUIT.md` nomme l'onglet Renforcement, et le Résumé business ci-dessus annonce
  quatre pages.
- **Benchmark du 2026-10-13** (neuf produits lus sur leur fiche, aucun installé ; quatre études) :
  https://claude.ai/artifact/8Sym4Aq9X1M4s6gzrJi46k (page privée). À retenir : les apps de
  mémorisation lues reprennent toutes points, séries à paliers ou classements ; aucune ne compose
  la partie à la place de l'utilisateur ; les versets similaires sont la difficulté qu'elles
  mettent en avant ; le chrono est reproché.

### US-21 — Ma mosaïque : mes niveaux, mes questions ratées, ce que je risque d'oublier
**État** : à scoper — blueprint du 2026-10-13, réécrit au blueprint Zellige du 2026-10-17 (voir le
cadre commun plus bas), validé par l'utilisateur le 2026-10-22. S'appuie sur US-20. Reprend les Idées produit « Mode "versets à
retravailler" en jeu à part » et « Gamification narrative [H] » de `docs/CHANGELOG.md`, à retirer
de ce fichier au scoping.

**Statement** : En tant qu'utilisateur qui s'éprouve régulièrement, je veux voir mes sourates en
mosaïque, avec mon niveau sur chacune et celles que je risque d'oublier, et des questions qui
deviennent plus dures à mesure que je progresse, afin de savoir en moins de 3 secondes où sont mes
trous et de voir ma mémoire se raffermir.

**Diagnostic (état après US-20 et US-22)** : une série ne laisse aucune trace. Un verset raté
n'est pas reposé, la difficulté ne bouge jamais, et rien ne dit quelle sourate est sûre ni
laquelle s'efface. La date de dernière révision existe (badges du Récap), mais elle se lit ligne
par ligne, au bas de l'écran.

**Critères d'acceptation** (haut niveau) :
1. Given l'onglet Renforcement, Then une mosaïque montre un carreau par sourate révisée, et le
   nombre de sourates à risque d'oublier passe avant tout le reste. Test des 3 secondes : montré
   3 secondes à quelqu'un qui ne connaît pas l'app, l'écran lui permet de dire quelles sourates
   sont à risque. La mosaïque reste lisible de 1 à 114 sourates, plages partielles comprises.
2. Given une sourate, Then elle porte un niveau, de « pas encore jouée » à 4, qui règle la
   difficulté de ses questions : 1, mauvaises réponses tirées d'autres sourates ; 2, de la même
   sourate ; 3, des versets voisins ; 4, des versets qui se ressemblent. L'utilisateur ne choisit
   jamais le niveau. Seules les questions de versets le font bouger (US-22 crit. 6).
3. Given une sourate réussie de façon répétée à son niveau, Then elle monte d'un niveau. Given une
   sourate ratée de façon répétée, Then elle redescend d'un niveau (choix utilisateur du
   2026-10-13, reconfirmé le 2026-10-17). Dans les deux sens, l'annonce est courte et sans
   reproche.
4. Given une question ratée (verset ou mot), Then elle revient dans une série suivante jusqu'à ce
   qu'elle soit réussie. La fin de série dit combien reviendront, sans reproche.
5. Given une sourate pas révisée depuis plus de 3 mois, ou depuis plus d'un tour quand le tour
   dure plus de 3 mois (choix utilisateur du 2026-10-17), Then son carreau est orange, avec un
   anneau, partout où la mosaïque apparaît. Il redevient normal dès qu'elle est révisée, c'est-à-
   dire récitée et validée en fin de journée : les questions ne l'effacent jamais. L'orange ne veut
   rien dire d'autre dans l'app. Les questions du jour font passer ces sourates avant les autres,
   après la part du plan du jour.
6. Given un carreau, When l'utilisateur le touche, Then il voit le nom de la sourate, son niveau et
   sa dernière révision, et peut lancer une série sur elle (US-20 crit. 5) ou ouvrir son texte.
   Given des niveaux, des retours et des sourates à risque, Then rien ne change dans le tour, les
   jours de suite, ni ce que la fin de journée valide ; tout est propre à chaque riwaya.

**Exclusions explicites** :
- **Le niveau peut se perdre** (choix utilisateur du 2026-10-13, reconfirmé le 2026-10-17 contre
  « il reste acquis »). Une question ratée coûte au plus un niveau, jamais un passage en orange :
  chaque axe a son signal (choix utilisateur du 2026-10-17, contre un orange aux deux raisons).
- Le niveau n'est pas une fraîcheur : le niveau dit si la sourate tient aux questions, l'orange
  dit depuis quand elle n'a pas été récitée. La mosaïque s'affiche dans l'onglet Renforcement et
  au Récap (US-23), jamais sur le plan du jour ni au check-in.
- Pas de niveau global, pas de niveau au-delà de 4, pas d'historique ni de courbe des scores. Les
  carreaux gagnés dans une série ne s'accumulent pas et ne s'échangent contre rien : ce n'est pas
  une monnaie.
- Pas de moment de jalon (US-13) pour un niveau atteint, pas d'écran de collection.
- Une question ratée ne change rien au plan de révision : le plan ne lit rien de l'onglet. Il tient
  compte de la dernière révision (US-26), jamais des questions.
- Le compteur « N mots connus sur M » (US-22 crit. 4, reporté ici) est retiré : un indicateur de
  plus irait contre le test des 3 secondes. Les mots ratés reviennent (crit. 4). Validé par
  l'utilisateur le 2026-10-22.
- L'Idée produit « SRS réel par verset » reste ouverte, à part.

**Défaut validé par l'utilisateur le 2026-10-22** : une sourate en cours d'apprentissage n'a pas de
carreau ; elle entre dans la mosaïque quand elle passe en révision.

**Points à lever au scoping** : le nombre de réussites et d'erreurs qui fait monter ou descendre
un niveau ; le niveau 4, qui demande de séparer « versets voisins » et « versets qui se
ressemblent », regroupés jusqu'ici ; ce que devient le niveau d'une sourate retirée de la
sélection puis remise, ou dont la plage change ; le carreau d'une plage partielle ; l'ordre des
sourates à risque ; la place de la mosaïque à côté du bouton « Choisir une sourate ».

**Reçu d'US-25** (scoping du 2026-10-22) : US-21 livre les formes de carreau (US-25 crit. 3). Formes
des maquettes Zellige : pas jouée, petit losange ; niveau 1, losange ; niveau 2, étoile à huit
pointes ; niveau 3, étoile évidée au centre ; niveau 4, étoile à cœur doré (`palette.gold`) ;
risque d'oublier, étoile orange dans un anneau. Les couleurs viennent des tokens d'US-25. La
mosaïque et l'onglet Quiz prennent directement les six styles d'US-25.

### Cadre commun du blueprint Zellige (2026-10-17) : US-21, US-23, US-24, US-25 et US-26

Ces stories sortent d'une phase de design sans code (2026-10-13 et 14), partie d'un constat de
l'utilisateur : Renforcement et Récap n'avaient « ni DA, ni vraiment jeu, ni objectif, ni avancée
matérialisée ». Maquettes de référence : https://claude.ai/artifact/7vd5A955cuPtFYfNRfzT4H (page
privée ; les écrans « Zellige » et la planche « Mosaïque » en haut du canevas, le reste est
l'exploration). Les maquettes sont antérieures à ce blueprint : là où elles divergent des stories
(orange aux deux raisons, date d'apprentissage au Récap), ce sont les stories qui font foi.

- **Direction : Zellige** (choix utilisateur du 2026-10-13, contre l'enluminure et les
  constellations). Chaque sourate est un carreau d'une mosaïque. La forme et la couleur du carreau
  disent le niveau ; l'orange dit le risque d'oublier.
- **Le registre s'ouvre au jeu** (choix utilisateur du 2026-10-13, revient sur le registre sobre du
  cadre US-20 à US-22). Restent exclus : points d'expérience, niveau global, trophées et badges,
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
  réciter, cadre US-20). L'app décide à la place de l'utilisateur : ni niveau, ni seuil, ni
  pondération à régler.
- **Ordre conseillé** : US-25 d'abord (police, styles, couleurs), puis US-21, puis US-23, qui
  reprend sa mosaïque. US-24 et US-26 sont indépendantes. Le scoping tranche.

### US-23 — Le Récap montre d'un coup d'œil ce qui tient et ce que je risque d'oublier (extension d'US-7)
**État** : à scoper — blueprint du 2026-10-17. Prolonge US-7 (livrée, voir `docs/SPEC_PRODUIT.md` § Récap) et modifie
ses critères 1 et 2 (voir les exclusions).

**Moment de l'histoire** : hors du fil de la journée, quand l'utilisateur se demande où il en est.
Ce que l'écran y prouve : ce qui tient, et ce qui demande de l'attention. Il regarde en arrière,
comme le check-in : aucune projection n'y est ajoutée.

**Statement** : En tant qu'utilisateur, je veux que le Récap me montre ma mosaïque et les sourates
que je risque d'oublier, sans rien de superflu, afin de savoir en moins de 3 secondes où j'en suis.

**Diagnostic (état actuel)** : huit blocs de même poids, onze chiffres avant l'historique, le total
de pages affiché deux fois. La date de dernière révision n'apparaît qu'en badges, dans la liste du
bas.

**Critères d'acceptation** (haut niveau) :
1. Given le Récap ouvert, Then il commence par la mosaïque d'US-21 (mêmes carreaux, mêmes couleurs,
   même règle), avec en tête le nombre de sourates à risque d'oublier, ou un message clair quand il
   n'y en a aucune.
2. Given des sourates à risque d'oublier, Then une section « Risque d'oublier » les nomme, de la
   révision la plus ancienne à la plus récente, avec depuis combien de temps chacune n'a pas été
   révisée.
3. Given un apprentissage en cours, Then une ligne compacte le montre (la sourate, les versets déjà
   appris), et permet toujours de supprimer un apprentissage (US-12).
4. Given le Récap, Then rien d'autre n'y figure (choix utilisateur du 2026-10-17) : jours de suite,
   pages, tour, rythme, historique jour par jour, répartition et liste « Mes sourates » le
   quittent. Le texte d'une sourate s'ouvre depuis son carreau (US-21 crit. 6).

**Exclusions explicites** :
- **Modifie US-7 (livrée, voir `docs/SPEC_PRODUIT.md` § Récap)** : la position dans le tour (crit. 1) quitte le Récap ; elle reste sur
  le plan du jour au repos. La fraîcheur par sourate (crit. 2) prend la forme de l'orange et de la
  section « Risque d'oublier », plus celle de badges.
- Les jours de suite restent visibles sur le plan du jour (US-6), la durée du tour à la fin de
  journée (US-14).
- Pas de date d'apprentissage au Récap : une projection se lit à la fin de journée, pas ici
  (règle « derrière au check-in, devant au check-out » de `docs/SPEC_PRODUIT.md`).
- Pas de nouvel indicateur, pas de carte d'activité (l'Idée produit « Timeline d'activité » reste
  ouverte).
- Pas de liste des questions ratées au Récap : elles reviennent dans les séries de l'onglet
  Renforcement (US-21 crit. 4).

### US-24 — L'app parle avec des mots de tous les jours
**État** : à scoper — blueprint du 2026-10-17, validé par l'utilisateur le 2026-10-22.

**Statement** : En tant qu'utilisateur de 13 à 45 ans, je veux que chaque écran, message et
notification utilise des mots de tous les jours, un seul par idée, afin de tout comprendre du
premier coup, sans vocabulaire à apprendre.

**Diagnostic (état actuel)** : une cinquantaine de textes sont écrits dans un registre littéraire
(« ce que tu portes », « pages en garde », « ce qui a tenu », « journée scellée », « à éprouver »).
Deux mots désignent parfois la même chose (« cycle » et « tour », « portion » et « plan »), et des
termes techniques s'affichent (« onboarding », « configuration », « session »). C'est le mal que la
direction narrative du `docs/SPEC_PRODUIT.md` dit soigner : introduire du vocabulaire inconnu.

**Critères d'acceptation** (haut niveau) :
1. Given n'importe quel texte de l'app (écrans, messages, notifications), Then chaque idée porte un
   seul mot, le même partout, celui du lexique ci-dessous.
2. Given n'importe quel texte, Then il ne reste ni métaphore à décoder ni terme technique. Les mots
   religieux que l'utilisateur emploie lui-même restent : rakaa, riwaya, hizb, imam, Al-Fatiha,
   sunna.
3. Given les textes longs (introduction de l'onboarding, jalons, étapes guidées), Then ils sont
   réécrits en phrases courtes, sans changer de sens. Les règles de la direction narrative
   tiennent : jamais « fini » ni « terminé » à propos de la révision, jamais de reproche, un tour
   plus long présenté comme une capacité.
4. Given l'app en anglais, Then le même principe s'applique, en anglais de tous les jours.

**Lexique** (proposé au blueprint du 2026-10-17, validé par l'utilisateur le 2026-10-22) :

| Idée | Aujourd'hui | Mot retenu |
|---|---|---|
| Ce que je connais | « ce que tu portes », « pages en garde », « mémorisées » | « ce que tu connais », « pages apprises », « sourates apprises » |
| Réussir, oublier | « ce qui a tenu », « un verset qui ne tient plus » | « ce que tu as réussi », « un verset oublié » |
| La boucle de révision | « cycle » et « tour » | « tour » |
| Finir la journée | « clôturer », « clôturée », « scellée » | « terminer ma journée », « journée terminée » |
| Le programme du jour | « portion », « plan », « portée du jour » | « plan du jour » |
| Hafs et Warsh | « parcours » | « lecture (riwaya) » |
| Depuis quand pas révisée | « fraîcheur », « partiellement récente » | « dernière révision », « révisée en partie » |
| Pas révisée depuis longtemps | (nouveau) | « risque d'oublier » |
| Jours d'affilée | « série », « régularité » | « jours de suite » |
| Les questions | « série du jour » | « questions du jour » |
| La difficulté | « palier » | « niveau » |
| Les trois couches | « le nouveau », « le récent encore fragile », « l'ancien qu'on fait tourner » | « ce que tu apprends », « ce que tu viens d'apprendre », « ce que tu connais déjà » |
| Mots techniques | « onboarding », « configuration », « session », « sélection » | « premiers réglages », « réglages », « journée », « tes sourates » |
| Les prières | « surérogatoires » | « sunna » |
| Le livre | « mushaf » | « Coran » |
| L'onglet des questions | « Renforcement » | « Quiz » (« Quiz » en anglais) |

« Quiz » retenu le 2026-10-22 (choix laissé à Claude par l'utilisateur) : « Renforcement » est un mot
abstrait, du registre que cette story retire ; « Quiz » est court, compris de 13 à 45 ans, identique
en français et en anglais, et dit le registre de jeu ouvert par le cadre Zellige. « Questions » a
été écarté : en nom d'onglet, il se lit comme une page d'aide. Pas de doublon avec « questions du
jour » : le quiz est l'onglet, les questions sont ce qu'il pose.

« Terminer ma journée » ne contredit pas la direction narrative : c'est la journée qui se termine,
pas la révision.

**Exclusions explicites** :
- Aucun changement de fonctionnement : seuls les mots changent.
- « Illuminer ma journée avec le Coran » reste : c'est la phrase de l'utilisateur.
- Le texte coranique, les traductions (Hamidullah, Saheeh International) et les sens mot à mot
  (CoranMot) ne sont jamais retouchés : ce ne sont pas des textes de l'app, et la source CoranMot
  interdit toute modification.
- Pas de nouvelle langue.

**Livrable hors critères** : la règle et le lexique validé s'écrivent dans le `CLAUDE.md` du projet,
à la clôture du sprint, pour que tout nouveau texte les suive.

### US-25 — Une seule allure, tenue d'un écran à l'autre (extension d'US-15)
**État** : en cours — Sprint A livré (police Outfit, `AppText`, tokens de couleur, contrastes,
badge de fraîcheur neutre : fondu dans `docs/SPEC_PRODUIT.md` § Registre visuel) ; restent les
Sprints B1 et B2 (les six styles dans les écrans, crit. 1 et 5). Blueprint du 2026-10-17, scoping
du 2026-10-22. Prolonge US-15 (livrée, voir `docs/SPEC_PRODUIT.md` § Registre visuel) et revient
sur son exclusion « pas de nouvelle couleur ni de nouvelle police ». Reprend l'Idée produit « Un
seul style de titre en capitales » de `docs/CHANGELOG.md`, retirée au scoping.

**Statement** : En tant qu'utilisateur, je veux que l'app ait la même allure et les mêmes repères
partout, afin de lire vite et de comprendre d'un coup d'œil ce que veut dire chaque couleur.

**Diagnostic (état actuel)** : 23 tailles de texte différentes ; huit titres en capitales qui ont
chacun leur taille et leur espacement ; une couleur hors palette au Récap. Aucune couleur n'existe
pour les niveaux ni pour le risque d'oublier.

**Critères d'acceptation** (haut niveau) :
1. Given n'importe quel écran, Then le texte est en Outfit (choix utilisateur du 2026-10-17 ; le
   texte coranique garde sa police) et n'emploie qu'un petit jeu de styles fixes : titre d'écran,
   titre de section, titre de carte, texte, légende, grand chiffre.
2. Given les niveaux et le risque d'oublier, Then leurs couleurs et leurs formes sont définies une
   seule fois et identiques partout : quatre teintes froides du vert au bleu nuit, un cœur doré au
   niveau 4, un gris pour « pas encore jouée », et l'orange avec un anneau, réservé au risque
   d'oublier.
3. Given les niveaux, Then ils se distinguent aussi sans les couleurs, par la forme du carreau.
   _Livré par US-21 (ajustement au scoping du 2026-10-22)._
4. Given le thème clair ou sombre de l'appareil, Then chaque style et chaque couleur a son
   équivalent, avec un texte lisible (contraste de 4,5:1, de 3:1 pour les grands chiffres).
   L'habillage reste vert et or.
5. Given chaque écran retouché, Then il est vérifié à l'œil en clair et en sombre avant d'être
   livré (règle d'US-15 crit. 5).

**Exclusions explicites** :
- Pas de nouvelle mise en page des autres écrans : on y applique la police et les styles, rien de
  plus.
- Pas de sélecteur de thème, pas de couleurs de tajwid.
- Les débordements quand le texte système est agrandi (Idées produit de `docs/CHANGELOG.md`)
  restent à part, sauf ceux que le passage à Outfit créerait : à revérifier, Outfit n'a pas la
  largeur de Lora.

**Scoping technique** (2026-10-22) :
- **Valeurs de design** : reprises des maquettes Zellige validées (écrans `Z-*` et planche
  `Z-Mosaique`). Les choix de DA ont été laissés à Claude par l'utilisateur le 2026-10-22.
  - Six styles, en Outfit : titre d'écran 28/600 (interligne 40, lettres −0,4) ; titre de section
    11/600, en capitales, lettres +2 (l'« eyebrow » des maquettes : c'est lui, le titre de
    section) ; titre de carte 17/600 ; texte 15/400 ; légende 13/400 ; grand chiffre 56/700.
    Trois graisses seulement : 400, 600, 700.
  - Carreaux, clair puis sombre : pas jouée `#8E8571` / `#4A524D` ; niveau 1 `#3C8F62` / `#4FA873` ;
    niveau 2 `#24909B` / `#45B5C2` ; niveau 3 `#2F5FB3` / `#6C97F0` ; niveau 4 `#2E2A78` / `#7B6CF0`.
    Gris sombre livré en `#626A65` au Sprint A : `#4A524D` n'atteignait que 2,3:1 sur le fond.
    Risque d'oublier : `#C2571F` / `#F0936B`. Le cœur doré réutilise `palette.gold`.
  - Contrastes corrigés : `textMuted` clair `#5A635D` (5,6:1, valeur des maquettes, au lieu de
    3,9) ; `danger` sombre `#F28B7D` (7,8:1, au lieu de 2,3) ; `goldDark` clair `#806226` (5,1:1,
    au lieu de 4,3, il sert de couleur de texte dans 8 fichiers).
- **Fichiers UI** : `pubspec.yaml` (fontes) ; `lib/core/app_theme.dart` (`textTheme`, styles des
  composants, classe `AppText`) ; `lib/core/app_colors.dart` (124 lignes, tokens) ;
  `lib/widgets/freshness_badge.dart` (texte neutre) ; puis, aux Sprints B1 et B2, les écrans à
  texte latin (59 fichiers portent un `fontSize:` littéral : 169 occurrences, 23 valeurs, chiffre
  du diagnostic confirmé ; 9 fichiers et 10 titres en capitales, et non 8).
- **Variables / champs** : `AppPalette` gagne `levelTints` (liste de 5 : pas jouée, niveaux 1 à 4)
  et `risk`, en clair et en sombre, avec `copyWith` et `lerp`. Aucune clé `SharedPreferences`,
  aucun champ d'`AppState`.
- **`ayah_facts`** : aucune lecture ni écriture. Story purement visuelle.
- **Décision data model** : sans objet (tokens de thème, pas de donnée).
- **Réutilisation** : `AppPalette`/`context.palette`, `palette.gold` pour le cœur ; `google_fonts`
  reste pour Amiri et Scheherazade. `AppText` vit dans `app_theme.dart` : `lib/core/` n'admet
  Flutter que dans `app_colors.dart` et `app_theme.dart` (documentation technique §13).
- **Risques / dépendances** : Outfit n'a pas la largeur de Lora et le texte passe de 13-14 à 15 px :
  débordements possibles, d'où la vérification à 320 px avec texte agrandi ×1,5. Pas de fonte
  variable (graisse rendue de façon inégale selon la plateforme, pas d'iPhone pour vérifier).
  Le Récap et l'onglet Quiz ne reçoivent pas les styles aux Sprints B : US-23 et US-21 les
  reconstruisent et les y prennent directement (sinon on retouche deux fois les mêmes lignes).
  US-24 change les libellés des mêmes widgets : conflits de merge mineurs, aucun ordre imposé.
- **Tests** : `test/core/app_palette_contrast_test.dart` (texte 4,5:1 ; grand chiffre et carreaux
  3:1 ; clair et sombre ; la carte composée sur le fond par `Color.alphaBlend`) ; famille Outfit
  portée par `buildAppTheme`. À l'œil sous Windows : clair et sombre, 390, 360 et 320 px, texte
  ×1,5. Non vérifiable ici : le rendu sur iPhone.
- **Item Backlog** : `[P2] US-25 Sprint B1`, `[P2] US-25 Sprint B2` (Sprint A livré).

**Ajustement au scoping** (2026-10-22) :
- Crit. 3 (forme du carreau) : passe à US-21, qui crée le seul écran qui affiche des carreaux.
  US-25 livre les couleurs, la mosaïque d'US-21 livre les formes. Le sens ne change pas : les
  niveaux se distinguent sans couleur. Validé par l'utilisateur : oui, 2026-10-22.
- Crit. 4 (contraste) : 4,5:1 pour le texte ; 3:1 pour les grands chiffres et pour les carreaux
  (seuil WCAG d'une forme). Le gris, le niveau 1 et le niveau 2 des maquettes sont assombris d'un
  cran en clair pour l'atteindre (2,05, 2,4 et 3,0 auparavant). Validé par l'utilisateur : oui,
  2026-10-22.
- Crit. 2 (une couleur, un sens) : les badges de date de révision du plan du jour perdent leurs
  couleurs (vert, or, rouge) et passent en texte secondaire neutre. Seuls l'orange et les niveaux
  portent un sens par la couleur. Validé par l'utilisateur : oui, 2026-10-22.

### US-26 — Le plan fait passer plus tôt ce que je n'ai pas révisé depuis longtemps (extension d'US-2)
**État** : à scoper — blueprint du 2026-10-17. Prolonge US-2 (livrée, voir `docs/SPEC_PRODUIT.md` § Règle du plan quotidien). Touche la
« Règle du plan quotidien » du `docs/SPEC_PRODUIT.md` (partie A, l'ordre du tour), pas ses invariants.

**Statement** : En tant qu'utilisateur, je veux que l'ordre de mes sourates dans le tour favorise
celles que je n'ai pas révisées depuis longtemps, afin de rattraper d'abord ce que je risque
d'oublier, sans rien avoir à décider.

**Diagnostic (état actuel)** : l'ordre du tour est fixé au départ, au hasard ou dans l'ordre du
mushaf, sans regarder la date de dernière révision. Dans l'usage normal, la sourate révisée il y a
le plus longtemps est déjà la prochaine du plan. Mais une sourate retirée au check-in, ou laissée
de côté par un changement de sélection, peut attendre un tour entier de plus.

**Critères d'acceptation** (haut niveau) :
1. Given un nouveau tour avec l'ordre aléatoire activé, Then l'ordre des sourates est tiré au
   hasard, et une sourate a d'autant plus de chances de passer tôt qu'elle n'a pas été révisée
   depuis longtemps (choix utilisateur du 2026-10-17). Une sourate jamais révisée compte comme la
   plus ancienne.
2. Given un tour en cours, Then l'ordre ne bouge plus jusqu'à la fin du tour (choix utilisateur du
   2026-10-17, contre un nouveau tirage chaque jour) : aucune page sautée, aucune page proposée
   deux fois avant la fin du tour, rythme quotidien inchangé.
3. Given une sourate sur plusieurs pages, Then ses pages restent dans l'ordre du mushaf. Given des
   sourates entières sur une même page, Then elles restent une seule journée (règle du plan,
   partie A).
4. Given l'ordre aléatoire désactivé, Then l'ordre du mushaf est gardé tel quel, sans pondération.
5. Given deux riwayas, Then chaque tour est tiré avec l'historique de sa propre riwaya.

**Exclusions explicites** :
- Le plan ne lit jamais les questions de l'onglet Renforcement : seule la récitation validée en fin
  de journée compte.
- Pas de nouveau tirage en cours de tour : une sourate retirée au check-in attend la fin du tour.
- Pas de réglage de la pondération.
- La durée d'un tour ne change pas, ni la garantie « chaque sourate revue au moins une fois par
  tour ».

**Défaut posé sans demander, à confirmer** : le crit. 4 (l'ordre du mushaf reste sans pondération).

**Point de vigilance** : la « Règle du plan quotidien » du `docs/SPEC_PRODUIT.md` fait foi sur le code. Ce
changement demande de réécrire sa partie A et de verrouiller le nouveau comportement par test,
invariants de la partie E compris.

