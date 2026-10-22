import 'learning_progress.dart';
import 'revision_unit.dart';

/// Today's plan while the user adjusts it at check-in. Held in the screen's
/// `State` and written to `ayah_facts` only when the check-in is validated
/// (`AppState.commitCheckIn`), so a check-in left unvalidated leaves no trace.
/// The surah being learned and the verses proposed today (not necessarily
/// contiguous).
typedef LearningDraft = ({LearningProgress progress, List<int> ayahIds});

class CheckInDraft {
  final List<RevisionUnit> units;
  final LearningDraft? learning;

  const CheckInDraft({required this.units, this.learning});

  /// First..last of the block, which isn't necessarily contiguous.
  RevisionUnit? get learningUnit {
    final l = learning;
    if (l == null || l.ayahIds.isEmpty) return null;
    return RevisionUnit.spanning(
        l.progress.sourate, l.ayahIds.first, l.ayahIds.last);
  }

  CheckInDraft withUnits(List<RevisionUnit> next) =>
      CheckInDraft(units: next, learning: learning);

  CheckInDraft withLearning(LearningDraft? next) =>
      CheckInDraft(units: units, learning: next);

  CheckInDraft without(RevisionUnit unit) =>
      withUnits([for (final u in units) if (u != unit) u]);

  /// Kept in mushaf order, like the rows read back from `ayah_facts`.
  CheckInDraft adding(RevisionUnit unit) => withUnits([...units, unit]
    ..sort((a, b) {
      final bySourate = a.sourate.id.compareTo(b.sourate.id);
      return bySourate != 0 ? bySourate : a.verseStart.compareTo(b.verseStart);
    }));

  CheckInDraft replacing(RevisionUnit from, RevisionUnit to) =>
      withUnits([for (final u in units) u == from ? to : u]);
}
