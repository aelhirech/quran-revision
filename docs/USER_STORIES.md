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
  réciter, `docs/SPEC_PRODUIT.md` § Renforcement). L'app décide à la place de l'utilisateur : ni niveau, ni seuil, ni
  pondération à régler.
- **Ordre conseillé** : US-25 d'abord (police, styles, couleurs ; livrée, voir
  `docs/SPEC_PRODUIT.md` § Registre visuel), puis US-21 (livrée, voir `docs/SPEC_PRODUIT.md` § Renforcement), puis US-23, qui reprend sa
  mosaïque (`lib/widgets/mosaic.dart`, `mosaic_tile_sheet.dart`). US-24 et US-26 sont indépendantes. Le scoping tranche.

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
   quittent. Le texte d'une sourate s'ouvre depuis son carreau, comme dans l'onglet Renforcement.

**Exclusions explicites** :
- **Modifie US-7 (livrée, voir `docs/SPEC_PRODUIT.md` § Récap)** : la position dans le tour (crit. 1) quitte le Récap ; elle reste sur
  le plan du jour au repos. La fraîcheur par sourate (crit. 2) prend la forme de l'orange et de la
  section « Risque d'oublier », plus celle de badges.
- Les jours de suite restent visibles sur le plan du jour (US-6), la durée du tour à la fin de
  journée (US-14).
- Pas de date d'apprentissage au Récap : une projection se lit à la fin de journée, pas ici
  (règle « derrière au check-in, devant au check-out » de `docs/SPEC_PRODUIT.md`).
- Pas de nouvel indicateur, pas de carte d'activité (calendrier d'activité écarté le 2026-10-23,
  voir « Écartées »).
- Pas de liste des questions ratées au Récap : elles reviennent dans les séries de l'onglet
  Renforcement (`docs/SPEC_PRODUIT.md` § Renforcement).

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

### US-31 — L'app reste lisible avec un texte agrandi (extension du Registre visuel)
**État** : en cours — Sprints A, B et C livrés (fondus dans `docs/SPEC_PRODUIT.md` § Registre
visuel). Reste le Récap et la
barre d'onglets, à scoper après US-23 et US-24 — blueprint du 2026-10-23, scoping du 2026-10-28.

**Moment de l'histoire** : tous. Ce que la story y prouve : rien de nouveau. Elle garantit qu'un
utilisateur qui lit en grand voit la même app que les autres, et non une app cassée.

**Statement** : En tant qu'utilisateur qui agrandit le texte de son téléphone, je veux que chaque
écran reste entier et lisible, afin de ne jamais deviner un mot coupé ni chercher un bouton qui
saute.

**Critères d'acceptation restants** (Récap et barre d'onglets) :
1. Given 375×667 avec texte ×1,5, et 320×568 avec texte ×1,5 en marge, Then au Récap et dans la
   barre d'onglets, un texte ne déborde pas, n'est pas coupé et ne s'écrit pas lettre par lettre.
2. Given un texte qui ne tient pas sur une ligne, Then il passe à la ligne entre deux mots, jamais
   au milieu d'un mot. Given un libellé qui doit rester sur une ligne, Then il rétrécit pour tenir ;
   des libellés côte à côte rétrécissent ensemble (choix utilisateur du 2026-10-23).

**Exclusions explicites** :
- L'app ne plafonne pas l'agrandissement choisi par l'utilisateur (la barre d'onglets du système
  garde le sien).
- Pas de réglage de taille dans l'app : elle suit celui du téléphone, comme le thème.
- Pas de textes raccourcis pour tenir : les mots sont le sujet d'US-24.

**Reste ouvert, hors Backlog** (choix utilisateur du 2026-10-23) :
- **Barre d'onglets** : à 320 px avec texte ×1,5, « Plan du jour » ne tient pas sur une ligne, et la
  barre système n'offre aucun moyen de rétrécir un libellé. À remesurer après le renommage « Quiz »
  d'US-24. On tranchera sur ces mesures : rétrécir, accepter deux lignes, ou raccourcir.
- **Récap** : « Aucune session enregistrée » se coupe au milieu des mots, sans cause identifiée à la
  lecture, et la zone de fin d'une ligne de sourate prend la largeur. Le Récap est reconstruit par
  US-23 : à remesurer après.
Ces deux points se scopent après US-23 et US-24, et US-31 ne passe à « terminée » qu'à ce moment.

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

