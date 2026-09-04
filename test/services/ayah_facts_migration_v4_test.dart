import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/services/ayah_facts_service.dart';

import 'test_helpers.dart';

/// Régression compagnon d'`ayah_facts_migration_test.dart` : vérifie l'autre
/// bord du garde `oldVersion >= 4 && oldVersion < 5` (`ayah_facts_service.dart`)
/// — un appareil déjà passé par le schéma v4 (colonne `cold`) doit toujours
/// déclencher le backfill vers `needs_work`, pas être sauté par erreur. Fichier
/// séparé du scénario pré-v4 : `AyahFactsService._db` est un singleton
/// process-wide, `flutter test` isole chaque fichier dans son propre process.
void main() {
  setUpAll(() async {
    final tempDir = await initFfiTestDb('qr_test_migration_v4_');

    // Reconstruit le schéma v4 historique (colonne `cold`, pas `needs_work`)
    // avec une ligne où cold=1, pour vérifier que le backfill la reporte.
    final seed = await databaseFactory.openDatabase(
      p.join(tempDir.path, 'history.db'),
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE ayah_facts (
              user_id     TEXT NOT NULL,
              date        TEXT NOT NULL,
              riwaya      TEXT NOT NULL,
              surah_id    INTEGER NOT NULL,
              ayah_id     INTEGER NOT NULL,
              type        TEXT NOT NULL,
              reach       INTEGER NOT NULL DEFAULT 0,
              cold        INTEGER NOT NULL DEFAULT 0,
              checked_out INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.insert('ayah_facts', {
            'user_id': 'local',
            'date': '2020-03-01',
            'riwaya': Riwaya.hafs.name,
            'surah_id': 7,
            'ayah_id': 4,
            'type': 'revise',
            'reach': 0,
            'cold': 1,
            'checked_out': 0,
          });
        },
      ),
    );
    await seed.close();
  });

  test('appareil déjà en v4 (colonne `cold`) : backfill vers `needs_work` préserve les données',
      () async {
    final facts = await AyahFactsService.dayFacts('2020-03-01', Riwaya.hafs);
    expect(facts, hasLength(1));
    expect(facts.first.surahId, 7);
    expect(facts.first.needsWorkVerses, {4},
        reason: 'le backfill `needs_work = cold` doit reporter la valeur existante');
  });
}
