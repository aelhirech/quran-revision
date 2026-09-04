import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/services/ayah_facts_service.dart';

import 'test_helpers.dart';

/// Régression sur `AyahFactsService._open()` : sqflite n'appelle `onUpgrade`
/// qu'une seule fois par ouverture, avec l'`oldVersion` d'origine — un
/// appareil resté sur un schéma pré-`ayah_facts` (< 4) traverse donc les
/// blocs `oldVersion < 4` ET `oldVersion < 5` dans le même appel. Le premier
/// bloc crée `ayah_facts` avec le schéma courant (colonne `needs_work`,
/// jamais `cold`) ; sans garde `oldVersion >= 4`, le second tentait quand
/// même `ALTER TABLE ADD COLUMN needs_work` (déjà là) puis
/// `UPDATE ... SET needs_work = cold` (`cold` n'existe pas) — l'app plantait
/// à l'ouverture de la base. Bug trouvé en revue de code Phase 8 Sprint 1,
/// jamais couvert avant (`test/CLAUDE.md` : `onUpgrade` n'était pas testé).
///
/// Un seul test par fichier : `AyahFactsService._db` est un singleton
/// process-wide (`_db ??= ...`) — deux scénarios de migration dans le même
/// fichier partageraient la même base déjà ouverte par le premier test,
/// malgré un `setDatabasesPath` différent pour le second (même piège que
/// documenté dans `ayah_facts_service_test.dart`). `flutter test` lance
/// chaque fichier dans son propre process, donc son propre singleton — c'est
/// la seule façon fiable d'isoler deux scénarios d'ouverture de base.
void main() {
  setUpAll(() async {
    final tempDir = await initFfiTestDb('qr_test_migration_pre4_');

    // Simule un appareil jamais mis à jour depuis avant l'introduction
    // d'ayah_facts : base vide en version 3 (aucune des deux tables, l'IF
    // EXISTS du DROP doit s'en accommoder).
    final seed = await databaseFactory.openDatabase(
      p.join(tempDir.path, 'history.db'),
      options: OpenDatabaseOptions(version: 3, onCreate: (db, _) async {}),
    );
    await seed.close();
  });

  test('appareil pré-ayah_facts (version < 4) : upgrade direct vers 5 ne plante pas', () async {
    // N'importe quel appel public déclenche `_open()` — ne doit pas lever.
    await AyahFactsService.proposeUnits(
        '2020-01-01', Riwaya.hafs, [testUnit(1, 1, 3)]);
    await AyahFactsService.setNeedsWork('2020-01-01', Riwaya.hafs, 1, 2, true);
    final facts = await AyahFactsService.dayFacts('2020-01-01', Riwaya.hafs);
    expect(facts, hasLength(1));
    expect(facts.first.needsWorkVerses, {2});
  });
}
