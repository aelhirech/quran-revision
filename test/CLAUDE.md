# test/ — notes pour Claude

## État actuel

Couverture réelle depuis Phase 9 (2026-09-08+), concentrée sur les moteurs et modèles les plus
sensibles. `widget_test.dart` reste un placeholder (`expect(true, isTrue)`). Deux vrais fichiers de
tests widget (`verse_bottom_sheet_test.dart`, US-16, US-18 et US-19, et `shell_screen_test.dart`, sprint 19), qui verrouillent des pièges d'état, pas l'apparence —
ne pas en déduire une couverture UI.

| Fichier | Ce qu'il couvre |
|---|---|
| `test/core/revision_engine_test.dart` | Le plus gros (1023 lignes) : construction du cycle, règles A-F du plan quotidien (`docs/SPEC_PRODUIT.md` § « Règle du plan quotidien »), regroupement par page partagée, mélange stable par sourate, apprentissage hors des rakaas sans prière (`outsideLearning`). Verrouille les invariants E1-E6 — les modifier, c'est changer la règle métier, pas corriger un test. |
| `test/core/freshness_engine_test.dart` | Paliers de fraîcheur par verset (`neverRevised`/`sixMonths`/`oneYear`, seuil "récente" 30j). |
| `test/core/streak_engine_test.dart` | Calcul du streak. |
| `test/models/prayer_test.dart` | Modèle `Prayer` (rakaas, imamat). |
| `test/services/ayah_facts_service_test.dart` | Sémantique `reach` (0=visé/1=atteint), `isDaySealed`, requêtes de plan/historique sur `ayah_facts`, `revisionPace` (fenêtres 7 j / 56 j, `reach=0` et autre riwaya ignorés, moyenne divisée par les semaines réellement couvertes). |
| `test/services/ayah_facts_migration_test.dart`, `ayah_facts_migration_v4_test.dart` | Migrations de schéma SQLite. |
| `test/core/reciters_test.dart` | Catalogue de récitateurs (pas de fuite cross-riwaya), URL KSU, disposition des fichiers audio hors connexion. |
| `test/services/audio_download_service_test.dart` | Audio hors connexion sur dossier temporaire (`AudioDownloadService.withRoot`) : source locale vs URL KSU, `.part` jamais compté, sourate complète, poids disque d'un récitateur, file d'intentions (demande bloquée gardée et persistée, dédoublonnage, sourate déjà stockée qui sort sans réseau, suppression sans toucher un récitateur au préfixe proche, demande Warsh sans texte Warsh gardée sans arrêter le passage). Ni le réseau ni le refus hors connexion (pas de plugin de connectivité en test : chaque passage s'arrête sur « pas de Wi-Fi »). |
| `test/state/app_state_checkin_test.dart` | Check-in : `ensureDayPlan` n'écrit rien, `checkInStart`/`commitCheckIn` (brouillon, réouverture, `reach=1` conservé), construction de la journée, répartition en rakaas, cas de regroupement par page partagée, `addableSelections` (sélection seule, hors plan du jour, ordre du mushaf, plage partielle gardée), manche sans prière (plan hors des rakaas, `hasPrayers` faux puis vrai avec une prière, reprise après redémarrage, prières d'hier gardées). |
| `test/state/app_state_learning_test.dart` | Apprentissage : progression verset par verset, hand-off sourate mémorisée → révision, retrait du dernier bloc au check-out avant le hand-off (US-12), filtre `checked_out = 0` de `learnPlanFor` face aux lignes héritées de l'ancien écran de pratique. |
| `test/state/app_state_learning_widen_test.dart` | Hand-off daté (US-29) : plage partielle élargie au scellement du jour de complétion (rattrapage d'un jour passé compris), une seule fois, réglage resserré ou sourate retirée jamais remis un autre jour, sélection déjà entière sans annonce, doublons fusionnés à la place de la première plage, autre riwaya non touchée, curseur qui pointe le même verset avec le mélange activé (Al-Mulk élargie avant le curseur). |
| `test/core/cycle_anchor_test.dart` | `reanchorCursor` en Dart pur : sourate élargie avant le curseur, ajout en fin, cycle vide, et caractérisation du cas rare E2 (page partagée qui se sépare : le fragment voisin est reproposé). |
| `test/state/app_state_day_close_test.dart` | Clôture (US-13/US-14) : `SealOutcome` (sourate mémorisée annoncée une seule fois, tour bouclé + mémorisation réunis dans un seul résultat), `dayRecap` (revu, appris, reliquat, rien d'un autre jour, lisible après scellement). |
| `test/core/reinforcement_engine_test.dart` | Séries de l'onglet Renforcement (US-20), sur les vrais textes Hafs et Warsh avec `Random` à graine fixe : découpe en passages sans perte et seulement aux signes de pause, passages répétés jamais posés, plage partielle jamais dépassée, passage similaire proposé, cinq questions du plan du jour, questions non reposées d'une série à l'autre, sélection trop petite, série sur une sourate qui ignore le plan du jour, `carriedVerses`. |
| `test/state/app_state_reinforcement_test.dart` | `reinforcementInputs` : versets du plan du jour dans `today`, verset proposé à l'apprentissage mais pas encore appris absent de `carried` et de `today`. |
| `test/core/reinforcement_words_test.dart` | Questions de mots et série mêlée (US-22), sur le vrai texte Hafs et les vrais sens CoranMot avec `Random` à graine fixe : mot posé d'au moins 3 lettres, choix aux mots arabes et aux sens tous différents, aucun sens voisin du bon, mot retrouvé à son rang dans le passage, verset sans un sens par mot jamais interrogé, mots non reposés, part du plan du jour, série sur une sourate, série mêlée à 5 et 5 et ses deux replis. Un test (« un même sens est proposé une seule fois ») passe des sens inventés par `glossesOf` : les données réelles ne produisent pas ce cas. Signe « ۞ » (sprint 19) : le mot du passage est le mot posé, ou ce mot précédé du signe et de l'espace insécable, rien d'autre ; sur la sourate 100 seule, aucun choix ne contient le signe, et le premier mot de 100:9 est bien proposé (sans quoi le test ne prouverait rien). |
| `test/services/word_gloss_service_test.dart` | Vrai asset `fr.coranmot.tsv` (US-22) : 77 429 sens, un sens par mot dans chaque verset Hafs sauf exactement sept, deux versets connus recopiés sans retouche (espaces insécables écrites en échappement, ne pas les « corriger »), disponibilité en français et en Hafs seulement. |
| `test/core/app_palette_contrast_test.dart` | Contrastes WCAG des deux palettes (US-25), en Dart pur : texte à 4,5:1, `risk` et `levelTints` à 3:1, sur le fond et sur la carte composée ; `buildAppTheme` porte Outfit. Changer une couleur d'`AppPalette` = relancer ce test. |
| `test/core/day_dates_test.dart` | `daysAgo` : jours entiers quelle que soit l'heure, pas de glissement au changement d'heure. |
| `test/services/translation_service_test.dart` | Vrais fichiers Tanzil (US-19) : chaque verset Hafs a une traduction non vide en français et en anglais, deux textes connus (112:1) attrapent des fichiers inversés, une langue jamais chargée renvoie `null`. |
| `test/widgets/text_scale_fit_test.dart` | Invariant de mise en page (US-31) : à 320×568 avec un texte ×1,5, sur les vraies polices Outfit chargées en `setUpAll` (Ahem fausse les largeurs), `PrimaryCtaButton`, `OutlinedActionButton`, `IndexBadge` à trois chiffres (taille 26, la plus petite de l'app), `FreshnessBadge`, `UnitRangeLabel`, `ProfileInfoCard` (libellé « Rythme » entier), la rangée de `PillChip` de sélection rapide et deux rangées recopiées de `check_in_sections.dart` et `prayer_plan_card.dart` (libellé + bouton, tag + nombre + badge) ne lèvent aucun `RenderFlex overflowed`, et les libellés des boutons et de la pastille tiennent sur une ligne (largeur après mise en page ≥ largeur naturelle : un texte coincé dans une boîte fixe passe à la ligne sans lever d'erreur). Plus `S.blocRange` en Dart pur (U+2060 de chaque côté du tiret, écrit en échappement). Plus `VerseRangeSlider` aux bornes 282-283 et le `VerseRangePicker` entier (sourate de 286 versets, rangée « Tout sélectionner » / « Confirmer » comprise). |
| `test/widgets/verse_list_offset_test.dart` | Piège d'état (US-31 Sprint C), sur Android et iOS : une liste qui raccourcit au repos garde sa position (`VerseBottomSheet.keepOffsetPhysics()`), même après `pumpAndSettle` — un seul `pump` ne voit pas le ressort qui la ramenait ; un glissé la recale à `maxScrollExtent`. Chacune des deux surcharges, retirée seule, fait échouer le test. |
| `test/widgets/verse_range_slider_test.dart` | `nudgeRange` seul (fonction pure, pas de pump de widget) : ±1 bornés à min/max, fin jamais avant le début (US-11). |
| `test/widgets/verse_bottom_sheet_test.dart` | Tests widget. US-16 : la `VerseAudioBar` garde son état après un défilement qui la fait sortir de l'écran puis revenir. US-18 : resserrer la portion masque les versets et l'élargir les réaffiche, l'en-tête garde la plage d'origine, le texte suit la poignée pendant le glissé (avant le relâché), une feuille rouverte repart de la plage entière. US-19 : afficher la traduction ne recrée pas l'état de la `VerseAudioBar`, un verset masqué par la portion ne laisse pas sa traduction, un second appui la retire, une feuille rouverte repart de l'arabe seul, aucun bouton en Warsh. US-31 : le `CustomScrollView` porte la physique qui garde la position. La traduction et `WarshService` se préchargent en `setUpAll` (un gros asset lu dans `testWidgets` ne se termine jamais sous l'horloge simulée). Lire le premier `VerseRow`, ne jamais les compter (liste paresseuse). Le chemin audio (relance de la boucle) n'est pas couvert : pas d'audio en test. Monte la feuille avec le vrai thème (`buildAppTheme`, sinon `context.palette` plante) et `GoogleFonts.config.allowRuntimeFetching = false`. Le premier glissé ne fait qu'agrandir la feuille, d'où plusieurs glissés. Un `SliverList` garde toujours son dernier enfant : seule la barre placée **parmi** les versets reproduit le piège. |
| `test/screens/shell_screen_test.dart` | Test widget (sprint 19). `ShellScreen` sous un `AppState` sans étape guidée : `checkout_done` ouvre le Récap, `recap_seen` ouvre les Réglages, puis un onglet choisi à la main reste après `settings_seen`. Lit le **libellé** de l'onglet sélectionné, jamais son indice : un onglet inséré avant le Récap sans corriger `_recapTab` laisserait l'indice à 2 et le test vert. Trois pièges : `ShellScreen.initState` lance des lectures SQLite qui ne se terminent pas sous l'horloge simulée, le test ne les attend jamais ; la barre glisse à l'entrée (`flutter_animate`), il faut deux `pump` avec durée avant de pouvoir la toucher (le premier lance le glissement, le second le termine) ; `flutter_animate` lance chaque entrée par une minuterie, d'où un `pump` avec durée en fin de test, sinon « A Timer is still pending ». L'`AppState` n'est pas libéré en fin de test : ses lectures sont encore en cours, un `notifyListeners` tardif lèverait. |

Avant de supposer qu'une fonctionnalité n'est pas testée, vérifier cette liste plutôt que
de se fier au seul nom du dossier.

## Lancer les tests
```
flutter test
```

## Comment ces tests tournent (pas de mocks)

Pas de mockito/mocktail dans `pubspec.yaml` — aucun test de service/`AppState` n'en a eu besoin
jusqu'ici. À la place :
- `sqflite_common_ffi` est déjà une **dépendance de prod** (voir `docs/CHANGELOG.md`, décision
  "infra"), donc les tests touchant `AyahFactsService`/`AppState` utilisent le vrai moteur SQLite
  via FFI, pas un mock — voir `test/services/test_helpers.dart`.
- `initFfiTestDb(prefix)` pointe `databaseFactory` vers un répertoire temporaire dédié **par
  fichier de test**. Nécessaire : `flutter test` lance les fichiers dans des process séparés qui
  partagent le même système de fichiers, et le chemin par défaut de `databaseFactoryFfi` est
  identique pour tous — sans ça, deux fichiers en parallèle peuvent lire/écrire la même
  `history.db`.
- `initFfiTestDb` isole les **fichiers** entre eux, pas les **tests d'un même fichier** : ils
  partagent une seule `history.db` par process et plusieurs réutilisent les mêmes dates relatives
  (J-1, J-3...). Appeler `clearFactsBetweenTests()` en `setUp` pour vider `ayah_facts` entre deux
  tests — **sans fermer la connexion** (`openDatabase` renvoie l'instance déjà en cache, la même
  que celle mémorisée par `AyahFactsService._db` ; la fermer laisserait le service sur un handle
  clos au test suivant).
- `HafsService`/`PageMetadataService` sont chargés en vrai (`rootBundle`, vrais JSON
  d'`assets/quran/`) dans `setUpAll` plutôt que mockés — un id de sourate fictif dans un test
  n'aurait donc aucune page et produirait toujours 0 unité. Utiliser des ids réels (1..114).
- `test_helpers.dart` porte `bareWord` (un token coranique sans voyelles ni signes) et `wholeSurahs`
  (une sélection de sourates entières). `bareWord` réécrit la règle du moteur au lieu de
  l'emprunter, exprès : un test doit dire la règle, pas la recopier.
- `WordGlossService.load()` se précharge en `setUpAll`, comme les traductions : c'est un asset de
  1,7 Mo.

## Conventions à suivre
- Miroir de la structure `lib/` : `test/core/revision_engine_test.dart` pour
  `lib/core/revision_engine.dart`, etc.
- Respecter les règles d'architecture du projet (voir `CLAUDE.md`/`docs/DOCUMENTATION_TECHNIQUE.md`) :
  `core/` reste pur Dart, services stateless sans `notifyListeners`, modèles testés via `copyWith`.
- Ne pas écrire de tests widget **d'apparence** tant que le thème/design (Mus'haf/Tahajjud) n'est
  pas stabilisé — préférer les unit tests sur la logique pure d'abord. Exception admise : un test
  widget qui verrouille un piège d'état ou de cycle de vie impossible à tester en Dart pur
  (précédent : `verse_bottom_sheet_test.dart`, US-16). Seconde exception (US-31, validée le
  2026-10-23) : un test d'absence de débordement avec texte agrandi est un invariant de mise en
  page, pas un test d'apparence (`text_scale_fit_test.dart`) — il ne compare aucun rendu.

## Avant de refactorer `RevisionEngine`, `FreshnessEngine` ou `AyahFactsService`
Ces fichiers portent des règles métier fixées au fil de plusieurs sprints (voir
`docs/CHANGELOG.md` et `CLAUDE.md`) et ont désormais un vrai filet de sécurité
(`revision_engine_test.dart`, `freshness_engine_test.dart`, `ayah_facts_service_test.dart`) :
lancer `flutter test` avant/après tout changement plutôt que de se fier à une relecture manuelle,
et ajouter un test de régression si le changement touche un comportement encore non couvert.
