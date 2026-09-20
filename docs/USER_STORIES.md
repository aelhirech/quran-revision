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

### US-1 — Premier contact : comprendre la méthode, puis la vivre en réel [priorité: P1] [état: en sprint]

**Historique** : livrée en deux temps le 2026-09-13 (Phase 11 Sprint 1 : démo sur An-Nas/Al-Falaq/
Al-Ikhlas + aperçu réel + retrait de l'ancien tour guidé ; Sprint 2 : bannières contextuelles sur
les 4 points d'entrée), archivée terminée. **Rouverte le 2026-09-20** après usage : la démo sur
3 sourates fixes perd l'utilisateur au lieu de l'aider (contenu étranger à ce qu'il vient de
configurer, et légèrement condescendant pour qui porte plusieurs juz), et l'onboarding terminé le
laisse devant une app dont il ne comprend ni la valeur, ni la méthode, ni le bon usage. Blueprint
du 2026-09-20 : la simulation est supprimée au profit d'un accompagnement des **gestes réels**, et
l'app assume enfin une direction narrative explicite (voir `CLAUDE.md` § « Direction narrative »).

**Thèse produit adoptée à ce blueprint** : l'utilisateur arrive motivé, mais la motivation
fluctue — elle est la variable la moins fiable. La valeur de l'app n'est pas de motiver, c'est de
**faire disparaître la décision quotidienne** (quoi réviser, combien, est-ce que j'ai déjà fait
celle-là) qui suffit, un jour de faible énergie, à faire sauter la journée. Recevoir un objectif
atteignable décidé par un tiers légitime est en soi un moteur.

**Statement** : En tant que nouvel utilisateur qui porte déjà du Coran et peine à le réviser seul,
je veux comprendre dès le premier contact pourquoi ma mémorisation s'effrite et comment l'app
supprime la décision quotidienne qui me fait sauter des jours, puis être accompagné sur mes
**premiers gestes réels** plutôt que sur une simulation, afin de savoir m'en servir seul et de
faire confiance à sa méthode.

**Critères d'acceptation** (haut niveau) :

1. Given un premier lancement, When l'utilisateur traverse l'onboarding, Then il lui est expliqué
   que ce qu'il a mémorisé s'efface faute de **structure** et non faute de sincérité, puis que
   l'app décide à sa place la portion du jour selon trois couches — le nouveau, le récent encore
   fragile, l'ancien qu'on fait tourner — présentées comme la méthode employée par les hafiz
   depuis des générations.
2. Given le choix du rythme, When l'utilisateur fixe son nombre de pages par jour, Then l'app lui
   annonce la **durée d'un tour complet** de sa sélection, formulée aussi comme une garantie
   (« aucune de tes sourates ne restera plus de N jours sans être revue ») — jamais comme une date
   à laquelle il aurait « fini » de réviser.
3. Given l'onboarding, When l'utilisateur le termine, Then il n'a traversé **aucune démonstration
   sur un contenu qui n'est pas le sien** ; le dernier écran avant la fin lui montre son vrai plan
   du jour 1 et lui annonce la forme que prendra sa journée : s'engager le matin, réviser dans ses
   prières, clôturer le soir.
4. Given l'onboarding terminé, When l'utilisateur arrive dans l'app, Then il est invité à
   déclencher lui-même son premier check-in et accompagné pas à pas sur ce qu'il fait et pourquoi,
   jusqu'à savoir que le texte de chaque portion est accessible depuis son plan ; l'app y regarde
   **derrière** (ce qui est acquis, régularité déjà constituée) et jamais devant, pour ne pas
   réintroduire le poids du total au moment où l'objectif du jour doit paraître léger.
5. Given une journée engagée non clôturée, When l'utilisateur revient dans l'app — **qu'il ait reçu
   ou non la notification du soir** —, Then il est accompagné sur son premier check-out, où l'app
   regarde cette fois **devant** (durée du tour, échéance d'apprentissage) puisque l'effort est
   déjà dépensé ; le bouton de clôture reste toujours actionnable, et avant l'heure configurée
   l'app se contente de signaler que la journée n'est pas finie.
6. Given un premier check-out qui vient de se clore, When il est terminé, Then l'app fait
   découvrir le Récap puis les Réglages — au moment précis où le Récap contient exactement une
   journée et n'a jamais été aussi lisible — et les anciennes bannières passives de ces écrans
   n'existent plus.
7. Given des versets non validés la veille, When l'utilisateur consulte son plan le lendemain,
   Then l'app lui signale **une fois** que ces versets sont revenus seuls, accompagnés de celui
   qui les précède, et que son cycle a avancé sans qu'il ait rien eu à noter — c'est ce moment,
   et non l'onboarding, qui prouve la méthode. Given un moment accompagné interrompu avant son
   terme, When l'utilisateur y revient, Then l'accompagnement est toujours là : il n'est considéré
   comme donné que lorsque l'étape a réellement été menée à bout, jamais parce qu'un écran a été
   affiché une fois.

**Exclusions explicites** (chacune verrouille une décision prise au blueprint du 2026-09-20 —
à ne pas réintroduire de bonne foi dans un sprint futur) :

- **Aucun verrou horaire sur la clôture**, sous aucune forme. Un bouton bloqué ajoute de la
  friction à l'instant précis où l'utilisateur a enfin l'énergie d'agir, et il n'arrête que les
  honnêtes : celui qui voudrait cocher sans avoir révisé attendra l'heure et cochera pareil.
- **Pas de lecteur de Coran autonome.** Lire reste attaché à une unité du plan (comportement
  actuel) : un mushaf libre remettrait la décision dans les mains de l'utilisateur, c'est-à-dire
  exactement ce que l'app existe pour lui retirer.
- **Jamais « fini »/« terminé » à propos de la révision** — elle boucle par nature. Seul
  l'apprentissage a une vraie fin et peut porter une date.
- **Aucun terme traditionnel arabe dans l'interface** (sabaq, sabqi, manzil, wird) et **aucune
  personnification d'un enseignant** : les trois couches sont nommées en clair, et la légitimité
  tient en une phrase. L'app n'est pas un cheikh — elle ne corrige ni la récitation ni le tajwid.
- **L'échéance d'apprentissage est toujours conditionnelle** (« si tu tiens ce rythme »),
  recalculée en silence après une absence, jamais opposée à l'utilisateur (« tu as perdu X jours »).
- **Une sélection qui grandit allonge le tour** : cet allongement se présente comme une capacité
  (« tu portes maintenant plus »), jamais comme une régression — sinon l'app dissuade d'ajouter
  du Coran.
- **Pas de nouvelle statistique là où le streak existe déjà** : le manque n'est pas un indicateur
  de plus, c'est une phrase qui explique celui-ci au moment où il compte.
- La démo sur 3 sourates fixes est **supprimée, pas déplacée** — elle a déjà été repositionnée une
  fois (2026-09-13) sans que cela règle quoi que ce soit.

**Ajustements des critères d'acceptation** (scoping du 2026-09-20 — le blueprint n'est pas
remis en cause, seuls ces cas non prévus par le code sont précisés) :

- **Critère 2, unité de calcul** : la durée du tour se calcule sur les **entrées de cycle**
  (`DaySelection.cycleTotal`), pas sur les pages réelles dédoublonnées. Raison : le plan du jour
  consomme `pagesPerDay` *entrées*, et depuis le fix du 2026-09-08 une page-frontière coûte
  2 entrées pour 1 page physique. Compter en pages réelles promettrait un tour plus court que
  celui réellement parcouru — inacceptable pour un chiffre formulé comme une *garantie*.
- **Critère 3, clause de véracité** : « son vrai plan du jour 1 » signifie **le plan réellement
  identique à celui qu'il recevra au premier check-in, même graine de mélange**. Raison :
  `shuffleEnabled` vaut `true` par défaut et la graine dérive de `config.startDate`, aujourd'hui
  régénérée à chaque build de l'aperçu puis une nouvelle fois à la persistance — l'écran actuel
  « satisfait » le critère tout en affichant un ordre différent de la réalité.
- **Critère 3, cas limite ajouté** : Given une sélection dont aucune sourate n'a de métadonnée de
  page, When l'utilisateur atteint l'écran Jour 1, Then l'app le **signale** au lieu d'afficher
  une liste vide (règle `CLAUDE.md` §F, déjà appliquée à l'accueil).
- **Critère 3, conséquence structurelle** : l'écran « Récapitulatif » de l'onboarding est
  **supprimé** (fusionné dans l'écran Jour 1), décision utilisateur du 2026-09-20. Il occupait la
  place de « dernier écran avant la fin » sans rien apporter que la Célébration ne répète.
- **Critère 4, portée du « jamais devant »** : le check-in lui-même ne contient aucune projection.
  Le seul chiffre « devant » de ce moment est le `/ total` de `CycleProgressCard` sur
  `HomeScreen`. Décision utilisateur du 2026-09-20 : ce total **suit l'état de la journée** —
  masqué au repos avant engagement (moment check-in), visible dans l'état « journée clôturée »
  (moment check-out). La règle est par **état**, pas par écran.
- **Critère 5, aucun verrou à retirer** : vérifié dans le code, il n'existe **aucun** verrou
  horaire sur la clôture (les trois portes sont libres, `PlanScreen._completionButton` porte le
  commentaire « always active — 2026-09-07 »). Le critère n'exige que l'ajout du signalement. La
  garde `_sealing` de `CheckOutScreen` est un anti-double-tap, à conserver.
- **Critère 5, heure du soir** : aucune heure de rappel n'est configurable aujourd'hui
  (`scheduleMorning`/`scheduleEvening` ont leurs heures en dur, 7:00 / 20:30 ; aucun appelant ne
  les surcharge ; `settings_card.dart` n'expose qu'un booléen). **Décision utilisateur du
  2026-09-20 : rendre les heures configurables dans ce sprint**, bien que ce morceau appartienne
  à US-3 critère 6 — voir la note de coordination dans US-3.
- **Critère 7, dépendance dure** : conditionné à la livraison d'**US-3 critère 4**. Voir
  « Risques » ci-dessous.

**Scoping technique** (2026-09-20) :

*Découpage en 3 sprints, dans cet ordre* : **A** = onboarding (critères 1-3, livré 2026-09-20) ·
**B** = accompagnement (critères 4-6, livré 2026-09-20) · puis **US-3** · puis **C** = preuve du
lendemain (critère 7, bloqué par US-3 crit. 4).

**Fichiers UI concernés**
- *Sprint A* : `lib/screens/onboarding/onboarding_screen.dart`, `steps/intro_page.dart`,
  `steps/method_page.dart` (nouveau), `steps/rhythm_page.dart`, `steps/preview_page.dart`,
  `widgets/step_header.dart` ; **suppressions** : `steps/demo_page.dart`, `steps/recap_page.dart`.
- *Sprint B* : `lib/widgets/hook_banner.dart` → `lib/widgets/guide_step.dart`,
  `check_in_screen.dart`, `check_in_sections.dart`, `plan_screen.dart`,
  `widgets/prayer_plan_card.dart`, `check_out_screen.dart`, `shell_screen.dart`,
  `recap_screen.dart`, `profile_screen.dart`, `widgets/day_plan_tab.dart`, `home_screen.dart`,
  `widgets/settings_card.dart` (heures de rappel).
- *Transverse* : `lib/core/strings.dart`.

**Variables / champs concernés**
- Sprint A : `_OnboardingScreenState._selections`/`_pagesPerDay`/`_riwaya`/`_dayUnitsFor`,
  **nouveau** `late final DateTime _startDate` (corrige le bug de graine). Aucun champ ajouté à
  `UserConfig` ni à `AppState`.
- Sprint B : **nouveau** `AppState._guideDone` (`Set<String>`, corps de la classe comme
  `_hasSeenTour` — une `extension` ne peut pas porter de champ), getter **synchrone**
  `guideDone(String)`, `markGuideDone(String)` ; **nouvelles** heures de rappel (matin/soir)
  persistées ; **supprimés** : `AppState.hasSeenHook`/`markHookSeen`,
  `StorageService.hasSeenHook`/`setHookSeen`, `HookVisibilityMixin`.
- Getters existants à réutiliser, jamais à réécrire : `AppState.pagesProgress` → `({pos, total})`,
  `AppState.daySelection`, `AyahFactsService.currentStreak`, `AyahFactsService.totalActiveDays`,
  `AppState.learningInProgress()`.

**Table(s) / requête(s) `ayah_facts` concernée(s)** — **aucune, dans les deux sens.**
L'onboarding n'écrit aujourd'hui aucune ligne et ne doit toujours pas en écrire : la première
écriture reste `ensureDayPlan` après bascule vers `ShellScreen`. Le calcul de l'aperçu passe par
`RevisionEngine.buildDayUnits`/`buildCycle`, Dart pur de `lib/core/`, zéro I/O. Invariant à
préserver tel quel.

**Décision data model** — deux données nouvelles, aucune ne justifie `ayah_facts` :
1. *Durée du tour / échéance d'apprentissage* : **rien à persister**, calculs purs dérivés à la
   volée. `DaySelection.cycleDays(int pagesPerDay)` dans `lib/core/revision_engine.dart` (un seul
   helper, deux appelants : onboarding et check-out — ne jamais en écrire un second) et
   `LearningProgress.daysToFinish(int versesPerDay)`. Dérivée à la volée, l'échéance est
   « recalculée en silence après une absence » par construction, sans une ligne de code pour ça.
2. *État d'accompagnement* : ni un fait de révision (`ayah_facts` écarté — ce n'est pas un verset
   daté, l'y mettre imposerait une ligne sentinelle **interdite**), ni un paramètre de calcul du
   plan (`UserConfig` écarté — préfixé par riwaya, et toute écriture passe par les gardes de
   `saveConfig` qui remettraient `cyclePosition` à 0), ni éphémère (doit survivre au kill).
   → **une clé `SharedPreferences` `guide_done` (`StringList`)**, globale, servie par le
   mécanisme `hasSeenHook`/`setHookSeen` existant **étendu et renommé**, chargée une fois au boot
   dans un `Set<String>` pour être lisible en **synchrone** dans `build` (sinon l'écran flashe
   l'état « pas guidé »). Idem pour les heures de rappel : clés `SharedPreferences` dédiées,
   **globales et hors `_loadTrackState`** — un réglage de notification n'est pas par riwaya.

**La règle qui porte tout le critère 7** : une étape n'est marquée donnée que par le **callback du
geste réel**, jamais par l'affichage ni par une fermeture. C'est précisément le défaut du
mécanisme actuel (`dismissHook()` écrit le flag au tap sur la croix). Corollaire de design qui
rend la règle tenable : **l'étape guidée n'a pas de croix** — elle porte un bouton d'action.
Ids et déclencheurs : `checkin_done` (pop de `CheckInScreen` avec prières non vides) ·
`verses_reachable` (ouverture effective de `VerseBottomSheet` depuis une rakaa) · `checkout_done`
(retour de `AppState.checkOut`) · `recap_seen` · `settings_seen` · `return_proof_seen`.
**Nouveaux ids, jamais les anciens** (`check_in`/`check_out`/`recap`/`profile`) : un utilisateur
qui a fermé l'ancienne bannière ne doit pas être privé du nouvel accompagnement. Les anciennes
clés `hook_seen_*` restent orphelines sur les appareils — inoffensif, pas de migration.

**Réutilisation (aucune dépendance externe, aucun nouveau mécanisme)**
- `HookBanner` (visuel carte or) est déjà le langage « bloc informatif » de l'app, identique à
  `PlanScreen._summaryBar` → conservé, renommé `GuideStep`, `onDismiss` remplacé par une action.
- **L'accès au texte depuis le plan existe déjà** (icône livre de `PrayerPlanCard` →
  `VerseBottomSheet`) : le critère 4 ne demande **rien à construire**, seulement à le *désigner*.
- `CycleMilestoneDialog` est le patron « moment fort en modale », déjà déclenché au check-out.
- `pubspec.yaml` vérifié : aucun package de coach-mark/showcase, **ne pas en ajouter** — ces
  critères demandent une phrase au bon moment, pas un overlay à trou.

**Risques / dépendances**
1. **US-1 critère 7 dépend d'US-3 critère 4.** Aujourd'hui, décocher une unité laisse `reach=0`,
   `_completedPagesFor` s'arrête sur ce groupe et le lendemain repropose **la page entière** —
   pas les versets seuls, et sans verset de contexte. Livré avant US-3, le message affirmerait un
   comportement que le moteur n'a pas, au moment précis censé **prouver** la méthode.
2. **Bug de production préexistant, corrigé dans le sprint A** parce qu'il est la condition du
   critère 3 : la graine du mélange de l'aperçu diffère de celle réellement persistée → l'aperçu
   ment dès 2 sourates sélectionnées, depuis le 2026-09-13.
3. **Tailles de fichiers** : `lib/core/strings.dart` est **déjà à 415 lignes** (plafond 300-350) et
   passera à ~450 ; `plan_screen.dart` est **déjà à 357**. Poser tout contenu guidé dans
   `lib/widgets/guide_step.dart`, jamais comme méthode privée de plus dans un écran. Découpage de
   `strings.dart` inscrit au Backlog comme item séparé.
4. **Aucun test n'existe sur les écrans** (`test/` ne couvre que `core/` et `models/`). Les deux
   calculs neufs sont purs : les verrouiller par test est le seul filet possible, et il est
   bon marché.
5. `docs/DOCUMENTATION_TECHNIQUE.md` §8.1 décrit un **tour guidé interactif à 4 étapes avec
   spotlight qui n'existe plus** (vérifié : aucun `TourKeys`, aucun spotlight ; `hasSeenTour` ne
   survit que comme proxy « onboarding terminé »). À corriger en même temps que les écrans
   d'onboarding.

---

### US-3 — Rituel quotidien check-in / check-out, avec ses rappels [priorité: P1] [état: à scoper]

**Historique** : livrée une première fois Phase 6 Sprint 2 (check-in/check-out) + Phase 9 Sprint 1
(rituel unique « Illuminer ma journée avec le Coran » + volet « j'ai fait plus que prévu »),
archivée terminée. **Rouverte le 2026-09-20** : le flag « à retravailler » (bookmark par verset,
indépendant du coché/décoché) est retiré et remplacé par une correction uniforme avec
l'apprentissage — décocher un verset le renvoie simplement au lendemain — plus une notification
à heure fixe (minuit) pour inviter à clôturer une journée non close, en plus des rappels
matin/soir existants. **Complétée le même jour** : ajouter manuellement une sourate au check-in ne
propose aujourd'hui que la sourate entière (asymétrie avec le check-out, qui permet déjà de choisir
une portion pour une sourate révisée en plus) — le check-in doit offrir le même choix de plage.

**Statement** : En tant qu'utilisateur, je veux confirmer le matin ce que je compte réviser
aujourd'hui puis confirmer le soir ce que j'ai réellement fait — avec un rappel matin et un rappel
le soir pour ne pas l'oublier même sans ouvrir l'app de moi-même —, afin que ma progression reflète
mon activité réelle plutôt qu'un plan simplement proposé et jamais vérifié.

**Critères d'acceptation** (haut niveau) :
1. Given un plan du jour proposé, When l'utilisateur fait son check-in, Then il peut ajuster ce
   qu'il compte réviser avant de s'engager, et cet engagement devient la référence de sa journée.
   Given qu'il ajoute manuellement une sourate en plus de la proposition, When il la choisit, Then
   il peut ensuite choisir la portion précise à réviser (comme au check-out pour une sourate faite
   en plus), plutôt que de se voir imposer la sourate entière.
2. Given une journée engagée, When l'utilisateur coche des versets/sourates comme faits au fil de
   ses prières, Then cette progression est visible immédiatement sans attendre le soir.
3. Given une journée en attente de clôture, When l'utilisateur fait son check-out, Then il
   confirme (ou corrige) verset par verset ce qui a été réellement fait, pour la révision comme
   pour l'apprentissage, et cette clôture est ce qui fait avancer son cycle de révision — pas le
   simple fait d'avoir coché quelque chose pendant la journée. **Remplace l'ancien mécanisme
   « à retravailler »** (bookmark séparé du coché/décoché, réservé jusqu'ici à la révision) : il
   n'existe plus qu'un seul geste — décocher un verset — que ce soit en révision ou en
   apprentissage, avec le même effet.
4. Given un verset décoché au check-out (révision ou apprentissage), When le plan du lendemain est
   calculé, Then ce verset y réapparaît accompagné du verset qui le précède immédiatement, affiché
   comme aide de contexte pour se remettre dans la récitation avant de le reprendre — comportement
   unifié entre révision et apprentissage.
5. Given une journée jamais clôturée, When l'utilisateur revient dans l'app un jour plus tard,
   Then l'app le lui signale et lui permet de la clôturer avant de continuer.
6. Given la permission de notification accordée, When les heures configurées arrivent, Then un
   rappel matin invite à faire le check-in et un rappel soir invite à faire le check-out, de façon
   récurrente ; Then une notification supplémentaire à heure fixe (minuit) invite aussi à clôturer
   la journée si elle ne l'est pas encore — l'app ne pouvant rien exécuter elle-même à cet instant
   précis sur mobile, ce n'est qu'une invitation de plus, jamais un scellement automatique et
   silencieux de la journée ; given la permission refusée ou révoquée, then leur absence ne bloque
   ni ne dégrade aucune autre fonctionnalité de l'app.

**Note de coordination (scoping US-1, 2026-09-20)** : le critère 6 ci-dessus parle d'« heures
configurées », or aucune heure de rappel n'est configurable aujourd'hui (`scheduleMorning`/
`scheduleEvening` ont leurs heures en dur, 7:00 / 20:30 ; `settings_card.dart` n'expose qu'un
booléen — l'archive d'US-8 qui les annonce livrées est fausse). **Rendre les heures matin/soir
configurables est repris par le sprint B d'US-1** (décision utilisateur du 2026-09-20, pour
débloquer le critère 5 d'US-1). US-3 ne doit donc scoper que ce qui reste : la notification
supplémentaire à minuit, et le branchement des rappels matin/soir sur les heures désormais
réglées. Ne pas réimplémenter le réglage lui-même.

**Exclusions explicites** : pas de scellement automatique de la journée à minuit (l'utilisateur
reste toujours celui qui confirme/corrige, voir critère 3) — seule une notification est ajoutée.
La granularité verset par verset remplace complètement l'ancienne case à cocher par sourate/
portion entière côté révision (décidé au blueprint, à confirmer au scoping selon ce que le code
permet sans réécriture disproportionnée). Le « verset d'avant » est un simple affichage d'aide,
il n'est jamais lui-même marqué comme fait/à refaire du seul fait d'être montré. Le choix de
portion à l'ajout manuel (critère 1) ne s'étend pas aux unités déjà proposées automatiquement par
le plan du jour — celles-ci restent « tout ou rien » (retrait complet via « × »), tranché au
blueprint du 2026-09-20.

**Scoping technique** : _(vide, à compléter par `quran-scoping`)_

---

## Archivées

Chaque story ci-dessous est **livrée et vérifiée par les tests automatisés + `flutter analyze`**, pas par un passage sur appareil réel : aucun device mobile n'est disponible sur cette machine (voir `docs/DOCUMENTATION_TECHNIQUE.md` §12). Une story archivée peut donc encore révéler un écart à l'usage — dans ce cas, ouvrir un item dans le Backlog de `docs/CHANGELOG.md` plutôt que de la ressortir d'ici.

### US-1 — Premier contact : comprendre la méthode, puis la vivre en réel
**État** : rouverte le 2026-09-20 — voir « Stories actives » en tête de fichier. Ce qui avait été
livré les Phase 11 Sprints 1 et 2 (démo sur An-Nas/Al-Falaq/Al-Ikhlas, bannières passives sur
Récap/Réglages) est **remplacé** par le nouveau blueprint, pas complété ; le détail de cette
livraison vit dans `git log`. L'ancien énoncé est retiré d'ici pour ne pas décrire comme acquis un
comportement que le prochain sprint supprime.

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
**État** : rouverte le 2026-09-20 — voir « Stories actives » en tête de fichier (retrait du flag
« à retravailler », uniformisation avec l'apprentissage, notification à minuit).

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
