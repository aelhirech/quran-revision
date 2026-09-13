part of '../onboarding_screen.dart';

/// Real preview of the first day's plan (US-1 criterion 4) — derived from
/// the REAL selection/pace already held by `_OnboardingScreenState`, never
/// persisted before `_confirm()`. Recomputed fresh on every `build()`
/// (StatelessWidget, not cached) because the wizard's `PageView` builds all
/// pages eagerly and keeps this widget's State across rebuilds — caching the
/// units in `initState` would freeze them at whatever the selection was on
/// the very first build (typically empty), never reflecting later edits.
///
/// Shows the list of day-1 surahs/portions, not a rakaa layout: onboarding
/// doesn't know the day's prayers yet (that only happens at check-in) —
/// faking prayers here would contradict "real preview" (criterion adjustment
/// confirmed by the user at scoping, 2026-09-13).
class _PreviewPage extends StatelessWidget {
  final Map<int, SourateSelection> selections;
  final int pagesPerDay;
  final Riwaya riwaya;
  final VoidCallback onNext;

  const _PreviewPage({
    required this.selections,
    required this.pagesPerDay,
    required this.riwaya,
    required this.onNext,
  });

  List<RevisionUnit> get _units {
    final config = UserConfig(
      selections: selections.values.toList(),
      pagesPerDay: pagesPerDay,
      startDate: DateTime.now(),
      riwaya: riwaya,
    );
    return _dayUnitsFor(config).units;
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingListStep(
      title: S.previewTitle,
      subtitle: S.previewSubtitle,
      ctaLabel: S.continuer,
      onCta: onNext,
      children: [
        for (final unit in _units)
          UnitRow(
            unit: unit,
            subtitle: '${unit.verseCount} ${S.versets}',
          ),
      ],
    );
  }
}
