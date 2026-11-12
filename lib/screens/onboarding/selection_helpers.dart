part of 'onboarding_screen.dart';

/// Ids des sourates que sélectionnerait `_quickSelect(fraction)`, sans
/// muter l'état — sert à la fois à l'appliquer et à détecter si la
/// sélection actuelle y correspond déjà.
Set<int> _quickSelectionIds(double fraction, List<Sourate> allSourates) {
  if (fraction >= 1.0) return allSourates.map((s) => s.id).toSet();
  final total = allSourates.fold(0, (sum, s) => sum + s.verses);
  final target = (total * fraction).round();
  final ids = <int>{};
  int count = 0;
  for (final s in allSourates.reversed) {
    if (count >= target) break;
    ids.add(s.id);
    count += s.verses;
  }
  return ids;
}

List<Object> _groupedBy(List<Sourate> sourates, int Function(Sourate) key) {
  final result = <Object>[];
  int? currentGroup;
  for (final s in sourates) {
    final group = key(s);
    if (group != currentGroup) {
      currentGroup = group;
      result.add(group);
    }
    result.add(s);
  }
  return result;
}
