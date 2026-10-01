# Changelog — Quran Revision App

> Backlog en attente + décisions encore actives utiles aux prochains sprints. L'historique détaillé des sprints livrés (features, bugs corrigés, refactors) vit dans `git log`, pas ici. Pour *comment* le code fonctionne aujourd'hui (architecture, moteurs métier, écrans), voir `docs/DOCUMENTATION_TECHNIQUE.md`. Pour le modèle de données `ayah_facts` et l'algorithme du plan quotidien (vocabulaire, invariants, cas limites), voir `CLAUDE.md` — ce fichier ne les reformule plus, seulement ce qui n'y est pas déjà couvert.

---

## Décisions actives à connaître

Ne garde que ce qui reste réellement à respecter en touchant ce code. Un choix produit fait puis défait, ou un bug déjà corrigé sans piège résiduel, vit dans `git log` — pas ici.

**Modèle de données**
- Migration SQLite 2026-08-30 (introduction d'`ayah_facts`) faite **sans backfill**, décision prise faute d'utilisateurs réels à l'époque. Ne pas reproduire sans redemander confirmation si l'app a de vrais utilisateurs au moment d'un futur changement de schéma.
- Profils élèves multi-utilisateurs (`StudentProfile`/`StudentService`/`StudentProfileBar`) supprimés en entier le 2026-09-01 sur retour utilisateur explicite (app mono-utilisateur). Ne pas réintroduire sans besoin confirmé.
- Le "fait" par défaut au check-out (`CheckOutScreen`) ne s'applique **qu'à cet écran** — jamais à `AyahFactsService.proposeUnits` ni à `PlanScreen`/`toggleTodayUnitReach`, qui doivent garder `reach=0` tant que rien n'a été coché en priant. Les confondre ferait afficher "déjà fait" avant même d'avoir prié.
- `todayClosed` a deux sources distinctes : `AyahFactsService.isDaySealed` (lignes `revise` réelles, seul garde-fou anti double-comptage du cycle) et `last_sealed_date` (`StorageService`, flag d'affichage uniquement pour les journées sans ligne à sceller — apprentissage seul, ou tout retiré au check-in). Ne jamais faire dépendre le comptage du cycle de la seconde.

**Cycle / `RevisionEngine`**
- Le mélange du cycle est un tri par clé stable par sourate (`_shuffleKey`), jamais un `List.shuffle` — insérer une sourate ne doit déplacer aucune autre (sinon pages sautées/reproposées pendant que `cyclePosition` reste en place). Verrouillé par test dans `revision_engine_test.dart`. Basculer le mélange on/off, en revanche, remet `cyclePosition` à 0 comme un changement de sélection.
- Ce qui ne tient pas dans les prières (règle D) est retourné par `distributeToRakaas` (`{plan, outside}`) — ne jamais redériver "hors prières" par différence d'ensembles dans `AppState` : `RevisionUnit.==` porte sur la plage de versets, donc une unité subdivisée n'est jamais égale à sa mère et fausse tout le calcul.
- Cocher une rakaa peut en cocher une autre automatiquement quand `_padCyclically` fait apparaître deux fois la même plage de versets dans la journée — `reach` est une vérité par verset/jour, pas par rakaa.
- Agréger plusieurs groupes de cycle se fait par **union** de pages, jamais par somme (deux groupes peuvent partager une page physique).
- **`pagesPerDay` compte des vraies pages du mushaf, pas des entrées de cycle (2026-09-26)** : avant cette date, le rythme quotidien prenait un nombre fixe d'*entrées* (`RevisionEngine.buildDayUnits`), pas toujours équivalent à une page réelle (fragment privé plus petit qu'une page, ou page frontière partagée par deux entrées consécutives) — l'onboarding annonçait « 1 page/jour » alors que ~0,7 page réelle était consommée en moyenne, contredisant l'accueil (« 85 pages ») qui, lui, comptait déjà en vraies pages via `DaySelection.realPages`. `RevisionEngine._takeEntriesForPages` (nouveau, partagé par `buildDayUnits` et `DaySelection.cycleDays`) prend maintenant des entrées jusqu'à couvrir AU MOINS `pagesPerDay` pages réelles distinctes — jamais une fraction d'entrée : un jour peut donc couvrir plus ou moins de pages que le budget exact (voir `CLAUDE.md` § Règle du plan quotidien, partie B, invariant 7). Ne jamais revenir à un décompte par entrées pour `pagesPerDay`/`cycleDays` — verrouillé par `test/core/revision_engine_test.dart` (groupe `DaySelection.cycleDays`).

**UI / lecture**
- **Verset de contexte à l'apprentissage (2026-09-26)** : `VerseBottomSheet` accepte un `contextAyah` optionnel — le verset `verseStart - 1`, affiché en tête de liste et atténué (`VerseRow.isContext`), jamais coché/compté/inclus dans la plage audio. `PrayerPlanCard` ne le passe que pour la rakaa d'apprentissage (`r.isLearning`) quand `verseStart > 1` — décision produit : apprendre un verset avec celui qui le précède aide la mémorisation, la révision n'en a pas besoin au même degré. Ne pas étendre à la révision sans repasser par blueprint (voir idée produit ci-dessous).

- **Portion audio (US-11, 2026-09-29)** : `VerseAudioBar` garde la portion en état local
  (`_portion`, jamais persistée). La boucle en cours est portée par le handler,
  `QuranAudioHandler.currentLoop` (récitateur, sourate, début, fin — `null` après `stop`), jamais
  recopiée dans la barre : une boucle « appartient » à la vue si même récitateur, même sourate et
  plage incluse dans la plage affichée, ce qui reconnaît une sous-portion après réouverture. La
  boucle ne suit un changement de portion que si **cette** boucle joue, et jamais
  après un démarrage raté : relancer une requête injouable (hors ligne + récitateur non
  téléchargé) bouclait sans fin, bug trouvé en `/code-review`. Relance au relâché du curseur ou au
  ±1 seulement, jamais à chaque pixel (`playLoop` remplace toute la playlist).
- **`QuranAudioHandler.playLoop` n'attend jamais `_player.play()` (2026-09-29)** : dans
  `just_audio`, ce `Future` ne se termine qu'à la pause/l'arrêt. L'attendre gardait `_starting`
  vrai pendant toute l'écoute (bouton bloqué sur le spinner, et `_followPortionIfPlaying` jamais
  exécuté). Son erreur est donc loguée dans le handler, plus remontée à la barre.

- **Clôture de journée (US-13/US-14, 2026-10-01)** :
  - `AppState.checkOut` renvoie un `SealOutcome` (`lib/models/day_close.dart`). C'est l'**unique**
    source des jalons : jamais un second calcul de « tour bouclé » ou de « sourate mémorisée »
    côté écran.
  - Le bilan de l'accueil (`dayRecap`) se relit toujours depuis `ayah_facts`, jamais mis en
    cache, sinon une clôture corrigée afficherait l'ancien bilan.
  - La transition de clôture est un état d'affichage de `DayPlanTab` (`_justClosedDate`, 4 s),
    pas d'`AppState`. Elle ne joue ni après un jalon, ni à la réouverture d'une journée déjà
    scellée.
- **Début de tour (US-15, 2026-10-01)** : `CycleProgressCard` affiche « Nouveau tour » et
  « N pages en garde » quand `pos == 0 && total > 0`, et cet affichage prime sur `showTotal`.
  Ce n'est pas une fuite de la règle US-1 crit. 4 : des pages en garde sont de l'acquis, pas le
  poids restant.

**Cadrage produit encore valide**
- « Prières où il est imam » = prières où c'est lui qui récite (seul ou en dirigeant) — un simple élargissement de libellé, pas un filtre d'exclusion ni une pondération de répartition.
- L'apprentissage n'a plus d'onglet dédié : la sourate à apprendre est choisie au check-in, récitée dans la **dernière rakaa** du plan, confirmée au check-out.
- Le hand-off "sourate mémorisée → révision" est automatique et passe par `AppState.addSelectionKeepingCycle`, **jamais** `saveConfig` (qui remettrait `cyclePosition` à 0).
- « Faire plus » (sourate en plus, verset en plus) fait avancer le cycle au-delà de la proposition du jour — mais seulement si l'utilisateur l'a explicitement déclaré ce jour-là ; le curseur reste ordonné, déclarer un groupe plus loin dans la rotation ne crédite pas ceux qui le précèdent.
- **Accompagnement guidé (`AppState.guideDone`/`markGuideDone`, US-1 sprint B, remplace l'ancien `hasSeenHook`/`HookBanner`)** : un id n'est marqué que par le callback du GESTE RÉEL qu'il accompagne (check-in validé, verset ouvert, check-out scellé, action du `GuideStep`) — jamais par le simple affichage d'une carte ni par une croix de fermeture. Toute nouvelle étape guidée doit suivre cette règle, pas réintroduire un dismiss passif.
- Heures de rappel matin/soir (`StorageService.loadMorningTime`/`loadEveningTime`) sont des préférences **globales**, jamais préfixées par riwaya et jamais rechargées dans `_loadTrackState` — un réglage de notification n'a rien à voir avec le parcours de révision actif.
- **`needs_work` retiré de tout le code applicatif (US-3, 2026-09-21)** : la colonne `ayah_facts.needs_work` reste dans le schéma SQLite (DEFAULT 0, jamais migrée/droppée sans utilisateurs réels) mais plus aucun code Dart ne l'écrit ni ne la lit — `AyahFactsRitual.setNeedsWork`/`lastRevisionFlags`, `AppState.setVerseNeedsWork`/`lastRevisionFlagsFor` et le toggle bookmark de `VerseBottomSheet` ont disparu. Le check-out est désormais **verset par verset** (`CheckOutRow`/`VerseToggleChips`, `Set<(int surahId, int ayahId)>`), plus par sourate/portion entière — un seul geste (décocher un verset précis) couvre révision et apprentissage. Ne jamais réintroduire de colonne/flag parallèle pour un besoin de correction fine : `reach` par verset suffit.

**Cycle / `RevisionEngine`**
- **Verset revenu + contexte (US-3 crit. 4, 2026-09-21)** : `RevisionEngine.contextVerseFor(surahId, ayahId, selections)` — pure, Dart — renvoie le verset `n-1` d'un verset donné **s'il reste dans la plage sélectionnée par l'utilisateur** (jamais hors plage, invariant E.3), `null` sinon. `AyahFactsRitual.returningVerses`/`AppState.returningVersesContext` identifient les versets laissés `reach=0` à un check-out **scellé** (`checked_out=1`) et redevenus candidats du plan du jour. Consommé par `PlanScreen` (US-1 sprint C, 2026-09-21) pour le message « ce verset est revenu seul », affiché une fois via l'étape guidée `return_proof_seen`.

**Infra / divers**
- `sqflite_common_ffi` est en dépendance de **prod**, pas dev-only : `main.dart` bascule dessus derrière `if (Platform.isWindows)`, une condition runtime que Dart ne tree-shake pas — léger surcoût de taille binaire mobile assumé pour pouvoir tester sur cette machine sans device.
- Fraîcheur par verset (2026-09-04) : seuils changés délibérément (30j remplace l'ancien badge 7j ; paliers `neverRevised`/`sixMonths`/`oneYear` remplacent le seuil unique 180j). Pas tranché à l'identique partout — à ajuster sur retour utilisateur, pas à traiter comme un bug.
- Tests `sqflite_common_ffi` : une seule `history.db` partagée par tous les tests d'un même fichier (`initFfiTestDb` isole les fichiers entre eux, pas les tests entre eux) — un test peut hériter d'un `checked_out` posé par le précédent. `clearFactsBetweenTests()` doit tourner en `setUp`, sans fermer la connexion (`openDatabase` renvoie l'instance en cache).
- **Notifications planifiées via `zonedSchedule` + fuseau réel de l'appareil (US-3 crit. 6, 2026-09-21)**, plus `periodicallyShow`. Bug corrigé au passage, présent depuis US-1 sprint B et invisible faute de test : `periodicallyShow` ignore purement `hour`/`minute`, les rappels se déclenchaient 24h après le dernier `enable()`/changement d'heure, jamais à l'heure configurée. Dépendances ajoutées : `timezone` (déjà transitive via `flutter_local_notifications`, rendue directe) + `flutter_timezone` (détection du fuseau IANA de l'appareil). `NotificationService._initializeTimeZone()` retombe explicitement sur `tz.UTC` si la détection échoue — `tz.local` est un champ `late` du package `timezone`, sans filet : le laisser non initialisé casserait silencieusement les 3 rappels pour toujours, pas seulement celui du jour.

---

## Backlog technique

Dette réelle et gaps prêts à l'implémentation — priorité qui reflète le risque/l'effort, pas l'enthousiasme produit. P1 = risque de correction (données/comportement), P2 = gap concret ou nettoyage rapide, P3 = différé délibérément (aucun bug connu) ou pure polish. Les idées produit non scopées vivent dans la section « Idées produit » plus bas, pas ici.

### [P2] US-10 Sprint B — Récitateur entier depuis Réglages, gestion du stockage, reprise automatique
Le Sprint A est livré (2026-09-29) : ce sprint réutilise `AudioDownloadService` et `downloadSurah`
tels que décrits dans `docs/DOCUMENTATION_TECHNIQUE.md` §6 (disque = source de vérité, retour
`DownloadFailure?`, progression via `current`).
- **`AudioDownloadService`** : `downloadReciter(reciter)` boucle sur les 114 sourates via
  `downloadSurah`, séquentiellement. File d'**intentions** en attente (`'reciterId'` pour un
  récitateur entier, `'reciterId:surahId'` pour une sourate), persistée via `StorageService`
  (`loadPendingAudioDownloads`/`savePendingAudioDownloads`, préférence globale, pas scopée par
  riwaya). Une intention est retirée seulement quand tout est sur disque. `resumePending()`
  relance la file, en respectant la règle réseau ; il est appelé au lancement (`main.dart`,
  après `QuranAudioHandler.initialize`) et au retour de l'arrière-plan (observateur existant de
  `ShellScreen`). `reciterDiskUsage(reciter)` additionne la taille des fichiers.
  `deleteReciter(reciter)` annule le téléchargement s'il est en cours, retire l'intention et
  supprime le dossier. Une `FileSystemException` (espace plein) arrête la file, garde
  l'intention et expose l'erreur dans la progression.
- **Règle réseau** : `StorageService.loadAllowMobileDownload`/`saveAllowMobileDownload`
  (globale, `false` par défaut). Si elle vaut `false` et que la connexion n'est pas le Wi-Fi,
  l'intention reste en attente (au lieu du refus immédiat du Sprint A) et repart au prochain
  `resumePending()`. Le bouton du Sprint A met alors en file au lieu d'afficher « Wi-Fi
  uniquement ». La règle est **revérifiée avant chaque verset** dans la boucle de
  `downloadSurah` (le Sprint A ne la vérifie qu'au départ : passer du Wi-Fi aux données
  mobiles en cours de route continue aujourd'hui sur données mobiles) — hors règle, la sourate
  s'arrête et son intention reste en attente.
- **Nouveau `lib/widgets/offline_audio_card.dart`** (pas dans `profile_screen.dart`, déjà à
  378 lignes : n'y ajouter que l'insertion de la carte) : l'interrupteur « autoriser les données
  mobiles » ; une ligne par récitateur ayant au moins un fichier sur disque (nom, poids,
  état prêt/en cours/en attente du Wi-Fi/espace insuffisant, bouton supprimer avec
  confirmation) ; une action « télécharger tout le Coran » pour le récitateur choisi dans la
  riwaya active, précédée d'une confirmation qui annonce **environ 1 à 2 Go** et la nécessité
  de garder l'app ouverte en Wi-Fi.
- **Tests** : la persistance de la file dans `StorageService` et `reciterDiskUsage` sur un
  dossier temporaire.
- **Exclus** : téléchargement en arrière-plan réel, suppression par sourate, détection de mise
  à jour côté KSU, pré-vérification de l'espace libre, geste de téléchargement dans le check-in
  ou le check-out.
- **Doc** : §6, §8.4 (Réglages), §8.6bis. Passer US-10 à « terminée » puis l'archiver.

### [P2] US-15 Sprint B — Check-in/check-out cohérents, et passe `critique` dans les deux thèmes
Le Sprint A est livré (2026-10-01).
- **Reliquat de vérification du Sprint A** : celui-ci n'a pu être vu qu'en thème sombre (changer
  le thème de Windows est un réglage système, hors de portée de Claude). Pendant la passe
  `critique` en clair, revoir aussi l'accueil (« Nouveau tour »), le Récap (rangée « Rythme ») et
  la dernière page de l'onboarding, jamais vue : son ornement qui se dessine en haut s'ajoute à
  celui sous le sous-titre, à garder ou retirer selon le rendu.
- **Nouveau `lib/widgets/step_footer.dart`** : le pied de page « retour + action principale »
  est extrait de `CheckInScreen` (l. ~299-340, `OutlinedActionButton` + `PrimaryCtaButton`).
  `CheckOutScreen` l'utilise pour l'étape 2 du rattrapage multi-jours, qui n'a pas de bouton
  retour aujourd'hui (`_step = 1`).
- **Transitions** : le contenu d'étape des deux écrans passe dans un même `AnimatedSwitcher`
  (fondu + léger glissement), défini une seule fois.
- **Lignes** : `UnitRow` et `CheckOutRow` ne fusionnent **pas** (décision §8.1bis maintenue,
  deux fonctions différentes). On aligne seulement le padding de `UnitRow` sur 14.
- **Doc** : marquer résolue la dette `DOCUMENTATION_TECHNIQUE.md` §8.5-14, puisque l'en-tête est
  déjà commun (`CheckHero`) et la navigation commune après ce sprint.
- **Passe `critique`** : appliquer à la main la grille d'impeccable aux 3 onglets, au check-in et
  au check-out, en clair et en sombre (`flutter run -d windows`).
  - Consigner le tableau « écran, problème, gravité, corrigé ou non » dans le message de commit.
  - Corriger tout ce qui est de gravité haute dans ce sprint.
  - Les gravités moyenne et basse vont au Backlog seulement si leur correction est entièrement
    tranchée, sinon en Idée produit.
- **Exclus** : refonte de la navigation et des flux, animation pendant les prières.
- **Fin** : passer US-15 à « terminée », puis l'archiver.

### [P3] Retour visuel du toucher invisible dans les feuilles « choisir une sourate/un récitateur »
Relevé le 2026-10-01 sous Windows, en thème sombre : 75 assertions de debug « ListTile
background color or ink splashes may be invisible ».
- **Où** : `SouratePickerSheet` (`lib/widgets/sourate_picker_sheet.dart`, ~l. 30) et
  `ReciterPickerSheet` (`lib/widgets/reciter_picker_sheet.dart`, ~l. 18) peignent leur fond dans
  un `Container(decoration: BoxDecoration(color: cs.surface, borderRadius: …top 24))`.
- **Effet** : leurs `ListTile` dessinent le surlignage et l'onde de toucher sur le `Material`
  ancêtre, qui se trouve **sous** ce fond. Le toucher d'une ligne n'a donc aucun retour visuel.
  Il n'y a pas de plantage en release, mais l'assertion inonde les logs de debug.
- **Fix** : dans les deux feuilles, remplacer le `Container` décoré par
  `Material(color: cs.surface, shape: const RoundedRectangleBorder(borderRadius:
  BorderRadius.vertical(top: Radius.circular(24))), clipBehavior: Clip.antiAlias, child: …)`.
  On garde la hauteur de `SouratePickerSheet` via un `SizedBox`.
- **Vérification** : `flutter run -d windows` en sombre. On ouvre le choix de sourate (ajout au
  check-in) et le choix de récitateur (vue Coran) : plus aucune assertion, et l'onde est visible
  au toucher.
- À regrouper avec **US-15 Sprint B** (passe `critique`, même vérification sous Windows). Sinon,
  c'est un mini sprint à part.

### [P3] Clé de jour `YYYY-MM-DD` recopiée inline une douzaine de fois
Relevé en `/simplify` du Sprint A d'US-15 (2026-10-01).
- **Où** : `DateTime(...).toIso8601String().substring(0, 10)` dans `core/streak_engine.dart`,
  `services/ayah_facts_ritual.dart`, `services/storage_service.dart`,
  `services/ayah_facts_service.dart` (`revisionPace`), `state/app_state.dart`,
  `widgets/history_card.dart`, `screens/day_plan_tab.dart` et `screens/check_in_screen.dart`.
  Côté tests, `_isoDate` est défini trois fois dans `test/state/`.
- **Fix** : ajouter `String dayKey(DateTime d)` dans `lib/core/day_dates.dart`, à côté de
  `daysAgo`, puis remplacer **toutes** les copies d'un coup, tests compris. Une migration
  partielle laisserait deux idiomes côte à côte.
- **Vérification** : `flutter test`, sans changement de comportement attendu.

### [P3] Hook de reprise d'arrière-plan logé dans `ShellScreen`, pas `AppState`
Relevé en `/code-review high` du sprint US-3 (2026-09-21, altitude). Le `WidgetsBindingObserver`
qui rejoue `ensureDayPlan()` au retour d'arrière-plan (US-3 crit. 5) vit dans `ShellScreen`. Un
futur écran racine qui ne descendrait pas de `ShellScreen` devrait dupliquer ce hook. Différé :
un seul écran racine existe aujourd'hui, centraliser dans `AppState` maintenant serait de la
généralisation anticipée pour un cas qui n'existe pas encore.

## Idées produit (non scopées)

Vision/features pas encore prêtes à l'implémentation — pas de priorité technique tant qu'elles n'ont pas été cadrées (`quran-blueprint` → user story dans `docs/USER_STORIES.md`, puis `quran-scoping` → item ci-dessus). Ne pas lancer à la volée.

- **SRS réel par verset** (score de difficulté depuis l'historique `ayah_facts`, aujourd'hui écrasé par `lastRevisionDatesPerVerse` qui ne garde que `MAX(date)`) — dépendait de `needsWork`, **retiré du code au sprint US-3** (2026-09-21) ; à rescoper sur un autre signal (ex. fréquence des décochages verset par verset) avant toute implémentation.
- **Coran en SQLite** (texte + word-by-word + tajweed) — débloquerait "jeu mot arabe → traduction" et "tajweed coloré" ci-dessous, JOIN naturel avec `ayah_facts`. Garde-fou : ne pas migrer parce que "c'est plus propre", seulement si une des deux features dépendantes est réellement engagée.
- **Jeu mot arabe → traduction** (Apprendre) — bloqué faute de données word-by-word (QUL), voir Coran SQLite.
- **Affichage tajweed coloré** — bloqué faute de données tajwid (QUL), voir Coran SQLite. Passera par `AppPalette`/tokens sémantiques, jamais de couleur en dur.
- **Timeline d'activité (heatmap) dans Profil/Récap** — chaque fait `ayah_facts` est déjà daté, gratuit en donnée.
- **Mode "versets à retravailler" en jeu à part** — mécanique de jeu à définir avant tout code.
- **Gamification narrative [H]** — vision long terme, direction artistique déjà validée (Mus'haf/Tahajjud), mécanique narrative encore à définir.
- **Versets revenus en révision → section "à réviser en dehors des prières", pas verset de contexte** (reformulation 2026-09-26 des items P2 "verset de contexte") : pour la révision, le contexte n'aide pas autant qu'à l'apprentissage (déjà traité, voir décision UI/lecture ci-dessus) — l'idée retenue est plutôt de faire atterrir les versets revenus dans le bloc hors-prières existant (`OutsidePrayersBlock`) plutôt que de les représenter avec leur contexte. À passer par `quran-blueprint` avant scoping : reste à définir comment ça s'articule avec `distributeToRakaas`/`RevisionUnit.==` (règle D) et si ça remplace ou complète le banner `return_proof_seen` actuel.

---

## Convention de commit

```
feat(sprint-N): description
fix(sprint-N): corrections lié au commentaires utilisateurs
```
