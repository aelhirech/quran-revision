import 'sourate.dart';

/// What sealing a day just unlocked: the rare milestones of US-13. US-14's
/// daily close transition is skipped when one of them is shown instead.
class SealOutcome {
  final bool cycleWrapped;
  final List<Sourate> memorized; // surahs that just moved to revision

  const SealOutcome({required this.cycleWrapped, required this.memorized});

  bool get hasMilestone => cycleWrapped || memorized.isNotEmpty;
}

/// What a sealed day brought (US-14), derived from that day's `ayah_facts`
/// rows. `leftover` = at least one proposed verse stayed at `reach=0`: it
/// comes back tomorrow.
typedef DayRecap = ({List<Sourate> revised, int learnedVerses, bool leftover});
