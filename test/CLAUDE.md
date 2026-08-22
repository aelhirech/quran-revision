# test/ — notes pour Claude

## État actuel
Aucune couverture réelle. `widget_test.dart` est un placeholder (`expect(true, isTrue)`) qui ne teste rien de l'app. Ne pas supposer qu'une fonctionnalité est testée sous prétexte que le dossier existe.

## Lancer les tests
```
flutter test
```

## Priorités si on écrit des tests
- `lib/core/revision_engine.dart` — le plus critique : construction du plan du jour, répétition cyclique (pas de rakaas vides), règle no-repeat sourate par prière (Sprint 6). Pur Dart, zéro import Flutter, zéro I/O → unit tests simples, pas besoin de `WidgetTester`/`TestWidgetsFlutterBinding`.
- `lib/core/freshness_engine.dart` — calcul fraîcheur/froid des sourates (SRS léger).
- `lib/services/*.dart` — nécessitent de mocker les I/O :
  - `SharedPreferences.setMockInitialValues({})` pour storage
  - sqflite (`history_service.dart`) n'a pas de lib de mock installée ; ajouter `sqflite_common_ffi` en dev_dependency serait nécessaire avant d'écrire ces tests.
- Aucune lib de mock (mockito/mocktail) n'est dans `pubspec.yaml` — à ajouter seulement si des tests de services/`AppState` en ont réellement besoin.

## Conventions à suivre
- Miroir de la structure `lib/` : `test/core/revision_engine_test.dart` pour `lib/core/revision_engine.dart`, etc.
- Respecter les règles d'architecture du projet (voir `docs/DOCUMENTATION_TECHNIQUE.md`) : `core/` reste pur Dart, services stateless sans `notifyListeners`, modèles testés via `copyWith`.
- Ne pas écrire de tests widget tant que le thème/design (Mus'haf/Tahajjud, `bf47184`) n'est pas stabilisé — préférer les unit tests sur la logique pure d'abord.

## Avant de refactorer `RevisionEngine` ou `FreshnessEngine`
Ces fichiers portent des règles métier fixées au fil de plusieurs sprints (voir `CHANGELOG.md` et `docs/DOCUMENTATION_TECHNIQUE.md`) et n'ont aucun filet de sécurité. Écrire des tests de régression sur le comportement actuel avant tout changement, plutôt que de faire confiance à une relecture manuelle.
