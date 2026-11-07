import '../models/revision_unit.dart';

/// Index in [newCycle] of the entry holding the first verse of
/// [oldCycle]`[oldPos]`, or `null` if [oldCycle] is empty or that verse is
/// gone. Anchored on a verse because the same index can name another page
/// once the selection changes.
int? reanchorCursor(
  List<List<RevisionUnit>> oldCycle,
  int oldPos,
  List<List<RevisionUnit>> newCycle,
) {
  if (oldCycle.isEmpty) return null;
  final anchor = oldCycle[oldPos].first;
  for (int i = 0; i < newCycle.length; i++) {
    for (final unit in newCycle[i]) {
      if (unit.sourate.id == anchor.sourate.id &&
          unit.verseStart <= anchor.verseStart &&
          anchor.verseStart <= unit.verseEnd) {
        return i;
      }
    }
  }
  return null;
}
