# test/ — notes pour Claude

## État actuel

Couverture réelle depuis Phase 9 (2026-09-08+), concentrée sur les moteurs et modèles les plus
sensibles. `widget_test.dart` reste un placeholder (`expect(true, isTrue)`). Un seul vrai test de
widget (`verse_bottom_sheet_test.dart`, US-16), qui verrouille un piège d'état, pas l'apparence —
ne pas en déduire une couverture UI.

| Fichier | Ce qu'il couvre |
|---|---|
| `test/core/revision_engine_test.dart` | Le plus gros (1023 lignes) : construction du cycle, règles A-F du plan quotidien (`CLAUDE.md` § « Règle du plan quotidien »), regroupement par page partagée, mélange stable par sourate. Verrouille les invariants E1-E6 — les modifier, c'est changer la règle métier, pas corriger un test. |
| `test/core/freshness_engine_test.dart` | Paliers de fraîcheur par verset (`neverRevised`/`sixMonths`/`oneYear`, seuil "récente" 30j). |
| `test/core/streak_engine_test.dart` | Calcul du streak. |
| `test/models/prayer_test.dart` | Modèle `Prayer` (rakaas, imamat). |
| `test/services/ayah_facts_service_test.dart` | Sémantique `reach` (0=visé/1=atteint), `isDaySealed`, requêtes de plan/historique sur `ayah_facts`, `revisionPace` (fenêtres 7 j / 56 j, `reach=0` et autre riwaya ignorés, moyenne divisée par les semaines réellement couvertes). |
| `test/services/ayah_facts_migration_test.dart`, `ayah_facts_migration_v4_test.dart` | Migrations de schéma SQLite. |
| `test/core/reciters_test.dart` | Catalogue de récitateurs (pas de fuite cross-riwaya), URL KSU, disposition des fichiers audio hors connexion. |
| `test/services/audio_download_service_test.dart` | Audio hors connexion sur dossier temporaire (`AudioDownloadService.withRoot`) : source locale vs URL KSU, `.part` jamais compté, sourate complète, poids disque d'un récitateur, file d'intentions (demande bloquée gardée et persistée, dédoublonnage, sourate déjà stockée qui sort sans réseau, suppression sans toucher un récitateur au préfixe proche). Ni le réseau ni le refus hors connexion (pas de plugin de connectivité en test : chaque passage s'arrête sur « pas de Wi-Fi »). |
| `test/state/app_state_checkin_test.dart` | Check-in : construction de la journée, répartition en rakaas, cas de regroupement par page partagée. |
| `test/state/app_state_learning_test.dart` | Apprentissage : progression verset par verset, hand-off sourate mémorisée → révision, retrait du dernier bloc au check-out avant le hand-off (US-12), filtre `checked_out = 0` de `learnPlanFor` face aux lignes héritées de l'ancien écran de pratique. |
| `test/state/app_state_day_close_test.dart` | Clôture (US-13/US-14) : `SealOutcome` (sourate mémorisée annoncée une seule fois, tour bouclé + mémorisation réunis dans un seul résultat), `dayRecap` (revu, appris, reliquat, rien d'un autre jour, lisible après scellement). |
| `test/core/day_dates_test.dart` | `daysAgo` : jours entiers quelle que soit l'heure, pas de glissement au changement d'heure. |
| `test/widgets/verse_range_slider_test.dart` | `nudgeRange` seul (fonction pure, pas de pump de widget) : ±1 bornés à min/max, fin jamais avant le début (US-11). |
| `test/widgets/verse_bottom_sheet_test.dart` | Test widget (US-16) : la `VerseAudioBar` garde son état et sa portion US-11 après un défilement qui la fait sortir de l'écran puis revenir. Monte la feuille avec le vrai thème (`buildAppTheme`, sinon `context.palette` plante) et `GoogleFonts.config.allowRuntimeFetching = false`. Le premier glissé ne fait qu'agrandir la feuille, d'où plusieurs glissés. Un `SliverList` garde toujours son dernier enfant : seule la barre placée **parmi** les versets reproduit le piège. |

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

## Conventions à suivre
- Miroir de la structure `lib/` : `test/core/revision_engine_test.dart` pour
  `lib/core/revision_engine.dart`, etc.
- Respecter les règles d'architecture du projet (voir `CLAUDE.md`/`docs/DOCUMENTATION_TECHNIQUE.md`) :
  `core/` reste pur Dart, services stateless sans `notifyListeners`, modèles testés via `copyWith`.
- Ne pas écrire de tests widget **d'apparence** tant que le thème/design (Mus'haf/Tahajjud) n'est
  pas stabilisé — préférer les unit tests sur la logique pure d'abord. Exception admise : un test
  widget qui verrouille un piège d'état ou de cycle de vie impossible à tester en Dart pur
  (précédent : `verse_bottom_sheet_test.dart`, US-16).

## Avant de refactorer `RevisionEngine`, `FreshnessEngine` ou `AyahFactsService`
Ces fichiers portent des règles métier fixées au fil de plusieurs sprints (voir
`docs/CHANGELOG.md` et `CLAUDE.md`) et ont désormais un vrai filet de sécurité
(`revision_engine_test.dart`, `freshness_engine_test.dart`, `ayah_facts_service_test.dart`) :
lancer `flutter test` avant/après tout changement plutôt que de se fier à une relecture manuelle,
et ajouter un test de régression si le changement touche un comportement encore non couvert.
