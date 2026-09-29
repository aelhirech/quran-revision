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

### US-10 — Écoute hors connexion (extension d'US-9)
**État** : en sprint — blueprint + scoping du 2026-09-28. **Sprint A livré le 2026-09-29**
(téléchargement d'une sourate depuis la vue Coran, lecture locale, signal hors connexion —
crit. 1 partie sourate, 2, 4 et 6 ; vérification sur appareil réel encore à faire). Reste le
Sprint B dans le Backlog de `docs/CHANGELOG.md` (récitateur entier, Réglages, données mobiles,
reprise automatique — crit. 1 partie récitateur, 3, 5). Reprend l'Idée produit « Téléchargement local des récitations ». Rattachée à
l'epic audio d'US-9 (archivée, pas ressortie).

**Statement** : En tant qu'utilisateur qui écoute ses sourates en boucle, je veux pouvoir garder
sur mon téléphone l'audio d'une sourate ou d'un récitateur entier, afin de continuer à écouter
sans connexion (voyage, trajet, mosquée sans réseau).

**Limite assumée** : la story supprime la dépendance au réseau **au moment de l'écoute**, pas la
dépendance au site source. Le téléchargement lui-même passe toujours par lui.

**Critères d'acceptation** (haut niveau) :
1. Given la vue Coran ouverte sur une plage, When l'utilisateur demande à télécharger, Then c'est
   la **sourate entière** de cette plage qui est stockée, pour le récitateur actuellement choisi.
   Given l'écran Réglages, When il demande le récitateur entier, Then tout le Coran de ce
   récitateur (dans sa riwaya) est stocké.
2. Given une sourate stockée pour le récitateur choisi, When l'utilisateur lance l'écoute sans
   aucune connexion, Then la boucle joue normalement, avec le même comportement qu'en ligne
   (arrière-plan, écran verrouillé, contrôles US-9).
3. Given le réglage par défaut, When un téléchargement est demandé sur données mobiles, Then il
   attend le Wi-Fi. Un réglage permet d'autoriser explicitement les données mobiles. Un
   téléchargement interrompu (coupure, app fermée) reprend là où il s'est arrêté, sans tout
   recommencer ni laisser une sourate à moitié marquée « disponible ».
   _Ajusté au scoping (2026-09-28, validé par l'utilisateur)_ : le téléchargement avance **tant
   que l'app est au premier plan**. iOS suspend l'app peu après sa mise en arrière-plan, et un
   vrai téléchargement en fond demanderait une librairie dédiée, écartée. Il se met en pause en
   arrière-plan et reprend **automatiquement** au retour dans l'app ou au lancement suivant, en
   sautant les versets déjà complets.
4. Given une plage non stockée (ou stockée pour un autre récitateur), When l'utilisateur écoute
   en ligne, Then l'app streame comme aujourd'hui. When il est hors ligne, Then elle **signale
   clairement** que l'audio n'est pas disponible hors connexion (continuité d'US-9 crit. 5),
   jamais une boucle muette.
5. Given plusieurs récitateurs téléchargés au fil du temps, When l'utilisateur change de
   récitateur, Then l'audio des précédents est **conservé**. Réglages affiche une ligne par
   récitateur stocké (poids occupé, état prêt/en cours) avec un bouton pour le supprimer.
6. Given un téléchargement terminé ou en cours, Then rien ne change dans la progression : ni
   cycle, ni streak, ni plan du jour (l'audio reste purement passif, US-9 crit. 4).

**Exclusions explicites** :
- Pas de téléchargement automatique : il ne se déclenche que sur geste explicite. Choix
  utilisateur du 2026-09-28, pris en connaissance de cause même s'il s'écarte de la thèse « l'app
  décide ». Aucun geste de téléchargement dans le check-in ni dans le check-out.
- Pas d'écran de liste des 114 sourates à cocher. Une sourate se télécharge depuis la vue Coran,
  un récitateur entier depuis Réglages (maintient l'exclusion US-9 « pas d'écran audio
  indépendant »).
- Pas de suppression sourate par sourate, seulement par récitateur.
- Pas de détection de mise à jour d'un fichier côté source : un fichier téléchargé est
  considéré comme définitif.
- Pas de source audio alternative à KSU : c'est un autre sujet, à cadrer à part si KSU casse.

**Scoping technique** (2026-09-28) :
- **Poids mesuré** (HEAD sur les 286 fichiers d'Al-Baqara, ~8 % du mushaf) : environ 93 Mo, que
  ce soit chez Husary en 64 kbps ou chez Qatami en 128 kbps. Un récitateur entier pèse donc
  **environ 1,1 à 1,2 Go**, et sans doute ~2 Go en 192 kbps. Ce poids est annoncé dans une
  confirmation avant le téléchargement complet. Une sourate pèse de quelques centaines de Ko à
  ~95 Mo, sans confirmation.
- **Source de vérité « téléchargé » = le disque, rien d'autre.** Chaque verset est écrit en
  `.part` puis renommé : un `.mp3` présent est donc toujours complet. Une sourate est
  « disponible » quand son nombre de `.mp3` égale son nombre de versets. Pas de marqueur, pas de
  table, pas de flag SharedPreferences qui pourrait diverger du disque. Rien dans `ayah_facts`.
- **Seule persistance ajoutée** : l'**intention** en attente (liste des téléchargements demandés
  mais pas finis) et le réglage « données mobiles », dans `StorageService`, en préférences
  **globales** (pas scopées par riwaya : l'id d'un récitateur appartient déjà à une seule
  riwaya).
- **Dossier** : cache applicatif (`path_provider`), pas Application Support. Sur iOS, 1 Go dans
  Application Support part dans la sauvegarde iCloud de l'utilisateur. Le cache n'est pas
  sauvegardé mais peut être purgé par le système. Ce mode de dégradation est acceptable : un
  fichier purgé repasse en streaming, ou en signal hors connexion (crit. 4), et la sourate
  redevient « à télécharger ».
- **Plage à moitié stockée** : lecture fichier par fichier, local si présent, sinon réseau.
  `QuranAudioHandler.playLoop` prend déjà une liste d'URI, et un `file://` passe tel quel.
  **Hors ligne avec au moins un verset manquant** : signal, pas de lecture partielle.
- **Espace disque insuffisant** : le téléchargement s'arrête, l'intention reste en attente et la
  ligne Réglages affiche l'erreur. Pas de pré-vérification d'espace libre (pas d'API sans
  dépendance native).

---

## Archivées

Chaque story ci-dessous est **livrée et vérifiée par les tests automatisés + `flutter analyze`**, pas par un passage sur appareil réel : aucun device mobile n'est disponible sur cette machine (voir `docs/DOCUMENTATION_TECHNIQUE.md` §12). Une story archivée peut donc encore révéler un écart à l'usage — dans ce cas, ouvrir un item dans le Backlog de `docs/CHANGELOG.md` plutôt que de la ressortir d'ici.

### US-11 — Répéter en boucle une portion choisie (extension d'US-9)
**État** : terminée — sprint `feature/phase-24-sprint2-us11-audio-portion` (2026-09-29) :
`VerseRangeSlider` (curseur + ±1, partagé avec `VerseRangePicker`) et `VerseAudioBar` (barre audio
sortie de `VerseBottomSheet`, portion locale non persistée). Curseur/±1 vérifiés en preview web ;
**lecture sur portion et relance pendant l'écoute non vérifiées sur appareil réel** (audio
indisponible sur web). Écart assumé au scoping : la boucle ne suit la portion que si elle **joue**
(en pause, le prochain appui lance la nouvelle portion). Rattachée à l'epic audio d'US-9, comme US-10.

**Statement** : En tant qu'utilisateur qui mémorise ou consolide un passage, je veux pouvoir
restreindre la boucle audio à quelques versets précis de la plage affichée, afin de répéter
jusqu'à ce qu'ils tiennent sans réécouter toute la sourate.

**Lève une exclusion d'US-9** : « la plage écoutée est toujours celle déjà affichée, jamais un
choix de plage dédié à l'audio ». Levée assumée : le choix se fait **à l'intérieur** de la plage
déjà affichée, dans la même vue, jamais par un écran audio indépendant (celle-là tient toujours).

**Critères d'acceptation** (haut niveau) :
1. Given la vue Coran ouverte depuis **n'importe quelle surface** (Plan du jour, Récap, carte
   d'apprentissage), Then deux réglages « du verset … au verset … » sont visibles près du bouton
   boucle, **pré-remplis avec la plage affichée** : sans y toucher, la boucle se comporte
   exactement comme aujourd'hui (zéro geste ajouté pour l'usage actuel).
2. Given une plage affichée, When l'utilisateur ajuste début et fin, Then il ne peut choisir que
   des versets **à l'intérieur** de cette plage, et la fin ne peut jamais précéder le début.
3. Given une portion choisie, When il lance la boucle, Then seuls ces versets sont répétés, en
   boucle continue, avec tout le comportement d'US-9 (arrière-plan, écran verrouillé, contrôles)
   et d'US-10 (lecture locale si la sourate est téléchargée, signal clair sinon hors ligne).
4. **Fluidité** : Given une longue sourate (ex. Al-Baqara, 286 versets), When l'utilisateur règle
   la portion, Then il y arrive **au verset près en quelques gestes**, sans faire défiler une
   liste de toute la sourate ni quitter la vue. When il modifie la portion pendant une lecture,
   Then la boucle bascule sur la nouvelle portion sans avoir à arrêter/relancer.
5. Given la vue Coran refermée puis rouverte, Then la portion repart de la plage affichée (pas de
   mémorisation d'une portion d'une ouverture à l'autre).
6. Given une écoute sur une portion, Then rien ne change dans la progression (US-9 crit. 4).

**Exclusions explicites** :
- Pas de compteur de répétitions (« 5 fois chaque verset »), pas de pause entre répétitions, pas
  de vitesse de lecture : fonctions courantes des apps de mémorisation, écartées ici pour ne pas
  transformer la vue Coran en lecteur audio à réglages (thèse : ne pas redonner des décisions).
  À recadrer en blueprint si un vrai usage le réclame.
- Pas de choix hors de la plage affichée, pas d'autre sourate.
- Pas de sélection par toucher des versets dans le texte (écarté au profit des deux réglages,
  plus visibles — choix utilisateur du 2026-09-29).

**Note pour le scoping** (recherche UX 2026-09-29) : les apps de mémorisation (Memorize de
Greentech, Quran Loop, Hafiz Quran) exposent toutes un « verset début / verset fin ». Pour tenir
le crit. 4 sur 286 versets, un simple menu déroulant ne suffit pas (défilement long) ; piste à
évaluer : un curseur à deux poignées pour le réglage grossier + un ajustement ±1 au verset près.
Le choix du composant revient au scoping.

**Scoping technique** (2026-09-29) :
- **Fichiers UI** : `lib/widgets/verse_bottom_sheet.dart` (285 lignes : la barre audio en sort,
  voir ci-dessous) ; **nouveau** `lib/widgets/verse_audio_bar.dart` (récitateur, boucle,
  téléchargement, portion) ; **nouveau** `lib/widgets/verse_range_slider.dart` (extrait de
  `VerseRangePicker`) ; `lib/widgets/verse_range_picker.dart` (consomme le widget extrait) ;
  `lib/core/strings.dart`. Aucun appelant de `VerseBottomSheet.show` ne change : la portion
  s'applique partout par construction (crit. 1).
- **Réutilisation, pas de duplication** : `VerseRangePicker` a déjà un `RangeSlider` + libellés
  « v.X … N versets … v.Y » sur `1..sourate.verses`. On l'extrait en `VerseRangeSlider(min, max,
  values, onChanged, onChangeEnd)` avec un **±1 sur chaque borne**, utilisé par les deux. Le ±1
  profite aussi au check-in, au check-out et à l'onboarding. Les chips de découpe rapide restent
  propres au picker.
- **Variables** : état local du nouveau `_VerseAudioBarState` : `_audioStart`/`_audioEnd`
  initialisés à `ayahStart`/`ayahEnd` (crit. 5 : rien de persisté), plus `_reciter`,
  `_starting` et `_riwayaForReciter`, déplacés tels quels depuis `_VerseBottomSheetState`.
  `_mediaId` et `playableSources` utilisent la **portion**, pas la plage affichée. `contextAyah`
  reste hors audio (il n'est déjà pas dans `ayahStart..ayahEnd`).
- **`ayah_facts`** : aucune lecture ni écriture (crit. 6).
- **Décision data model** : état UI éphémère, local au widget. Ni `AppState`, ni
  `SharedPreferences`.
- **Crit. 4, précisé (même intention)** : `QuranAudioHandler.playLoop` remplace la playlist
  (`setAudioSources`). Changer la portion pendant une lecture relance donc la boucle
  **automatiquement**, au **relâché** du curseur (`onChangeEnd`) ou à chaque ±1, et jamais à
  chaque pixel de glisser. La coupure dure quelques centaines de ms, et l'utilisateur n'a aucun
  geste à faire. Si la nouvelle portion n'est pas jouable hors ligne (`playableSources == null`),
  le signal hors connexion s'affiche, la boucle continue sur l'ancienne portion et le curseur y
  revient.
- **Plage d'un seul verset** : le curseur est masqué, rien à choisir.
- **Risques** : aucun partage de fichier avec US-12 (qui ne touche que `learning_progress_card`
  côté callers, pas la feuille). Tests : l'état UI n'est pas testable en Dart pur. Test widget
  léger possible sur `VerseRangeSlider` (±1 bornés à min/max, fin ≥ début).

---

### US-12 — Recentrer l'apprentissage sur le check-out (Récap = suivi seulement)
**État** : terminée — sprint `feature/phase-24-sprint1-us12-learn-checkout` (2026-09-29) : `LearnSurahScreen` supprimé, carte du Récap en suivi seul, retrait du dernier bloc au check-out (`lastLearnedBlock`/`unlearnVerses`, écrit avant le hand-off, verrouillé par test). Vue du check-out non vérifiée sur appareil réel. Modifie le comportement livré par US-4 (archivée) : son critère 4 (annuler un verset marqué par erreur) change de lieu, voir crit. 3.

**Statement** : En tant qu'utilisateur qui apprend une sourate, je veux que le Récap me montre
simplement où j'en suis et que tout ce qui fait avancer (ou reculer) mon apprentissage passe par
la clôture de ma journée, afin de ne plus avoir un second écran d'apprentissage à comprendre.

**Pourquoi** : l'écran détaillé ouvert depuis la carte d'apprentissage du Récap (taille de bloc,
validation de versets, dôme, hadith) est une seconde porte d'entrée pour créditer des versets,
en dehors du check-out — elle redonne une décision que le rituel quotidien porte déjà.

**Critères d'acceptation** (haut niveau) :
1. Given une sourate en cours d'apprentissage dans le Récap, When l'utilisateur touche sa carte,
   Then **rien ne s'ouvre** : la carte est un suivi (nom, progression, prochain verset). L'écran
   d'apprentissage détaillé n'existe plus nulle part dans l'app.
2. Given cette carte, Then le texte reste accessible (icône livre → vue Coran, avec la boucle et
   la portion d'US-11), et le glisser pour **abandonner** la sourate est conservé.
3. Given le check-out, Then l'utilisateur peut, pour une sourate en apprentissage, **retirer les
   versets du jour et le dernier bloc appris les jours précédents** s'il constate qu'ils ne
   tiennent pas : ils redeviennent « à apprendre », et la sourate reste en cours d'apprentissage
   (jamais perdue — continuité US-4 crit. 4).
4. Given l'apprentissage d'une sourate, Then les versets ne sont crédités **qu'au check-out** ;
   quand le dernier verset y est validé, la sourate bascule en révision comme aujourd'hui.
5. Given un utilisateur qui avait des versets validés via l'ancien écran, Then sa progression est
   intacte après la mise à jour (rien à migrer, rien de perdu).

**Exclusions explicites** :
- Pas de remplacement de l'écran supprimé par un autre écran ou une feuille équivalente.
- Pas d'annulation au-delà du dernier bloc appris (pas de liste de tous les versets appris au
  check-out — choix du 2026-09-29, pour ne pas alourdir la clôture).
- La section « en cours d'apprentissage » du Récap reste ; seule la vue qui s'ouvrait au toucher
  disparaît.

**Scoping technique** (2026-09-29) :
- **Fichiers UI** : suppression de `lib/screens/learn_surah_screen.dart` et de
  `lib/widgets/verse_display_card.dart` (son seul appelant). `lib/screens/recap_screen.dart` :
  suppression de `_openSourate` et de l'import. Le hand-off qu'il déclenchait est déjà fait par
  `AppState.checkOut` (`app_state_checkout.dart`, `handOffLearnedSurahs`).
  `lib/widgets/learning_progress_card.dart` : suppression du paramètre `onTap` et du chevron ;
  l'icône livre et le glisser (`onDismiss`) restent. `lib/screens/check_out_screen.dart` (329
  lignes) et `check_out_sections.dart` (224 lignes) : la nouvelle section va dans
  `check_out_sections.dart`, et l'écran ne reçoit que l'état et l'appel.
- **Faux orphelins, à garder** : `DomeProgressCard` (`cycle_progress_card`), `hadith_data`
  (`home_screen`), `LearningProgress.nextBlock` (`app_state_learning`),
  `AyahFactsLearning.unlearnVerse` (réutilisé ici), `S.blocRange` et `S.versetN`.
  **Vrais orphelins, à supprimer** : `S.versetsParBloc` et `S.marquerBlocAppris` (FR/EN).
- **Variables** : `CheckOutScreen._lastBlock` (`List<int>`, chargé avec `_learnPlan`) et
  `_retiredFromLastBlock` (`Set<int>`, vide par défaut). Même convention que `_notLearned` :
  **coché = tient, décoché = retiré**.
- **`ayah_facts`** : **nouvelle requête** `AyahFactsLearning.lastLearnedBlock(surahId,
  beforeDate, riwaya)`. Elle renvoie les `ayah_id` des lignes `type='learn' AND reach=1` à la
  date `MAX(date) < beforeDate` pour cette sourate, triés. Le retrait appelle `unlearnVerse`
  (existant), qui repasse **toutes** les lignes datées du verset à `reach=0`, sans jamais les
  supprimer. Après un retrait, le « dernier bloc » suivant est donc le lot d'avant, ce qui est
  cohérent.
- **Décision data model** : dérivé par requête sur `ayah_facts`. Ni table, ni flag.
- **Crit. 3, précisé (même intention)** : la section ne concerne que **la sourate de la portion
  d'apprentissage de la journée clôturée** (`_learnPlan`). Pas de portion d'apprentissage ce
  jour-là, ou pas de bloc antérieur : pas de section. Le bloc se cherche avant `widget.date`,
  pas avant aujourd'hui, pour rester correct au check-out d'une journée en retard.
- **Crit. 4, ordre obligatoire** : les `unlearnVerse` du dernier bloc passent **avant**
  `state.checkOut(...)`, dans le même `Future.wait` que les `markLearnVerses`. Sinon
  `handOffLearnedSurahs` peut basculer en révision une sourate dont on vient de retirer un
  verset.
- **Aucune interaction avec le cycle** : `isDaySealed`/`last_sealed_date` ne regardent que les
  lignes `revise` et la date du jour, et le retrait ne touche que des lignes `learn` d'autres
  dates. `nextVerse` repart au plus petit verset non acquis, donc le verset retiré est
  reproposé en premier.
- **Tests** : `lastLearnedBlock` (plusieurs dates, `reach=0` ignoré, rien avant la date → vide),
  et un scénario « retirer un verset du dernier bloc puis compléter la sourate le même jour ne
  déclenche pas le hand-off ». `unlearnVerse` est déjà testé (`ayah_facts_service_test.dart`).

---


### US-9 — Écoute audio en boucle depuis la vue Coran
**État** : terminée — implémentée 2026-09-26 (`lib/services/quran_audio_handler.dart`,
`lib/core/reciters.dart`, bouton dans `VerseBottomSheet`). Critère 3 (verrouillage/arrière-plan)
codé (`audio_service` + config native iOS/Android) et **vérifié sur appareil réel le 2026-09-26**
(notification media, contrôles écran verrouillé, audio qui survit à la mise en arrière-plan —
retour utilisateur direct). Écart au scoping initial : le
sélecteur de récitateur vit dans `VerseBottomSheet` (feuille modale interne), pas dans
`lib/screens/profile_screen.dart` — plus simple, le critère 2 n'imposait pas cet emplacement.
Détail technique complet : `docs/DOCUMENTATION_TECHNIQUE.md` §6/§8.6bis.

**Statement** : En tant qu'utilisateur qui porte du Coran, je veux pouvoir déclencher l'écoute en
boucle de la plage de versets déjà affichée (au Plan du jour, au Récap ou à l'écran Apprendre), y
compris quand mon écran est verrouillé ou l'app en arrière-plan, afin de renforcer ma mémorisation
pendant un temps où je ne suis de toute façon pas activement en train de réviser.

**Critères d'acceptation** (haut niveau) :

1. Given la vue Coran ouverte depuis n'importe laquelle des trois surfaces existantes (Plan du
   jour, Récap, Apprendre), When l'utilisateur déclenche « écouter en boucle », Then l'audio joue
   exactement la plage de versets déjà affichée par cette vue, en boucle continue jusqu'à arrêt
   explicite — jamais un écran de sélection de contenu séparé (cohérent avec l'exclusion « pas de
   lecteur de Coran autonome » d'US-1).
2. Given la riwaya active de l'utilisateur (Hafs ou Warsh), When l'audio joue, Then la récitation
   correspond à cette riwaya ; l'utilisateur peut choisir son récitateur parmi ceux disponibles
   **pour cette riwaya seulement**, et ce choix est mémorisé d'une écoute à l'autre sans être
   redemandé à chaque lecture.
3. Given une lecture en cours, When l'utilisateur quitte la vue Coran, verrouille l'écran ou met
   l'app en arrière-plan, Then l'audio continue sans interruption, avec des contrôles de lecture
   basiques (lecture/pause/arrêt) accessibles depuis l'écran verrouillé/la notification système.
4. Given une écoute en cours ou terminée, Then aucun verset n'est jamais marqué comme fait/révisé
   par ce seul fait — l'écoute reste **purement passive** et ne modifie ni la progression du
   cycle, ni le streak, ni aucun état que seuls le check-in/check-out font aujourd'hui évoluer.
5. Given une plage ou un récitateur dont l'audio n'est pas disponible (verset hors couverture,
   pas de réseau), When l'utilisateur déclenche l'écoute, Then l'app le **signale clairement**
   plutôt que de boucler en silence sur un flux vide ou en échec.

**Exclusions explicites** :
- Pas d'écran de navigation/sélection audio indépendant de la vue Coran existante — la plage
  écoutée est toujours celle déjà affichée, jamais un choix de sourate/plage dédié à l'audio.
- Aucun crédit automatique dans `ayah_facts` déclenché par l'écoute (voir critère 4).
- Pas de récitateur cross-riwaya (un récitateur Hafs ne s'affiche pas comme option en Warsh).

---

### US-1 — Premier contact : comprendre la méthode, puis la vivre en réel
**État** : terminée — sprint C livré le 2026-09-21 (message « verset revenu » au Plan du jour via
`AppState.returningVersesContext` + étape guidée `return_proof_seen` dans `PlanScreen`). Le verset
de contexte a été livré côté apprentissage le 2026-09-26 (`VerseBottomSheet.contextAyah`) ; son
extension à la révision est une **Idée produit** de `docs/CHANGELOG.md` (à repasser par
`quran-blueprint`), pas un item de Backlog. Priorité d'origine : P1.

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
**État** : terminée — livrée 2026-09-21 (sprint US-3). Ajout manuel d'une sourate au check-in avec
choix de portion (crit. 1) ; retrait complet du flag « à retravailler », remplacé par un check-out
verset par verset unifié révision/apprentissage (crit. 3) ; infrastructure « verset revenu + verset
de contexte » posée dans `RevisionEngine`/`AppState` mais pas encore affichée — consommée par
US-1 sprint C (crit. 4) ; signal de jour non clôturé aussi au retour d'arrière-plan, pas seulement
au lancement à froid (crit. 5) ; notification minuit, et bug corrigé au passage : les rappels
matin/soir ignoraient silencieusement leur heure configurée depuis US-1 sprint B (crit. 6). Détail
technique dans `git log`/`docs/CHANGELOG.md`.

**Statement** : En tant qu'utilisateur, je veux confirmer le matin ce que je compte réviser
aujourd'hui puis confirmer le soir ce que j'ai réellement fait — avec un rappel matin et un rappel
le soir pour ne pas l'oublier même sans ouvrir l'app de moi-même —, afin que ma progression reflète
mon activité réelle plutôt qu'un plan simplement proposé et jamais vérifié.

**Critères d'acceptation** (haut niveau) :
1. Given un plan du jour proposé, When l'utilisateur fait son check-in, Then il peut ajuster ce
   qu'il compte réviser avant de s'engager, et cet engagement devient la référence de sa journée.
   Given qu'il ajoute manuellement une sourate en plus de la proposition, When il la choisit, Then
   il peut ensuite choisir la portion précise à réviser, plutôt que de se voir imposer la sourate
   entière.
2. Given une journée engagée, When l'utilisateur coche des versets/sourates comme faits au fil de
   ses prières, Then cette progression est visible immédiatement sans attendre le soir.
3. Given une journée en attente de clôture, When l'utilisateur fait son check-out, Then il
   confirme (ou corrige) verset par verset ce qui a été réellement fait, pour la révision comme
   pour l'apprentissage — un seul geste, décocher un verset, avec le même effet des deux côtés.
4. Given un verset décoché au check-out, When le plan du lendemain est calculé, Then ce verset y
   réapparaît accompagné du verset qui le précède immédiatement, affiché comme aide de contexte.
5. Given une journée jamais clôturée, When l'utilisateur revient dans l'app un jour plus tard (à
   froid ou depuis l'arrière-plan), Then l'app le lui signale et lui permet de la clôturer avant
   de continuer.
6. Given la permission de notification accordée, When les heures configurées arrivent, Then un
   rappel matin invite à faire le check-in et un rappel soir invite à faire le check-out ; Then une
   notification supplémentaire à heure fixe (minuit) invite aussi à clôturer la journée si elle ne
   l'est pas encore, jamais un scellement automatique.

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
