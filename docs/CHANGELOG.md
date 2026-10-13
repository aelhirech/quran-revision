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
- **Portion de la vue Coran (US-11, US-18 — 2026-10-13)** : la portion vit dans le `State` de
  `VerseBottomSheet` (`_portion`, jamais persistée), parce que le curseur et la liste de versets
  doivent lire le même état. `VerseAudioBar` la reçoit par `portion`/`onPortionChanged`.
  - **Ne jamais relire `widget.portion` dans la barre au moment d'un geste** : un ±1 appelle
    `onChanged` puis `onChangeEnd` avant tout rebuild, `widget.portion` y vaut encore l'ancienne
    portion. `_startLoop`, `_playsPortion` et `_followPortionIfPlaying` la prennent en argument.
    Après un démarrage, le rattrapage relit `widget.portion` **après la frame**
    (`addPostFrameCallback`), pour la même raison.
  - La boucle en cours est portée par le handler, `QuranAudioHandler.currentLoop` (récitateur,
    sourate, début, fin — `null` après `stop`), jamais recopiée dans la barre : une boucle
    « appartient » à la vue si même récitateur, même sourate et plage incluse dans la plage
    affichée, ce qui reconnaît une sous-portion après réouverture.
  - La boucle ne suit un changement de portion que si **cette** boucle joue, et jamais après un
    démarrage raté : relancer une requête injouable (hors ligne + récitateur non téléchargé)
    bouclait sans fin, bug trouvé en `/code-review`. Relance au relâché du curseur ou au ±1
    seulement, jamais à chaque pixel (`playLoop` remplace toute la playlist). Le texte, lui, suit
    en direct.
  - L'en-tête garde la plage d'origine. Aucun verset de contexte n'est affiché (retiré par US-18).
- **`QuranAudioHandler.playLoop` n'attend jamais `_player.play()` (2026-09-29)** : dans
  `just_audio`, ce `Future` ne se termine qu'à la pause/l'arrêt. L'attendre gardait `_starting`
  vrai pendant toute l'écoute (bouton bloqué sur le spinner, et `_followPortionIfPlaying` jamais
  exécuté). Son erreur est donc loguée dans le handler, plus remontée à la barre.
- **File de téléchargement audio (US-10 Sprint B, 2026-10-05)** :
  - La file (`AudioDownloadService.pending`, persistée par `AudioPrefs`) ne retient que les
    **demandes** (`'reciterId'` ou `'reciterId:surahId'`), jamais ce qui est stocké : le disque
    reste la seule vérité. Une demande ne sort de la file que quand tout est sur disque.
  - Une seule boucle tourne (`resumePending`). Un appel pendant qu'elle tourne programme un
    passage de plus, jamais une boucle parallèle : c'est ce qui relance une sourate coupée par
    l'arrière-plan iOS.
  - Pas de Wi-Fi ou disque plein arrêtent la file (`blockedBy`). Une sourate en échec réseau est
    sautée et gardée : un fichier manquant chez KSU ne doit pas bloquer tout le reste.
  - La règle réseau est revérifiée avant chaque verset téléchargé (pas une fois au départ).
  - Un verset n'est écrit que si la réponse est de type `audio/*` (2026-10-12) : un portail
    captif répond `200` avec du HTML. KSU sert `audio/mpeg` sur tous ses dossiers ; si ce type
    change un jour, tous les téléchargements seront sautés — regarder là en premier.
  - `deleteReciter` attend la fin du verset en cours avant d'effacer : effacer sous lui ferait
    échouer son renommage, lu comme « disque plein ».
  - Préférences audio (récitateur, file, données mobiles) : `AudioPrefs`, jamais
    `StorageService` (déjà au plafond de taille).

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

- **Cartes et pas d'étapes (US-15 Sprint B, 2026-10-01)** :
  - Le style des `Card` vient du `cardTheme` (`app_theme.dart`, marge nulle comprise). Ne pas
    le recopier widget par widget : une copie locale ne suit plus le thème quand il change.
    Une nouvelle carte `surfaceCard` + rayon 16 + `cardBorder` s'écrit `Card(...)`, jamais
    `Container(decoration: …)` (nettoyage du 2026-10-02 : 11 copies retirées). Si elle contient
    un `InkWell`, il va **dans** la `Card` : posé au-dessus, son onde est peinte sous le fond.
    Restent en `Container`, volontairement : les cartes `surfaceCardSolid` et
    `SouratesRecapCard` (rayon 20).
- **Clé de jour (2026-10-02)** : `dayKey(DateTime)` (`core/day_dates.dart`) est la seule façon
  d'écrire une date `YYYY-MM-DD` (format de `ayah_facts.date` et des préférences par jour).
  Ne pas réécrire `toIso8601String().substring(0, 10)` à la main.
  - Le check-in et le check-out passent d'une étape à l'autre par `StepFooter` et
    `StepTransition`. Une nouvelle étape dans l'un de ces deux écrans les réutilise.
  - `PrimaryCtaButton` réduit un libellé trop long au lieu de le couper, et n'a plus d'ombre
    quand il est désactivé.

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

### [P2] US-19 — Traduction sous les versets dans la vue Coran (Hafs)
**Prérequis : US-18 livrée.** Ce sprint réutilise le `State` de `VerseBottomSheet` et sa liste
filtrée par portion, et touche les mêmes fichiers. Un bouton de l'en-tête affiche sous chaque
verset sa traduction dans la langue de l'app, en Hafs seulement. Voir
`docs/DOCUMENTATION_TECHNIQUE.md` §8.6.
- **Assets** (`assets/quran/translations/fr.hamidullah.txt`, `en.sahih.txt`) : téléchargés depuis
  `https://tanzil.net/trans/fr.hamidullah` et `https://tanzil.net/trans/en.sahih`, embarqués
  **sans aucune modification** (bloc de commentaires final compris), déclarés dans la section
  `assets:` de `pubspec.yaml`. Format : une ligne `sourate|verset|texte` par verset, 6236 lignes,
  fins de ligne CRLF.
- **`lib/services/translation_service.dart`** (nouveau, statique, sans état autre qu'un cache) :
  `static Future<void> load(String locale)` lit le fichier de la langue (`'fr'` → Hamidullah,
  `'en'` → Saheeh International) une seule fois, le découpe avec `LineSplitter`, ignore toute
  ligne qui ne commence pas par un chiffre et range chaque texte sous la clé `(sourate, verset)`.
  `static String? verse(String locale, int surahId, int ayahId)` renvoie le texte, ou `null` si
  la langue n'est pas chargée. Le service prend la langue en paramètre et n'importe pas
  `core/strings.dart`.
- **`lib/widgets/verse_row.dart`** : paramètre optionnel `String? translation`. Non nul, il
  s'affiche sous le texte arabe, aligné à gauche, 8 px plus bas, en 14 px, interligne 1,5, couleur
  `Theme.of(context).colorScheme.onSurfaceVariant`. Nul, le rendu est celui d'aujourd'hui.
- **`lib/widgets/verse_bottom_sheet.dart`** : le `State` porte `bool _showTranslation = false`.
  `_toggleTranslation()` : si la traduction est masquée, `await TranslationService.load(S.locale)`
  puis `if (!mounted) return;`, puis `setState` qui inverse le booléen. `itemBuilder` passe à
  `VerseRow` `translation: _showTranslation ? TranslationService.verse(S.locale, sourate.id,
  ayahId) : null`. Dans l'en-tête : un `IconButton` (`Icons.translate`, `isSelected:
  _showTranslation`, infobulle `S.masquerTraduction` ou `S.afficherTraduction`) posé en haut à
  droite par un `Stack`, pour que le titre reste centré, et construit seulement si
  `riwaya == Riwaya.hafs`. Sous la ligne « nom · plage », `Text(S.traductionSource)` en 11 px,
  même couleur, affiché seulement quand `_showTranslation` est vrai. **Aucun sliver ajouté** :
  l'ordre reste en-tête, `VerseAudioBar`, `GuideStep` conditionnel, liste.
- **`lib/core/strings.dart`** : `afficherTraduction` (« Afficher la traduction » / « Show
  translation »), `masquerTraduction` (« Masquer la traduction » / « Hide translation »),
  `traductionSource` (« Traduction : Muhammad Hamidullah · tanzil.net » / « Translation: Saheeh
  International · tanzil.net »).
- **Réutilisé tel quel** : `VerseService.getVerse`, la liste filtrée par `_portion` (un verset
  masqué n'est pas construit, sa traduction non plus), `S.locale`, le thème pour la couleur et la
  police. Ne pas passer par `QuranTextAsset` (JSON avec comptage, autre format).
- **Tests** :
  - `test/services/translation_service_test.dart` : après `HafsService.initialize()` et `load`
    des deux langues, pour chaque sourate de 1 à 114 et chaque verset de 1 à
    `HafsService.verseCounts[id]`, `verse` est non nul et non vide en `'fr'` et en `'en'` ;
    `verse('fr', 112, 1)` contient « Il est Allah, Unique » et `verse('en', 112, 1)` contient
    « He is Allah ».
  - `test/widgets/verse_bottom_sheet_test.dart`, traduction `'fr'` et `WarshService` préchargés
    dans `setUpAll` : (1) un appui sur `S.afficherTraduction` fait apparaître le texte français
    du verset 2 d'Al-Baqara et laisse la même instance d'état de `VerseAudioBar` ; (2) après deux
    `S.debutPlusUn`, ce texte n'est plus trouvé ; (3) un appui sur `S.masquerTraduction` retire
    toute traduction ; (4) avec un `AppState` en Warsh, `find.byTooltip(S.afficherTraduction)` ne
    trouve rien.
  - Sous Windows, en clair et en sombre, en français et en anglais, à 390×844 puis à 320×568 avec
    texte ×1,5 : le bouton ne chevauche pas le nom de la sourate, la traduction se lit comme
    secondaire, la ligne de source apparaît et disparaît avec elle, un long verset (Al-Baqara 282)
    reste lisible.
- **Exclus** : traduction en Warsh, mémorisation de l'affichage, choix de la traduction ou de sa
  langue, notes de bas de page, tafsir, translittération, mot à mot, traduction du nom de la
  sourate et du bismillah d'en-tête, traduction hors de la vue Coran, toute écriture dans
  `ayah_facts` ou `SharedPreferences`.
- **Doc** : `docs/DOCUMENTATION_TECHNIQUE.md` §6 (ligne `TranslationService`), §8.6 (bouton,
  état local, Hafs seulement), §10 (source Tanzil, condition d'usage non commercial, fichiers non
  couverts par la licence MIT du dépôt, mise à jour par nouveau téléchargement), §14 ;
  `test/CLAUDE.md` (deux lignes). Dans ce fichier, ajouter aux « Décisions actives » : traductions
  Tanzil embarquées sans modification, usage non commercial, à réexaminer avant toute version
  payante ou publicité. Passer US-19 à « terminée » puis l'archiver.

### [P2] US-20 Sprint A — Moteur des séries de l'onglet Renforcement
Premier des deux sprints d'US-20. Il livre le moteur pur et ses tests, sans rien d'affiché : le
Sprint B le branche sur l'onglet. Aucune écriture nulle part (`ayah_facts`, `SharedPreferences`).
Mesures du scoping dans `docs/USER_STORIES.md`, US-20.
- **`lib/core/reinforcement_engine.dart`** (nouveau, Dart pur, ~200 lignes) :
  - `class Passage` : `surahId`, `ayahId`, `index` (rang dans le verset), `words` (les tokens
    d'origine, signes compris), `startsVerse`, `endsVerse`, et le getter `text`
    (`words.join(' ')`).
  - `class SeriesQuestion` : `prompt`, `answer`, `choices` (2 à 4 `Passage`, mélangés, la bonne
    réponse une seule fois).
  - **Normalisation** (privée) d'un token : retirer
    `[ؐ-ًؚ-ٰٟۖ-ۭـ‏]`, remplacer U+0671 par U+0627.
    Un **mot** est un token qui garde au moins une lettre après ce retrait (le signe « ۞ » seul
    n'en est pas un). La **clé** d'un passage est la suite de ses mots normalisés, joints par une
    espace.
  - `static List<Passage> passagesOf(int surahId, int ayahId, String verse)` : le verset est
    découpé sur les espaces. 12 mots au plus : un seul passage. Au-delà : une coupe après chaque
    token qui porte un signe de pause (U+06D6, U+06D7, U+06D8, U+06DA), puis les morceaux voisins
    sont regroupés tant que le passage ne dépasse pas 12 mots. Un morceau sans signe de pause
    reste entier, même long : aucune coupe ailleurs qu'à un signe. Un token qui n'est pas un mot
    reste dans son passage sans être compté.
  - `static Map<int, Set<int>> carriedVerses({required List<SourateSelection> selections,
    required List<LearningProgress> learning})` : par sourate, l'union des plages
    `verseStart..verseEnd` des sélections et des `learnedVerses` des apprentissages **non
    complets**.
  - `static List<SeriesQuestion> buildSeries({required Map<int, Set<int>> carried, required
    String Function(int surahId, int ayahId) textOf, required Random random,
    Set<(int, int)> today = const {}, Set<(int, int, int)> avoid = const {}, int? surahId})` :
    1. **Chaîne** : pour chaque sourate de `carried`, les passages de ses versets portés, par
       verset croissant. « q suit p » : même verset et rang suivant, ou premier passage du verset
       `ayahId + 1` quand celui-ci est porté et que p termine le sien.
    2. **Question posable** (p → q) : q suit p, et la clé de p comme celle de q n'apparaissent
       qu'une fois parmi les passages portés de la sourate.
    3. **Tirage de 10 questions**, mélangées par `random`. Celles dont le passage posé
       `(surahId, ayahId, index)` est dans `avoid` passent après les autres. Sans `surahId` : 5 au
       plus parmi celles dont le verset posé est dans `today`, les autres parmi le reste ; si l'un
       des deux groupes manque, l'autre complète. Avec `surahId` : seulement les questions de
       cette sourate, `today` ignoré.
    4. **Mauvais choix**, 3 au plus, pris parmi les passages portés hors p et q, de clé
       différente de celle de q et différentes entre elles. À chaque tirage, les passages de même
       nature que q (`startsVerse` égal) sont préférés ; à défaut, n'importe lequel. Dans
       l'ordre : un passage **similaire** à q (mots normalisés en commun, divisés par la taille du
       plus grand des deux ensembles, ≥ 0,5) ; un **voisin** (même sourate, à 3 rangs au plus de q
       dans la chaîne) ; un passage d'une **autre sourate** ; puis, pour compléter, la même
       sourate, puis n'importe où.
    5. Une question sans aucun mauvais choix est écartée, et la suivante du tirage la remplace.
       Liste vide si rien n'est posable.
  - Les cinq seuils (10 questions, 5 du plan du jour, 12 mots, 0,5, 3 rangs) sont des constantes
    privées de ce fichier, pas d'`AppRules` : un seul lecteur.
- **`lib/state/app_state_reinforcement.dart`** (nouveau, `part of`, ~30 lignes) :
  `Future<({Map<int, Set<int>> carried, Set<(int, int)> today})> reinforcementInputs()`. Lance
  `learningProgressList()` et `dayUnits()` ensemble. `carried` vient de
  `ReinforcementEngine.carriedVerses`. `today` : les versets des unités du jour
  (`RevisionUnit.verses`) qui sont dans `carried`. Deux collections vides si `config == null`.
  Aucune écriture, aucun `_notify()`.
- **`lib/state/app_state.dart`** (334 lignes, au plafond) : une ligne `part` et l'import du
  moteur, rien d'autre.
- **Réutilisé tel quel** : `AppState.dayUnits`, `AppState.learningProgressList`,
  `RevisionUnit.verses`. Le texte arrive par le paramètre `textOf` : le moteur n'importe aucun
  service.
- **Tests** :
  - `test/core/reinforcement_engine_test.dart` (vrais textes Hafs et Warsh chargés en `setUpAll`,
    `Random` à graine fixe) :
    1. Pour chaque verset des deux riwayas, les tokens des passages recollés sont ceux du verset,
       et une coupe ne tombe qu'après un token portant un signe de pause.
    2. Hafs 2:255 donne 6 passages de 12, 7, 7, 6, 12 et 6 mots ; Hafs 94:5 en donne un seul.
    3. Sur les sourates 78 à 114 et 20 graines : q suit p ; 2 à 4 choix ; la bonne réponse une
       seule fois ; tout choix dans `carried` ; toutes les clés différentes.
    4. Sourate 109 seule : une seule question, 109:1 → 109:2. Sourate 55 seule : aucun passage
       posé ni attendu n'a la clé du verset 13 (le refrain, 31 occurrences).
    5. `carried = {2: 255..260}` : aucun verset hors de 255..260 dans aucune question, et le
       dernier passage de 260 n'est jamais posé.
    6. Sourates 93 à 95, `surahId: 94` : la question posée sur 94:4 propose 94:6 (seul passage
       similaire à 94:5, à 0,75).
    7. Sourates 78 à 114, `today` = les versets de la sourate 78 : exactement 5 questions posées
       dans la 78.
    8. Deux séries de suite sur les sourates 78 à 114, la seconde avec en `avoid` les passages
       posés de la première : aucun en commun.
    9. `carried = {108: {1, 2}}` : liste vide. `{108: {1, 2, 3}}` : des questions à 2 choix.
    10. Avec `surahId` : tous les passages posés sont dans cette sourate, des choix viennent
        d'ailleurs.
    11. `carriedVerses` : sélection 2:255–260, apprentissage en cours de la 67 avec {1, 2, 3},
        apprentissage complet de la 112 → `{2: 255..260, 67: {1, 2, 3}}`.
    12. Les invariants du test 3 tiennent sur une sélection Warsh.
  - `test/state/app_state_reinforcement_test.dart` (`initFfiTestDb`, `clearFactsBetweenTests`) :
    un verset proposé à l'apprentissage aujourd'hui et pas encore appris n'est ni dans `carried`
    ni dans `today` ; les versets du plan du jour sont dans `today`.
- **Exclus** : tout affichage, toute persistance, les paliers (US-21), les questions de mots
  (US-22), tout cache des passages entre deux séries.
- **Doc** : `docs/DOCUMENTATION_TECHNIQUE.md` §5 (nouvelle sous-section `ReinforcementEngine` :
  passage, question posable, mauvais choix, seuils), §7 (`reinforcementInputs`), §10 (les signes
  de pause dépendent de l'encodage QUL du texte), §11, §14 ; `test/CLAUDE.md` (deux lignes).
  US-20 passe à « en sprint ».

### [P2] US-20 Sprint B — Onglet Renforcement et écran de série
**Le Sprint A est livré** : ce sprint branche `ReinforcementEngine.buildSeries` et
`AppState.reinforcementInputs()` sur un quatrième onglet. Rien n'est persisté. Maquettes :
https://claude.ai/artifact/8Sym4Aq9X1M4s6gzrJi46k (direction 3).
- **`lib/screens/shell_screen.dart`** (141 lignes) : quatrième onglet en **2e position** (Plan du
  jour, Renforcement, Récap, Réglages), `ReinforcementTab` à l'index 1 de l'`IndexedStack`.
  Libellé `SReinforcement.onglet`. Icône : `Transform.rotate(angle: pi / 4, child:
  Icon(Icons.crop_square, size: 20))`, et `Icons.square` pour l'état sélectionné (le losange des
  marques de score). **Piège** : `didChangeDependencies` ouvre le Récap puis les Réglages après
  la première clôture par `_index = 1` et `_index = 2`. Ils deviennent 2 et 3, portés par deux
  constantes privées `_recapTab` et `_settingsTab`.
- **`lib/screens/reinforcement/reinforcement_tab.dart`** (nouveau, ~120 lignes,
  `StatefulWidget`) : `Scaffold`, `CustomScrollView` et `SliverAppBar.large(title:
  SReinforcement.onglet)`, comme le Récap. Une `Card` « Série du jour » (titre, ligne
  `SReinforcement.serieDuJourDesc`, `PrimaryCtaButton(SReinforcement.commencer)`), puis
  `OutlinedActionButton(icon: Icons.menu_book_outlined, label: SReinforcement.choisirSourate)`.
  Même spinner que le Récap quand `config == null`.
  - `_start({Sourate? sourate})` : `await state.reinforcementInputs()`, `if (!mounted) return;`,
    puis `ReinforcementEngine.buildSeries(carried: …, today: …, textOf: (s, a) =>
    VerseService.getVerse(s, a, riwaya: state.riwaya), random: Random(), avoid: _lastPrompts,
    surahId: sourate?.id)`. Liste vide : `_tooSmall = true`, et la carte affiche
    `SReinforcement.selectionTropPetite` sous le bouton. Sinon `_tooSmall = false`,
    `_lastPrompts` (`Set<(int, int, int)>`) est remplacé par les passages posés de cette série,
    et `SeriesScreen` est poussé comme le check-in (`Navigator.of(context, rootNavigator:
    true)`, `MaterialPageRoute(fullscreenDialog: true)`).
  - « Choisir une sourate » : `await state.reinforcementInputs()`, puis
    `showModalBottomSheet<Sourate>` avec `SouratePickerSheet(sourates: <celles de
    state.sourates dont l'id est une clé de carried>, title: SReinforcement.choisirSourate)`,
    puis `_start(sourate: picked)`.
- **`lib/screens/reinforcement/series_screen.dart`** (nouveau, ~220 lignes, `StatefulWidget`) :
  reçoit `List<SeriesQuestion> questions` et `String title` (`SReinforcement.serieDuJour` ou
  `SReinforcement.serieSur(nom)`). État local : `_index`, `_picked` (`Passage?`), `_held`
  (`List<bool>`).
  - **En-tête** : bouton fermer, `title` en capitales (le `TextStyle` de l'eyebrow de
    `CycleProgressCard`, en `palette.textMuted`), `SReinforcement.progression(n, total)`,
    `SeriesMarks`.
  - **Question**, dans `StepTransition(step: _index)` et un `SingleChildScrollView` :
    `SReinforcement.sourateVerset(nom, verset)`, le passage posé dans une `Card`
    (`ArabicVerseText`), `SReinforcement.quelleSuite`, puis une `PassageChoice` par choix.
  - **Points de suspension** : le passage posé est précédé de « … » s'il ne commence pas son
    verset. Tout passage, posé ou proposé, est suivi de « … » s'il ne termine pas son verset. Un
    choix n'est jamais précédé de « … ».
  - **Après un appui**, les choix se figent. Le bon choix prend une bordure `palette.gold` et un
    losange plein. Le choix appuyé, s'il est mauvais, prend une bordure `palette.textMuted`, un
    losange vide et la ligne `SReinforcement.passageDans(sourate, verset)`. Les autres passent à
    50 % d'opacité. Aucun usage de `palette.danger`. Dessous, une `Card`
    `SReinforcement.laSuite` : un seul `VerseRow` si les deux passages sont du même verset
    (passage posé puis suite), deux sinon ; puis `TextButton.icon(Icons.menu_book_outlined,
    SReinforcement.ouvrirTexte)` qui appelle `VerseBottomSheet.show(context, sourate,
    prompt.ayahId, answer.ayahId)`.
  - **Pied** : `PrimaryCtaButton(SCheckIn.suivant)`, inactif tant qu'aucun choix n'est appuyé.
  - **Fin de série** : `SReinforcement.progression(tenues, total)` en grand, `SeriesMarks`
    complète, `SReinforcement.finSerieNote`, `PrimaryCtaButton(SReinforcement.fermer)` qui fait
    `Navigator.pop`. Fermer en cours de série fait aussi `Navigator.pop`, sans confirmation.
- **`lib/screens/reinforcement/widgets/series_marks.dart`** (nouveau, ~45 lignes) :
  `SeriesMarks({required List<bool> held, required int total, int? current})`. Un carré de 8 px
  tourné de 45° par question : plein `palette.gold` si elle a tenu, bordure `palette.gold` si
  elle est ratée, bordure `palette.cardBorder` si elle est à venir. La question en cours est
  entourée en `palette.textPrimary`.
- **`lib/screens/reinforcement/widgets/passage_choice.dart`** (nouveau, ~60 lignes) : une `Card`
  avec l'`InkWell` **dedans** (décision active « Cartes »), `ArabicVerseText(fontSize: 20)`,
  `enum ChoiceState { idle, correct, pickedWrong, dimmed }` et `String? note`.
- **`lib/core/strings_reinforcement.dart`** (nouveau, `part of 'strings.dart'`, classe
  `SReinforcement`, français / anglais) :
  - `onglet` : « Renforcement » / « Strengthen »
  - `serieDuJour` : « Série du jour » / « Today's series »
  - `serieDuJourDesc` : « Des questions sur ce que tu portes. L'app choisit, tu réponds. » /
    « Questions on what you carry. The app picks, you answer. »
  - `commencer` : « Commencer » / « Start »
  - `choisirSourate` : « Choisir une sourate » / « Pick a surah »
  - `serieSur(nom)` : « Série sur $nom » / « Series on $nom »
  - `sourateVerset(nom, n)` : « $nom · verset $n » / « $nom · verse $n »
  - `quelleSuite` : « Quelle est la suite ? » / « What comes next? »
  - `progression(n, total)` : « $n sur $total » / « $n of $total »
  - `passageDans(sourate, n)` : « Ce passage est dans $sourate, verset $n. » / « This passage is
    in $sourate, verse $n. »
  - `laSuite` : « La suite, dans l'ordre » / « What follows, in order »
  - `ouvrirTexte` : « Ouvrir le texte » / « Open the text »
  - `finSerieNote` : « Ton tour de révision ne change pas : seule ta récitation le fait
    avancer. » / « Your revision round does not change: only your recitation moves it forward. »
  - `fermer` : « Fermer » / « Close »
  - `selectionTropPetite` : « Ta sélection est trop petite pour composer une série. Ajoute une
    sourate dans les Réglages. » / « Your selection is too small to build a series. Add a surah in
    Settings. »
- **`lib/core/strings.dart`** (308 lignes) : une ligne `part 'strings_reinforcement.dart';`.
- **Réutilisé tel quel** : `SouratePickerSheet`, `ArabicVerseText`, `VerseRow`,
  `VerseBottomSheet.show`, `PrimaryCtaButton`, `OutlinedActionButton`, `StepTransition`,
  `SCheckIn.suivant`, le `cardTheme`. `OrnamentalDivider` n'est pas modifié.
- **Tests** : aucun test automatisé (apparence, `test/CLAUDE.md`). Sous Windows, en clair et en
  sombre, en français et en anglais :
  - La barre à quatre onglets à 390×844, 360×640 et 320×568 : aucun libellé ne déborde. À 320,
    un libellé coupé par des points de suspension est toléré et ouvre un item P3 ; un débordement
    ne l'est pas.
  - Après une première clôture sur un profil neuf, le Récap puis les Réglages s'ouvrent toujours.
  - Une série sur les sourates 78 à 114 (passages courts), une sur Al-Baqara (passages longs,
    « … »), à 320×568 avec texte ×1,5 : tout défile, le bouton du pied reste atteignable.
  - Le bon choix et le mauvais choix se distinguent en sombre sans aucun rouge.
  - Une sélection réduite à Al-Kawthar 1 à 2 affiche le message « trop petite ».
  - Une série se lance en Warsh.
  - Le temps de `buildSeries` sur une sélection de 113 sourates, mesuré en debug et noté dans la
    doc. Au-delà de 500 ms, un item P2 est ouvert (garder les passages en mémoire entre deux
    séries) : pas d'optimisation dans ce sprint.
- **Exclus** : toute persistance (score, série faite aujourd'hui), les paliers et le retour des
  versets ratés (US-21), les questions de mots (US-22), une étape d'accompagnement guidé, un
  ajout à l'onboarding, le retour tactile, une explication de ce qui distingue deux passages
  proches, la reprise d'une série quittée, toute notification.
- **Doc** : `docs/DOCUMENTATION_TECHNIQUE.md` §8 « Structure générale » (quatre onglets, indices
  par constantes), nouvelle §8.7 (onglet et écran de série), §10 (`SReinforcement`), §14 (« 3
  onglets » devient 4, deux lignes ajoutées) ; `CLAUDE.md`, ligne « Milieu » de la forme de la
  journée (l'onglet Renforcement, à un moment choisi, s'ajoute à l'accès au texte) ;
  `docs/USER_STORIES.md`, Résumé business (« Il y 3 pages »). Dans ce fichier, ajouter aux
  « Décisions actives » : l'onglet Renforcement ne crédite rien et n'écrit rien ; un verset ne
  se coupe qu'aux signes de pause ; les onglets se désignent par constantes, pas par indices en
  dur. Passer US-20 à « terminée » puis l'archiver.

### [P2] US-22 Sprint C — Questions de mots et trois modes (français, Hafs)
**Les Sprints A et B d'US-20 sont livrés** : ce sprint ajoute les questions de mots et le choix
entre trois modes dans l'onglet Renforcement. Rien n'est persisté : le compte « N mots connus »
(US-22 crit. 4) se livre avec US-21. Mesures du scoping dans `docs/USER_STORIES.md`, US-22.
- **Asset `assets/quran/wbw/fr.coranmot.tsv`** (nouveau, ~1,7 Mo, UTF-8, fins de ligne LF,
  déclaré dans `pubspec.yaml`) : export de la table `allwords` du fichier `words.db` de
  `github.com/DrUsamaN/CoranMot` (branche `main`), une ligne par mot,
  `sura<TAB>ayah<TAB>word<TAB>fr`, triée par ces trois clés, 77 429 lignes. Les sens sont
  recopiés **sans aucune modification** (quatre gardent une espace de début ou de fin). Export :
  `select sura, ayah, word, fr from allwords order by sura, ayah, word`, lu par le module
  `sqlite3` de Python (`py -3` sur cette machine) et écrit ligne par ligne. Le script d'export
  n'entre pas dans le dépôt : la source n'a qu'un commit.
- **`lib/services/word_gloss_service.dart`** (nouveau, statique, ~40 lignes) :
  `static bool availableFor(String locale, Riwaya riwaya)` (vrai pour `'fr'` et `Riwaya.hafs`
  seulement) ; `static Future<void> load()` (lit l'asset une seule fois, `LineSplitter`, quatre
  champs séparés par une tabulation, rangés par `(sura, ayah)`) ;
  `static List<String>? glosses(int surahId, int ayahId)` (`null` si l'asset n'est pas chargé).
- **`lib/core/reinforcement_engine.dart`** : `SeriesQuestion` devient
  `sealed class SeriesQuestion`. La classe du Sprint A est renommée
  `PassageQuestion extends SeriesQuestion` (renommage mécanique dans le moteur, son test, l'onglet
  et l'écran de série). Le tirage de son étape 3 (part du plan du jour, `avoid`, `surahId`) est
  extrait en fonction privée, pour servir aussi aux mots. Une ligne `part`.
- **`lib/core/reinforcement_words.dart`** (nouveau, `part of 'reinforcement_engine.dart'`,
  ~130 lignes) :
  - `class WordChoice` : `surahId`, `ayahId`, `arabic` (le token d'origine), `gloss`.
  - `class WordQuestion extends SeriesQuestion` : `passage` (le passage qui contient le mot),
    `wordIndex` (rang du token dans `passage.words`), `answer`, `choices` (2 à 4 `WordChoice`,
    mélangés), `arabicToMeaning`.
  - `static List<WordQuestion> buildWordQuestions({carried, textOf, required List<String>?
    Function(int surahId, int ayahId) glossesOf, random, today, Set<(int, int, int)> avoid,
    surahId, int count = 10})` :
    1. **Mot posable** : dans un verset porté dont le nombre de mots égale le nombre de sens ; le
       token normalisé a au moins 3 lettres ; le sens, une fois retirés ses segments entre
       parenthèses ou crochets, garde au moins un mot de 3 lettres.
    2. **Tirage** : la règle des passages (au plus la moitié du plan du jour, `avoid` sur
       `(surahId, ayahId, rang du mot dans le verset)`, `surahId`). Un même mot arabe normalisé
       n'est posé qu'une fois par série.
    3. **Mauvais choix**, 3 au plus : d'autres mots posables portés, de la même sourate d'abord,
       d'ailleurs ensuite. Sont écartés : le même mot arabe normalisé que le mot posé ; un sens
       qui partage un mot de 4 lettres ou plus avec le bon sens (en minuscules, hors parenthèses
       et crochets) ; un sens déjà présent parmi les choix.
    4. `arabicToMeaning` est tiré au sort pour chaque question.
    5. Une question sans aucun mauvais choix est écartée.
  - `static List<SeriesQuestion> buildMixedSeries({… les mêmes paramètres, avec deux ensembles
    avoid distincts …})` : 5 `PassageQuestion` et 5 `WordQuestion`, mélangées. Si un type en
    fournit moins, l'autre complète jusqu'à 10.
- **`lib/screens/reinforcement/reinforcement_tab.dart`** : `enum SeriesMode { mix, passages,
  words }`, état local, `mix` par défaut, jamais persisté. Un `SegmentedButton<SeriesMode>` dans
  la carte « Série du jour », affiché seulement si `WordGlossService.availableFor(S.locale,
  state.riwaya)` ; sinon le mode est `passages` et l'onglet reste celui du Sprint B. `_start` :
  hors mode `passages`, `await WordGlossService.load()` puis `if (!mounted) return;`. Selon le
  mode : `buildSeries`, `buildWordQuestions` ou `buildMixedSeries`, avec
  `glossesOf: WordGlossService.glosses`. Les mots posés sont gardés dans un second ensemble
  `_lastWords`, séparé de `_lastPrompts` : les deux rangs ne désignent pas la même chose.
  « Choisir une sourate » suit le mode en cours.
- **`lib/screens/reinforcement/series_screen.dart`** : `switch` exhaustif sur `PassageQuestion` et
  `WordQuestion`.
  - **Arabe vers sens** : `SReinforcement.sourateVerset`, le passage dans une `Card` avec le mot
    en `palette.gold`, `SReinforcement.queVeutDire`, puis les sens en choix, tels quels.
  - **Sens vers arabe** : le sens en Lora 20 px, `SReinforcement.quelMot`, puis les mots arabes
    en choix. Le passage n'apparaît qu'après la réponse.
  - **Après un appui** : les mêmes états que pour un passage. Sous un mauvais choix, la ligne
    `'${choice.arabic} : ${choice.gloss}'`. Dessous, une `Card` : le passage avec le mot en or,
    le bon sens, la ligne `SReinforcement.sourceMots`, et le bouton `ouvrirTexte` qui ouvre
    `VerseBottomSheet.show(context, sourate, ayahId, ayahId)`.
- **`lib/screens/reinforcement/widgets/passage_choice.dart`** : paramètre `bool latin = false`
  (texte en Lora 15 px au lieu d'`ArabicVerseText`).
- **`lib/widgets/arabic_verse_text.dart`** (33 lignes) : paramètres optionnels
  `int? highlightWord` (rang d'un mot dans `text` découpé sur les espaces) et
  `Color? highlightColor`. Renseignés, le texte est rendu par `Text.rich` en trois `TextSpan` du
  même style. Absents, le rendu est celui d'aujourd'hui. L'écran de série décale le rang d'un
  cran quand le passage est précédé de « … ».
- **`lib/core/strings_reinforcement.dart`** : `modeMelange` (« Mélange » / « Mix »),
  `modeVersets` (« Versets » / « Verses »), `modeTraduction` (« Traduction » / « Meaning »),
  `queVeutDire` (« Que veut dire le mot en or ? » / « What does the golden word mean? »),
  `quelMot` (« Quel mot porte ce sens ? » / « Which word carries this meaning? »), `sourceMots`
  (« Sens : Dr Usama Nonnenmacher, CoranMot » / « Meanings: Dr Usama Nonnenmacher, CoranMot »).
- **Réutilisé tel quel** : `ReinforcementEngine.passagesOf` et sa normalisation,
  `SeriesMarks`, `SouratePickerSheet`, `VerseBottomSheet.show`, `AppState.reinforcementInputs`.
- **Tests** :
  - `test/services/word_gloss_service_test.dart` (vrai asset, `HafsService` chargé) : 77 429
    sens ; chaque verset Hafs en a ; leur nombre égale le nombre de mots du verset partout sauf
    dans exactement sept versets, 2:181, 8:6, 13:37, 15:7, 27:20, 36:22 et 37:130 ;
    `glosses(112, 1)` vaut `['Dis :', '« Il (est)', 'Allâh,', 'Un.']`.
  - `test/core/reinforcement_words_test.dart` (`Random` à graine fixe, sourates 78 à 114) : le mot
    posé a au moins 3 lettres ; 2 à 4 choix ; le bon sens une seule fois ; aucun choix ne porte
    le même mot arabe normalisé ; aucun ne partage un mot de 4 lettres ou plus avec le bon sens.
    Sourate 37 seule : aucun mot posé dans 37:130. Sur 20 graines, les deux sens de question
    apparaissent. `buildMixedSeries` : 5 `PassageQuestion` et 5 `WordQuestion` ; avec un
    `glossesOf` qui renvoie toujours `null`, 10 `PassageQuestion`.
  - Sous Windows, en clair et en sombre : le sélecteur à trois segments à 320×568 ; le mot en or
    lisible dans un passage ; un sens long (« Celui qui subsiste par lui-même et fait subsister
    tout. ») sur plusieurs lignes dans un choix ; en Warsh puis en anglais, aucun sélecteur.
- **Exclus** : le compte des mots connus et toute mémoire des réponses (US-21), la mémorisation
  du mode, l'anglais, Warsh, toute retouche ou tri du texte des sens, grammaire, racines,
  translittération, le mot à mot dans la vue Coran.
- **Doc** : `docs/DOCUMENTATION_TECHNIQUE.md` §5 (questions de mots, mot posable, mauvais choix),
  §6 (`WordGlossService`), §8.7 (modes, vue d'une question de mot), §10 (source CoranMot ; ses
  trois conditions : projet islamique, aucune modification, source citée ; fichier hors licence
  MIT du dépôt ; requête d'export), §11, §14 ; `test/CLAUDE.md` (deux lignes). Dans ce fichier,
  ajouter aux « Décisions actives » : les sens CoranMot ne sont jamais modifiés ni triés, et
  sept versets ne sont jamais interrogés. US-22 reste « en sprint » jusqu'au compte des mots
  connus.

### [P3] Page Intro de l'onboarding : débordement sur petit écran avec texte agrandi
Relevé au sprint US-17 (2026-10-12) en vérifiant sous Windows : à 320×568 avec texte ×1,5,
`_IntroPage` (`lib/screens/onboarding/steps/intro_page.dart`) déborde de 279 px en bas et son
bouton sort de l'écran. Elle est bâtie sur une `Column` avec des `Spacer`. Correctif : envelopper
cette `Column` dans `LayoutBuilder` → `SingleChildScrollView` → `ConstrainedBox(minHeight:
constraints.maxHeight)` → `IntrinsicHeight`, ce qui garde les `Spacer` (donc le centrage actuel)
quand la place suffit et fait défiler la page sinon. Textes, styles et animations inchangés.
Vérification sous Windows : à 320×568 texte ×1,5, plus de débordement et bouton atteignable en
défilant ; à 390×844, rendu identique à aujourd'hui. P3 : aucun effet à taille de texte normale.

### [P3] Hook de reprise d'arrière-plan logé dans `ShellScreen`, pas `AppState`
Relevé en `/code-review high` du sprint US-3 (2026-09-21, altitude). Le `WidgetsBindingObserver`
qui rejoue `ensureDayPlan()` au retour d'arrière-plan (US-3 crit. 5) — et depuis US-10 Sprint B
`AudioDownloadService.resumePending()` — vit dans `ShellScreen`. Un
futur écran racine qui ne descendrait pas de `ShellScreen` devrait dupliquer ce hook. Différé :
un seul écran racine existe aujourd'hui, centraliser dans `AppState` maintenant serait de la
généralisation anticipée pour un cas qui n'existe pas encore.

## Idées produit (non scopées)

Vision/features pas encore prêtes à l'implémentation — pas de priorité technique tant qu'elles n'ont pas été cadrées (`quran-blueprint` → user story dans `docs/USER_STORIES.md`, puis `quran-scoping` → item ci-dessus). Ne pas lancer à la volée.

- **SRS réel par verset** (score de difficulté depuis l'historique `ayah_facts`, aujourd'hui écrasé par `lastRevisionDatesPerVerse` qui ne garde que `MAX(date)`) — dépendait de `needsWork`, **retiré du code au sprint US-3** (2026-09-21) ; à rescoper sur un autre signal (ex. fréquence des décochages verset par verset) avant toute implémentation.
- **Coran en SQLite** (texte + word-by-word + tajweed) — débloquerait "tajweed coloré" ci-dessous, JOIN naturel avec `ayah_facts`. Garde-fou : ne pas migrer parce que "c'est plus propre", seulement si cette feature est réellement engagée. Les questions de mots (US-22, au Backlog) s'en passent : leurs données sont un asset texte.
- **Affichage tajweed coloré** — bloqué faute de données tajwid (QUL), voir Coran SQLite. Passera par `AppPalette`/tokens sémantiques, jamais de couleur en dur.
- **Timeline d'activité (heatmap) dans Profil/Récap** — chaque fait `ayah_facts` est déjà daté, gratuit en donnée.
- **Mode "versets à retravailler" en jeu à part** — mécanique de jeu à définir avant tout code.
- **Gamification narrative [H]** — vision long terme, direction artistique déjà validée (Mus'haf/Tahajjud), mécanique narrative encore à définir.
- **Versets revenus en révision → section "à réviser en dehors des prières", pas verset de contexte** (reformulation 2026-09-26 des items P2 "verset de contexte") : pour la révision, le contexte n'aide pas autant qu'à l'apprentissage (où il a été livré le 2026-09-26, puis retiré par US-18 le 2026-10-13) — l'idée retenue est plutôt de faire atterrir les versets revenus dans le bloc hors-prières existant (`OutsidePrayersBlock`) plutôt que de les représenter avec leur contexte. À passer par `quran-blueprint` avant scoping : reste à définir comment ça s'articule avec `distributeToRakaas`/`RevisionUnit.==` (règle D) et si ça remplace ou complète le banner `return_proof_seen` actuel.
- **Vue Coran : la barre saute quand on resserre la portion après avoir défilé** (relevé au
  sprint US-18, 2026-10-13, mesuré sous Windows) : feuille défilée de 140 px, portion resserrée
  de 50 à 2 versets, le contenu devient plus court que la position de défilement, Flutter recale
  et la barre descend de 140 px sous le doigt. Le glissé d'une poignée n'est pas gêné, un ±1
  répété peut tomber à côté du bouton. Il reste à choisir le comportement voulu (défilement figé
  pendant le réglage, retour en haut, autre) avant tout correctif.
- **Un seul style de titre en capitales (« eyebrow »)** (relevé au Sprint B d'US-15) : huit
  titres en capitales ont chacun leur taille et leur espacement (`check_in_screen.dart`,
  `check_out_sections.dart`, `day_closed_summary.dart`, `prayer_selector.dart`,
  `streak_card.dart`, `verse_chips_scaffold.dart`, `check_hero.dart`, `cycle_progress_card.dart`).
  Il reste à choisir le style commun avant d'écrire un widget ou un style de thème partagé.

---

## Convention de commit

```
feat(sprint-N): description
fix(sprint-N): corrections lié au commentaires utilisateurs
```
