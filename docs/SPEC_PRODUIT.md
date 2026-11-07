# Spec produit — Quran Revision App

**Ce que fait l'app aujourd'hui**, domaine par domaine : l'état actuel, pas l'historique des
changements. Complète `docs/USER_STORIES.md` (les changements **à venir**, sous forme de stories)
et `docs/DOCUMENTATION_TECHNIQUE.md` (**comment** c'est codé).

- **Fait foi sur le code** : en cas d'écart entre ce fichier et le comportement de l'app, c'est le
  code qui est faux — sauf décision explicite de changer la règle, qui passe par une story.
- **Se met à jour à la clôture d'une story** (`quran-close`) : ses critères d'acceptation sont
  fondus dans la section du domaine concerné, puis la story est retirée de `docs/USER_STORIES.md`.
- **Pas de dates ni de numéros de sprint dans le corps** sauf quand ils expliquent une règle
  (« corrigé le … parce que … ») : l'historique vit dans `git log`.
- **Chaque domaine dit aussi ce que l'app ne fait pas** (« Ne fait pas ») : ce sont des décisions
  prises, pas des oublis. Les réintroduire de bonne foi demande une story.

**Sommaire** : Direction narrative · Vue d'ensemble · Premier contact · Check-in · Règle du plan
quotidien · Pendant la journée · Check-out et clôture · Apprentissage · Vue Coran et écoute ·
Renforcement · Récap · Réglages, régularité et rappels · Registre visuel

---

## Direction narrative de l'app (cadrée au blueprint du 2026-09-20)

Avant ce cadrage, chaque fonctionnalité était ajoutée pour sa valeur propre, sans place assignée
dans un récit — d'où un onboarding qui collectait des réglages sans faire comprendre la méthode,
et une démo sur 3 sourates fixes qui n'appartenait à aucun moment (déplacée une fois sans que ça
règle quoi que ce soit, puis supprimée). **Toute fonctionnalité ajoutée à partir d'ici doit savoir
à quel moment de l'histoire elle entre.**

### La thèse

L'utilisateur arrive **déjà motivé** — il porte du Coran et sait ce qu'il risque à le perdre. Mais
la motivation fluctue : c'est la variable la moins fiable. L'app ne cherche donc pas à motiver ;
elle **supprime la décision quotidienne** (quoi réviser, combien, est-ce que j'ai déjà fait
celle-là) qui suffit, un jour de faible énergie, à faire sauter la journée. Recevoir un objectif
atteignable décidé par un tiers légitime est en soi un moteur.

Corollaire opérationnel : **toute fonctionnalité qui redonne une décision à l'utilisateur joue
contre la thèse**, même si elle paraît généreuse (lecteur de Coran libre, choix supplémentaire au
check-in, réglage de plus). La générosité, ici, c'est de décider à sa place.

### L'ancrage, et sa limite

L'app automatise trois couches connues de toute mémorisation sérieuse — **le nouveau**, **le
récent encore fragile**, **l'ancien qu'on fait tourner** (respectivement l'apprentissage,
`FreshnessEngine`, `RevisionEngine`). Elles se nomment **en clair**, jamais par leurs termes
traditionnels arabes : introduire du vocabulaire inconnu est exactement le mal qu'on soigne. La
légitimité tient en une phrase — *la méthode des hafiz depuis des générations* — et ne se répète
pas. **L'app n'est pas un enseignant** : elle ne corrige ni la récitation ni le tajwid et ne se
présente jamais comme remplaçant un cheikh. Elle tient le carnet, pas la chaire.

### La forme de la journée

| Moment | Ce qui s'y passe | Regard |
|---|---|---|
| **Début** — check-in | Prendre en considération l'objectif du jour et s'y engager | **Derrière** : l'acquis, la régularité déjà constituée |
| **Milieu** — les prières | Réviser, apprendre. L'app est quasi absente : elle n'offre que l'accès au texte depuis chaque ligne du plan et, à un moment choisi, l'onglet Renforcement pour s'éprouver sur ce qu'on porte | — |
| **Fin** — check-out | Confirmer ce qui a tenu ; ce qui n'a pas tenu revient demain | **Devant** : durée du tour, échéance d'apprentissage |

Règle de placement des chiffres : **derrière au check-in, devant au check-out.** Le check-in doit
rendre l'objectif du jour *léger* — y afficher une projection réintroduit le poids du total au
moment exact où l'on cherchait à l'alléger. Au check-out l'effort est déjà dépensé : la projection
s'y lit comme une récompense.

### Ce qu'on a le droit de promettre

- **L'apprentissage a une fin** → une date est légitime, mais toujours conditionnelle (« si tu
  tiens ce rythme »), recalculée en silence après une absence, jamais opposée à l'utilisateur
  (« tu as perdu X jours »).
- **La révision n'a pas de fin, elle a un tour** → `cycleTotal ÷ pages par jour`. Ce nombre est
  stable (il ne bouge pas quand des jours sont sautés) et se lit de deux façons : une période, et
  une garantie — *aucune sourate ne restera plus de N jours sans être revue*.
- **Ne jamais écrire « fini »/« terminé » à propos de la révision.** L'utilisateur qui croit
  atteindre une ligne d'arrivée et voit le cycle reboucler vit une trahison.
- Une sélection qui grandit allonge le tour : le présenter comme une **capacité**, jamais comme une
  régression — sinon l'app dissuade d'ajouter du Coran.

### Où entre une nouvelle fonctionnalité

Avant d'ajouter un écran, un message ou un indicateur : dire **à quel moment de l'histoire il
entre** (diagnostic, engagement, milieu, clôture, preuve du lendemain) et **ce qu'il y prouve**.
Une fonctionnalité sans moment est soit mal placée, soit inutile — c'est ce diagnostic qui a tué
la démo sur 3 sourates fixes. Et ne jamais ajouter un indicateur là où une phrase expliquant un
indicateur existant suffirait : le streak existait déjà, ce qui manquait c'était de dire ce qu'il
signifie au moment où il compte.

---

## Vue d'ensemble

- App mobile (iOS/Android) **mono-utilisateur, entièrement locale** : aucun compte, aucune donnée
  hors de l'appareil. Profils multiples supprimés sur demande explicite : ne pas les réintroduire
  sans besoin confirmé.
- **Quatre onglets** : Plan du jour, Renforcement, Récap, Réglages.
- **Deux riwayas, Hafs et Warsh, comme deux parcours totalement indépendants** : sélection,
  cycle, curseur, apprentissage et historique propres à chacune, jamais mélangés ni traduits de
  l'une vers l'autre. Une riwaya indisponible sur l'appareil est signalée, jamais remplacée par un
  contenu incorrect.
- **Langue** de l'app : français ou anglais. **Thème** : suit le mode clair/sombre du système,
  sans réglage.
- Tout ce que l'app sait de la relation de l'utilisateur au Coran (proposé, fait, appris) est un
  journal daté par verset ; tous les chiffres affichés en sont dérivés.

## Premier contact

### Onboarding
1. **Explique avant de configurer** : ce qu'on a mémorisé s'efface faute de **structure**, pas
   de sincérité ; l'app décide la portion du jour selon trois couches (le nouveau, le récent
   encore fragile, l'ancien qu'on fait tourner), présentées comme la méthode des hafiz depuis des
   générations.
2. **Rythme** : quand l'utilisateur choisit ses pages par jour, l'app annonce la durée d'un tour
   complet de sa sélection, aussi formulée comme une garantie (« aucune de tes sourates ne restera
   plus de N jours sans être revue »). Calculée en vraies pages du mushaf, comme le plan
   (invariant E.7).
3. **Dernier écran = le vrai plan du jour 1**, identique à celui du premier check-in (même graine
   de mélange). Il est précédé du **récit d'une journée en quatre moments** : le matin (bouton
   « Illuminer ma journée avec le Coran »), dans les prières (l'icône livre de chaque ligne du
   plan), avant de prier ou à un moment choisi (le bouton lecture de la vue Coran), le soir
   (clôturer : ce qui a tenu est confirmé, le reste revient demain). Chaque moment montre le
   **vrai contrôle**, dans la langue et le thème en cours, mais inerte. Le matin y est décrit
   comme « l'app propose, tu confirmes ou ajustes », jamais comme des réglages à remplir.
4. Une sélection sans aucune métadonnée de page est **signalée** sur cet écran, pas montrée comme
   une liste vide.
5. Configurer une **seconde riwaya** saute les pages d'explication et le récit.
6. Le récit reste lisible en entier sur petit écran ou texte agrandi ; le bouton de fin reste
   atteignable.

### Accompagnement des premiers gestes réels
- Après l'onboarding, l'utilisateur déclenche lui-même son premier check-in ; des étapes guidées
  l'accompagnent ensuite : check-in validé, texte ouvert depuis une rakaa, premier check-out, puis
  découverte du Récap et des Réglages juste après la première clôture, et première écoute lancée
  depuis la vue Coran (si l'audio est disponible).
- **Une étape n'est considérée comme donnée que lorsque le geste réel a eu lieu**, jamais parce
  qu'elle a été affichée ni fermée : les étapes n'ont pas de croix, elles portent une action. Une
  étape interrompue est encore là au retour.
- Au premier check-in, l'app regarde **derrière** (l'acquis, la régularité) ; au premier
  check-out, **devant** (durée du tour, échéance d'apprentissage).
- **Preuve du lendemain** : quand des versets laissés non faits la veille reviennent dans le
  plan, le Plan du jour le dit **une fois** (« ce verset est revenu tout seul »), avec le nom de la
  sourate, le numéro du verset et le nombre d'autres versets revenus. C'est ce moment, pas
  l'onboarding, qui prouve la méthode.

**Ne fait pas** : aucune démonstration sur un contenu qui n'est pas celui de l'utilisateur (la
démo sur 3 sourates fixes est supprimée, pas déplacée) ; aucun bouton cliquable ni mini-parcours
dans l'onboarding ; pas de capture d'écran, vidéo ou voix ; pas de moyen de revoir le récit ;
aucun chiffre de projection dans le récit ; pas de librairie de coach-marks ni d'overlay à trou.

## Check-in — « Illuminer ma journée avec le Coran »

- **Le plan du jour n'existe qu'après l'appui sur ce bouton et la validation du check-in.**
  Ouvrir l'app n'écrit rien. Quitter le check-in sans valider n'écrit rien : pas de journée en
  attente, pas de rattrapage le lendemain. Le plan s'ajuste en mémoire pendant le check-in et
  n'est enregistré qu'à la validation.
- L'utilisateur **confirme ou ajuste** ce que l'app propose : le rythme du jour (pages), les
  portions de révision (retirer une portion, ajouter une sourate), la sourate et le nombre de
  versets à apprendre, les prières où il compte réciter. Deux réglages s'enregistrent dès le tap
  et valent aussi pour les jours suivants, comme dans les Réglages : le rythme et le nombre de
  versets à apprendre par jour.
- **« Ajouter une sourate »** ne propose que les sourates de la sélection de révision, puis la
  portion précise à réviser ; le sélecteur s'ouvre sur la plage choisie mais reste réglable
  au-delà (voulu).
- **« Prières où il récite »** = prières où c'est lui qui récite, seul ou en dirigeant. Ni filtre
  d'exclusion ni pondération. **Choisir une prière est facultatif** : le check-in se valide sans
  aucune, et une phrase dit alors que tout le plan sera en dehors des prières.
- Chaque ligne proposée porte un **libellé discret de fraîcheur** (depuis quand ces versets n'ont
  pas été revus, au grain verset).
- **Ré-appui après « Refaire le plan »** : le brouillon repart de ce qui est déjà enregistré pour
  le jour, jamais d'un nouveau calcul. Un verset déjà fait n'est jamais retiré par un ajustement.
  « Je n'apprends rien aujourd'hui » n'est pas re-proposé au ré-appui.
- Valider le check-in donne un **retour tactile**.

**Ne fait pas** : aucune projection (durée du tour, échéance) au check-in ni sur l'accueil avant
l'engagement ; aucun effet ni jalon ; aucun geste de téléchargement audio.

## Règle du plan quotidien : quelles pages, et comment elles arrivent dans les rakaas

> **Le code s'y conforme depuis la Phase 9 Sprint 3 (2026-09-08)**, signalement des sourates sans
> pagination compris (Sprint 4). En cas d'écart entre ce bloc et le code, **c'est le code qui est
> faux**, pas ce bloc.
>
> Cette règle est écrite ici parce que son absence a laissé passer trois bugs majeurs pendant
> plusieurs sprints : la doc technique affirmait une continuation que rien n'implémentait, et
> personne ne pouvait constater l'écart. Les invariants de la partie E sont verrouillés par
> `test/core/revision_engine_test.dart` — les modifier, c'est changer la règle, pas corriger un test.

### Vocabulaire

| Terme | Définition |
|---|---|
| **Sélection** | Ce que l'utilisateur a choisi de réviser : une liste de portions (sourate + plage `verseStart..verseEnd`, souvent la sourate entière) — `UserConfig.selections`. |
| **Page** | Une page **réelle** du mushaf, pour la riwaya active (`PageMetadataService`). |
| **Fragment** | L'intersection d'une portion de la sélection et d'une page. |
| **Entrée de cycle** | Une page, avec tous les fragments de la sélection qui s'y trouvent. |
| **Curseur** (`cyclePosition`) | L'index de la **prochaine entrée** à réviser. **En pages, jamais en sourates.** |
| **Rythme** (`pagesParJour`) | Un budget de **vraies pages du mushaf par jour** (décision 2026-09-26 — avant cette date, comptait des entrées de cycle, pas toujours identiques à une page réelle, voir `RevisionEngine._takeEntriesForPages`). |

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

3. entrées := regrouper les fragments par numéro de page,
   MAIS un fragment ne rejoint le groupe de sa page QUE si toute la portion
   dont il vient tient ENTIÈREMENT sur cette page (un seul fragment pour
   cette portion). Sinon il forme sa propre entrée, exclusive à
   (sourate, page) — jamais partagée avec une autre sourate.
   # Plusieurs sourates COMPLÈTES sur une même page physique = UNE entrée,
   # donc UNE journée (ex. Al-Kawthar/Al-Ma'un/Quraysh sur une même page).
   # Mais une sourate qui déborde sur une page (elle y a un fragment PARTIEL)
   # n'entre jamais dans le groupe de cette page, même si une autre sourate,
   # elle, y est entière : on révise sourate par sourate, la page n'est
   # qu'une aide mémoire pour le débit quotidien, pas une unité de fusion.
   # Piège corrigé (retour utilisateur 2026-09-08) : fusionner sans cette
   # garde faisait hériter le fragment débordant du rang MINIMUM de la page
   # partagée — un verset isolé (la fin d'Al-Inshiqaq, sur la même page
   # qu'Al-Buruj) se retrouvait alors proposé à un autre moment du cycle que
   # le reste de sa propre sourate, dès que le mélange plaçait le voisin
   # avant elle. Conséquence assumée : une page-frontière entre une sourate
   # entière et une sourate qui déborde coûte alors 2 entrées au lieu d'1.

4. trier les entrées par (plus petit `rang` de leurs fragments, puis n° de page croissant)
   # Le mélange ordonne les sourates ; à l'intérieur d'une sourate,
   # les pages restent toujours dans l'ordre du mushaf.

5. cycleTotal := nombre d'entrées   # = nombre de pages réelles à réviser
```

### B. Le plan du jour

```text
PLAN_DU_JOUR(cycle, curseur, pagesParJour) -> [entrées du jour]

si cycle est vide : ne rien proposer, et le SIGNALER (ne jamais boucler à vide en silence)

# pagesParJour compte des VRAIES PAGES, pas des entrées (décision 2026-09-26) :
# une entrée peut être plus petite qu'une page (fragment "privé" d'une sourate
# à cheval) ou partager sa page avec l'entrée suivante (page frontière, voir
# partie A) — prendre un nombre fixe d'entrées promettrait un rythme différent
# de ce que l'utilisateur choisit à l'écran.
pagesVues := ensemble vide
pris := []
tant que pagesVues.taille < pagesParJour ET pris.taille < cycleTotal :
    e := cycle[(curseur + pris.taille) mod cycleTotal]
    pris.ajouter(e)
    pagesVues += pages réelles touchées par les fragments de `e`
retourner pris
# Une entrée n'est jamais coupée pour tomber pile sur `pagesParJour` : le jour
# peut finir par couvrir plus ou moins de pages réelles que le budget demandé
# (ex. deux entrées consécutives qui partagent la même page réelle ne font
# progresser `pagesVues` qu'une fois — le jour prend alors une entrée de plus
# pour rejoindre le budget, sans jamais le dépasser en repassant par une page
# déjà comptée ce jour-là).
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

si rakaasRécitées = 0 (aucune prière choisie) :
    toute la révision va dans le bloc « à réviser en dehors des prières » ;
    la portion à apprendre va dans un second bloc, « À apprendre ».
    # Le check-out crédite ces deux blocs comme le contenu des rakaas.

dans une même prière : ne jamais assigner deux fois le même fragment
tant qu'une alternative non encore utilisée dans cette prière existe.
les rakaas au-delà de `suratRakaas` restent « Al-Fatiha seule » — seul cas de rakaa vide légitime.
```

### E. Invariants — à vérifier par test, pas par relecture

1. **Aucune page sautée.** Une sourate de N pages est couverte en N entrées consécutives : page 1
   aujourd'hui, page 2 demain, jusqu'à la fin. C'était le bug principal du 2026-09-08. Seule
   exception : une sourate apprise qui entre ou s'élargit en révision garde le curseur sur son
   verset, donc ses pages placées avant lui attendent le tour suivant (reculer répéterait des
   pages, invariant 2).
2. **Aucune répétition avant bouclage.** Tant que `cycleTotal` entrées n'ont pas été parcourues,
   aucune page n'est reproposée.
3. **Jamais hors de la plage choisie.** Si l'utilisateur ne sélectionne que les versets 255–260
   d'Al-Baqara, aucun autre verset n'est jamais proposé. C'était le second bug du 2026-09-08.
4. **Le curseur progresse à l'intérieur d'une sourate**, y compris quand elle est seule sélectionnée.
5. **Aucun contenu crédité sans avoir été proposé** au check-in ou déclaré au check-out.
6. **Aucune rakaa récitée vide** tant qu'il reste de la matière.
7. **Le budget quotidien (`pagesParJour`) compte des vraies pages, jamais des entrées** (décision
   2026-09-26) : `DaySelection.cycleDays` et `PLAN_DU_JOUR` (partie B) doivent utiliser le même
   calcul par pages réelles distinctes, jamais une simple division de `cycleTotal`.

### F. Cas limites — la réponse est ici, pas dans le code

| Cas | Comportement attendu |
|---|---|
| Portion sans métadonnée de page | Ignorée du cycle. Si plus rien ne reste alors que des sourates sont sélectionnées, l'accueil le **signale** au lieu d'afficher « 0 / 0 pages ». |
| `pagesParJour` (en vraies pages) > total de pages réelles du cycle | Le jour propose tout le cycle, une seule fois (pas de répétition), même si le budget de pages n'est jamais atteint. |
| Page partagée par 2 sourates sélectionnées | Une seule entrée, donc une seule journée, et **une seule page** dans les compteurs. |
| Page partagée dont une seule sourate est sélectionnée | Entrée normale ; la sourate non sélectionnée n'y entre jamais. |
| Portion retirée au check-in | Ni comptée ni bloquante à la clôture. |
| Changement de rythme en cours de sourate | Le curseur ne bouge pas : seul le nombre d'entrées prises par jour change. |
| Changement de sélection | Le cycle est reconstruit ; la progression repart de 0 (`saveConfig` le fait déjà). Exception : une sourate apprise en entier qui entre ou s'élargit en révision ne remet pas à 0, le curseur reste sur le verset qu'il pointait. |
| Changement de riwaya | Cycle et curseur sont scopés par riwaya, indépendants. |
| Journée sautée | Le curseur n'avance pas ; rien n'est perdu, le contenu revient le lendemain. |
| Bouton « Illuminer ma journée avec le Coran » jamais pressé (ou check-in quitté sans valider) | Aucune ligne n'est écrite dans `ayah_facts` pour ce jour : pas de jour en attente, pas de rattrapage le lendemain. Le plan du jour n'est écrit que par `AppState.commitCheckIn`. |

## Pendant la journée — le Plan du jour

- Le plan affiche les prières choisies, rakaa par rakaa, selon la partie D de la règle du plan ;
  ce qui ne tient pas dans les rakaas apparaît dans un bloc **« à réviser en dehors des
  prières »**. Rien n'est caché.
- **Cocher une rakaa** au fil des prières rend la progression visible tout de suite (léger
  retour tactile). Cocher une rakaa peut en cocher une autre quand la même plage de versets
  revient deux fois dans la journée : ce qui est fait l'est par verset, pas par rakaa.
- Sur chaque ligne, **l'icône livre** ouvre la vue Coran sur la plage concernée.
- Rien n'est « fait » avant d'avoir été coché : seul le check-out coche tout par défaut.
- **Sans prière choisie**, le plan n'a aucune rakaa et ne parle pas de prières : la révision est
  dans un bloc **« À réviser aujourd'hui »**, avec sa propre phrase, et le passage à apprendre
  dans un bloc « À apprendre », en lecture seule. Ni le résumé ni le bas de l'écran n'affichent de
  nombre de rakaas ou de barre de progression. La journée se clôture comme les autres.
- **Avec au moins une prière**, le compteur « N / M rakaas » et sa barre restent, même si aucune
  rakaa ne reçoit de contenu (« 0 / 0 rakaas »).

**Ne fait pas** : aucun compteur de remplacement (versets, pages) un jour sans prière — il n'y a
rien à cocher, la fin de journée valide ce qui a été fait ; aucune animation pendant les prières
au-delà du retour tactile de coche ;
aucun lecteur de Coran libre (lire reste attaché à une ligne du plan — un mushaf libre
redonnerait la décision que l'app existe pour retirer).

## Check-out et clôture — « Clôturer ma journée »

### Confirmer
- L'utilisateur confirme **verset par verset** ce qui a réellement été fait, révision et
  apprentissage avec le même geste : tout est coché par défaut, **décocher un verset** le laisse
  à faire. Ce qui n'a pas tenu revient le lendemain (l'entrée de cycle n'est pas dépassée, partie
  C de la règle du plan).
- **« J'ai révisé une sourate en plus »** : ne propose que la sélection de révision. Faire plus
  fait avancer le tour, mais seulement ce qui est déclaré ce jour-là, et dans l'ordre : déclarer
  une portion plus loin dans le tour ne crédite pas celles qui la précèdent.
- **Apprentissage** : pour la sourate apprise ce jour-là, l'utilisateur peut aussi retirer le
  **dernier bloc appris les jours précédents** s'il ne tient pas ; ces versets redeviennent « à
  apprendre » et la sourate reste en cours. Rien au-delà du dernier bloc.
- **Aucun verrou horaire** : le bouton de clôture est toujours actionnable. Avant l'heure du
  rappel du soir, l'app se contente de signaler que la journée n'est pas finie. (Un verrou
  n'arrête que les honnêtes et ajoute de la friction au moment où l'utilisateur a enfin
  l'énergie d'agir.)
- Sceller la journée donne un **retour tactile**. Une journée ne fait avancer le tour qu'une fois.

### Journée non clôturée
- Revenir dans l'app un jour plus tard (lancement ou retour d'arrière-plan) **signale la journée
  non clôturée et propose de la clôturer** avant de continuer. Jamais de scellement automatique.

### Après la clôture
- **Transition courte et sobre** (environ 4 s, sans geste à faire) qui nomme le jour clôturé —
  « Hier est clôturé » pour un rattrapage. Pas de modale.
- **Accueil d'une journée clôturée**, chaque jour : ce que la journée a apporté (versets revus,
  versets appris s'il y en a), sans reproche (« le reste reviendra demain », jamais « tu as raté
  X »), et en regard **devant** la durée du tour et l'échéance conditionnelle de l'apprentissage.
  Après le rattrapage d'un jour passé, l'accueil revient à l'état de repos d'aujourd'hui, pas au
  bilan d'hier.
- **Jalons rares**, annoncés dans un seul moment sobre qui se referme en un geste :
  - une sourate dont le dernier verset vient d'être confirmé est **mémorisée** et entre dans la
    révision, présentée comme une capacité gagnée ;
  - le **tour de révision boucle** : « tout a été revu, un nouveau tour commence », jamais
    « fini » ni « terminé ».

  Les deux le même soir = un seul moment. Un jalon remplace la transition de clôture, et
  s'annonce aussi au rattrapage d'un jour passé.
- Afficher un jalon ou un bilan ne change rien à la progression.

**Ne fait pas** : pas de palier de régularité (7/30/100 jours : fêter la série la transforme en
pression) ; pas de son, pas de trophées ni de collection de jalons ; pas de modale chaque soir.

## Apprentissage

- Pas d'onglet dédié. La sourate à apprendre est **choisie au check-in**, ses versets sont
  récités dans la **toute dernière rakaa** du jour (dans le bloc « À apprendre » quand aucune
  prière n'est choisie), et ils ne sont crédités **qu'au check-out**.
- Démarrer une sourate en garde la trace même avant qu'aucun verset ne soit appris.
- Quand la fin de journée confirme le dernier verset d'une sourate, la sourate **passe en
  révision en entier**, sans geste de l'utilisateur : une plage partielle déjà sélectionnée devient
  la sourate entière. Rattraper la fin de journée d'un jour passé fait de même. La fin de journée
  annonce la sourate apprise, que la sourate ait été ajoutée ou élargie.
- Tous ses versets entrent alors dans le tour et dans les questions. Le tour continue sur le verset
  où il en était, sans repartir de zéro : les pages de la sourate placées avant ce point sont
  revues au tour suivant.
- Cela n'a lieu qu'une fois, au jour où la sourate est complétée. Ensuite le réglage de
  l'utilisateur fait foi : une plage resserrée n'est plus élargie, une sourate retirée n'est plus
  remise. Seule la riwaya où la sourate a été apprise est touchée.
- Revenir en arrière sur un verset le remet « à apprendre » sans jamais perdre le fait que la
  sourate est en cours.
- **L'échéance d'apprentissage est toujours conditionnelle** (« si tu tiens ce rythme »),
  recalculée en silence après une absence, jamais opposée à l'utilisateur.
- Au Récap, une sourate en cours est un **suivi** : nom, progression, prochain verset, icône livre
  vers la vue Coran, glisser pour l'abandonner. La toucher n'ouvre rien.

**Ne fait pas** : aucun second écran d'apprentissage ni de feuille équivalente ; aucun crédit
de verset en dehors du check-out ; aucun verset de contexte grisé en tête de la plage apprise ;
aucune modification de sélection pour une sourate pas encore apprise en entier ; aucun
élargissement rétroactif à l'ouverture de l'app (une sourate déjà apprise et restée partielle
reste telle quelle). Cas rare accepté : resserrer la plage puis refaire la fin de journée du jour
même de la complétion la réélargit.

## Vue Coran et écoute

S'ouvre depuis le Plan du jour, le bloc hors prières, la carte d'apprentissage et le Récap,
toujours sur la plage de la ligne d'où elle est ouverte.

### Le texte
- En-tête (nom de la sourate, plage, bismillah) et barre audio défilent avec le texte ; seule la
  poignée reste fixe. À l'ouverture, tout est visible en haut.
- **Portion** (curseur à deux poignées + ±1 sur chaque borne) : sans y toucher, toute la plage
  est affichée et jouée. Resserrée, elle **masque** les versets hors portion, en direct pendant le
  geste. Bornée à la plage affichée ; absente pour une plage d'un seul verset. L'en-tête garde la
  plage d'origine. Elle repart de la plage entière à chaque ouverture.
- **Traduction** (Hafs seulement) : un bouton dans l'en-tête affiche sous chaque verset la
  traduction dans la langue de l'app (Muhammad Hamidullah en français, Saheeh International en
  anglais, éditions Tanzil ; nom du traducteur et source affichés). Un verset masqué ne laisse pas
  sa traduction. Repart de l'arabe seul à chaque ouverture. Absente en Warsh.

### L'écoute
- Le bouton lecture/pause joue **en boucle** la portion affichée, jusqu'à l'arrêt, y compris
  écran verrouillé ou app en arrière-plan, avec les contrôles de la notification système.
- Récitateurs propres à la riwaya active ; le choix est mémorisé.
- Changer la portion pendant l'écoute relance la boucle sur la nouvelle portion au relâché du
  curseur ou au ±1, sans geste de plus. En pause, le prochain appui lance la nouvelle portion.
- **Hors connexion** : une sourate se télécharge depuis la vue Coran (la sourate entière, pour le
  récitateur choisi), un récitateur entier depuis les Réglages (poids annoncé avant). Les
  téléchargements attendent le Wi-Fi sauf autorisation des données mobiles, avancent tant que
  l'app est au premier plan et reprennent seuls au retour, sans recommencer ce qui est complet.
  Changer de récitateur conserve les précédents ; les Réglages listent les récitateurs stockés
  (poids, état) et permettent d'en supprimer un.
- Audio indisponible (hors ligne et non téléchargé, verset non couvert) : **signalé
  clairement**, jamais une boucle muette ni une lecture partielle.

**Ne fait pas** : l'écoute, la traduction et le téléchargement ne créditent rien (ni tour, ni
série, ni check-out) ; pas d'écran audio indépendant ni de liste des 114 sourates à télécharger ;
pas de téléchargement automatique ; pas de suppression sourate par sourate ; pas de compteur de
répétitions, de pause entre répétitions ni de vitesse ; pas de barre de lecture flottante ;
pas de mot à mot, de tafsir, de notes ni de translittération ; pas de choix de traduction ; pas
de mémorisation de la portion ni de l'affichage de la traduction ; pas de source audio autre que
KSU.

## Renforcement

- L'onglet propose une **série déjà composée** : une dizaine de questions, finie, sans chrono,
  lancée en un geste ; un second geste lance une série sur une sourate choisie dans la sélection.
- **Question de suite** : un passage est affiché (avec sourate et numéro) et l'utilisateur
  retrouve celui qui le suit parmi quatre au plus. Un verset de plus de 12 mots est coupé aux
  signes de pause du mushaf ; « … » marque un passage qui ne commence ou ne termine pas son
  verset, jamais devant un choix. Les mauvais choix viennent de ce que l'utilisateur porte (autres
  sourates, même sourate, voisins, passages similaires : au moins la moitié des mots en commun).
  Jamais deux bonnes réponses : un passage qui se répète à l'identique dans la sourate, ou dont la
  suite se répète, n'est pas posé.
- **Questions de mots** (français, Hafs) : un mot montré en or dans son verset, quatre sens au
  plus ; ou un sens, quatre mots arabes au plus. Mots d'au moins 3 lettres, tirés des sourates
  portées ; un mauvais choix n'est jamais un sens voisin du bon. Sens affichés tels que la source
  (CoranMot, Dr Usama Nonnenmacher) les donne, source citée sous chaque réponse.
- **Trois modes** quand les questions de mots existent : « Mélange » (présélectionné, 5 + 5),
  « Versets », « Traduction ». En Warsh ou en anglais, pas de sélecteur : questions de suite
  seulement.
- Au plus la moitié des questions vient du plan du jour quand il existe. Les questions de la
  série précédente ne sont pas reposées pendant la session tant que la sélection en offre
  d'autres.
- Après chaque réponse : la bonne réponse en entier, un accès au texte, et sous un mauvais choix
  l'endroit d'où il vient — jamais un « faux ». En fin de série, un score factuel.
- Sélection trop petite : l'onglet le dit au lancement, jamais de série vide ni de verset pris
  hors sélection.

**Ne fait pas** : rien n'est crédité ni enregistré (reconnaître un passage n'est pas le
réciter) ; aucun verset hors de ce que l'utilisateur porte — sa sélection dans les plages
choisies et les versets déjà appris ; jamais un verset pas encore appris, jamais une suite hors
plage ; pas de question sur le verset précédent, de remise en ordre, de sourate à nommer, ni par
l'écoute ; pas de rappel pour jouer ; une série quittée repart du début ; pas de cours de mots
fréquents, de grammaire ni de racines.

## Récap

- La **position dans le tour** et l'étendue de la sélection, issues du même calcul que le plan du
  jour. Au début d'un tour : « Nouveau tour » et « N pages en garde » plutôt qu'un 0 %.
- **Mémorisées en entier** : sourates de la sélection couvertes du premier au dernier verset,
  d'où qu'elles viennent (une portion n'y compte pas). **En cours d'apprentissage** : les cartes
  de suivi.
- **Rythme** : versets revus sur les 7 derniers jours, et moyenne par semaine sur 8 semaines.
- La **fraîcheur** de chaque sourate, au grain verset : jamais revue, revue récemment en entier,
  partiellement fraîche, ancienne — le même calcul que partout ailleurs.
- Chaque sourate ouvre son texte.
- Chaque chiffre a un sens unique : pas de doublon, pas deux chiffres qui semblent se contredire.

## Réglages, régularité et rappels

- **Réglages** : langue, riwaya active, sélection de sourates (et plages), rythme, nombre de
  versets à apprendre, ordre mélangé ou non, heures de rappel, jour de pause, téléchargements
  audio. Changer la sélection ou le mélange **reconstruit le tour et repart de 0** ; changer le
  rythme ne bouge pas le curseur. Changer de langue ou de riwaya ne perd rien.
- **Une sélection qui grandit allonge le tour** : présenté comme une capacité (« tu portes
  maintenant plus »), jamais comme une régression.
- **Série de régularité** : nombre de jours consécutifs actifs, mis à jour à chaque journée
  clôturée. Un jour déclaré « pause » ne la casse pas ; une vraie interruption la remet à zéro.
- **Rappels** (si la permission est accordée), à l'heure configurée dans le fuseau de l'appareil :
  matin pour le check-in, soir pour le check-out, et minuit pour clôturer une journée qui ne l'est
  pas. Heures communes aux deux riwayas.

**Ne fait pas** : pas de nouvelle statistique là où la série existe déjà — ce qui manquait, c'est
une phrase qui l'explique au moment où elle compte.

## Registre visuel

- Direction artistique **Mus'haf** (clair : papier crème, vert, or) et **Tahajjud** (sombre),
  registre **sobre et solennel** : lumière dorée, ornement qui se dessine, fondu lent.
- **Une seule police latine, Outfit**, embarquée dans l'app (même rendu hors connexion au premier
  lancement). Le texte coranique garde ses polices arabes.
- **Six styles de texte**, chacun choisi selon son rôle : titre d'écran, titre de section (en
  capitales), titre de carte, texte, légende, grand chiffre. Tous les écrans n'emploient que
  ceux-là, sauf le Récap et l'onglet Quiz, qui gardent encore leurs tailles propres. Avec un texte
  système agrandi, l'en-tête du check-in et du check-out défile avec le contenu, les pages
  d'accueil et de choix de la riwaya de l'onboarding défilent quand elles ne tiennent plus, et un
  libellé de bouton trop long rétrécit plutôt que d'être coupé. Les pastilles de numéro et de
  date de révision rétrécissent aussi pour tenir (« 282 » reste entier). Des libellés côte à côte
  (modes du Quiz, « Tout sélectionner » / « Confirmer ») rétrécissent ensemble, à la même taille.
  Une plage de versets (« v.1–10 ») ne se coupe jamais au tiret.
- **Aucun italique** : la police n'en a pas, et des lettres penchées artificiellement se lisent
  mal. Citations, indications et légendes s'affichent droites.
- **Une couleur, un sens.** Les badges de date de révision du plan du jour et du Récap sont
  neutres (texte secondaire, sans couleur) quel que soit le niveau. Seuls les niveaux de jeu
  (quatre teintes froides du vert au bleu nuit, un gris pour « pas encore jouée ») et le risque
  d'oublier (orange, qui lui est réservé) porteront un sens par la couleur ; ces couleurs sont
  définies une fois, en clair et en sombre, et ne sont pas encore affichées.
- **Lisibilité** : en clair comme en sombre, le texte atteint un contraste de 4,5:1 sur le fond et
  sur les cartes, les teintes de niveau et l'orange 3:1.
- **Aucun emoji** comme illustration, y compris dans les titres de notification.
- L'effet fort est réservé aux **moments rares** (jalons) ; la clôture quotidienne reste courte ;
  le reste est de la finition diffuse. Check-in et check-out partagent le même langage (en-tête,
  navigation retour/suivant, transition entre étapes).
- Les trois couches se nomment **en clair** : aucun terme traditionnel arabe dans l'interface
  (sabaq, sabqi, manzil, wird), aucune personnification d'un enseignant. L'app ne corrige ni la
  récitation ni le tajwid.

**Ne fait pas** : pas de sélecteur de thème (l'app suit le réglage de l'appareil), pas de couleurs
de tajwid.
