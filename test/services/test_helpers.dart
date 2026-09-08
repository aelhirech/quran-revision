import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quran_revision/models/revision_unit.dart';
import 'package:quran_revision/models/sourate.dart';

Sourate testSourate(int id, {int verses = 50, int words = 500}) =>
    Sourate(id: id, nameAr: 'س$id', nameFr: 'S$id', verses: verses, words: words);

RevisionUnit testUnit(int surahId, int start, int end) => RevisionUnit(
      sourate: testSourate(surahId),
      verseStart: start,
      verseEnd: end,
      isWhole: false,
    );

/// Initialise le backend sqflite ffi (pas de plugin plateforme en `flutter
/// test`) et pointe vers un répertoire temporaire dédié au fichier de test
/// appelant. Nécessaire pour chaque fichier de test touchant `AyahFactsService` :
/// `flutter test` lance les fichiers dans des process séparés qui partagent
/// le même système de fichiers, et `databaseFactoryFfi.getDatabasesPath()`
/// résout un chemin par défaut identique pour tous — sans répertoire dédié,
/// deux fichiers tournant en parallèle peuvent lire/écrire le même
/// `history.db` et se polluer l'un l'autre.
Future<Directory> initFfiTestDb(String tempDirPrefix) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final tempDir = await Directory.systemTemp.createTemp(tempDirPrefix);
  await databaseFactory.setDatabasesPath(tempDir.path);
  return tempDir;
}

/// Vide `ayah_facts` entre deux tests d'un même fichier. `initFfiTestDb`
/// isole les fichiers de test les uns des autres, pas les tests d'un même
/// fichier : ils partagent une seule `history.db` pour tout le process, et
/// plusieurs réutilisent les mêmes dates relatives (J-1, J-3…). Sans ce
/// nettoyage, un test hérite des lignes — y compris de leur `checked_out` —
/// écrites par le précédent sur la même date.
Future<void> clearFactsBetweenTests() async {
  final path = p.join(await databaseFactory.getDatabasesPath(), 'history.db');
  if (!await databaseFactory.databaseExists(path)) return;
  // `openDatabase` renvoie l'instance déjà en cache pour ce chemin — la même
  // que celle mémorisée par `AyahFactsService._db`. La fermer ici laisserait
  // le service sur un handle clos (`database_closed` au test suivant) : on
  // supprime les lignes et on laisse la connexion ouverte.
  final db = await databaseFactory.openDatabase(path);
  await db.delete('ayah_facts');
}
