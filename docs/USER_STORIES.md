# User Stories — Quran_revision

Cadrage business : alimenté par le skill `quran-blueprint` (statement + critères d'acceptation),

Plafond indicatif : ~15 stories actives, au niveau **epic** (un pan entier de l'app, pas une tâche d'implémentation)

Les critères d'acceptation sont volontairement de haut niveau (le comportement observable qui définit "cet epic marche"), pas une liste exhaustive d'écrans/étapes — le détail logique à ajouter /mettre à jour se construit au scoping technique, pas au blueprint.

**Principe de regroupement** : on rassemble au maximum une fonctionnalité secondaire dans l'epic qu'elle sert (ex. les rappels matin/soir n'existent que pour soutenir le rituel Illuminer ma journée avec le Coran/Cloturer ma journée, donc ils vivent dans la même story plutôt que d'avoir la leur ; le choix de riwaya est un réglage parmi d'autres, donc il vit dans la story « Personnalisation »). 
On ne split une fonctionnalité en story séparée que si elle porte assez de valeur business à elle seule pour mériter son propre suivi — c'est le cas du rituel check-in/check-out par rapport au calcul du plan lui-même, qui aurait pu rester une seule story mais dont la mécanique de confirmation quotidienne est un pilier du produit à part entière.

**Fichier maintenu à la main** (comme `docs/DOCUMENTATION_TECHNIQUE.md` et `docs/CHANGELOG.md`) : chaque story porte un **état** — `à scoper` → `en sprint` → `terminée`, et une story terminée descend dans « Archivées » avec le sprint qui l'a livrée, plutôt que de rester dans la liste active (règle `CLAUDE.md` du projet). La liste active peut légitimement être vide juste après un blueprint entièrement livré : le prochain « Début de blueprint » la remplit.

## Résumé business de l'app

Quran Revision est une app mobile (iOS/Android, + web pour prévisualisation uniquement) à utilisateur unique : tout est local sur l'appareil, avec un data model pour préparer le backend. Elle s'adresse à quelqu'un qui a déjà mémorisé (ou est en train de mémoriser) des sourates du Coran et qui veut les garder fraîches dans sa mémoire sans effort d'organisation manuelle.

Le cœur du produit est une boucle quotidienne : après que l'utilisateur est configuré  les sourates déjà apprises et à quel rythme il veut les réviser (rythme exprimé en pages, qui sert à pré-remplir une proposition par défaut bornée aux limites de sourate ou de page — le calcul interne fonctionne en versets). Chaque jour, via le bouton Illuminer ma journée avec le Coran, l'utilisateur confirme le rythme ou l'ajuste et confirme le nombre de versets qu'il souhaite apprendre aujourd'hui ainsi que les prières qu'il compte prier en tant qu'imam puis l'app propose les versets à réviser et les versets à apprendre et répartit automatiquement ce contenu dans les rakaas de ses prières individuelles du jour — la révision occupant les premières rakaas, l'apprentissage la dernière — pour transformer un temps déjà consacré à la prière en temps de révision actif. L'utilisateur confirme ce qui a réellement été fait il peut en avoir fait plus, ou moins dans ce cas il flag les versets à retravailler ou à continuer d'apprendre — c'est cette confirmation qui fait progresser son cycle de révision et d'apprentissage.

Autour de cette boucle, l'app entretient la motivation (streak de régularité, vue d'ensemble de progression) et alerte discrètement sur ce qui commence à s'effriter dans la mémoire (fraîcheur par verset, pas juste par sourate). L'app fonctionne dans les deux riwayas les plus courantes (Hafs et Warsh) comme deux parcours de mémorisation totalement indépendants, permet à l'utilisateur de défini heure de rappel matin et heure de rappel soir et s'adapte à la langue de l'utilisateur. Il y 3 pages, Plan du jour, recap, réglage

---

## Stories actives

_Aucune._ Le blueprint du 2026-09-06 a été entièrement livré par la Phase 9 Sprint 1 (2026-09-07). Le prochain « Début de blueprint » remplira cette section.

---

## Archivées

Chaque story ci-dessous est **livrée et vérifiée par les tests automatisés + `flutter analyze`**, pas par un passage sur appareil réel : aucun device mobile n'est disponible sur cette machine (voir `docs/DOCUMENTATION_TECHNIQUE.md` §12). Une story archivée peut donc encore révéler un écart à l'usage — dans ce cas, ouvrir un item dans le Backlog de `docs/CHANGELOG.md` plutôt que de la ressortir d'ici.

### US-1 — Premier lancement et prise en main de l'app
**État** : terminée — onboarding (langue, riwaya, sourates, rythme) déjà en place ; Phase 9 Sprint 1 ramène le tour guidé à 3 onglets et rend le démarrage d'un apprentissage accessible dès le check-in (critère 3).

**Statement** : En tant que nouvel utilisateur, je veux configurer mes préférences de base (langue, riwaya, sourates à réviser, rythme) et comprendre comment utiliser l'app au premier lancement, afin de pouvoir m'en servir seul dès la fin de l'onboarding, sans blocage ni confusion sur les gestes de base 

**Critères d'acceptation** (haut niveau) :
1. Given un premier lancement sans configuration existante, When l'utilisateur termine   l'onboarding, Then il dispose d'une configuration valide (langue, riwaya, sélection de   sourates, rythme) sans être jamais bloqué par une étape qu'il ne peut pas compléter. 
2. Given l'onboarding terminé, When l'utilisateur arrive sur l'écran d'accueil pour la première fois, Then un tour guidé lui présente les points d'entrée essentiels de l'app, et peut être ignoré à tout moment sans dégrader l'utilisabilité de l'app.
3. Given l'onboarding terminé (ou le tour ignoré), When l'utilisateur utilise l'app normalement, Then il peut immédiatement engager un plan du jour, faire un check-in puis un check-out, et démarrer l'apprentissage d'au moins une sourate.
4. Given une configuration déjà existante, When l'utilisateur relance l'app, Then ses préférences sont restaurées automatiquement sans repasser par l'onboarding.

---

### US-2 — Plan quotidien réparti dans la journées grâce aux prières
**État** : terminée — moteur pages/jour (Phase 8 Sprint 3) + répartition en rakaas ; Phase 9 Sprint 1 y ajoute la rakaa d'apprentissage en dernière position.

**Statement** : En tant qu'utilisateur, je veux qu'un plan de révision soit calculé automatiquement chaque jour à partir de ma sélection de sourates et de mon rythme (pages/jour), et réparti dans les rakaas de mes prières individuelles, afin de réviser sans avoir à décider moi-même quoi réviser ni comment le répartir.

**Critères d'acceptation** (haut niveau) :
1. Given une sélection de sourates et un rythme configurés, When un nouveau jour commence, Then l'app propose un plan du jour cohérent avec le budget de pages configuré, qui progresse dans le cycle de révision plutôt que de repartir de zéro chaque fois.
2. Given un plan du jour proposé, When l'utilisateur choisit les prières où il compte réviser, Then les unités du jour sont réparties dans les rakaas de ces prières sans jamais laisser de rakaa vide et sans répéter deux fois la même sourate dans une même prière si une alternative existe.
3. Given un cycle de révision en cours, When l'utilisateur termine une journée de révision, Then sa position dans le cycle avance, et le cycle reboucle proprement une fois toute la sélection couverte.
4. Given l'ordre aléatoire activé, When le plan du jour est calculé, Then l'ordre reste stable pour un même cycle (pas un tirage différent à chaque ouverture de l'app).

---

### US-3 — Rituel quotidien check-in / check-out, avec ses rappels
**État** : terminée — check-in/check-out (Phase 6 Sprint 2) + rappels matin/soir ; Phase 9 Sprint 1 en fait le rituel unique déclenché par « Illuminer ma journée avec le Coran » et ajoute le volet « j'ai fait plus que prévu ».

**Statement** : En tant qu'utilisateur, je veux confirmer le matin ce que je compte réviser
aujourd'hui puis confirmer le soir ce que j'ai réellement fait — avec un rappel matin et un rappel le soir pour ne pas l'oublier même sans ouvrir l'app de moi-même —, afin que ma progression reflète
mon activité réelle plutôt qu'un plan simplement proposé et jamais vérifié.

**Critères d'acceptation** (haut niveau) :
1. Given un plan du jour proposé, When l'utilisateur fait son check-in, Then il peut ajuster ce
   qu'il compte réviser avant de s'engager, et cet engagement devient la référence de sa journée.
2. Given une journée engagée, When l'utilisateur coche des versets/sourates comme faits au fil de
   ses prières, Then cette progression est visible immédiatement sans attendre le soir.
3. Given une journée en attente de clôture, When l'utilisateur fait son check-out, Then il
   confirme (ou corrige) ce qui a été réellement fait, peut signaler un passage « à retravailler »,
   et cette clôture est ce qui fait avancer son cycle de révision — pas le simple fait d'avoir
   coché quelque chose pendant la journée.
4. Given une journée jamais clôturée, When l'utilisateur revient dans l'app un jour plus tard,
   Then l'app le lui signale et lui permet de la clôturer avant de continuer.
5. Given la permission de notification accordée, When les heures configurées arrivent, Then un
   rappel matin invite à faire le check-in et un bilan soir invite à faire le check-out, de façon
   récurrente ; given la permission refusée ou révoquée, then leur absence ne bloque ni ne
   dégrade aucune autre fonctionnalité de l'app.


---

### US-4 — Apprentissage de nouvelles sourates 
**État** : terminée — Phase 9 Sprint 1 : choix de la sourate au check-in, versets récités dans la dernière rakaa, confirmation verset par verset au check-out, bascule automatique en révision une fois mémorisée, suivi verset par verset conservé dans Récap.

**Statement** : En tant qu'utilisateur qui n'a pas encore mémorisé une sourate, je veux pouvoir la
mémoriser verset par verset dans l'app et suivre ma progression, afin qu'elle rejoigne ensuite mon
cycle de révision une fois acquise.

**Critères d'acceptation** (haut niveau) :
1. Given une sourate pas encore démarrée, When l'utilisateur démarre son apprentissage, Then
   l'app garde une trace de ce démarrage même avant qu'aucun verset ne soit marqué acquis.
2. Given un apprentissage en cours, When l'utilisateur marque un verset comme mémorisé, Then sa
   progression sur cette sourate augmente visiblement, verset par verset.
3. Given une sourate entièrement mémorisée, When l'utilisateur consulte sa liste de sourates,
   Then elle apparaît comme acquise et peut rejoindre sa sélection de révision.
4. Given un verset marqué mémorisé par erreur, When l'utilisateur revient en arrière dessus, Then
   son statut redevient « visé » sans perdre la trace que cette sourate est en cours
   d'apprentissage.

---

### US-5 — Prise en compte de la fraîcheur de mémorisation
**État** : terminée — `FreshnessEngine` au grain verset (Phase 8 Sprint 1), badges + section « À prioriser » du check-in.

**Statement** : En tant qu'utilisateur, je veux voir en un coup d'œil quelles sourates (ou
portions de sourates) commencent à s'effriter dans ma mémoire faute de révision récente, afin de
savoir où porter mon attention au-delà du simple cycle automatique.

**Critères d'acceptation** (haut niveau) :
1. Given une sourate jamais révisée, When l'utilisateur la consulte, Then elle est signalée
   distinctement d'une sourate déjà travaillée.
2. Given une sourate révisée récemment dans son intégralité, When l'utilisateur la consulte, Then
   aucune alerte ne s'affiche.
3. Given une sourate partiellement révisée (certains versets récents, d'autres non), When
   l'utilisateur la consulte, Then l'app distingue ce cas d'une sourate uniformément fraîche ou
   uniformément ancienne.
4. Given une sourate non révisée depuis longtemps, When l'utilisateur consulte une vue
   « à prioriser », Then elle y apparaît pour orienter son attention.

---

### US-6 — Maintient de la Régularité et motivation
**État** : terminée — `StreakEngine` + jours de pause (Phase 6), affiché sur Plan du jour et Récap.

**Statement** : En tant qu'utilisateur, je veux voir depuis combien de jours consécutifs je suis
régulier dans ma révision, afin de rester motivé à maintenir cette régularité.

**Critères d'acceptation** (haut niveau) :
1. Given une activité de révision quotidienne, When l'utilisateur consulte l'app, Then son nombre
   de jours consécutifs actifs est visible et se met à jour après chaque journée clôturée.
2. Given un jour explicitement déclaré « pause », When ce jour est atteint, Then il n'interrompt
   pas la série en cours.
3. Given une interruption réelle (ni activité, ni pause déclarée), When l'utilisateur revient,
   Then sa série repart de zéro plutôt que de rester figée artificiellement.

---

### US-7 — Récapitulatif et vue d'ensemble de la progression
**État** : terminée — `RecapScreen` ; Phase 9 Sprint 1 y intègre l'apprentissage en cours (critère 1 du résumé business : une seule vue d'ensemble révision + apprentissage).

**Statement** : En tant qu'utilisateur, je veux une vue d'ensemble de ma progression (où j'en
suis dans mon apprentissage et ma révision, quelles sourates sont couvertes, avec quel niveau de fraîcheur), afin de comprendre mon avancement global.

**Critères d'acceptation** (haut niveau) :
1. Given un cycle de révision en cours, When l'utilisateur ouvre le récapitulatif, Then il voit sa
   position dans le cycle et l'étendue totale de sa sélection, cohérentes avec ce que le plan du
   jour lui a réellement fait réviser.
2. Given sa sélection de sourates, When l'utilisateur consulte le récapitulatif, Then chaque
   sourate affiche son niveau de fraîcheur (voir US-5) sans recalcul divergent d'un écran à
   l'autre de l'app.
3. Given une sourate du récapitulatif, When l'utilisateur veut la relire, Then il peut consulter
   son texte directement depuis cette vue.

---

### US-8 — Personnalisation et réglages
**État** : terminée — Réglages (langue, riwaya, sourates, rythme, heures de rappel, thème système) livrés avant ce sprint ; Phase 9 Sprint 1 renomme l'onglet « Profil » en « Réglages » et unifie le changement de rythme avec le check-in.

**Statement** : En tant qu'utilisateur, je veux pouvoir ajuster à tout moment ma langue, ma  riwaya (Hafs/Warsh), ma sélection de sourates, mon rythme de révision, mes heures de rappel, afin que l'app continue de correspondre à mes besoins après l'onboarding initial.

**Critères d'acceptation** (haut niveau) :
1. Given des réglages accessibles depuis le profil, When l'utilisateur change de langue ou de
   riwaya active, Then le changement prend effet immédiatement sans perte de sa progression.
2. Given deux riwayas pratiquées à des moments différents, When l'utilisateur bascule de l'une à
   l'autre, Then sa progression de chacune reste indépendante et n'est jamais mélangée ou
   traduite d'une riwaya vers l'autre ; given une riwaya indisponible sur l'appareil, then l'app
   le signale clairement plutôt que d'afficher un contenu incorrect.
3. Given une sélection de sourates, un rythme ou des heures de rappel existants, When
   l'utilisateur les modifie, Then le prochain plan calculé (et les prochains rappels) reflètent
   ce changement sans casser la cohérence du cycle en cours.
4. Given le thème système de l'appareil (clair/sombre), When l'utilisateur ouvre l'app, Then
   l'apparence suit ce thème sans réglage manuel supplémentaire.