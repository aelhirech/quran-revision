import 'dart:io';

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
